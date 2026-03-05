import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:samsun_ulasim/constants.dart';

class HomeMapWidget extends StatelessWidget {
  final MapController mapController;
  final bool isLoadingMap;
  final LatLng myLocation;
  final LatLng? targetLocation;
  final List<LatLng> routePolyline;
  final List<Map<String, dynamic>> activeLineDuraklar;
  final List<LatLng> activeLineRoadPolyline;
  final List<Map<String, dynamic>> liveVehicles;
  final List<Map<String, dynamic>> duraklar;
  final bool showNearbyOnly;
  final String? activeLineCode;
  final List<Widget> toastOverlayWidgets;

  final void Function(LatLng latLng) onTargetSelected;
  final void Function(double lat, double lon) onCalculateRoute;
  final void Function(Map<String, dynamic> durak) onStopTap;
  final VoidCallback onLocationPress;
  final void Function(String msg) onToastError;

  const HomeMapWidget({
    Key? key,
    required this.mapController,
    required this.isLoadingMap,
    required this.myLocation,
    this.targetLocation,
    required this.routePolyline,
    required this.activeLineDuraklar,
    this.activeLineRoadPolyline = const [],
    required this.liveVehicles,
    required this.duraklar,
    required this.showNearbyOnly,
    this.activeLineCode,
    required this.toastOverlayWidgets,
    required this.onTargetSelected,
    required this.onCalculateRoute,
    required this.onStopTap,
    required this.onLocationPress,
    required this.onToastError,
  }) : super(key: key);

  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingMap) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: const Color(0xFF2979FF).withValues(alpha: 0.7))),
        const SizedBox(height: 20),
        Text("Duraklar yükleniyor...", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
      ]));
    }
    return Stack(children: [
      FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: myLocation,
          initialZoom: 13.0,
          onLongPress: (tapPos, latLng) {
            onTargetSelected(latLng);
            showDialog(context: context, builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1A2940),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("🎯 Hedef Seçildi", style: TextStyle(color: Colors.white)),
              content: Text("Bu konuma nasıl giderim?", style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal", style: TextStyle(color: Colors.white.withValues(alpha: 0.5)))),
                ElevatedButton(
                  onPressed: () { Navigator.pop(context); onCalculateRoute(latLng.latitude, latLng.longitude); },
                  child: const Text("Rota Hesapla"),
                ),
              ],
            ));
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png",
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.samsun.transit',
          ),
          // Teleferik Hattı Polyline (Batıpark ↔ Amisos Tepesi)
          PolylineLayer(polylines: [
            if (routePolyline.isNotEmpty)
              Polyline(points: routePolyline, strokeWidth: 5.0, color: const Color(0xFF2979FF)),
            // RT-14: Seçili hattın güzergah polyline'ı (yol takip eden)
            if (activeLineDuraklar.isNotEmpty)
              Polyline(
                points: activeLineRoadPolyline.isNotEmpty
                    ? activeLineRoadPolyline
                    : activeLineDuraklar
                        .where((d) => (d['lat'] as num?)?.toDouble() != null && (d['lat'] as num).toDouble() > 0)
                        .map((d) => LatLng((d['lat'] as num).toDouble(), (d['lon'] as num).toDouble()))
                        .toList(),
                strokeWidth: 4.0,
                color: const Color(0xFF00BFA5),
              ),
            Polyline(
              points: const [
                LatLng(teleferikAltLat, teleferikAltLon), // Batıpark (alt istasyon)
                LatLng(teleferikUstLat, teleferikUstLon), // Amisos Tepesi (üst istasyon)
              ],
              strokeWidth: 3.5,
              color: const Color(0xFFFF4081),
              isDotted: true,
            ),
          ]),
          MarkerLayer(markers: [
            // Benim konumum
            Marker(point: myLocation, width: 40, height: 40, child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2979FF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 3)],
              ),
              child: const Center(child: Icon(Icons.person, color: Colors.white, size: 18)),
            )),
            // Hedef
            if (targetLocation != null)
              Marker(point: targetLocation!, width: 40, height: 40, child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 3)],
                ),
                child: const Center(child: Icon(Icons.flag, color: Colors.white, size: 18)),
              )),
            // RT-14/RT-16: Seçili hattın durak marker'ları (tıklanınca durak adı gösterilsin)
            ...activeLineDuraklar
                .where((d) => (d['lat'] as num?)?.toDouble() != null && (d['lat'] as num).toDouble() > 0)
                .map((d) {
              final sira = (d['sira'] as num?)?.toInt() ?? 0;
              final ad = d['ad']?.toString() ?? 'Durak $sira';
              return Marker(
                point: LatLng((d['lat'] as num).toDouble(), (d['lon'] as num).toDouble()),
                width: 24, height: 24,
                child: GestureDetector(
                  onTap: () {
                    // RT-16: Durak bilgisi göster
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📍 $sira. $ad', style: const TextStyle(fontWeight: FontWeight.bold)),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF00695C),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(child: Text('$sira', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                  ),
                ),
              );
            }),
            ...liveVehicles.map((v) => Marker(
              point: LatLng(v['lat'] as double, v['lon'] as double),
              width: 38, height: 38,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2979FF), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Center(
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset(
                        'assets/bus.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.directions_bus, color: Color(0xFF2979FF), size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            )).toList(),
            // Teleferik İstasyonları
            Marker(
              point: const LatLng(teleferikAltLat, teleferikAltLon), width: 40, height: 40,
              child: Tooltip(
                message: teleferikAltAd,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4081),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF4081).withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)],
                  ),
                  child: const Center(child: Icon(Icons.airline_seat_recline_extra, color: Colors.white, size: 18)),
                ),
              ),
            ),
            Marker(
              point: const LatLng(teleferikUstLat, teleferikUstLon), width: 40, height: 40,
              child: Tooltip(
                message: teleferikUstAd,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4081),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF4081).withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)],
                  ),
                  child: const Center(child: Icon(Icons.terrain, color: Colors.white, size: 18)),
                ),
              ),
            ),
            // Duraklar (en yakın 300 veya sadece yakın)
            ...() {
              var sorted = List<Map<String, dynamic>>.from(duraklar);
              // Teleferik duraklarını filtrele — zaten ayrı marker olarak gösteriliyor
              sorted.removeWhere((d) => (d['kod']?.toString() ?? '').startsWith('T') && (d['ad']?.toString() ?? '').contains('Teleferik'));
              sorted.sort((a, b) {
                double da = haversine(myLocation.latitude, myLocation.longitude, (a['lat'] as num).toDouble(), (a['lon'] as num).toDouble());
                double db = haversine(myLocation.latitude, myLocation.longitude, (b['lat'] as num).toDouble(), (b['lon'] as num).toDouble());
                return da.compareTo(db);
              });
              final filtered = showNearbyOnly
                  ? sorted.where((d) => haversine(myLocation.latitude, myLocation.longitude, (d['lat'] as num).toDouble(), (d['lon'] as num).toDouble()) < 1.0)
                  : sorted.take(300);
              return filtered.map((d) {
                double lat = (d['lat'] as num).toDouble();
                double lon = (d['lon'] as num).toDouble();
                if (showNearbyOnly) {
                  return Marker(
                    point: LatLng(lat, lon),
                    width: 100, height: 45,
                    child: GestureDetector(
                      onTap: () => onStopTap(d),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2979FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)],
                            ),
                            child: const Center(child: Icon(Icons.directions_bus, color: Colors.white, size: 14)),
                          ),
                          Text(d['ad'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 3, color: Colors.white, offset: Offset(0, 0)), Shadow(blurRadius: 6, color: Colors.white, offset: Offset(0, 0))]), overflow: TextOverflow.ellipsis, maxLines: 1),
                        ],
                      ),
                    ),
                  );
                }
                return Marker(
                  point: LatLng(lat, lon), 
                  width: 28, height: 28,
                  child: GestureDetector(
                    onTap: () => onStopTap(d), 
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2979FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)],
                      ),
                      child: const Center(child: Icon(Icons.directions_bus, color: Colors.white, size: 14)),
                    ),
                  )
                );
              });
            }(),
          ]),
        ],
      ),
      // FAB'lar
      Positioned(bottom: 16, right: 16,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _glassFab(Icons.my_location, onLocationPress),
          const SizedBox(height: 8),
          if (liveVehicles.isNotEmpty)
            _glassFab(Icons.directions_bus, () {
              // Canlı araç bilgilerini göster
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🚌 ${liveVehicles.length} canlı araç takip ediliyor ($activeLineCode)'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF0D47A1),
                ),
              );
            }, badge: '${liveVehicles.length}'),
        ]),
      ),
      // Durak sayacı
      Positioned(bottom: 16, left: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on, color: Color(0xFF2979FF), size: 14),
            const SizedBox(width: 4),
            Text("${duraklar.length} durak", style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
          ]),
        ),
      ),
      // Akıllı Durak (SmartStation) / QR Durak Arama
      Positioned(top: 8, left: 12, right: 12, // Safe area genelde AppBar veya framework halleder ama SafeArea sarmalayınca daha iyi
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF152238).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Akıllı Durak No girin (Örn: 10101)",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                prefixIcon: const Icon(Icons.qr_code_scanner, color: Color(0xFF69F0AE), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (val) {
                final query = val.trim();
                if (query.isNotEmpty) {
                   final find = duraklar.where((d) {
                     final durakId = d['id']?.toString() ?? '';
                     final kod = d['kod']?.toString() ?? '';
                     final ad = d['ad']?.toString() ?? '';
                     // Adın başındaki sayısal kısmı da akıllı durak no olarak kabul et (ör: "50122 - SOĞUK SU")
                     final adMatch = RegExp(r'^(\d+)').firstMatch(ad);
                     final adKod = adMatch?.group(1) ?? '';
                     return durakId == query || kod == query || adKod == query || ad.toUpperCase().contains(query.toUpperCase());
                   }).toList();
                   if (find.isNotEmpty) {
                      final f = find.first;
                      mapController.move(LatLng((f['lat'] as num).toDouble(), (f['lon'] as num).toDouble()), 16.0);
                      onStopTap(f);
                   } else {
                      onToastError("❌ Durak bulunamadı: $query");
                   }
                }
              },
            ),
          ),
        ),
      ),
      // TOAST OVERLAY
      ...toastOverlayWidgets,
    ]);
  }

  Widget _glassFab(IconData icon, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF152238).withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
        ),
        child: Stack(children: [
          Center(child: Icon(icon, color: const Color(0xFF2979FF), size: 22)),
          if (badge != null)
            Positioned(top: 2, right: 2, child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Color(0xFFFF5252), shape: BoxShape.circle),
              child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            )),
        ]),
      ),
    );
  }
}
