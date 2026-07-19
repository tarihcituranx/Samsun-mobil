import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/ybs_api_service.dart';
import '../services/samair_service.dart';
import '../services/query_client.dart';
import '../widgets/samair_vehicle_detail_widget.dart';

class SamAirScreen extends StatefulWidget {
  const SamAirScreen({Key? key}) : super(key: key);

  @override
  State<SamAirScreen> createState() => _SamAirScreenState();
}

class _SamAirScreenState extends State<SamAirScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<dynamic> _liveBuses = [];
  bool _isLoading = true;
  StreamSubscription? _vehicleSubscription;
  late TabController _tabController;

  // Çarşamba Havaalanı Konumu
  final LatLng _airportLocation = const LatLng(41.2589, 36.5564);

  // SamAir hat isim eşleştirmesi
  static const Map<String, String> _lineNames = {
    'H1': 'H1 OMÜ-İlkadım',
    'H2': 'H2 TTTM-Canik',
    'H3': 'H3 Bafra-19 Mayıs',
    'H4': 'H4 Çarşamba-Salıpazarı',
    'H5': 'H5',
  };

  String _getLineName(String lineCode) {
    // Hat kodunu bul — tam eşleşme veya içerme
    for (final entry in _lineNames.entries) {
      if (lineCode.toUpperCase().contains(entry.key)) return entry.value;
    }
    return lineCode.isNotEmpty ? lineCode : 'SamAir';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _startLiveTracking();
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    QueryClient().removeSubscriber('samair_vehicles');
    _tabController.dispose();
    super.dispose();
  }

  void _startLiveTracking() {
    _vehicleSubscription = QueryClient().useQuery<List<dynamic>>(
      queryKey: 'samair_vehicles',
      queryFn: _fetchAllSamAirBuses,
      refetchInterval: const Duration(seconds: 15),
    ).listen((state) {
      if (mounted && state.data != null) {
        setState(() {
          _liveBuses = state.data!;
          _isLoading = false;
        });
      }
    });
  }

  Future<List<dynamic>> _fetchAllSamAirBuses() async {
    List<dynamic> allBuses = [];
    try {
      final results = await Future.wait(
        ['H1', 'H2', 'H3', 'H4', 'H5'].map((line) =>
          ApiService.getHattakiAraclar(line).catchError((e) {
            debugPrint('SamAir $line araç çekme hatası: $e');
            return <Map<String, dynamic>>[];
          })
        ),
      );
      for (var vehicles in results) {
        allBuses.addAll(vehicles);
      }
    } catch (e) { debugPrint('SamAir araç çekme hatası: $e'); }
    if (allBuses.isEmpty) {
      allBuses = await SamAirService.getLiveSamAirBuses();
    }
    return allBuses;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar
        Container(
          color: const Color(0xFF0F1E36),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF2979FF),
            labelColor: const Color(0xFF2979FF),
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(icon: Icon(Icons.map), text: "Harita"),
              Tab(text: "H1 OMÜ"),
              Tab(text: "H2 TTTM"),
              Tab(text: "H3 Bafra"),
              Tab(text: "H4 Çarşamba"),
              Tab(text: "H5"),
            ],
          ),
        ),
        
        // TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Harita kaydırması ile çakışmasın
            children: [
              _buildMapTab(),
              const _SamAirScheduleTab(lineId: 3, lineName: 'H1', color: Color(0xFF2979FF)),
              const _SamAirScheduleTab(lineId: 4, lineName: 'H2', color: Color(0xFF00BFA5)),
              const _SamAirScheduleTab(lineId: 5, lineName: 'H3', color: Color(0xFFFF5252)),
              const _SamAirScheduleTab(lineId: 9, lineName: 'H4', color: Color(0xFFFFAB00)),
              const _SamAirScheduleTab(lineId: 10, lineName: 'H5', color: Color(0xFF7C4DFF)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapTab() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(41.2867, 36.3300),
            initialZoom: 11.0,
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              tileProvider: NetworkTileProvider(
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Referer': 'https://www.openstreetmap.org/',
                },
              ),
            ),
            MarkerLayer(
              markers: [
                // Havaalanı İşareti
                Marker(
                  point: _airportLocation,
                  width: 60, height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF152238),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2979FF), width: 2),
                    ),
                    child: const Icon(Icons.local_airport, color: Color(0xFF2979FF), size: 30),
                  ),
                ),
                // Canlı Araçlar — Proxy: lat/lon/plate/speed, ASIS: lat/lon/plate/speed, YBS: Enlem/Boylam/Plaka/Hizi
                ..._liveBuses.where((b) {
                  final hasNormalized = b['lat'] != null && b['lon'] != null;
                  final hasYbs = b['Enlem'] != null && b['Boylam'] != null;
                  return hasNormalized || hasYbs;
                }).map((b) {
                  // Proxy/ASIS normalized format veya YBS raw format
                  final lat = double.tryParse((b['lat'] ?? b['Enlem'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
                  final lon = double.tryParse((b['lon'] ?? b['Boylam'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
                  if (lat == 0 || lon == 0) return null;
                  final hizi = (b['speed'] ?? b['hiz'] ?? b['Hizi'] ?? '0').toString();
                  final plaka = (b['plate'] ?? b['plaka'] ?? b['Plaka'] ?? 'SAMAIR').toString();
                  final hatKodu = (b['lineCode'] ?? b['HatKodu'] ?? '').toString();
                  final hatAdi = _getLineName(hatKodu);
                  
                  return Marker(
                    point: LatLng(lat, lon),
                    width: 50, height: 50,
                    child: GestureDetector(
                      onTap: () => _showSamairDetail(context, b, plaka, hizi, hatKodu),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF2979FF), Color(0xFF00BFA5)]),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(blurRadius: 8, color: const Color(0xFF2979FF).withValues(alpha: 0.5))],
                        ),
                        child: Center(
                          child: Text(
                            hatKodu.isNotEmpty ? hatKodu : 'SA',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                }).whereType<Marker>().toList(),
              ],
            ),
          ],
        ),
        
        if (_isLoading)
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF152238).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16)),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2979FF)),
                  SizedBox(height: 16),
                  Text("SamAIR araçları YBS'den yükleniyor...", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          
        Positioned(
          bottom: 20, left: 20, right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF152238),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/samair.png', width: 56, height: 56, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.flight_takeoff, color: Color(0xFF2979FF), size: 40)),
                      const SizedBox(width: 8),
                      const Text("Canlı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF2979FF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text("${_liveBuses.length} Araç", style: const TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  if (_liveBuses.isEmpty && !_isLoading)
                     Text("Şu anda hareket halinde olan SAMAIR aracı bulunmuyor.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                  if (_liveBuses.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _liveBuses.length,
                        itemBuilder: (context, i) {
                          final b = _liveBuses[i];
                          final plaka = (b['plate'] ?? b['plaka'] ?? b['Plaka'] ?? '?').toString();
                          final hizi = (b['speed'] ?? b['hiz'] ?? b['Hizi'] ?? '0').toString();
                          final hatKodu = (b['lineCode'] ?? b['HatKodu'] ?? '').toString();
                          final hatAdi = _getLineName(hatKodu);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () => _showSamairDetail(context, b, plaka, hizi, hatKodu),
                              child: Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  radius: 20,
                                  child: const Icon(Icons.flight_takeoff, color: Colors.white70),
                                ),
                                label: Text("$hatAdi - $hizi km/s", style: const TextStyle(color: Colors.white, fontSize: 11)),
                                backgroundColor: const Color(0xFF2979FF),
                                side: BorderSide.none,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  void _showSamairDetail(BuildContext ctx, Map<String, dynamic> b, String plaka, String hizi, String hatKodu) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => SamairVehicleDetailWidget(
        busData: b,
        plaka: plaka,
        hizi: hizi,
        hatKodu: hatKodu,
      ),
    );
  }
}

// ─── SCHEDULE TAB ───

class _SamAirScheduleTab extends StatefulWidget {
  final int lineId;
  final String lineName;
  final Color color;

  const _SamAirScheduleTab({required this.lineId, required this.lineName, required this.color});

  @override
  State<_SamAirScheduleTab> createState() => _SamAirScheduleTabState();
}

class _SamAirScheduleTabState extends State<_SamAirScheduleTab> {
  List<dynamic> _schedules = [];
  List<dynamic> _filteredSchedules = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    final s = await YbsApiService().getSamairSaatleri(widget.lineId);
    if (mounted) {
      setState(() {
        _schedules = s;
        _isLoading = false;
        _filterByDate();
      });
    }
  }

  void _filterByDate() {
    final selectedStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    setState(() {
      _filteredSchedules = _schedules.where((s) {
        final tarih = s['tarih']?.toString() ?? s['Tarih']?.toString() ?? s['date']?.toString() ?? '';
        // If schedule has a date field, filter by selected date
        if (tarih.isNotEmpty) {
          final scheduleDateStr = tarih.length >= 10 ? tarih.substring(0, 10) : tarih;
          return scheduleDateStr == selectedStr;
        }
        // If no date field, show all (static schedules)
        return true;
      }).toList();
    });
  }

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    // Don't allow past dates
    if (newDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) return;
    setState(() {
      _selectedDate = newDate;
      _filterByDate();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: widget.color));

    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;
    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}';
    final displaySchedules = _filteredSchedules.isNotEmpty ? _filteredSchedules : _schedules;

    return Column(
      children: [
        // Tarih Seçici
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0F1E36),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () => _changeDate(-1),
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(primary: widget.color, surface: const Color(0xFF152238)),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _filterByDate();
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: widget.color),
                      const SizedBox(width: 8),
                      Text(
                        isToday ? "Bugün ($dateStr)" : dateStr,
                        style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: () => _changeDate(1),
              ),
            ],
          ),
        ),

        // Sefer Listesi
        Expanded(
          child: displaySchedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.airplanemode_inactive, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text("Bu tarihte sefer bulunamadı.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(height: 8),
                      Text(dateStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: displaySchedules.length,
                  itemBuilder: (context, i) {
                    final s = displaySchedules[i];
                    final cityTime = s['saat']?.toString() ?? s['SehirKalkis']?.toString() ?? '-';
                    final flightTime = s['varis']?.toString() ?? s['varis_saati']?.toString() ?? s['UcusSaati']?.toString() ?? '-';
                    final flightNo = s['firma']?.toString() ?? s['ucak_firmasi']?.toString() ?? s['UcusKodu']?.toString() ?? '';
                    final note = s['ucak_saat']?.toString() ?? s['ucak_saatleri']?.toString() ?? s['Aciklama']?.toString() ?? '';
                    final tarih = s['tarih']?.toString() ?? s['Tarih']?.toString() ?? s['date']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF152238),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (tarih.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                                    const SizedBox(width: 6),
                                    Text(
                                      tarih.length >= 10 ? tarih.substring(0, 10) : tarih,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                    ),
                                    if (note.isNotEmpty) ...[
                                      const Spacer(),
                                      Text(note, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                                    ],
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                // Şehirden Kalkış
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Şehir Kalkış", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                                      Text(cityTime, style: TextStyle(color: widget.color, fontSize: 24, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                // Flight Icon
                                Icon(Icons.flight_takeoff, color: Colors.white.withValues(alpha: 0.2), size: 32),
                                // Uçuş Saati
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("Uçuş Saati", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                                      Text(flightTime, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                      if (flightNo.isNotEmpty)
                                        Text(flightNo, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
