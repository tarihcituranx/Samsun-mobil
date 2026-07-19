import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SamAirService {
  // Tüm çağrılar Render proxy üzerinden (proje şeması gereği)
  static const String _renderBase = 'https://deflation-shaded-sterility.ngrok-free.dev';

  // H1, H2, H3, H4, H5 hatlarını takip edeceğiz
  static final List<String> samairLines = ['H1', 'H2', 'H3', 'H4', 'H5'];

  static Future<List<Map<String, dynamic>>> getLiveSamAirBuses() async {
    List<Map<String, dynamic>> allVehicles = [];

    try {
      final r = await http.get(
        Uri.parse('$_renderBase/samair/vehicles'),
        headers: {'User-Agent': 'samsun_ulasim/2.0', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        var decodedData = json.decode(utf8.decode(r.bodyBytes));
        
        if (decodedData is Map && decodedData.containsKey('araçlar')) {
          List<dynamic> data = decodedData['araçlar'] ?? [];
          
          for (var item in data) {
            if (item is Map<String, dynamic>) {
              allVehicles.add({
                'lineCode': (item['HatKodu'] ?? 'SAMAIR').toString(),
                'lat': double.tryParse((item['enlem']).toString()) ?? 0.0,
                'lon': double.tryParse((item['boylam']).toString()) ?? 0.0,
                'plate': (item['plaka']).toString(),
                'speed': (item['hiz'] ?? '0').toString(),
                'yon': (item['yon'] ?? '0').toString(),
                'gunlukYolcu': (item['gunlukYolcu'] ?? '0').toString(),
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("SamAir Canlı Takip Hatası: $e");
    }

    return allVehicles;
  }
}
