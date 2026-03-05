import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PriceService {
  static const String _pricesUrl = "https://raw.githubusercontent.com/tarihcituranx/Samsun-GTFS-RT/main/prices.json";
  static const String _renderBase = "https://samsun-gtfs-rt.onrender.com/api";
  
  static Map<String, dynamic>? _cachedPrices;
  static DateTime? _cacheTime;

  /// GitHub üzerindeki dinamik prices.json dosyasını çeker.
  /// 1 saat (3600s) boyunca önbellekte tutar.
  static Future<Map<String, dynamic>> fetchPrices() async {
    if (_cachedPrices != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!).inHours < 1) {
        return _cachedPrices!;
      }
    }

    try {
      final response = await http.get(Uri.parse(_pricesUrl)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _cachedPrices = data;
        _cacheTime = DateTime.now();
        return _cachedPrices!;
      }
    } catch (e) {
      debugPrint("Dinamik fiyat çekme hatası: $e");
    }

    // Fallback Fiyatlar (Sunucuya ulaşılamazsa) — Güncel: Mart 2026
    return _cachedPrices ?? {
      "default": {"tam": 30.0, "indirimli": 20.0},
      "otobus": {"tam": 30.0, "indirimli": 20.0},
      "tramvay_1_24": {"tam": 26.0, "indirimli": 18.0},
      "tramvay_1_42": {"tam": 34.0, "indirimli": 20.0},
      "tramvay_kampus": {"tam": 5.0, "indirimli": 3.0},
      "tramvay": {"tam": 26.0, "indirimli": 18.0},
      "teleferik": {"tam": 50.0, "indirimli": 30.0},
      "ekspres": {"tam": 30.0, "indirimli": 20.0},
      "ring": {"tam": 22.0, "indirimli": 16.0},
      "SAMSUNUM-1": {"tam": 250.0, "indirimli": 200.0},
      "SAMSUNUM-2": {"tam": 250.0, "indirimli": 200.0},
      "SAMSUNUM-3": {"tam": 250.0, "indirimli": 200.0},
      "tekne": {"tam": 250.0, "indirimli": 200.0},
      "havalimani": {"tam": 140.0, "indirimli": 70.0},
      "odak": {"tam": 280.0, "indirimli": 225.0},
      "ilce": {"tam": 70.0, "indirimli": 35.0},
      "aktarma": {"tam": 8.0, "indirimli": 8.0},
      "samkart": {"tam_kart": 110.0, "kisisel": 120.0, "vizeleme": 70.0, "kayip": 150.0},
      "abonman_ogrenci_50": {"tam": 500.0, "binis_basina": 10.0},
      "abonman_ogrenci_sinirsiz": {"tam": 550.0},
      "abonman_sivil_50": {"tam": 1000.0, "binis_basina": 20.0},
      "abonman_sivil_sinirsiz": {"tam": 1100.0}
    };
  }

  /// Hat fiyatını proxy üzerinden çek (samsun.py'nin samulas.com.tr'den çektiği güncel fiyatlar)
  /// Önce Render proxy → sonra GitHub prices.json → son fallback hardcoded
  static Future<Map<String, double>> getPriceForLine(String name, String kat) async {
    // 1. Render proxy: samsun.py'nin DB'sinden hat bazlı güncel fiyat
    try {
      final uri = Uri.parse("$_renderBase/hat/fiyat/${Uri.encodeComponent(name)}");
      final response = await http.get(uri, headers: {
        'User-Agent': 'samsun_ulasim/2.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic> && data['tam_fiyat'] != null) {
          final tam = (data['tam_fiyat'] as num?)?.toDouble() ?? 0.0;
          final ind = (data['indirimli_fiyat'] as num?)?.toDouble() ?? (tam * 0.70); // INDIRIMLI_ORAN ile senkron
          if (tam > 0) return {"tam": tam, "indirimli": ind};
        }
      }
    } catch (e) {
      debugPrint("Proxy fiyat çekme hatası: $e");
    }

    // 2. GitHub prices.json (kategori bazlı fallback)
    final prices = await fetchPrices();
    
    // Özel isme göre arama
    for (var key in prices.keys) {
      if (key != "default" && name.toUpperCase().contains(key.toUpperCase())) {
        return {
          "tam": (prices[key]["tam"] ?? 0.0).toDouble(),
          "indirimli": (prices[key]["indirimli"] ?? 0.0).toDouble()
        };
      }
    }
    
    // Kategoriye (kat) göre arama
    if (prices.containsKey(kat.toLowerCase())) {
      return {
        "tam": (prices[kat.toLowerCase()]["tam"] ?? 0.0).toDouble(),
        "indirimli": (prices[kat.toLowerCase()]["indirimli"] ?? 0.0).toDouble()
      };
    }
    
    // Default fallback
    final defaultPrices = prices["default"];
    return {
      "tam": (defaultPrices?["tam"] ?? 20.0).toDouble(),
      "indirimli": (defaultPrices?["indirimli"] ?? 14.0).toDouble()
    };
  }
}
