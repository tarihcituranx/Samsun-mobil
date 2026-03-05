import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Samsun Ulaşım fiyat servisi.
///
/// Mart 2026 güncel sabit fiyatlar — ağ çağrısı yapmaz (1 yıl boyunca).
/// İstisna: Odak ve Samair fiyatları proxy'den dinamik çekilir.
class PriceService {
  static const String _renderBase = "https://samsun-gtfs-rt.onrender.com/api";

  // ───────────────────────────────────────────────────────────────
  // Sabit fiyat tablosu — Mart 2026 güncel
  // ───────────────────────────────────────────────────────────────
  static const Map<String, dynamic> _staticPrices = {
    "default":                  {"tam": 30.0, "indirimli": 20.0},
    "otobus":                   {"tam": 30.0, "indirimli": 20.0},
    "ekspres":                  {"tam": 30.0, "indirimli": 20.0},
    "ring":                     {"tam": 22.0, "indirimli": 16.0},
    "tramvay":                  {"tam": 26.0, "indirimli": 18.0},
    "tramvay_1_24":             {"tam": 26.0, "indirimli": 18.0},
    "tramvay_1_42":             {"tam": 34.0, "indirimli": 20.0},
    "tramvay_kampus":           {"tam": 5.0,  "indirimli": 3.0},
    "teleferik":                {"tam": 50.0, "indirimli": 30.0},
    "havalimani":               {"tam": 140.0, "indirimli": 70.0},
    "tekne":                    {"tam": 250.0, "indirimli": 200.0},
    "SAMSUNUM-1":               {"tam": 250.0, "indirimli": 200.0},
    "SAMSUNUM-2":               {"tam": 250.0, "indirimli": 200.0},
    "SAMSUNUM-3":               {"tam": 250.0, "indirimli": 200.0},
    "odak":                     {"tam": 280.0, "indirimli": 225.0},
    "ilce":                     {"tam": 70.0,  "indirimli": 35.0},
    "aktarma":                  {"tam": 8.0,   "indirimli": 8.0},
    "samkart":                  {"tam_kart": 110.0, "kisisel": 120.0, "vizeleme": 70.0, "kayip": 150.0},
    "abonman_ogrenci_50":       {"tam": 500.0, "binis_basina": 10.0},
    "abonman_ogrenci_sinirsiz": {"tam": 550.0},
    "abonman_sivil_50":         {"tam": 1000.0, "binis_basina": 20.0},
    "abonman_sivil_sinirsiz":   {"tam": 1100.0},
    "aktarma_ucretsiz_dk":      60,
    "aktarma_ucretli":          8.0,
  };

  /// Sabit fiyat tablosunu döner (ağ çağrısı yok).
  static Map<String, dynamic> getPrices() => _staticPrices;

  /// Geriye uyumluluk: eski fetchPrices() çağrıları için.
  /// Artık ağ çağrısı yapmaz, sabit tabloyu döner.
  static Future<Map<String, dynamic>> fetchPrices() async => _staticPrices;

  /// Hat fiyatını döner.
  ///
  /// Odak/Samair hatları → Render proxy'den dinamik çeker.
  /// Diğer hatlar → sabit tablodan döner (ağ çağrısı yok).
  static Future<Map<String, double>> getPriceForLine(String name, String kat) async {
    final katLower = kat.toLowerCase();

    // ── Odak ve Samair: proxy'den dinamik fiyat ───────────────
    if (katLower == 'odak' || katLower == 'samair') {
      try {
        final uri = Uri.parse(
            "$_renderBase/hat/fiyat/${Uri.encodeComponent(name)}");
        final response = await http.get(uri, headers: {
          'User-Agent': 'samsun_ulasim/2.5',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          if (data is Map<String, dynamic> && data['tam_fiyat'] != null) {
            final tam = (data['tam_fiyat'] as num?)?.toDouble() ?? 0.0;
            final ind = (data['indirimli_fiyat'] as num?)?.toDouble() ??
                (tam * 0.70);
            if (tam > 0) return {"tam": tam, "indirimli": ind};
          }
        }
      } catch (e) {
        debugPrint("Proxy fiyat çekme hatası ($name): $e");
      }
      // Proxy başarısız → sabit tablodan fallback
    }

    // ── Sabit tablodan fiyat bul ─────────────────────────────
    final prices = _staticPrices;

    // Özel isme göre arama
    for (var key in prices.keys) {
      if (key == "default") continue;
      final val = prices[key];
      if (val is! Map) continue;
      if (name.toUpperCase().contains(key.toUpperCase())) {
        return {
          "tam": ((val["tam"] ?? 0.0) as num).toDouble(),
          "indirimli": ((val["indirimli"] ?? 0.0) as num).toDouble(),
        };
      }
    }

    // Kategoriye göre arama
    if (prices.containsKey(katLower)) {
      final val = prices[katLower];
      if (val is Map) {
        return {
          "tam": ((val["tam"] ?? 0.0) as num).toDouble(),
          "indirimli": ((val["indirimli"] ?? 0.0) as num).toDouble(),
        };
      }
    }

    // Default fallback
    return {"tam": 30.0, "indirimli": 20.0};
  }
}
