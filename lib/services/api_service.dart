import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Render Proxy — tüm API çağrıları proxy üzerinden geçer (proje şeması gereği)
  static const String _renderBase = 'https://samsun-gtfs-rt.onrender.com/api';

  // API'den gelen bozuk Türkçe karakterleri düzelten harita
  static final Map<String, String> _turkishCharacterFixes = {
    '¦': 'İ', '‹': 'İ', 'Ý': 'İ',
    '▄': 'Ü',
    'Ì': 'Ş', '™': 'Ş', 'Þ': 'Ş',
    'Ã': 'Ç', '˙': 'Ç', 'Æ': 'Ç',
    'º': 'Ğ', '°': 'Ğ', 'Ð': 'Ğ',
    'Í': 'Ö', 'Ô': 'Ö',
    'ý': 'ı', '²': 'ı',
    'Ó': 'ö',
    'ã': 'ü',
    'þ': 'ş', '³': 'ş',
    'ð': 'ğ', 'Ï': 'ğ',
    '®': 'ç', 'æ': 'ç',
  };

  static final List<String> _skipKeywords = [
    'OTOPARK', 'KENT MÜZESİ', 'GÖREVLİ', 'BAŞVURU', 'İADE', 'IADE',
    'SAMULAŞ - AKTARMA', 'BANDIRMA VAPURU', 'AMAZON KÖYÜ'
  ];

  // ─────────────────────────────────────────────────────────────
  // Yardımcı metodlar
  // ─────────────────────────────────────────────────────────────

  /// ASIS API yanıtından veri listesini güvenli şekilde çıkarır.
  /// ASIS bazen düz liste, bazen {"data": [...]} döner.
  static List<dynamic> _extractDataList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      final inner = decoded['data'];
      return inner is List ? inner : [inner];
    }
    return [decoded];
  }

  static String _fixAndCleanText(String text) {
    String fixedText = text;
    _turkishCharacterFixes.forEach((key, value) {
      fixedText = fixedText.replaceAll(key, value);
    });
    return fixedText.trim();
  }

  /// Ortak GET isteği — tüm proxy çağrıları bu üzerinden geçer
  static Future<http.Response?> _proxyGet(String url, {int timeoutSec = 12}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'samsun_ulasim/2.0',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: timeoutSec));
      return response;
    } catch (e) {
      debugPrint('proxyGet hata [$url]: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Durağa yaklaşan araçlar  →  /api/proxy/smart_stations
  // ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getDuragaYaklasanAraclar(String stopId) async {
    final url = '$_renderBase/proxy/smart_stations?stationId=$stopId';
    final response = await _proxyGet(url);

    if (response == null) {
      throw Exception('Bağlantı Hatası: İnternet bağlantınızı kontrol edin.');
    }
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is List) return _cleanSmartStationData(data);
    }
    return [];
  }

  static List<dynamic> _cleanSmartStationData(List<dynamic> data) {
    List<dynamic> cleaned = [];
    for (var item in data) {
      if (item is Map<String, dynamic> && item.containsKey('BusLineCode')) {
        String busLineCode = _fixAndCleanText(item['BusLineCode'] as String);
        bool shouldSkip =
            _skipKeywords.any((kw) => busLineCode.toUpperCase().contains(kw));
        if (shouldSkip) continue;
        item['BusLineCode'] = busLineCode;
        cleaned.add(item);
      }
    }
    return cleaned;
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Hattaki canlı araçlar  →  /api/hat/arac/{lineCode}
  //    Fallback               →  /api/proxy/realtime
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getHattakiAraclar(
      String lineCode) async {
    // 1. Akıllı eşleştirmeli endpoint (tramvay, samair vb. için)
    final url1 =
        '$_renderBase/hat/arac/${Uri.encodeComponent(lineCode)}';
    final r1 = await _proxyGet(url1);
    if (r1 != null && r1.statusCode == 200 && r1.bodyBytes.isNotEmpty) {
      final data = json.decode(utf8.decode(r1.bodyBytes));
      if (data is List) return _parseRealTimeData(data, lineCode);
    }

    // 2. Fallback: basit proxy/realtime
    final url2 =
        '$_renderBase/proxy/realtime?lineCode=${Uri.encodeComponent(lineCode)}';
    final r2 = await _proxyGet(url2, timeoutSec: 10);
    if (r2 != null && r2.statusCode == 200 && r2.bodyBytes.isNotEmpty) {
      final data = json.decode(utf8.decode(r2.bodyBytes));
      if (data is List) return _parseRealTimeData(data, lineCode);
    }

    throw Exception(
        'Araç Takip Başarısız — İnternet bağlantınızı kontrol edin.');
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Hat durakları  →  /api/proxy/stops_stations
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getHatDuraklari(
      String lineCode) async {
    final url =
        '$_renderBase/proxy/stops_stations?lineCode=${Uri.encodeComponent(lineCode)}';
    final response = await _proxyGet(url);

    if (response == null) {
      throw Exception('Bağlantı Hatası: İnternet bağlantınızı kontrol edin.');
    }
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final list = _extractDataList(decoded);
      return list.map((item) {
        if (item is Map<String, dynamic>) {
          return {
            'stopId':   (item['stopId']   ?? item['DurakId']   ?? '').toString(),
            'stopName': _fixAndCleanText(
                (item['stopName'] ?? item['DurakAdi'] ?? '').toString()),
            'orderId':  (item['orderId']  ?? item['SiraNo']    ?? '').toString(),
            'latitude': (item['latitude'] ?? item['Enlem']     ?? '').toString(),
            'longitude':(item['longitude']?? item['Boylam']    ?? '').toString(),
          };
        }
        return <String, dynamic>{};
      }).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Hat yönleri  →  /api/proxy/line_directions
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getHatYonleri(
      String lineCode) async {
    final url =
        '$_renderBase/proxy/line_directions?lineCode=${Uri.encodeComponent(lineCode)}';
    final response = await _proxyGet(url);

    if (response == null) {
      throw Exception('Bağlantı Hatası: İnternet bağlantınızı kontrol edin.');
    }
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final list = _extractDataList(decoded);
      return list.map((item) {
        if (item is Map<String, dynamic>) {
          return {
            'direction': (item['Direction'] ?? item['Yon']      ?? '').toString(),
            'lineCode':  _fixAndCleanText(
                (item['lineCode']  ?? item['HatKodu']  ?? lineCode).toString()),
            'lineNo':    (item['lineNo']    ?? item['HatNo']    ?? '').toString(),
            'stopName':  _fixAndCleanText(
                (item['stopName']  ?? item['DurakAdi'] ?? '').toString()),
            'orderId':   (item['orderId']   ?? item['SiraNo']   ?? '').toString(),
            'stopId':    (item['durakId']   ?? item['DurakId']  ?? '').toString(),
          };
        }
        return <String, dynamic>{};
      }).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Hat saatleri (tarife)  →  /api/proxy/schedules
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getHatSaatleri(
      String lineCode, {DateTime? date}) async {
    final scheduleDate = (date ?? DateTime.now())
        .toIso8601String()
        .substring(0, 10); // yyyy-MM-dd
    final dateParam = '${scheduleDate}T00:00:00';

    final url =
        '$_renderBase/proxy/schedules'
        '?lineCode=${Uri.encodeComponent(lineCode)}'
        '&scheduleDate=${Uri.encodeComponent(dateParam)}';
    final response = await _proxyGet(url);

    if (response == null) {
      throw Exception('Bağlantı Hatası: İnternet bağlantınızı kontrol edin.');
    }
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final list = _extractDataList(decoded);
      return list.map((item) {
        if (item is Map<String, dynamic>) {
          return {
            'lineCode': _fixAndCleanText(
                (item['hatkodu']      ?? item['cizelgekodu'] ?? lineCode).toString()),
            'time':     (item['saat']         ?? item['Saat']        ?? '').toString(),
            'direction':(item['yon']           ?? item['Yon']         ?? '').toString(),
          };
        }
        return <String, dynamic>{};
      }).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────
  // RealTimeData parse
  // ─────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _parseRealTimeData(
      List<dynamic> data, String lineCode) {
    List<Map<String, dynamic>> vehicles = [];
    for (var item in data) {
      if (item is Map<String, dynamic>) {
        final lat = double.tryParse(
                (item['lat'] ?? item['enlem'] ?? item['Lat'] ??
                 item['Latitude'] ?? item['Enlem'] ?? '0').toString()) ??
            0.0;
        final lon = double.tryParse(
                (item['lon'] ?? item['boylam'] ?? item['Lng'] ??
                 item['Longitude'] ?? item['Boylam'] ?? '0').toString()) ??
            0.0;
        // Samsun koordinat sınırı
        if (lat > 40 && lat < 43 && lon > 34 && lon < 38) {
          vehicles.add({
            'lat': lat,
            'lon': lon,
            'plate': (item['plate']  ?? item['plaka']  ?? item['PlateNumber'] ?? item['Plaka'] ?? '').toString(),
            'speed': (item['speed']  ?? item['hiz']    ?? item['Speed']       ?? item['Hizi']  ?? '0').toString(),
            'lineCode': _fixAndCleanText(
                (item['lineCode'] ?? item['HatKodu'] ?? item['LineCode'] ?? lineCode).toString()),
            'gunlukYolcu':   (item['gunlukYolcu']   ?? item['GunlukYolcuSayisi'] ?? item['DailyPassenger']  ?? item['GunlukYolcu']  ?? '0').toString(),
            'seferYolcu':    (item['seferYolcu']    ?? item['SeferYolcuSayisi']  ?? item['TripPassenger']   ?? item['SeferYolcu']   ?? '0').toString(),
            'toplamHasilat': (item['toplamHasilat'] ?? item['ToplamHasilat']     ?? item['TotalRevenue']    ?? item['Hasilat']      ?? '0').toString(),
            'maxHiz':        (item['maxHiz']        ?? item['MaxHiz']            ?? item['MaxSpeed']        ?? item['MaksimumHiz']  ?? '0').toString(),
            'yon':           (item['yon']           ?? item['Yon']               ?? item['Direction']       ?? item['Yonu']         ?? '0').toString(),
            'mesafe':        (item['mesafe']        ?? item['Mesafe']            ?? item['TotalDistance']   ?? item['ToplamMesafe'] ?? '0').toString(),
            'lastUpdate':    (item['lastUpdate']    ?? item['editDate']          ?? item['tarih']           ??
                              item['LastLocationTime'] ?? item['SonKonumZamani'] ?? '').toString(),
            'yakin': item['yakin'],
          });
        }
      }
    }
    return vehicles;
  }

  // ─────────────────────────────────────────────────────────────
  // Test erişim metodları (unit test desteği)
  // ─────────────────────────────────────────────────────────────
  @visibleForTesting
  static List<dynamic> extractDataListForTest(dynamic decoded) =>
      _extractDataList(decoded);
  @visibleForTesting
  static List<Map<String, dynamic>> parseRealTimeDataForTest(
          List<dynamic> data, String lineCode) =>
      _parseRealTimeData(data, lineCode);
  @visibleForTesting
  static List<dynamic> cleanSmartStationDataForTest(List<dynamic> data) =>
      _cleanSmartStationData(data);
  @visibleForTesting
  static String fixAndCleanTextForTest(String text) => _fixAndCleanText(text);
}
