import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class RouteService {
  static const String otpBaseUrl = 'https://seeds-humanity-visitors-approx.trycloudflare.com/otp/routers/default/plan';

  /// Metin tabanlı (ör. 'Atakum') adresi Koordinata çevirir (Nominatim)
  static Future<LatLng?> geocodeAddress(String query) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}+Samsun&format=json&limit=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'samsun_ulasim/2.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'] ?? '') ?? 0.0;
          final lon = double.tryParse(data[0]['lon'] ?? '') ?? 0.0;
          if (lat != 0 && lon != 0) return LatLng(lat, lon);
        }
      }
    } catch (e) {
      debugPrint('Geocoding hatası: $e');
    }
    return null;
  }

  /// OpenTripPlanner'dan Rota Çeker
  static Future<List<Map<String, dynamic>>> getOTPRoute(double startLat, double startLon, double destLat, double destLon) async {
    final url = Uri.parse('$otpBaseUrl?fromPlace=$startLat,$startLon&toPlace=$destLat,$destLon&mode=TRANSIT,WALK&maxWalkDistance=1000');
    
    try {
      final response = await http.get(url, headers: {'User-Agent': 'samsun_ulasim/2.0'}).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['plan'] != null && data['plan']['itineraries'] != null) {
          final itineraries = data['plan']['itineraries'] as List;
          List<Map<String, dynamic>> results = [];
          
          for (var i = 0; i < itineraries.length; i++) {
            final itinerary = itineraries[i];
            final duration = (itinerary['duration'] as num?)?.toInt() ?? 0; // saniye
            final durationMin = (duration / 60).round();
            
            final legs = itinerary['legs'] as List;
            List<LatLng> fullPolyline = [];
            String desc = "$durationMin dk (";
            List<String> modes = [];
            
            for (var leg in legs) {
              final mode = leg['mode'];
              final route = leg['route'];
              if (mode == 'WALK') {
                modes.add('Yürüme');
              } else if (mode == 'BUS' || mode == 'TRAM') {
                modes.add(route ?? mode);
              }
              
              if (leg['legGeometry'] != null && leg['legGeometry']['points'] != null) {
                final encoded = leg['legGeometry']['points'];
                fullPolyline.addAll(_decodePolyline(encoded));
              }
            }
            desc += "${modes.join(' > ')})";
            
            results.add({
              'desc': desc,
              'duration': durationMin,
              'polyline': fullPolyline.map((p) => [p.latitude, p.longitude]).toList(), // UI array formatı istiyor
            });
          }
          return results;
        }
      }
    } catch (e) {
      debugPrint('OTP Route hatası: $e');
    }
    return [];
  }

  /// Google Encoded Polyline Algorithm
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
