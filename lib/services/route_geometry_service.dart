import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:samsun_ulasim/constants.dart';

/// Duraklar arası yol geometrisini OSRM API ile çeken servis.
/// Kuş uçuşu çizgi yerine gerçek yol güzergahını döndürür.
class RouteGeometryService {
  // Sonuçları bellekte önbellekle (hat kodu → polyline)
  static final Map<String, List<LatLng>> _cache = {};

  /// Verilen durak listesi için yol takip eden polyline döndürür.
  /// Duraklar [{lat, lon, ...}, ...] formatında olmalı.
  /// Önce önbellekte arar, yoksa OSRM API'den çeker.
  static Future<List<LatLng>> getRoutePolyline(
    String cacheKey,
    List<Map<String, dynamic>> duraklar,
  ) async {
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final coords = duraklar
        .where((d) =>
            (d['lat'] as num?)?.toDouble() != null &&
            (d['lat'] as num).toDouble() > 0)
        .map((d) => LatLng(
              (d['lat'] as num).toDouble(),
              (d['lon'] as num).toDouble(),
            ))
        .toList();

    if (coords.length < 2) return coords;

    // Çok fazla waypoint olursa OSRM'ye parçalara bölerek gönder (max ~100)
    try {
      final routePoints = await _fetchOsrmRoute(coords);
      if (routePoints.isNotEmpty) {
        _cache[cacheKey] = routePoints;
        return routePoints;
      }
    } catch (e) {
      debugPrint('OSRM yol geometrisi hatası: $e');
    }

    // Fallback: Kuş uçuşu (orijinal davranış)
    _cache[cacheKey] = coords;
    return coords;
  }

  /// OSRM match API ile sıralı waypoint'ler arasında yol geometrisi çeker.
  static Future<List<LatLng>> _fetchOsrmRoute(List<LatLng> waypoints) async {
    // OSRM URL'de 100 waypoint limiti var, gerekirse parçala
    if (waypoints.length > 80) {
      return _fetchOsrmRouteChunked(waypoints);
    }

    final coordStr = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    final url = Uri.parse(
      '$osrmBaseUrl/route/v1/driving/$coordStr'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(url, headers: {
      'User-Agent': 'samsun_ulasim/2.0',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
        final geometry = data['routes'][0]['geometry'];
        if (geometry != null && geometry['coordinates'] != null) {
          final coords = geometry['coordinates'] as List;
          return coords
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
        }
      }
    }

    return [];
  }

  /// 80+ waypoint için parçalara bölüp birleştir
  static Future<List<LatLng>> _fetchOsrmRouteChunked(List<LatLng> waypoints) async {
    const chunkSize = 60;
    List<LatLng> fullRoute = [];

    for (int i = 0; i < waypoints.length; i += chunkSize - 1) {
      final end = math.min(i + chunkSize, waypoints.length);
      final chunk = waypoints.sublist(i, end);
      if (chunk.length < 2) continue;

      final chunkRoute = await _fetchOsrmRoute(chunk);
      if (chunkRoute.isNotEmpty) {
        // İlk parça dışında, birleşme noktası duplikasyonunu önle
        if (fullRoute.isNotEmpty && chunkRoute.isNotEmpty) {
          fullRoute.addAll(chunkRoute.sublist(1));
        } else {
          fullRoute.addAll(chunkRoute);
        }
      } else {
        // OSRM başarısız olduysa kuş uçuşu ekle
        fullRoute.addAll(chunk);
      }
    }

    return fullRoute;
  }

  /// Önbelleği temizle
  static void clearCache() => _cache.clear();
}
