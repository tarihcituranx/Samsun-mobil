
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

// samsun.py'nin veritabanı şemasını temel alan merkezi veritabanı yardımcısı.
class DatabaseHelper {

  static const _databaseName = "SamsunTransit.db";
  static const _databaseVersion = 1;
  static int get databaseVersion => _databaseVersion;

  // Tablo ve Sütun Adları (samsun.py'den alınmıştır)
  static const tableHat = 'hat';
  static const tableDurak = 'durak';
  static const tableHatDurak = 'hat_durak';
  static const tableSefer = 'sefer';
  static const tableFiyat = 'fiyat';
  static const tableOdak = 'odak';
  static const tableOdakDurak = 'odak_durak';
  static const tableSamair = 'samair';
  static const tableSamairDurak = 'samair_durak';
  static const tableSamairSefer = 'samair_sefer';
  static const tableMeta = 'meta';


  // Singleton sınıf yapısı
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Sadece tek bir uygulama çapında veritabanı referansı
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Veritabanını açar, eğer yoksa oluşturur.
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion,
        onCreate: (db, version) => createTables(db));
  }

  /// Veritabanını silip yeniden oluştur (test ve tam sıfırlama için).
  Future<void> deleteDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    await databaseFactory.deleteDatabase(path);
  }

  /// Veritabanı tabloları oluşturan statik metot.
  /// Hem DatabaseHelper hem DBService tarafından kullanılır.
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMeta(
        key TEXT PRIMARY KEY, 
        value TEXT
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableHat (
        code TEXT PRIMARY KEY, 
        name TEXT, 
        tip TEXT, 
        kat TEXT,
        alias TEXT, 
        short_name TEXT
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDurak (
        id TEXT PRIMARY KEY, 
        kod TEXT, 
        ad TEXT, 
        lat REAL, 
        lon REAL
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableHatDurak (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        hat TEXT, 
        durak_id TEXT, 
        ad TEXT, 
        sira INT, 
        lat REAL, 
        lon REAL,
        FOREIGN KEY (hat) REFERENCES $tableHat (code),
        FOREIGN KEY (durak_id) REFERENCES $tableDurak (id)
      )
      ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSefer (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        hat TEXT, 
        saat TEXT, 
        yon TEXT, 
        gun TEXT,
        FOREIGN KEY (hat) REFERENCES $tableHat (code)
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFiyat (
        id INTEGER PRIMARY KEY,
        kaynak TEXT, 
        hat_adi TEXT, 
        hat_code TEXT,
        tam_fiyat REAL DEFAULT 0, 
        ogrenci_fiyat REAL DEFAULT 0,
        guncelleme TEXT
      )
      ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOdak (
        id TEXT PRIMARY KEY, 
        ad TEXT, 
        kod TEXT, 
        gunler TEXT
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOdakDurak (
        id INTEGER PRIMARY KEY, 
        hat TEXT, 
        ad TEXT, 
        kod TEXT, 
        sira INT, 
        lat REAL, 
        lon REAL, 
        fiyat TEXT, 
        fiyat_ogr TEXT
      )
      ''');
      
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSamair (
        id INTEGER PRIMARY KEY, 
        ad TEXT, 
        kod TEXT
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSamairDurak (
        id INTEGER PRIMARY KEY, 
        hat INTEGER, 
        ad TEXT, 
        kod TEXT, 
        sira INT, 
        lat REAL, 
        lon REAL, 
        fiyat TEXT
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSamairSefer (
        id INTEGER PRIMARY KEY, 
        hat INTEGER, 
        saat TEXT, 
        varis TEXT, 
        firma TEXT, 
        ucak_saat TEXT, 
        tarih TEXT, 
        gun_format TEXT
      )
      ''');
      
    // İndeksler (samsun.py'deki gibi)
    await db.execute("CREATE INDEX IF NOT EXISTS idx_hd ON $tableHatDurak(hat)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_sf ON $tableSefer(hat)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_dk_latlon ON $tableDurak(lat, lon)");
  }
}
