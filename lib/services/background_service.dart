import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Arka plan servisi — batarya dostu periyodik güncellemeler ve bildirimler.
///
/// 🔋 BATARYA OPTİMİZASYONU:
/// - Varsayılan aralık 30 dk (sık çalışmaz)
/// - Art arda başarısız isteklerde aralık otomatik uzar (backoff)
/// - Her görev 8sn timeout ile çalışır (uzun bağlantı beklenmez)
/// - Gece saatlerinde (00:00-06:00) uyku moduna geçer
/// - Tek seferde sadece 1 HTTP isteği yapılır (paralel istek yok)
/// - Canlı takip kapalıyken ekstra API çağrısı yapılmaz
/// - Kullanıcı ayarlardan her özelliği kapatabilir
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Timer? _updateTimer;
  bool _isRunning = false;
  int _consecutiveFailures = 0;
  DateTime? _lastSuccessfulCheck;

  // ─── KULLANICI AYARLARI (SharedPreferences'tan yüklenir) ───
  bool backgroundUpdateEnabled = true;
  bool backgroundNotificationsEnabled = true;
  bool backgroundLiveTrackingEnabled = false;
  int updateIntervalMinutes = 30; // Varsayılan: 30dk (batarya dostu)

  // Bildirim callback'i — uygulama katmanından set edilir
  void Function(String title, String body)? onNotification;

  static const String _renderBase = 'https://samsun-gtfs-rt.onrender.com/api';

  // 🔋 Batarya koruma sabitleri
  static const int _maxBackoffMinutes = 120;   // Max 2 saat aralığa uzayabilir
  static const int _nightStartHour = 0;        // Gece modu başlangıç
  static const int _nightEndHour = 6;          // Gece modu bitiş
  static const int _httpTimeoutSeconds = 8;     // Kısa timeout = az bekleme
  static const int _maxConsecutiveFailures = 5; // 5 hatadan sonra backoff

  /// Ayarları SharedPreferences'tan yükle
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      backgroundUpdateEnabled = prefs.getBool('bg_update_enabled') ?? true;
      backgroundNotificationsEnabled = prefs.getBool('bg_notifications_enabled') ?? true;
      backgroundLiveTrackingEnabled = prefs.getBool('bg_live_tracking_enabled') ?? false;
      updateIntervalMinutes = prefs.getInt('bg_update_interval') ?? 30;
    } catch (e) {
      debugPrint('BackgroundService ayar yükleme hatası: $e');
    }
  }

  /// Bir ayarı kaydet
  Future<void> saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('BackgroundService ayar kaydetme hatası: $e');
    }
  }

  /// 🔋 Aktif aralığı hesapla (backoff + gece modu)
  int get _effectiveIntervalMinutes {
    final now = DateTime.now();

    // Gece modu: 00:00-06:00 arası çalışma — batarya koru
    if (now.hour >= _nightStartHour && now.hour < _nightEndHour) {
      return 60; // Gece saatlerinde saatte 1 kontrol yeter
    }

    // Backoff: Art arda hata varsa aralığı uzat
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      final backoff = updateIntervalMinutes * 2;
      return backoff > _maxBackoffMinutes ? _maxBackoffMinutes : backoff;
    }

    return updateIntervalMinutes;
  }

  /// Servisi başlat
  Future<void> start() async {
    if (_isRunning) return;
    await loadSettings();

    if (!backgroundUpdateEnabled) {
      debugPrint('BackgroundService: Arka plan güncelleme devre dışı');
      return;
    }

    _isRunning = true;
    _consecutiveFailures = 0;
    final interval = _effectiveIntervalMinutes;
    debugPrint('BackgroundService başlatıldı (interval: ${interval}dk, batarya modu aktif)');

    // İlk çalıştırma — 10sn gecikme (uygulama açılışını bloklamaz)
    Future.delayed(const Duration(seconds: 10), () {
      if (_isRunning) _performBackgroundTasks();
    });

    // Periyodik güncelleme
    _scheduleNextRun();
  }

  /// 🔋 Bir sonraki çalışmayı planla (adaptif aralık)
  void _scheduleNextRun() {
    _updateTimer?.cancel();
    if (!_isRunning || !backgroundUpdateEnabled) return;

    final interval = _effectiveIntervalMinutes;
    _updateTimer = Timer(Duration(minutes: interval), () {
      _performBackgroundTasks();
      _scheduleNextRun(); // Bir sonrakini planla (aralık değişmiş olabilir)
    });
  }

  /// Servisi durdur
  void stop() {
    _updateTimer?.cancel();
    _isRunning = false;
    debugPrint('BackgroundService durduruldu');
  }

  /// Ayarlar değiştiğinde yeniden başlat
  Future<void> restart() async {
    stop();
    await start();
  }

  /// 🔋 Arka plan görevlerini çalıştır (tek tek, sırayla — paralel istek yok)
  Future<void> _performBackgroundTasks() async {
    if (!backgroundUpdateEnabled) return;

    debugPrint('BackgroundService: Görev çalışıyor (hata sayısı: $_consecutiveFailures)');

    try {
      // Yalnızca güncelleme kontrolü — hafif, tek HTTP isteği
      await _checkForUpdates();
      _consecutiveFailures = 0; // Başarılı — sayacı sıfırla
      _lastSuccessfulCheck = DateTime.now();
    } catch (e) {
      _consecutiveFailures++;
      debugPrint('BackgroundService görev hatası ($_consecutiveFailures): $e');
    }
  }

  /// Güncelleme kontrolü (sessiz, kısa timeout)
  Future<void> _checkForUpdates() async {
    try {
      final response = await http
          .get(Uri.parse('https://github.com/tarihcituranx/test/raw/main/releases/version.json'))
          .timeout(Duration(seconds: _httpTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final int latestCode = data['versionCode'] ?? 0;
        final String latestVersion = data['latestVersion'] ?? '';

        final prefs = await SharedPreferences.getInstance();
        final currentBuild = prefs.getInt('last_known_build') ?? 0;

        if (latestCode > currentBuild && backgroundNotificationsEnabled) {
          // Aynı güncellemeyi tekrar bildirme
          final lastNotifiedVersion = prefs.getString('last_notified_version') ?? '';
          if (lastNotifiedVersion != latestVersion) {
            _sendNotification(
              'Güncelleme Mevcut',
              'Samsun Ulaşım v$latestVersion yeni sürümü mevcut.',
            );
            await prefs.setString('last_notified_version', latestVersion);
          }
        }
      }
    } catch (e) {
      // Network yoksa sessizce geç — batarya harcama
      debugPrint('BackgroundService güncelleme kontrol hatası (sessiz): $e');
      rethrow; // Backoff mekanizması için yukarı at
    }
  }

  /// Bildirim gönder (callback üzerinden)
  void _sendNotification(String title, String body) {
    if (!backgroundNotificationsEnabled) return;
    debugPrint('BackgroundService Bildirim: $title — $body');
    onNotification?.call(title, body);
  }

  // ─── KULLANICI AYAR DEĞİŞTİRME METODLARİ ───

  /// Kullanıcı arka plan güncellemeyi açtı/kapattı
  Future<void> setBackgroundUpdateEnabled(bool enabled) async {
    backgroundUpdateEnabled = enabled;
    await saveSetting('bg_update_enabled', enabled);
    if (enabled) {
      await start();
    } else {
      stop();
    }
  }

  /// Kullanıcı bildirimleri açtı/kapattı
  Future<void> setNotificationsEnabled(bool enabled) async {
    backgroundNotificationsEnabled = enabled;
    await saveSetting('bg_notifications_enabled', enabled);
  }

  /// Kullanıcı canlı takibi açtı/kapattı
  Future<void> setLiveTrackingEnabled(bool enabled) async {
    backgroundLiveTrackingEnabled = enabled;
    await saveSetting('bg_live_tracking_enabled', enabled);
  }

  /// Güncelleme aralığını değiştir
  Future<void> setUpdateInterval(int minutes) async {
    updateIntervalMinutes = minutes;
    await saveSetting('bg_update_interval', minutes);
    await restart();
  }

  /// Son başarılı kontrol zamanı
  DateTime? get lastSuccessfulCheck => _lastSuccessfulCheck;
  bool get isRunning => _isRunning;
  int get consecutiveFailures => _consecutiveFailures;
}
