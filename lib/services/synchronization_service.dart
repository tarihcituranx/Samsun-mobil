
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:samsun_ulasim/services/db_service.dart';
import 'package:samsun_ulasim/services/gtfs_sync_service.dart';
import 'package:sqflite/sqflite.dart';

// samsun.py'nin Collector sınıfının mantığını Flutter/Dart'a taşıyan servis.
// API'lerden veri toplar, temizler, işler ve yerel SQLite veritabanını doldurur.
// GTFS (ASIS) işleri GtfsSyncService'e delege edilir; SAMULAŞ işleri burada kalır.
class SynchronizationService {
  final dbHelper = DBService();
  late final GtfsSyncService _gtfsSync = GtfsSyncService(dbHelper);
  static const _renderBase = 'https://deflation-shaded-sterility.ngrok-free.dev';

  Future<List<dynamic>> _ybsApiCall(String module, String method, {Map<String, String>? params}) async {
    try {
      // YBS çağrıları da proxy üzerinden: odak, samair vb.
      String proxyEndpoint;
      if (module.contains('odak')) {
        if (method == 'HatlarList' || method == 'HatlarAllList') {
          proxyEndpoint = '$_renderBase/proxy_odak';
        } else if (method.contains('Durak')) {
          final kodu = params?['kodu'] ?? '';
          proxyEndpoint = '$_renderBase/odak/$kodu/durak';
          params = null;
        } else {
          proxyEndpoint = '$_renderBase/odak';
        }
      } else if (module.contains('samair')) {
        if (method == 'LokasyonlarList') {
          proxyEndpoint = '$_renderBase/samair';
        } else if (method == 'HatlarList') {
          final hatid = params?['hatid'] ?? '';
          proxyEndpoint = '$_renderBase/proxy_samair_saatler?hatid=$hatid';
          params = null;
        } else if (method == 'araclar') {
          proxyEndpoint = '$_renderBase/proxy_samair_araclar';
        } else if (method.contains('Durak')) {
          final hatid = params?['hatid'] ?? params?['hat'] ?? '';
          proxyEndpoint = '$_renderBase/samair/$hatid/durak';
          params = null;
        } else {
          proxyEndpoint = '$_renderBase/samair';
        }
      } else {
        proxyEndpoint = '$_renderBase/proxy_odak';
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
        if (decoded is Map && decoded.containsKey('root')) return decoded['root'] is List ? decoded['root'] : [];
        if (decoded is List) return decoded;
        return [decoded];
      }
    } catch (e) {
      debugPrint('YBS Proxy Hatası ($module/$method): $e');
    }
    return [];
  }

  // --- SAMULAŞ Veri Çekme ve İşleme Fonksiyonları ---

  Future<void> _fetchAndSaveOdak() async {
    debugPrint('📥 Odak Turistik Hatlar çekiliyor...');
    final db = await dbHelper.database;
    List<dynamic> odakHatlar = await _ybsApiCall('odak_otobus_public', 'HatlarList');
    int dCount = 0;

    if (odakHatlar.isNotEmpty) {
      final hatBatch = db.batch();
      for (var h in odakHatlar) {
        // Proxy format: {id, kod, ad, gunler} | YBS format: {kodu, adi, gunler}
        String code = (h['id'] ?? h['kod'] ?? h['kodu'] ?? '').toString();
        String name = (h['ad'] ?? h['adi'] ?? '').toString();
        String gCode = code.startsWith('G_') ? code : "G_$code";
        
        hatBatch.insert("odak", {
          'id': code,
          'ad': name,
          'kod': gCode,
          'gunler': (h['gunler'] ?? '').toString(),
        });

        hatBatch.insert("hat", {
          'code': gCode,
          'name': name,
          'tip': 'odak',
          'kat': 'odak',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Durakları proxy'den çek (fiyat dahil)
        List<dynamic> duraklar = await _ybsApiCall('odak_otobussefer_public', 'DuraklarByKodu', params: {'kodu': code});
        if (duraklar.isNotEmpty) {
           final dBatch = db.batch();
           for (var i = 0; i < duraklar.length; i++) {
              var d = duraklar[i];
              // Proxy format: {ad, kod, sira, lat, lon, fiyat, fiyat_ogr} | YBS format: {durak_adi, durak_kodu, lat, lon, fiyat, fiyat_ogr}
              double lat = double.tryParse((d['lat'] ?? '0').toString()) ?? 0;
              double lon = double.tryParse((d['lon'] ?? '0').toString()) ?? 0;
              dBatch.insert("odak_durak", {
                  'hat': gCode,
                  'ad': (d['ad'] ?? d['durak_adi'] ?? '').toString(),
                  'kod': (d['kod'] ?? d['durak_kodu'] ?? '').toString(),
                  'sira': int.tryParse((d['sira'] ?? '${i+1}').toString()) ?? (i+1),
                  'lat': lat,
                  'lon': lon,
                  'fiyat': (d['fiyat'] ?? d['durak_fiyat'] ?? '').toString(),
                  'fiyat_ogr': (d['fiyat_ogr'] ?? d['durak_fiyat_ogr'] ?? '').toString(),
              });
              dCount++;
           }
           await dBatch.commit(noResult: true);
        }
      }
      await hatBatch.commit(noResult: true);
      debugPrint('✅ ${odakHatlar.length} Odak Hattı ve $dCount Odak Durağı eklendi.');
    }
  }

  Future<void> _fetchAndSaveSamair() async {
    debugPrint('📥 Samair Havalimanı Hatları çekiliyor...');
    final db = await dbHelper.database;
    List<dynamic> hatlar = await _ybsApiCall('samair_ucaksefersaatleri_public', 'LokasyonlarList');
    
    int hatCount = 0;
    int seferCount = 0;

    if (hatlar.isNotEmpty) {
      final batch = db.batch();
      for (var h in hatlar) {
         // Proxy format: {id, kod, ad} | YBS format: {id, adi}
         String name = (h['ad'] ?? h['adi'] ?? '').toString();
         String id = (h['id'] ?? '').toString();
         String kod = (h['kod'] ?? 'H_$id').toString();
         
         batch.insert("samair", {
           'id': int.tryParse(id) ?? 0,
           'ad': name,
           'kod': kod,
         });

         batch.insert("hat", {
           'code': kod,
           'name': name,
           'tip': 'havalimani',
           'kat': 'havalimani',
         }, conflictAlgorithm: ConflictAlgorithm.ignore);
         
         hatCount++;

         List<dynamic> seferler = await _ybsApiCall('samair_ucaksefersaatleri_public', 'HatlarList', params: {'hatid': id});
         if (seferler.isNotEmpty) {
             final sfBatch = db.batch();
             for (var sf in seferler) {
                 // Proxy format: {saat, varis, firma, ucak_saat, tarih, gun_format}
                 // YBS format: {saat, varis_saati, ucak_firmasi, ucak_saatleri, tarih, formatted_date}
                 sfBatch.insert("samair_sefer", {
                     'hat': int.tryParse(id) ?? 0,
                     'saat': (sf['saat'] ?? '').toString(),
                     'varis': (sf['varis'] ?? sf['varis_saati'] ?? '').toString(),
                     'firma': (sf['firma'] ?? sf['ucak_firmasi'] ?? '').toString(),
                     'ucak_saat': (sf['ucak_saat'] ?? sf['ucak_saatleri'] ?? '').toString(),
                     'tarih': (sf['tarih'] ?? '').toString(),
                     'gun_format': (sf['gun_format'] ?? sf['formatted_date'] ?? '').toString(),
                 });
                 seferCount++;
             }
             await sfBatch.commit(noResult: true);
         }
      }
      await batch.commit(noResult: true);
      debugPrint('✅ $hatCount Samair Hattı ve $seferCount Samair Seferi Eklendi.');
    }
  }

  Future<void> _injectFixedPrices() async {
    debugPrint('💰 Sabit Fiyatlar Ekleniyor (son güncelleme fallback)...');
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();
    
    // Önce proxy'den tüm fiyatları çekmeyi dene (samsun.py'nin samulas.com.tr'den çektiği güncel veriler)
    bool proxySuccess = false;
    try {
      final response = await http.get(
        Uri.parse('https://deflation-shaded-sterility.ngrok-free.dev/hat'),
        headers: {'User-Agent': 'SamsunMobilApp/2.0'},
      ).timeout(const Duration(seconds: 12));
      
      if (response.statusCode == 200) {
        final hatlar = json.decode(utf8.decode(response.bodyBytes));
        if (hatlar is List && hatlar.isNotEmpty) {
          final batch = db.batch();
          int count = 0;
          for (var hat in hatlar) {
            final code = (hat['code'] ?? '').toString();
            if (code.isEmpty) continue;
            try {
              final fiyatResp = await http.get(
                Uri.parse('https://deflation-shaded-sterility.ngrok-free.dev/hat/fiyat/${Uri.encodeComponent(code)}'),
                headers: {'User-Agent': 'SamsunMobilApp/2.0'},
              ).timeout(const Duration(seconds: 5));
              
              if (fiyatResp.statusCode == 200) {
                final fiyat = json.decode(fiyatResp.body);
                final tam = (fiyat['tam_fiyat'] as num?)?.toDouble() ?? 0;
                final ind = (fiyat['indirimli_fiyat'] as num?)?.toDouble() ?? 0;
                if (tam > 0) {
                  batch.insert("fiyat", {
                    'kaynak': 'proxy',
                    'hat_adi': hat['name'] ?? code,
                    'hat_code': code,
                    'tam_fiyat': tam,
                    'ogrenci_fiyat': ind,
                    'guncelleme': now,
                  }, conflictAlgorithm: ConflictAlgorithm.replace);
                  count++;
                }
              }
            } catch (e) { debugPrint('Fiyat parse hatası: $e'); }
            // Rate limiting: çok hızlı istek atmayalım
            if (count % 10 == 0) await Future.delayed(const Duration(milliseconds: 200));
          }
          if (count > 0) {
            await batch.commit(noResult: true);
            proxySuccess = true;
            debugPrint('✅ Proxy fiyatlar: $count hat güncellendi');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Proxy fiyat çekme hatası: $e');
    }

    // Proxy başarısız olduysa fallback: Kategori bazlı varsayılan fiyatlar
    if (!proxySuccess) {
      debugPrint('⚠️ Proxy fiyatlar alınamadı, kategori bazlı fallback kullanılıyor...');

      // Kategori fiyatları — GitHub prices.json fallback ile senkronize
    }
  }

  // --- Ana Senkronizasyon Fonksiyonu ---

  Future<void> runFullSynchronization({bool force = false}) async {
    final db = await dbHelper.database;
    
    // Güncelleme gerekli mi kontrol et (samsun.py'deki gibi)
    if (!force) {
      final lastUpdate = await db.query("meta", where: 'key = ?', whereArgs: ['last_update']);
      if (lastUpdate.isNotEmpty) {
        final lastDate = DateTime.tryParse(lastUpdate.first['value'] as String);
        if (lastDate != null && DateTime.now().difference(lastDate).inDays < 7) {
          debugPrint('📦 Veriler güncel. Senkronizasyon atlanıyor.');
          return;
        }
      }
    }

    debugPrint('🔄 **Büyük Veri Senkronizasyonu Başladı** 🔄');
    
    // Önce eski verileri temizle
    await db.delete("hat");
    await db.delete("durak");
    await db.delete("hat_durak");
    await db.delete("sefer");
    await db.delete("fiyat");
    await db.delete("odak");
    await db.delete("odak_durak");
    await db.delete("samair");
    await db.delete("samair_durak");
    await db.delete("samair_sefer");

    await _gtfsSync.fetchAndSaveHats();
    await _gtfsSync.fetchAndSaveDuraklar();
    await _gtfsSync.fetchAndSaveGuzergahlar();
    await _gtfsSync.fetchAndSaveSeferler();
    await _fetchAndSaveOdak();
    await _fetchAndSaveSamair();
    await _injectFixedPrices();
    
    // Güncelleme zamanını kaydet
    await db.insert("meta", 
      {'key': 'last_update', 'value': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace
    );

    // Sync sonrası DBService önbelleğini temizle (güncel veri okunabilsin)
    dbHelper.invalidateCache();

    debugPrint('🎉 **Senkronizasyon Başarıyla Tamamlandı** 🎉');
  }

}
