import 'package:flutter_test/flutter_test.dart';
import 'package:samsun_ulasim/helpers/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

/// DBService veritabanı katmanının doğrulama testleri.
///
/// Bu testler gerçek dosya sistemi veya Flutter asset'leri kullanmadan,
/// in-memory SQLite üzerinde şema oluşturma, veri okuma/yazma ve
/// eksik tablo/sütun kurtarma senaryolarını doğrular.
///
/// "Bulunamadı" (not found) hatasının kök nedenini test eder:
/// - Asset DB'deki eksik tablolar (meta, sefer, odak, odak_durak, samair, samair_sefer)
/// - Asset DB'deki eksik sütunlar (hat.kat, hat.alias, hat.short_name, durak.kod)
/// - fiyat tablosu şema uyumsuzluğu (asset vs app beklentisi)
void main() {
  // sqflite_common_ffi ile masaüstü ortamında SQLite çalıştır
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper.createTables — Tablo Oluşturma', () {
    late Database db;

    setUp(() async {
      // Her test için temiz in-memory DB
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Boş DB üzerinde tüm tablolar oluşturulabilir', () async {
      // ACT
      await DatabaseHelper.createTables(db);

      // ASSERT: Tüm beklenen tablolar mevcut olmalı
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames, contains('hat'));
      expect(tableNames, contains('durak'));
      expect(tableNames, contains('hat_durak'));
      expect(tableNames, contains('sefer'));
      expect(tableNames, contains('fiyat'));
      expect(tableNames, contains('odak'));
      expect(tableNames, contains('odak_durak'));
      expect(tableNames, contains('samair'));
      expect(tableNames, contains('samair_durak'));
      expect(tableNames, contains('samair_sefer'));
      expect(tableNames, contains('meta'));
    });

    test('createTables tekrar çağrılınca hata vermez (IF NOT EXISTS)', () async {
      await DatabaseHelper.createTables(db);
      // İkinci kez çağırmak hata vermemeli
      await DatabaseHelper.createTables(db);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      expect(tables.length, greaterThanOrEqualTo(11));
    });
  });

  group('hat tablosu — Okuma/Yazma', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      await DatabaseHelper.createTables(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('hat tablosuna veri yazılıp okunabilir', () async {
      await db.insert('hat', {
        'code': 'R1',
        'name': 'R1 SAMSUN',
        'tip': 'gidis',
        'kat': 'ring',
      });

      final rows = await db.query('hat');
      expect(rows.length, 1);
      expect(rows.first['code'], 'R1');
      expect(rows.first['name'], 'R1 SAMSUN');
      expect(rows.first['kat'], 'ring');
    });

    test('hat tablosu boşken query boş liste döner (hata vermez)', () async {
      final rows = await db.query('hat');
      expect(rows, isEmpty);
    });

    test('hat tablosuna birden fazla kayıt yazılıp toplu okunabilir', () async {
      final batch = db.batch();
      batch.insert('hat', {'code': 'R1', 'name': 'Ring 1', 'tip': 'gidis', 'kat': 'ring'});
      batch.insert('hat', {'code': 'R2', 'name': 'Ring 2', 'tip': 'donus', 'kat': 'ring'});
      batch.insert('hat', {'code': 'TRAMVAY-1', 'name': 'Tramvay Hattı', 'tip': 'gidis', 'kat': 'tramvay'});
      await batch.commit(noResult: true);

      final rows = await db.query('hat');
      expect(rows.length, 3);
    });
  });

  group('durak tablosu — Okuma/Yazma', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      await DatabaseHelper.createTables(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('durak tablosuna veri yazılıp okunabilir', () async {
      await db.insert('durak', {
        'id': 'D001',
        'kod': '1001',
        'ad': 'Cumhuriyet Meydanı',
        'lat': 41.2867,
        'lon': 36.3300,
      });

      final rows = await db.query('durak');
      expect(rows.length, 1);
      expect(rows.first['ad'], 'Cumhuriyet Meydanı');
      expect(rows.first['lat'], closeTo(41.2867, 0.001));
    });

    test('durak tablosu Türkçe karakter içeren verilerle çalışır', () async {
      await db.insert('durak', {
        'id': 'D002',
        'kod': '1002',
        'ad': 'Şahinkaya Çeşmesi Güzergâhı',
        'lat': 41.30,
        'lon': 36.35,
      });

      final rows = await db.query('durak', where: 'id = ?', whereArgs: ['D002']);
      expect(rows.first['ad'], 'Şahinkaya Çeşmesi Güzergâhı');
    });
  });

  group('Asset DB Şema Uyumsuzluğu Simülasyonu', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Asset şemasındaki hat tablosuna kat sütunu eklenebilir', () async {
      // Asset DB'deki hat tablosu şeması (kat sütunu yok)
      await db.execute('''
        CREATE TABLE hat (
          code TEXT PRIMARY KEY,
          name TEXT,
          tip TEXT,
          gtfs_route_id TEXT
        )
      ''');

      // Veri ekle (kat olmadan)
      await db.insert('hat', {'code': 'R1', 'name': 'Ring 1', 'tip': 'gidis'});

      // kat sütunu eksik olduğunu doğrula
      final colsBefore = await db.rawQuery('PRAGMA table_info(hat)');
      final namesBefore = colsBefore.map((c) => c['name']).toSet();
      expect(namesBefore.contains('kat'), isFalse);

      // ALTER TABLE ile kat sütunu ekle
      await db.execute('ALTER TABLE hat ADD COLUMN kat TEXT');

      // Şimdi kat sütunu var mı?
      final colsAfter = await db.rawQuery('PRAGMA table_info(hat)');
      final namesAfter = colsAfter.map((c) => c['name']).toSet();
      expect(namesAfter.contains('kat'), isTrue);

      // Yeni sütunla veri yazılabilir mi?
      await db.insert('hat', {'code': 'R2', 'name': 'Ring 2', 'tip': 'donus', 'kat': 'ring'});

      final rows = await db.query('hat', orderBy: 'code');
      expect(rows.length, 2);
      expect(rows[0]['kat'], isNull); // Eski satırda kat null
      expect(rows[1]['kat'], 'ring'); // Yeni satırda kat dolu
    });

    test('Asset şemasında eksik tablolar CREATE TABLE IF NOT EXISTS ile oluşturulur', () async {
      // Asset DB'nin sahip olduğu tablolar
      await db.execute('CREATE TABLE hat (code TEXT PRIMARY KEY, name TEXT, tip TEXT)');
      await db.execute('CREATE TABLE durak (id TEXT PRIMARY KEY, ad TEXT, lat REAL, lon REAL)');
      await db.execute('CREATE TABLE hat_durak (id INTEGER PRIMARY KEY AUTOINCREMENT, hat TEXT, durak_id TEXT, sira INTEGER, ad TEXT, lat REAL, lon REAL)');

      // Eksik tabloları kontrol et
      var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
      var names = tables.map((t) => t['name']).toSet();
      expect(names.contains('meta'), isFalse);
      expect(names.contains('sefer'), isFalse);
      expect(names.contains('odak'), isFalse);

      // createTables çağrıldığında eksik tabloları oluşturur
      await DatabaseHelper.createTables(db);

      tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
      names = tables.map((t) => t['name']).toSet();
      expect(names.contains('meta'), isTrue);
      expect(names.contains('sefer'), isTrue);
      expect(names.contains('odak'), isTrue);
      expect(names.contains('odak_durak'), isTrue);
      expect(names.contains('samair'), isTrue);
      expect(names.contains('samair_sefer'), isTrue);

      // Yeni tablolara veri yazılabilir mi?
      await db.insert('meta', {'key': 'last_update', 'value': '2026-03-04'});
      await db.insert('sefer', {'hat': 'R1', 'saat': '08:00', 'yon': 'gidis', 'gun': 'hergun'});
      await db.insert('odak', {'id': '1', 'ad': 'Odak Hat 1', 'kod': 'G_1', 'gunler': 'Pazartesi'});

      final meta = await db.query('meta');
      expect(meta.length, 1);
      final sefer = await db.query('sefer');
      expect(sefer.length, 1);
      final odak = await db.query('odak');
      expect(odak.length, 1);
    });

    test('fiyat tablosu şema uyumsuzluğu tespit edilip düzeltilir', () async {
      // Asset DB'deki eski fiyat şeması
      await db.execute('''
        CREATE TABLE fiyat (
          hat_code TEXT PRIMARY KEY,
          hat_adi TEXT,
          tam_fiyat REAL,
          indirimli_fiyat REAL,
          aktarma1 TEXT
        )
      ''');
      await db.insert('fiyat', {'hat_code': 'R1', 'hat_adi': 'Ring 1', 'tam_fiyat': 20.0});

      // Eski şemada kaynak ve ogrenci_fiyat yok
      final colsBefore = await db.rawQuery('PRAGMA table_info(fiyat)');
      final namesBefore = colsBefore.map((c) => c['name']).toSet();
      expect(namesBefore.contains('kaynak'), isFalse);
      expect(namesBefore.contains('ogrenci_fiyat'), isFalse);

      // Tablo yeniden oluşturulur (yeni şema)
      await db.execute('DROP TABLE IF EXISTS fiyat');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fiyat (
          id INTEGER PRIMARY KEY,
          kaynak TEXT,
          hat_adi TEXT,
          hat_code TEXT,
          tam_fiyat REAL DEFAULT 0,
          ogrenci_fiyat REAL DEFAULT 0,
          guncelleme TEXT
        )
      ''');

      // Yeni şema ile yazılabilir mi?
      await db.insert('fiyat', {
        'kaynak': 'proxy',
        'hat_adi': 'Ring 1',
        'hat_code': 'R1',
        'tam_fiyat': 20.0,
        'ogrenci_fiyat': 14.0,
        'guncelleme': '2026-03-04',
      });

      final rows = await db.query('fiyat');
      expect(rows.length, 1);
      expect(rows.first['kaynak'], 'proxy');
      expect(rows.first['ogrenci_fiyat'], 14.0);
    });
  });

  group('Senkronizasyon Veri Akışı — Tüm Tablolara Yazma/Okuma', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      await DatabaseHelper.createTables(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Senkronizasyon sonrası tüm tablolara veri yazılıp okunabilir', () async {
      // Sync'in yaptığı gibi toplu veri ekle
      final batch = db.batch();

      // hat
      batch.insert('hat', {'code': 'R1', 'name': 'R1 SAMSUN', 'tip': 'gidis', 'kat': 'ring'});
      batch.insert('hat', {'code': 'TRAMVAY-1', 'name': 'Tramvay 1', 'tip': 'gidis', 'kat': 'tramvay'});

      // durak
      batch.insert('durak', {'id': 'D1', 'kod': '100', 'ad': 'Merkez', 'lat': 41.29, 'lon': 36.33});
      batch.insert('durak', {'id': 'D2', 'kod': '200', 'ad': 'Atakum', 'lat': 41.33, 'lon': 36.28});

      // hat_durak
      batch.insert('hat_durak', {'hat': 'R1', 'durak_id': 'D1', 'ad': 'Merkez', 'sira': 1, 'lat': 41.29, 'lon': 36.33});
      batch.insert('hat_durak', {'hat': 'R1', 'durak_id': 'D2', 'ad': 'Atakum', 'sira': 2, 'lat': 41.33, 'lon': 36.28});

      // sefer
      batch.insert('sefer', {'hat': 'R1', 'saat': '07:30', 'yon': 'gidis', 'gun': 'hergun'});

      // fiyat
      batch.insert('fiyat', {'kaynak': 'proxy', 'hat_adi': 'R1 SAMSUN', 'hat_code': 'R1', 'tam_fiyat': 20.0, 'ogrenci_fiyat': 14.0, 'guncelleme': '2026-03-04'});

      // odak
      batch.insert('odak', {'id': '1', 'ad': 'Kültür Yolu', 'kod': 'G_1', 'gunler': 'Cumartesi'});

      // odak_durak
      batch.insert('odak_durak', {'hat': 'G_1', 'ad': 'Amisos Tepesi', 'kod': 'OD1', 'sira': 1, 'lat': 41.30, 'lon': 36.34, 'fiyat': '280', 'fiyat_ogr': '225'});

      // samair
      batch.insert('samair', {'id': 1, 'ad': 'Havalimanı H1', 'kod': 'H_1'});

      // samair_sefer
      batch.insert('samair_sefer', {'hat': 1, 'saat': '06:00', 'varis': '07:00', 'firma': 'THY', 'ucak_saat': '08:00', 'tarih': '2026-03-04', 'gun_format': 'Çarşamba'});

      // meta
      batch.insert('meta', {'key': 'last_update', 'value': '2026-03-04T17:00:00Z'});

      await batch.commit(noResult: true);

      // ASSERT: Tüm veriler doğru okunabilir
      expect((await db.query('hat')).length, 2);
      expect((await db.query('durak')).length, 2);
      expect((await db.query('hat_durak')).length, 2);
      expect((await db.query('sefer')).length, 1);
      expect((await db.query('fiyat')).length, 1);
      expect((await db.query('odak')).length, 1);
      expect((await db.query('odak_durak')).length, 1);
      expect((await db.query('samair')).length, 1);
      expect((await db.query('samair_sefer')).length, 1);
      expect((await db.query('meta')).length, 1);

      // meta'dan son güncelleme tarihi okunabilir mi?
      final meta = await db.query('meta', where: 'key = ?', whereArgs: ['last_update']);
      expect(meta.first['value'], '2026-03-04T17:00:00Z');
    });

    test('Veritabanı DELETE sonrası tekrar doldurulabilir (sync döngüsü)', () async {
      // İlk veri ekle
      await db.insert('hat', {'code': 'R1', 'name': 'Eski Hat', 'tip': 'gidis', 'kat': 'ring'});
      expect((await db.query('hat')).length, 1);

      // Sync: önce sil, sonra yeniden ekle
      await db.delete('hat');
      expect((await db.query('hat')).length, 0);

      await db.insert('hat', {'code': 'R1', 'name': 'Yeni Hat', 'tip': 'gidis', 'kat': 'ring'});
      final rows = await db.query('hat');
      expect(rows.length, 1);
      expect(rows.first['name'], 'Yeni Hat');
    });
  });

  group('Hata Dayanıklılığı (Error Resilience)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Var olmayan tablodan okuma DatabaseException fırlatır', () async {
      // Bu test, try-catch korumasının neden gerekli olduğunu gösterir
      expect(
        () async => await db.query('hat'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('createTables sonrası tüm tablolar güvenle sorgulanabilir', () async {
      await DatabaseHelper.createTables(db);

      // Hiçbir tablo sorgusu hata vermemeli (boş dönebilir ama hata değil)
      expect(await db.query('hat'), isEmpty);
      expect(await db.query('durak'), isEmpty);
      expect(await db.query('hat_durak'), isEmpty);
      expect(await db.query('sefer'), isEmpty);
      expect(await db.query('fiyat'), isEmpty);
      expect(await db.query('odak'), isEmpty);
      expect(await db.query('odak_durak'), isEmpty);
      expect(await db.query('samair'), isEmpty);
      expect(await db.query('samair_durak'), isEmpty);
      expect(await db.query('samair_sefer'), isEmpty);
      expect(await db.query('meta'), isEmpty);
    });

    test('ConflictAlgorithm.replace ile aynı PK tekrar yazılabilir', () async {
      await DatabaseHelper.createTables(db);

      await db.insert('hat', {'code': 'R1', 'name': 'Eski', 'tip': 'gidis', 'kat': 'ring'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('hat', {'code': 'R1', 'name': 'Yeni', 'tip': 'gidis', 'kat': 'ring'},
          conflictAlgorithm: ConflictAlgorithm.replace);

      final rows = await db.query('hat');
      expect(rows.length, 1);
      expect(rows.first['name'], 'Yeni');
    });
  });
}
