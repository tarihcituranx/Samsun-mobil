import 'package:flutter/material.dart';

/// Extracted from SamAirScreen — vehicle detail bottom sheet content.
class SamairVehicleDetailWidget extends StatelessWidget {
  final Map<String, dynamic> busData;
  final String plaka;
  final String hizi;
  final String hatKodu;

  const SamairVehicleDetailWidget({
    Key? key,
    required this.busData,
    required this.plaka,
    required this.hizi,
    required this.hatKodu,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gunlukYolcu = (busData['gunlukYolcu'] ?? busData['GunlukYolcu'] ?? '0').toString();
    final seferYolcu = (busData['seferYolcu'] ?? busData['SeferYolcu'] ?? '0').toString();
    final hasilat = (busData['toplamHasilat'] ?? busData['ToplamHasilat'] ?? '0').toString();
    final maxHiz = (busData['maxHiz'] ?? busData['MaxHiz'] ?? '0').toString();
    final mesafe = (busData['mesafe'] ?? busData['Mesafe'] ?? '0').toString();
    final yon = (busData['bearing'] ?? busData['yon'] ?? busData['Yon'] ?? '0').toString();
    final lastUpdate = (busData['lastUpdate'] ?? busData['editDate'] ?? busData['tarih'] ?? '').toString();
    String updateStr = '';
    if (lastUpdate.isNotEmpty) {
      try {
        final dt = DateTime.parse(lastUpdate);
        updateStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      } catch (_) {
        updateStr = lastUpdate;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF152238),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2979FF), Color(0xFF00BFA5)]), borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Icon(Icons.flight_takeoff, color: Colors.white, size: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plaka, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            if (hatKodu.isNotEmpty) Text(hatKodu, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF2979FF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Text('$hizi km/s', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2979FF), fontSize: 16)),
          ),
        ]),
        const Divider(color: Colors.white12, height: 28),
        Row(children: [
          _samairStat(Icons.people, seferYolcu, 'Sefer Yolcu'),
          _samairStat(Icons.groups, gunlukYolcu, 'Günlük Yolcu'),
          _samairStat(Icons.payments, '₺$hasilat', 'Hasılat'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _samairStat(Icons.speed, '$maxHiz km/s', 'Max Hız'),
          _samairStat(Icons.straighten, '${(int.tryParse(mesafe) ?? 0) ~/ 1000} km', 'Mesafe'),
          _samairStat(Icons.navigation, '$yon°', 'Yön'),
        ]),
        if (updateStr.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Son güncelleme: $updateStr', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
        ]
      ]),
    );
  }

  Widget _samairStat(IconData icon, String value, String label) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(color: const Color(0xFF1A2940), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, size: 18, color: const Color(0xFF2979FF).withValues(alpha: 0.7)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4))),
      ]),
    ));
  }
}
