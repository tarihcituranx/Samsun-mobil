
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:samsun_ulasim/services/db_service.dart';
import 'package:sqflite/sqflite.dart';

/// GTFS (ASIS) verilerini çeken ve yerel SQLite veritabanına kaydeden servis.
/// Hat, durak, güzergah ve sefer verilerini yönetir.
class GtfsSyncService {
  final DBService dbHelper;
  static const renderBase = 'https://samsun-gtfs-rt.onrender.com/api';

  GtfsSyncService(this.dbHelper);

  // --- samsun.py'den Port Edilen Veri Temizleme Mantığı ---
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

  static String _fixText(String text) {
    String fixedText = text;
    _turkishCharacterFixes.forEach((key, value) {
      fixedText = fixedText.replaceAll(key, value);
    });
    return fixedText.trim();
  }

  // --- API Çağrıları (Render Proxy üzerinden — proje şeması gereği) ---
  Future<List<dynamic>> _asisApiCall(String endpoint, {Map<String, String>? params}) async {
    try {
      // ASIS çağrıları proxy üzerinden: /api/proxy/realtime, /api/proxy/smart_stations vb.
      // Genel endpoint'ler için: /api/hat, /api/hat/durak/{code} vb.
      String proxyEndpoint;
      if (endpoint == 'Lines' || endpoint == 'OrjLines') {
        proxyEndpoint = '$renderBase/hat';
      } else if (endpoint == 'StopsStations') {
        final lineCode = params?['lineCode'];
        proxyEndpoint = lineCode != null && lineCode.isNotEmpty
            ? '$renderBase/hat/durak/${Uri.encodeComponent(lineCode)}'
            : '$renderBase/proxy/smart_stations';
        params = lineCode != null ? null : params; // proxy/hat/durak yolunda param gerekmez
      } else if (endpoint == 'Schedules') {
        final lineCode = params?['lineCode'] ?? '';
        proxyEndpoint = '$renderBase/hat/sefer/${Uri.encodeComponent(lineCode)}';
        params = null;
      } else if (endpoint == 'RealTimeData') {
        proxyEndpoint = '$renderBase/proxy/realtime';
      } else if (endpoint == 'SmartStations') {
        proxyEndpoint = '$renderBase/proxy/smart_stations';
      } else {
        proxyEndpoint = '$renderBase/proxy/${endpoint.toLowerCase()}';
      }

      final uri = params != null && params.isNotEmpty
          ? Uri.parse(proxyEndpoint).replace(queryParameters: params)
          : Uri.parse(proxyEndpoint);
      final response = await http.get(uri, headers: {
        'User-Agent': 'SamsunMobilApp/2.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        var decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded.containsKey('data')) return decoded['data'] is List ? decoded['data'] : [];
        if (decoded is List) return decoded;
        return [decoded];
      }
    } catch (e) {
      debugPrint('Proxy API Hatası ($endpoint): $e');
    }
    return [];
  }

  // --- GTFS Veri Çekme ve İşleme Fonksiyonları ---

  Future<void> fetchAndSaveHats() async {
    debugPrint('📥 Hatlar çekiliyor...');
    final db = await dbHelper.database;
    
    // Proxy /api/hat hem Lines hem OrjLines'ı birleşik döner
    List<dynamic> lines = await _asisApiCall('Lines');

    Set<String> seenCodes = {};
    List<Map<String, dynamic>> hatsToInsert = [];

    for (var l in lines) {
      // Proxy format: {code, name, tip, kat} | ASIS format: {lineCode, lineName, tip}
      String code = _fixText((l['code'] ?? l['lineCode'] ?? '').toString());
      String name = _fixText((l['name'] ?? l['lineName'] ?? code).toString());
      if (code.isNotEmpty && !seenCodes.contains(code)) {
        bool shouldSkip = _skipKeywords.any((kw) => code.toUpperCase().contains(kw) || name.toUpperCase().contains(kw));
        if (shouldSkip) continue;

        hatsToInsert.add({
          'code': code,
          'name': name,
          'tip': (l['tip'] ?? 'gidis').toString(),
          'kat': categorizeHat(code, name),
        });
        seenCodes.add(code);
      }
    }

    if (hatsToInsert.isNotEmpty) {
      final batch = db.batch();
      for (var hat in hatsToInsert) {
        batch.insert("hat", hat, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      debugPrint('✅ ${hatsToInsert.length} hat veritabanına kaydedildi.');
    }
  }

  Future<void> fetchAndSaveDuraklar() async {
    debugPrint('📥 Duraklar çekiliyor...');
    final db = await dbHelper.database;
    // Proxy /api/hat/durak veya fallback ASIS StopsStations
    List<dynamic> stops = await _asisApiCall('StopsStations');

    List<Map<String, dynamic>> duraklarToInsert = [];
    Set<String> seenIds = {};

    for (var s in stops) {
      // Proxy format: {id, hat, durak_id, ad, sira, lat, lon} | ASIS format: {stopId, stopName, latitude, longitude}
      String stopId = (s['id'] ?? s['durak_id'] ?? s['stopId'] ?? '').toString();
      if (stopId.isNotEmpty && !seenIds.contains(stopId)) {
        double lat = double.tryParse((s['lat'] ?? s['latitude'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
        double lon = double.tryParse((s['lon'] ?? s['longitude'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;

        if (lat < 40 || lat > 43 || lon < 34 || lon > 38) continue;

        String ad = _fixText((s['ad'] ?? s['stopName'] ?? '').toString());
        String kod = (s['kod'] ?? '').toString();
        if (kod.isEmpty) {
          final match = RegExp(r'^(\d+)').firstMatch(ad);
          if (match != null) kod = match.group(1)!;
        }

        duraklarToInsert.add({'id': stopId, 'kod': kod, 'ad': ad, 'lat': lat, 'lon': lon});
        seenIds.add(stopId);
      }
    }

    duraklarToInsert.add({'id': 'T1', 'kod': 'T1', 'ad': 'Teleferik Alt İstasyon', 'lat': 41.3204, 'lon': 36.3231});
    duraklarToInsert.add({'id': 'T2', 'kod': 'T2', 'ad': 'Teleferik Üst İstasyon', 'lat': 41.3246, 'lon': 36.3228});

    if (duraklarToInsert.isNotEmpty) {
      final batch = db.batch();
      for (var durak in duraklarToInsert) {
        batch.insert("durak", durak, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      debugPrint('✅ ${duraklarToInsert.length} durak veritabanına kaydedildi.');
    }
  }

  Future<void> fetchAndSaveGuzergahlar() async {
    debugPrint('📥 Güzergahlar çekiliyor...');
    final db = await dbHelper.database;
    final hats = await db.query("hat", columns: ['code']);

    await db.delete("hat_durak");

    int i = 0;
    for (var hat in hats) {
      String code = hat['code'] as String;
      List<dynamic> stopsOnRoute = await _asisApiCall('StopsStations', params: {'lineCode': code});
      
      if (stopsOnRoute.isNotEmpty) {
        final batch = db.batch();
        for (var s in stopsOnRoute) {
            // Proxy format: {hat, ad, kod, sira, lat, lon} | ASIS format: {stopId, stopName, latitude, longitude, orderId}
            double lat = double.tryParse((s['lat'] ?? s['latitude'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
            double lon = double.tryParse((s['lon'] ?? s['longitude'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
            if (lat < 40 || lat > 43 || lon < 34 || lon > 38) continue;

            batch.insert("hat_durak", {
              'hat': code,
              'durak_id': (s['durak_id'] ?? s['kod'] ?? s['stopId'] ?? '').toString(),
              'ad': _fixText((s['ad'] ?? s['stopName'] ?? '').toString()),
              'sira': int.tryParse((s['sira'] ?? s['orderId'] ?? '0').toString()) ?? 0,
              'lat': lat,
              'lon': lon,
            });
        }
        await batch.commit(noResult: true);
      }
      i++;
      if (i % 20 == 0) {
        debugPrint('   ... $i / ${hats.length} güzergah işlendi.');
      }
    }
    
    // --- TELEFERİK GÜZERGAHI (Manuel Ekleme) ---
    final teleferikHat = hats.where((h) => h['code'].toString().contains('TELEFERİK')).toList();
    if (teleferikHat.isNotEmpty) {
      String tCode = teleferikHat.first['code'] as String;
      final tBatch = db.batch();
      tBatch.insert("hat_durak", {'hat': tCode, 'durak_id': 'T1', 'ad': 'Teleferik Alt İstasyon', 'sira': 1, 'lat': 41.3204, 'lon': 36.3231});
      tBatch.insert("hat_durak", {'hat': tCode, 'durak_id': 'T2', 'ad': 'Teleferik Üst İstasyon', 'sira': 2, 'lat': 41.3246, 'lon': 36.3228});
      await tBatch.commit(noResult: true);
      debugPrint('🚠 Teleferik güzergahı eklendi.');
    }

    debugPrint('✅ Güzergahlar tamamlandı.');
  }

  Future<void> fetchAndSaveSeferler() async {
    debugPrint('📥 Seferler çekiliyor...');
    final db = await dbHelper.database;
    final hats = await db.query("hat", columns: ['code']);

    int count = 0;
    for (var hat in hats) {
      String code = hat['code'] as String;
      List<dynamic> schedules = await _asisApiCall('Schedules', params: {'lineCode': code});
      
      if (schedules.isNotEmpty) {
        final batch = db.batch();
        for (var d in schedules) {
          // Proxy format: {hat, saat, yon, gun} | ASIS format: {saat, time, yon}
          String saat = (d['saat'] ?? d['time'] ?? '').toString();
          String yon = (d['yon'] ?? '').toString();
          if (saat.isNotEmpty) {
            batch.insert("sefer", {
              'hat': code,
              'saat': saat,
              'yon': yon,
              'gun': (d['gun'] ?? 'hergun').toString(),
            });
            count++;
          }
        }
        await batch.commit(noResult: true);
      }
    }
    debugPrint('✅ $count sefer kaydedildi.');
  }

  // --- Yardımcı Fonksiyonlar ---
  String categorizeHat(String code, String name) {
    final c = code.toUpperCase();
    final n = name.toUpperCase();

    // Odak turistik hatlar
    if (n.contains('SAMSUNUM') || n.contains('ALTINKAYA') || n.contains('ODAK') || c.contains('SAMSUNUM')) return 'odak';
    // Tekne/deniz
    if (n.contains('BANDIRMA') || n.contains('VAPUR') || (n.contains('FERİBOT') && !n.contains('TELEFERİK'))) return 'tekne';
    // Ring
    if (c.startsWith('R') && c.length > 1 && int.tryParse(c.substring(1, 2)) != null) return 'ring';
    if (n.contains('TRAMVAY')) return 'tramvay';
    if (n.contains('TELEFERİK')) return 'teleferik';
    if (c.startsWith('H') && c.length > 1 && int.tryParse(c.substring(1, 2)) != null) return 'havalimani';
    if (n.contains('EKSPRES') || (c.startsWith('E') && c.length > 1 && int.tryParse(c.substring(1, 2)) != null)) return 'ekspres';
    if (['TERME','ÇARŞAMBA','BAFRA','HAVZA','LADİK','KAVAK','ASARCIK','SALIPAZARI','TEKKEKÖY','ALAÇAM','AYVACIK','VEZİRKÖPRÜ','YAKAKENT','19 MAYIS','ONDOKUZMAYIS'].any((ilce) => n.contains(ilce))) return 'ilce';
    
    return 'otobus';
  }
}
