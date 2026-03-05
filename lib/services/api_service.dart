import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Samsun Ulaşım — API Servisi v2.5
///
/// Tüm API çağrıları Render proxy üzerinden geçer:
///   https://samsun-gtfs-rt.onrender.com/api
///
/// Endpoint haritası:
///   /api/proxy/smart_stations    → ASIS SmartStations
///   /api/proxy/realtime          → ASIS RealTimeData          (fallback)
///   /api/proxy/stops_stations    → ASIS StopsStations
///   /api/proxy/line_directions   → ASIS LineDirections        (sunucu filtresi bozuk, proxy filtreler)
///   /api/proxy/schedules         → ASIS Schedules             (tarih parametresi etkisiz)
///   /api/proxy_odak              → YBS odakSamsun_Crud
///   /api/proxy_odak_araclar      → YBS AraclarList
///   /api/proxy_samair_saatler    → YBS samair_ucaksefersaatleri_public
///   /api/proxy_samair_araclar    → YBS samair_duraklar_public
///   /api/hat/*                   → Render DB (SQLite önbellekli)
///   /api/odak/*                  → Render DB
///   /api/samair/*                → Render DB
///
class ApiService {
  static const String _base = 'https://samsun-gtfs-rt.onrender.com/api';

  // ─────────────────────────────────────────────────────────────
  // API'den gelen bozuk Türkçe karakterler (Windows-1254 artifact)
  // ─────────────────────────────────────────────────────────────
  static final Map<String, String> _trFix = {
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

  /// SmartStations sonuçlarından çıkarılacak hat kodları
  static final List<String> _skipKeywords = [
    'OTOPARK', 'KENT MÜZESİ', 'GÖREVLİ', 'BAŞVURU',
    'İADE', 'IADE', 'SAMULAŞ - AKTARMA', 'BANDIRMA VAPURU', 'AMAZON KÖYÜ',
  ];

  // ─────────────────────────────────────────────────────────────
  // Yardımcılar
  // ─────────────────────────────────────────────────────────────

  static String _fix(String text) {
    String t = text;
    _trFix.forEach((k, v) => t = t.replaceAll(k, v));
    return t.trim();
  }

  /// null-safe string + Türkçe karakter düzeltme
  static String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : _fix(v.toString());

  /// Proxy GET — tüm istek gövdesi buradan geçer
  static Future<http.Response?> _get(String url, {int timeoutSec = 12}) async {
    try {
      return await http
          .get(Uri.parse(url), headers: {
            'User-Agent': 'samsun_ulasim/2.5',
            'Accept': 'application/json',
          })
          .timeout(Duration(seconds: timeoutSec));
    } catch (e) {
      debugPrint('ApiService._get hata [$url]: $e');
      return null;
    }
  }

  /// ASIS yanıtından liste çıkarır.
  /// ASIS bazen {"statusCode":200,"data":[...]} bazen düz liste döndürür.
  static List<dynamic> _list(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final inner = decoded['data'];
      if (inner is List) return inner;
      if (inner != null) return [inner];
    }
    return [];
  }

  /// Araç listesini parse eder — hat/arac + proxy/realtime için ortak.
  ///
  /// Gerçek ASIS RealTimeData alan adları (test ile doğrulandı):
  ///   plaka, enlem, boylam, hiz, yon (0-360 derece pusula),
  ///   seferYolcu, gunlukYolcu, toplamHasilat, maxHiz,
  ///   mesafe, editDate, HatKodu, renk
  static List<Map<String, dynamic>> _parseVehicles(
      List<dynamic> data, String lineCode) {
    final result = <Map<String, dynamic>>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;

      final lat = double.tryParse(
            _s(item['lat'] ?? item['enlem'] ?? item['Lat'] ??
               item['Latitude'] ?? item['Enlem'], '0')) ?? 0.0;
      final lon = double.tryParse(
            _s(item['lon'] ?? item['boylam'] ?? item['Lng'] ??
               item['Longitude'] ?? item['Boylam'], '0')) ?? 0.0;

      if (lat < 40 || lat > 43 || lon < 34 || lon > 38) continue;

      result.add({
        'lat':           lat,
        'lon':           lon,
        'plate':         _s(item['plate']  ?? item['plaka']  ?? item['Plaka']),
        'speed':         _s(item['speed']  ?? item['hiz']    ?? item['Hizi'], '0'),
        'lineCode':      _s(item['lineCode'] ?? item['HatKodu'] ?? lineCode),
        // yon: 0-360 pusula (0=K, 90=D, 180=G, 270=B)
        'bearing':       _s(item['yon']    ?? item['Yon'], '0'),
        'seferYolcu':    _s(item['seferYolcu']    ?? item['SeferYolcu'],    '0'),
        'gunlukYolcu':   _s(item['gunlukYolcu']   ?? item['GunlukYolcu'],   '0'),
        'toplamHasilat': _s(item['toplamHasilat'] ?? item['ToplamHasilat'], '0'),
        'maxHiz':        _s(item['maxHiz']        ?? item['MaxHiz'],        '0'),
        'mesafe':        _s(item['mesafe']        ?? item['Mesafe'],        '0'),
        'lastUpdate':    _s(item['editDate'] ?? item['tarih'] ?? item['lastUpdate']),
        // hat/arac endpoint'inden gelirse yakin durak bilgisi olabilir
        'yakin':         item['yakin'],
      });
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. DURAĞA YAKLAŞAN ARAÇLAR (SmartStations)
  //    GET /api/proxy/smart_stations?stationId={id}
  //
  //    Alanlar: BusLineCode, BusLineNo, BusLineShortName, panelId,
  //    RemainingTimeCurr, RemainingTimeNext, IsAccordingToTimeSchedule,
  //    BusStatusCurr, BusStatusNext, distance,
  //    RemainingNumberOfBusStops, latitude, longitude, speed, direction
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getDuragaYaklasanAraclar(
      String stopId) async {
    final r = await _get('$_base/proxy/smart_stations?stationId=$stopId',
        timeoutSec: 10);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    final result = <Map<String, dynamic>>[];
    for (final item in _list(json.decode(utf8.decode(r.bodyBytes)))) {
      if (item is! Map<String, dynamic>) continue;
      final code = _s(item['BusLineCode'] ?? '');
      if (code.isEmpty) continue;
      if (_skipKeywords.any((kw) => code.toUpperCase().contains(kw))) continue;
      result.add({
        'BusLineCode':               _s(item['BusLineCode']),
        'BusLineNo':                 _s(item['BusLineNo']),
        'BusLineShortName':          _s(item['BusLineShortName']),
        'panelId':                   item['panelId']?.toString() ?? '',
        // ASIS tüm alanları string döner (ör: "15", "0", "41.37006833")
        // int/double'a çeviriyoruz, parse başarısızsa 0 döner
        'RemainingTimeCurr':         int.tryParse(item['RemainingTimeCurr']?.toString() ?? '') ?? 0,
        'RemainingTimeNext':         int.tryParse(item['RemainingTimeNext']?.toString() ?? '') ?? 0,
        'IsAccordingToTimeSchedule': _s(item['IsAccordingToTimeSchedule'], 'A'),
        'BusStatusCurr':             _s(item['BusStatusCurr']),
        'BusStatusNext':             _s(item['BusStatusNext']),
        'distance':                  int.tryParse(item['distance']?.toString() ?? '') ?? 0,
        'RemainingNumberOfBusStops': int.tryParse(item['RemainingNumberOfBusStops']?.toString() ?? '') ?? 0,
        // ASIS koordinatları string döner (ör: "41.37006833", "36.22803333")
        'latitude':                  double.tryParse(item['latitude']?.toString() ?? '') ?? 0.0,
        'longitude':                 double.tryParse(item['longitude']?.toString() ?? '') ?? 0.0,
        'speed':                     int.tryParse(item['speed']?.toString() ?? '') ?? 0,
        'direction':                 int.tryParse(item['direction']?.toString() ?? '') ?? 0,
      });
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. HAT CANLI ARAÇLAR
  //    Birincil → /api/hat/arac/{code}    (DB eşleştirmeli, yakin durak var)
  //    Fallback → /api/proxy/realtime     (yalnızca HTTP/ağ hatasında)
  //
  //    NOT: Birincil [] dönerse araç yok demektir, fallback çalışmaz.
  //    Fallback yalnızca r1 == null veya statusCode != 200 ise devreye girer.
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getHattakiAraclar(
      String lineCode) async {
    final encoded = Uri.encodeComponent(lineCode);

    // ── Birincil ──────────────────────────────────────────────────
    final r1 = await _get('$_base/hat/arac/$encoded');
    if (r1 != null && r1.statusCode == 200 && r1.bodyBytes.isNotEmpty) {
      final data = json.decode(utf8.decode(r1.bodyBytes));
      if (data is List) return _parseVehicles(data, lineCode);
    }

    // ── Fallback: proxy/realtime ───────────────────────────────────
    debugPrint('getHattakiAraclar: birincil hata — fallback proxy/realtime ($lineCode)');
    final r2 = await _get(
      '$_base/proxy/realtime?lineCode=$encoded',
      timeoutSec: 14,
    );
    if (r2 != null && r2.statusCode == 200 && r2.bodyBytes.isNotEmpty) {
      final data = json.decode(utf8.decode(r2.bodyBytes));
      if (data is List) return _parseVehicles(data, lineCode);
    }

    return [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. HAT DURAKLARI — Proxy (gerçek zamanlı, sıralı)
  //    GET /api/proxy/stops_stations?lineCode={code}
  //
  //    Alanlar: stopId, stopName, orderId, latitude, longitude
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getHatDuraklari(
      String lineCode) async {
    final url =
        '$_base/proxy/stops_stations?lineCode=${Uri.encodeComponent(lineCode)}';
    final r = await _get(url, timeoutSec: 12);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'stopId':    _s(item['stopId']    ?? item['DurakId']),
              'stopName':  _s(item['stopName']  ?? item['DurakAdi']),
              'orderId':   _s(item['orderId']   ?? item['SiraNo']),
              'latitude':  _s(item['latitude']  ?? item['Enlem'],  '0'),
              'longitude': _s(item['longitude'] ?? item['Boylam'], '0'),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. HAT DURAKLARI — DB (tramvay koordinat düzeltmeleri dahil)
  //    GET /api/hat/durak/{code}
  //
  //    Alanlar: hat, durakId, ad, sira, lat, lon
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getHatDuraklariDB(
      String lineCode) async {
    final url = '$_base/hat/durak/${Uri.encodeComponent(lineCode)}';
    final r = await _get(url);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'hat':     _s(item['hat']),
              'durakId': _s(item['durak_id'] ?? item['id']),
              'ad':      _s(item['ad']),
              'sira':    (item['sira'] as num?)?.toInt() ?? 0,
              'lat':     (item['lat']  as num?)?.toDouble() ?? 0.0,
              'lon':     (item['lon']  as num?)?.toDouble() ?? 0.0,
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. HAT YÖNLERİ (Proxy — istemci tarafında filtrelenmiş)
  //    GET /api/proxy/line_directions?lineCode={code}
  //
  //    KRİTİK: API sunucu filtresi çalışmıyor (~8557 kayıt döner).
  //    Proxy istemci tarafında lineCode alanına göre filtreler.
  //    Direction değerleri: "FORWARD" | "BACKWARD" | "CIRCULAR"
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getHatYonleri(
      String lineCode) async {
    final url =
        '$_base/proxy/line_directions?lineCode=${Uri.encodeComponent(lineCode)}';
    final r = await _get(url, timeoutSec: 18);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'direction': _s(item['Direction'] ?? item['Yon']),
              'lineCode':  _s(item['lineCode']  ?? item['HatKodu'] ?? lineCode),
              'lineNo':    _s(item['lineNo']    ?? item['HatNo']),
              'stopName':  _s(item['stopName']  ?? item['DurakAdi']),
              'orderId':   _s(item['orderId']   ?? item['SiraNo']),
              'stopId':    _s(item['durakId']   ?? item['DurakId']),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. HAT SAATLERİ / TARİFE (Proxy)
  //    GET /api/proxy/schedules?lineCode={code}&scheduleDate={yyyy-MM-dd}
  //
  //    KRİTİK: scheduleDate parametresi API'de etkisizdir — her zaman
  //    aktif çizelge döner. Parametre yine de gönderilmelidir.
  //
  //    Gerçek alan adları: cizelgekodu, hatkodu, saat, yon
  //    yon: proxy "Gidiş"/"Dönüş" olarak normalize eder (API "G"/"D" döndürür)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getHatSaatleri(
    String lineCode, {
    DateTime? date,
  }) async {
    // T00:00:00 suffix gereksiz — proxy temizler, ama clean gönderelim
    final scheduleDate =
        (date ?? DateTime.now()).toIso8601String().substring(0, 10);

    final url = '$_base/proxy/schedules'
        '?lineCode=${Uri.encodeComponent(lineCode)}'
        '&scheduleDate=${Uri.encodeComponent(scheduleDate)}';

    final r = await _get(url);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              // cizelgekodu = hatkodu (aynı veri, farklı ad)
              'lineCode':  _s(item['hatkodu']  ?? item['cizelgekodu'] ?? lineCode),
              'time':      _s(item['saat']     ?? item['Saat']),
              // proxy normalize eder: "Gidiş" veya "Dönüş"
              'direction': _s(item['yon']      ?? item['Yon']),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7. TÜM HATLAR (DB — önbellekli)
  //    GET /api/hat
  //
  //    Alanlar: code, name, tip, kat, alias, shortName,
  //    gtfsRouteId, gtfsRouteShortName, gtfsRouteLongName,
  //    gtfsRouteType, gtfsRouteColor
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getHatlar() async {
    final r = await _get('$_base/hat');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'code':               _s(item['code']),
              'name':               _s(item['name']),
              'tip':                _s(item['tip']),
              'kat':                _s(item['kat']),
              'alias':              _s(item['alias']),
              'shortName':          _s(item['short_name'] ?? item['gtfs_route_short_name']),
              'gtfsRouteId':        _s(item['gtfs_route_id']),
              'gtfsRouteShortName': _s(item['gtfs_route_short_name']),
              'gtfsRouteLongName':  _s(item['gtfs_route_long_name']),
              'gtfsRouteType':      _s(item['gtfs_route_type'],  '3'),
              'gtfsRouteColor':     _s(item['gtfs_route_color'], '1877F2'),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 8. TEK HAT BİLGİSİ (DB)
  //    GET /api/hat/info/{code}
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> getHatBilgi(String lineCode) async {
    final r = await _get('$_base/hat/info/${Uri.encodeComponent(lineCode)}');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return null;

    final decoded = json.decode(utf8.decode(r.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded.isEmpty) return null;

    return {
      'code':              _s(decoded['code']),
      'name':              _s(decoded['name']),
      'tip':               _s(decoded['tip']),
      'kat':               _s(decoded['kat']),
      'alias':             _s(decoded['alias']),
      'shortName':         _s(decoded['short_name'] ?? decoded['gtfs_route_short_name']),
      'gtfsRouteColor':    _s(decoded['gtfs_route_color'], '1877F2'),
      'gtfsRouteLongName': _s(decoded['gtfs_route_long_name']),
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9. HAT SEFER SAATLERİ (DB — statik, API'den çekilmiş)
  //    GET /api/hat/sefer/{code}
  //
  //    Alanlar: hat, saat, yon ("Gidiş"/"Dönüş"), gun (hi/hs)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getHatSeferler(
      String lineCode) async {
    final r = await _get('$_base/hat/sefer/${Uri.encodeComponent(lineCode)}');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'hat':  _s(item['hat']),
              'saat': _s(item['saat']),
              'yon':  _s(item['yon']),
              'gun':  _s(item['gun']),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 10. HAT FİYATI (DB — Samulaş web + sabit fiyatlar)
  //     GET /api/hat/fiyat/{code}
  //
  //     Alanlar: tam_fiyat, indirimli_fiyat, aktarma1, aktarma2, hat_adi
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getHatFiyat(String lineCode) async {
    const fallback = <String, dynamic>{
      'tam_fiyat': 20.0,
      'indirimli_fiyat': 14.0,
      'aktarma1': 'Ücretsiz',
      'aktarma2': 0.0,
      'hat_adi': '',
    };

    final r = await _get('$_base/hat/fiyat/${Uri.encodeComponent(lineCode)}');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) {
      return fallback;
    }

    final decoded = json.decode(utf8.decode(r.bodyBytes));
    if (decoded is! Map<String, dynamic>) return fallback;

    return {
      'tam_fiyat':       (decoded['tam_fiyat']       as num?)?.toDouble() ?? 20.0,
      'indirimli_fiyat': (decoded['indirimli_fiyat'] as num?)?.toDouble() ?? 14.0,
      'aktarma1':        _s(decoded['aktarma1'], 'Ücretsiz'),
      'aktarma2':        (decoded['aktarma2']         as num?)?.toDouble() ?? 0.0,
      'hat_adi':         _s(decoded['hat_adi']),
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 11. YAKIN DURAKLAR
  //     GET /api/yakin?lat={lat}&lon={lon}
  //
  //     Alanlar: kod, ad, lat, lon, dist (metre)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getYakinDuraklar(
      double lat, double lon) async {
    final r = await _get('$_base/yakin?lat=$lat&lon=$lon');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'kod':  _s(item['kod']),
              'ad':   _s(item['ad']),
              'lat':  (item['lat'] as num?)?.toDouble() ?? 0.0,
              'lon':  (item['lon'] as num?)?.toDouble() ?? 0.0,
              'dist': (item['dist'] as num?)?.toInt() ?? 0,
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 12. DURAK PANELİ (hangi hatlar geçiyor + ETA)
  //     GET /api/durak_panel/{kod}
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getDurakPaneli(
      String stopKod) async {
    final r = await _get(
        '$_base/durak_panel/${Uri.encodeComponent(stopKod)}',
        timeoutSec: 15);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'hat':   _s(item['hat']),
              'ad':    _s(item['ad']),
              'kat':   _s(item['kat']),
              // null veya {plaka, tahmini_dk, hiz, doluluk, lat, lon, verify}
              'gelen': item['gelen'],
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 13. YOL TARİFİ / ROTA (akıllı, aktarmalı)
  //     GET /api/rota?lat1=&lon1=&lat2=&lon2=
  //     GET /api/rota?lat1=&lon1=&end={yer_adi}    (Nominatim geocode)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getRota({
    required double lat1,
    required double lon1,
    double? lat2,
    double? lon2,
    String? hedef,
  }) async {
    final String url;
    if (hedef != null) {
      url = '$_base/rota?lat1=$lat1&lon1=$lon1'
          '&end=${Uri.encodeComponent(hedef)}';
    } else if (lat2 != null && lon2 != null) {
      url = '$_base/rota?lat1=$lat1&lon1=$lon1&lat2=$lat2&lon2=$lon2';
    } else {
      return [];
    }

    final r = await _get(url, timeoutSec: 20);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    final decoded = json.decode(utf8.decode(r.bodyBytes));
    if (decoded is Map && decoded.containsKey('error')) return [];
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // 14. ODAK TURİSTİK HATLAR (DB)
  //     GET /api/odak
  //
  //     Alanlar: id, ad, kod, gunler
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getOdakHatlar() async {
    final r = await _get('$_base/odak');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'id':     _s(item['id']),
              'ad':     _s(item['ad']),
              'kod':    _s(item['kod']),
              'gunler': _s(item['gunler']),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 15. ODAK HAT DURAKLARI (DB)
  //     GET /api/odak/{id}/durak
  //
  //     Alanlar: hat, ad, kod, sira, lat, lon, fiyat, fiyatOgr
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getOdakDuraklar(
      String hatId) async {
    final r = await _get('$_base/odak/$hatId/durak');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'hat':      _s(item['hat']),
              'ad':       _s(item['ad']),
              'kod':      _s(item['kod']),
              'sira':     (item['sira'] as num?)?.toInt() ?? 0,
              'lat':      (item['lat']  as num?)?.toDouble() ?? 0.0,
              'lon':      (item['lon']  as num?)?.toDouble() ?? 0.0,
              'fiyat':    _s(item['fiyat'],                      '0'),
              'fiyatOgr': _s(item['fiyat_ogr'] ?? item['fiyatOgr'], '0'),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 16. ODAK CANLI ARAÇLAR (YBS Proxy)
  //     GET /api/proxy_odak_araclar?hatid={id}
  //
  //     Döner: {"active": true, "vehicles": [...]}
  //     Normalize alanlar: lat, lon, plaka, hiz
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getOdakAraclar(
      String hatId) async {
    final r = await _get('$_base/proxy_odak_araclar?hatid=$hatId',
        timeoutSec: 10);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    final decoded = json.decode(utf8.decode(r.bodyBytes));
    if (decoded is! Map<String, dynamic>) return [];

    final vehicles = decoded['vehicles'];
    if (vehicles is! List) return [];

    return vehicles.whereType<Map<String, dynamic>>().map((item) {
      final latRaw = (item['Enlem']  ?? item['enlem']  ?? item['lat']  ?? '0').toString();
      final lonRaw = (item['Boylam'] ?? item['boylam'] ?? item['lon']  ?? '0').toString();
      final lat = double.tryParse(latRaw.replaceAll(',', '.')) ?? 0.0;
      final lon = double.tryParse(lonRaw.replaceAll(',', '.')) ?? 0.0;
      return <String, dynamic>{
        'lat':   lat,
        'lon':   lon,
        'plaka': _s(item['Plaka'] ?? item['plaka'] ?? item['plate']),
        'hiz':   _s(item['Hizi']  ?? item['hiz']   ?? item['speed'], '0'),
      };
    }).where((v) => v['lat'] != 0.0 && v['lon'] != 0.0).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 17. SAMAİR HATLAR (DB)
  //     GET /api/samair
  //
  //     Alanlar: id, ad, kod
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getSamairHatlar() async {
    final r = await _get('$_base/samair');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'id':  item['id']?.toString() ?? '',
              'ad':  _s(item['ad']),
              'kod': _s(item['kod']),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 18. SAMAİR HAT DURAKLARI (DB)
  //     GET /api/samair/{id}/durak
  //
  //     Alanlar: hat, ad, kod, sira, lat, lon, fiyat
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getSamairDuraklar(
      int hatId) async {
    final r = await _get('$_base/samair/$hatId/durak');
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'hat':   item['hat']?.toString() ?? '',
              'ad':    _s(item['ad']),
              'kod':   _s(item['kod']),
              'sira':  (item['sira'] as num?)?.toInt() ?? 0,
              'lat':   (item['lat']  as num?)?.toDouble() ?? 0.0,
              'lon':   (item['lon']  as num?)?.toDouble() ?? 0.0,
              'fiyat': _s(item['fiyat'], '0'),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 19. SAMAİR UÇUŞ SEFERLERİ (DB — günlük güncellenir)
  //     GET /api/samair/{id}/sefer
  //
  //     Döner: {"data": [...], "last_update": "dd.MM.yyyy HH:mm"}
  //     Veri alanları: id, hat, saat, varis, firma, ucakSaat, tarih, gunFormat
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getSamairSeferler(int hatId) async {
    final r = await _get('$_base/samair/$hatId/sefer', timeoutSec: 15);

    const empty = <String, dynamic>{'data': [], 'last_update': ''};
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return empty;

    final decoded = json.decode(utf8.decode(r.bodyBytes));
    if (decoded is! Map<String, dynamic>) return empty;

    final rawData = decoded['data'];
    final List items = rawData is List ? rawData : [];

    return {
      'data': items.whereType<Map<String, dynamic>>().map((item) => {
            'id':        item['id']?.toString() ?? '',
            'hat':       item['hat']?.toString() ?? '',
            'saat':      _s(item['saat']),
            'varis':     _s(item['varis']),
            'firma':     _s(item['firma']),
            'ucakSaat':  _s(item['ucak_saat'] ?? item['ucakSaat']),
            'tarih':     _s(item['tarih']),
            'gunFormat': _s(item['gun_format'] ?? item['gunFormat']),
          }).toList(),
      'last_update': _s(decoded['last_update'] ?? ''),
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 20. SAMAİR CANLI ARAÇLAR (YBS Proxy)
  //     GET /api/proxy_samair_araclar
  //
  //     Proxy normalize edilmiş alanlar: lat, lon, plate, speed, lineCode
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getSamairAraclar() async {
    final r = await _get('$_base/proxy_samair_araclar', timeoutSec: 10);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .where((item) {
          final lat = (item['lat'] as num?)?.toDouble() ?? 0.0;
          final lon = (item['lon'] as num?)?.toDouble() ?? 0.0;
          return lat > 40 && lat < 43 && lon > 34 && lon < 38;
        })
        .map((item) => {
              'lat':      (item['lat']  as num?)?.toDouble() ?? 0.0,
              'lon':      (item['lon']  as num?)?.toDouble() ?? 0.0,
              'plate':    _s(item['plate']),
              'speed':    _s(item['speed'], '0'),
              'lineCode': _s(item['lineCode'], 'SAMAIR'),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 21. SAMAİR UÇUŞ SAATLERİ — Canlı (YBS Proxy)
  //     GET /api/proxy_samair_saatler?hatid={id}
  //
  //     Normalize alanlar: saat, varis, firma, ucakSaat, tarih, gunFormat
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getSamairSaatlerProxy(
      int hatId) async {
    final r = await _get('$_base/proxy_samair_saatler?hatid=$hatId',
        timeoutSec: 12);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return [];

    return _list(json.decode(utf8.decode(r.bodyBytes)))
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'saat':      _s(item['saat']),
              'varis':     _s(item['varis']),
              'firma':     _s(item['firma']),
              'ucakSaat':  _s(item['ucakSaat'] ?? item['ucak_saat']),
              'tarih':     _s(item['tarih']),
              'gunFormat': _s(item['gunFormat'] ?? item['gun_format']),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 22. SAĞLIK KONTROLÜ
  //     GET /api/health
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getHealth() async {
    final r = await _get('$_base/health', timeoutSec: 6);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) {
      return {'status': 'error'};
    }
    final decoded = json.decode(utf8.decode(r.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : {'status': 'error'};
  }

  // ═══════════════════════════════════════════════════════════════════
  // 23. UYGULAMA SÜRÜM KONTROLÜ
  //     GET /api/app_version
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getAppVersion() async {
    final r = await _get('$_base/app_version', timeoutSec: 6);
    if (r == null || r.statusCode != 200 || r.bodyBytes.isEmpty) return {};

    final decoded = json.decode(utf8.decode(r.bodyBytes));
    if (decoded is! Map<String, dynamic>) return {};
    return {
      'latestVersion': _s(decoded['latest_version']),
      'minVersion':    _s(decoded['min_version']),
      'releaseNotes':  _s(decoded['release_notes']),
      'downloadUrl':   _s(decoded['download_url']),
      'forceUpdate':   decoded['force_update'] as bool? ?? false,
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // Test erişim metodları (@visibleForTesting)
  // ═══════════════════════════════════════════════════════════════════

  /// _parseVehicles test erişimi — RT araç verilerini parse eder
  @visibleForTesting
  static List<Map<String, dynamic>> parseRealTimeDataForTest(
          List<dynamic> data, String lineCode) =>
      _parseVehicles(data, lineCode);

  /// SmartStation verisini temizler: BusLineCode filtresi + skip keywords
  @visibleForTesting
  static List<Map<String, dynamic>> cleanSmartStationDataForTest(
      List<dynamic> data) {
    final result = <Map<String, dynamic>>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final code = _s(item['BusLineCode'] ?? '');
      if (code.isEmpty) continue;
      if (_skipKeywords.any((kw) => code.toUpperCase().contains(kw))) continue;
      result.add(item);
    }
    return result;
  }

  /// ASIS yanıtından liste çıkarır — tekil objeyi de listeye sarar
  @visibleForTesting
  static List<dynamic> extractDataListForTest(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final inner = decoded['data'];
      if (inner is List) return inner;
      // Tekil obje → listeye sar
      return [decoded];
    }
    return [];
  }

  /// Türkçe karakter düzeltme test erişimi
  @visibleForTesting
  static String fixAndCleanTextForTest(String text) => _fix(text);
}
