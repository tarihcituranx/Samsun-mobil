import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, useColorScheme, ActivityIndicator, TextInput, Modal, FlatList } from 'react-native';
import { Colors } from '../constants/Colors';
import { Typography } from '../constants/Typography';
import { ArrowLeft, ArrowUpDown, MapPin, Navigation2, Clock, Info, Bus, Footprints, Train, Search, X } from 'lucide-react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as Location from 'expo-location';
import { useRouteSearch, OTPItinerary } from '../api/useRouteSearch';
import { useAllStops } from '../services/api/samsun';
import { SuperStop } from '../types/transit';
import { useRouteStore } from '../store/useRouteStore';

// Tip tanımlamaları
type LocationResult = {
  id: string;
  name: string;
  desc: string;
  lat: number;
  lon: number;
  type: 'stop' | 'place';
};

export default function RouteScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const destLat = params.destLat as string;
  const destLon = params.destLon as string;
  const setActiveItinerary = useRouteStore(state => state.setActiveItinerary);

  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';
  const theme = Colors[isDark ? 'dark' : 'light'];

  // Uygulama içi 1627 durak verisi
  const { data: stops = [] } = useAllStops();

  // Seçilmiş Koordinatlar
  const [fromCoords, setFromCoords] = useState<string>('');
  const [toCoords, setToCoords] = useState<string>(destLat && destLon ? `${destLat},${destLon}` : '');
  
  // Arayüzde Görünen Metinler
  const [fromText, setFromText] = useState<string>('Konum aranıyor...');
  const [toText, setToText] = useState<string>(destLat ? 'Seçilen Hedef (Harita)' : '');

  const [shouldSearch, setShouldSearch] = useState(false);
  const { data: itineraries, isLoading, isError, error } = useRouteSearch(fromCoords, toCoords, shouldSearch);

  // Arama Modalı State'leri
  const [searchVisible, setSearchVisible] = useState(false);
  const [activeInput, setActiveInput] = useState<'from' | 'to'>('from');
  const [searchText, setSearchText] = useState('');
  const [searchResults, setSearchResults] = useState<LocationResult[]>([]);
  const [isSearchingPhoton, setIsSearchingPhoton] = useState(false);

  useEffect(() => {
    (async () => {
      let { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') return;
      let location = await Location.getCurrentPositionAsync({});
      setFromCoords(`${location.coords.latitude},${location.coords.longitude}`);
      setFromText('Mevcut Konumum');
    })();
  }, []);

  // Hibrit Arama (Duraklar + Photon)
  useEffect(() => {
    if (searchText.length < 3) {
      setSearchResults([]);
      return;
    }

    const delay = setTimeout(async () => {
      // 1. Yerel Durakları Filtrele
      const query = searchText.toLowerCase();
      const matchedStops = stops
        .filter(s => s.isim.toLowerCase().includes(query))
        .slice(0, 5) // En fazla 5 durak göster
        .map(s => ({
          id: `stop_${s.id}`,
          name: s.isim,
          desc: 'Otobüs/Tramvay Durağı',
          lat: s.konum.lat,
          lon: s.konum.lng,
          type: 'stop' as const
        }));

      setSearchResults(matchedStops);
      
      // 2. Google Places API (VPS üzerinden) ve Fallback Photon API
      try {
        setIsSearchingPhoton(true);
        const apiBaseUrl = useSettingsStore.getState().getCurrentCity().apiBaseUrl;
        
        let photonPlaces = [];
        try {
          // Önce VPS'teki Google Places uç noktamızı deneyelim
          const googleRes = await fetch(`${apiBaseUrl}/places/search?q=${encodeURIComponent(searchText)}`, {
            headers: { 'x-api-key': 'mobile-client' } // Eger API key gerekliyse (su an optional)
          });
          
          if (googleRes.ok) {
            const data = await googleRes.json();
            photonPlaces = data.features || [];
          } else {
            throw new Error('Google Places API failed');
          }
        } catch (googleErr) {
          console.warn('Google Places Hatası, Photon API\'ye düşülüyor...', googleErr);
          // Fallback: Photon
          const photonRes = await fetch(`https://photon.komoot.io/api/?q=${encodeURIComponent(searchText)}+Samsun&limit=5`);
          const data = await photonRes.json();
          
          if (data.features && data.features.length > 0) {
            photonPlaces = data.features.map((f: any) => ({
              id: `photon_${f.properties.osm_id}`,
              name: f.properties.name || f.properties.street || 'Bilinmeyen Yer',
              desc: [f.properties.street, f.properties.district, f.properties.city].filter(Boolean).join(', '),
              lat: f.geometry.coordinates[1],
              lon: f.geometry.coordinates[0],
              type: 'place' as const
            }));
          }
        }

        setSearchResults(prev => {
          // Kendi duraklarımız ile dış mekan sonuçlarını birleştir
          const combined = [...prev, ...photonPlaces];
          return combined;
        });
      } catch (err) {
        console.warn('Genel Arama Hatası:', err);
      } finally {
        setIsSearchingPhoton(false);
      }
    }, 500); // 500ms debounce

    return () => clearTimeout(delay);
  }, [searchText]);

  const handleSwap = () => {
    setFromCoords(toCoords);
    setFromText(toText);
    setToCoords(fromCoords);
    setToText(fromText);
  };

  const openSearch = (type: 'from' | 'to') => {
    setActiveInput(type);
    setSearchText('');
    setSearchResults([]);
    setSearchVisible(true);
  };

  const selectLocation = (item: LocationResult) => {
    const coords = `${item.lat},${item.lon}`;
    if (activeInput === 'from') {
      setFromCoords(coords);
      setFromText(item.name);
    } else {
      setToCoords(coords);
      setToText(item.name);
    }
    setSearchVisible(false);
    setShouldSearch(false); // Yeni konum seçildi, butona basması beklensin
  };

  const formatTime = (ts: number) => {
    const d = new Date(ts);
    return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={[styles.header, { backgroundColor: theme.cardBackground, borderBottomColor: theme.border }]}>
        <View style={styles.headerTop}>
          <TouchableOpacity onPress={() => router.back()} style={styles.backBtn}>
            <ArrowLeft color={theme.text} size={24} />
          </TouchableOpacity>
          <Text style={[styles.title, { color: theme.text, ...Typography.heading }]}>Yol Tarifi</Text>
          <View style={{ width: 24 }} />
        </View>

        <View style={styles.inputsContainer}>
          <TouchableOpacity style={[styles.inputBox, { borderColor: theme.border }]} onPress={() => openSearch('from')}>
            <MapPin color={theme.info} size={20} />
            <Text style={{ color: fromCoords ? theme.text : theme.textSecondary, marginLeft: 8 }} numberOfLines={1}>
              {fromText || 'Nereden?'}
            </Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={[styles.inputBox, { borderColor: theme.border }]} onPress={() => openSearch('to')}>
            <Navigation2 color={theme.error} size={20} />
            <Text style={{ color: toCoords ? theme.text : theme.textSecondary, marginLeft: 8 }} numberOfLines={1}>
              {toText || 'Nereye?'}
            </Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={[styles.swapBtn, { backgroundColor: theme.cardBackground, borderColor: theme.border }]} onPress={handleSwap}>
            <ArrowUpDown color={theme.tint} size={18} />
          </TouchableOpacity>
        </View>
        
        <TouchableOpacity 
          style={[styles.searchBtn, { backgroundColor: fromCoords && toCoords ? theme.tint : theme.border }]} 
          onPress={() => setShouldSearch(true)}
          disabled={!fromCoords || !toCoords}
        >
          <Text style={styles.searchBtnText}>Rota Bul</Text>
        </TouchableOpacity>
      </View>

      {/* Hibrit Arama Modalı */}
      <Modal visible={searchVisible} animationType="slide" presentationStyle="pageSheet">
        <SafeAreaView style={[styles.modalContainer, { backgroundColor: theme.background }]}>
          <View style={[styles.modalHeader, { borderBottomColor: theme.border }]}>
            <TouchableOpacity onPress={() => setSearchVisible(false)} style={styles.modalClose}>
              <X color={theme.text} size={24} />
            </TouchableOpacity>
            <View style={[styles.modalSearchBox, { backgroundColor: theme.cardBackground }]}>
              <Search color={theme.textSecondary} size={20} />
              <TextInput
                style={[styles.modalInput, { color: theme.text }]}
                placeholder="Durak, sokak veya mekan ara..."
                placeholderTextColor={theme.textSecondary}
                autoFocus
                value={searchText}
                onChangeText={setSearchText}
              />
            </View>
          </View>

          <FlatList
            data={searchResults}
            keyExtractor={item => item.id}
            contentContainerStyle={styles.listContent}
            ListHeaderComponent={
              isSearchingPhoton ? <ActivityIndicator style={{margin: 20}} color={theme.tint} /> : null
            }
            renderItem={({ item }) => (
              <TouchableOpacity 
                style={[styles.resultItem, { borderBottomColor: theme.border }]}
                onPress={() => selectLocation(item)}
              >
                <View style={[styles.iconWrap, { backgroundColor: item.type === 'stop' ? theme.bus + '20' : theme.info + '20' }]}>
                  {item.type === 'stop' ? (
                    <Bus color={theme.bus} size={20} />
                  ) : (
                    <MapPin color={theme.info} size={20} />
                  )}
                </View>
                <View style={styles.resultTextWrap}>
                  <Text style={[styles.resultName, { color: theme.text }]}>{item.name}</Text>
                  <Text style={[styles.resultDesc, { color: theme.textSecondary }]} numberOfLines={1}>
                    {item.desc}
                  </Text>
                </View>
              </TouchableOpacity>
            )}
            ListEmptyComponent={
              searchText.length >= 3 && !isSearchingPhoton ? (
                <Text style={{ textAlign: 'center', marginTop: 40, color: theme.textSecondary }}>
                  Sonuç bulunamadı.
                </Text>
              ) : null
            }
          />
        </SafeAreaView>
      </Modal>

      <ScrollView style={styles.content}>
        {!shouldSearch ? (
          <View style={styles.emptyState}>
            <MapPin color={theme.textSecondary} size={48} opacity={0.5} />
            <Text style={[styles.emptyText, { color: theme.textSecondary }]}>
              Hedefinize gitmek için en iyi alternatifleri bulun.
            </Text>
          </View>
        ) : isLoading ? (
          <View style={styles.emptyState}>
            <ActivityIndicator size="large" color={theme.tint} />
            <Text style={[styles.emptyText, { color: theme.textSecondary, marginTop: 12 }]}>Rotalar hesaplanıyor...</Text>
          </View>
        ) : isError ? (
          <View style={styles.emptyState}>
            <Info color={theme.error} size={48} />
            <Text style={[styles.emptyText, { color: theme.error, marginTop: 12 }]}>
              {error instanceof Error ? error.message : 'Rota bulunamadı'}
            </Text>
          </View>
        ) : (
          <View style={styles.resultsContainer}>
            <Text style={[styles.resultsTitle, { color: theme.text }]}>Alternatif Rotalar</Text>
            
            {itineraries?.map((itin: OTPItinerary, index: number) => {
              const minutes = Math.round(itin.duration / 60);
              return (
                <TouchableOpacity 
                  key={index} 
                  style={[styles.resultCard, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}
                  onPress={() => {
                    setActiveItinerary(itin);
                    router.push('/');
                  }}
                >
                  <View style={styles.resultHeader}>
                    <View style={styles.routeBadges}>
                      {itin.legs.map((leg, i) => {
                        if (leg.mode === 'WALK') return <Footprints key={i} size={16} color={theme.textSecondary} style={{marginRight: 6}} />;
                        if (leg.mode === 'TRAM') return (
                          <View key={i} style={[styles.badge, { backgroundColor: theme.tram, flexDirection: 'row', alignItems: 'center' }]}>
                            <Train size={14} color="#FFF" style={{marginRight: 4}}/>
                            <Text style={styles.badgeText}>{leg.routeShortName || 'TRAM'}</Text>
                          </View>
                        );
                        return (
                          <View key={i} style={[styles.badge, { backgroundColor: theme.bus, flexDirection: 'row', alignItems: 'center' }]}>
                            <Bus size={14} color="#FFF" style={{marginRight: 4}}/>
                            <Text style={styles.badgeText}>{leg.routeShortName || 'BUS'}</Text>
                          </View>
                        );
                      })}
                    </View>
                    <View style={styles.timeInfo}>
                      <Clock size={16} color={theme.success} />
                      <Text style={[styles.timeText, { color: theme.success }]}>{minutes} dk</Text>
                    </View>
                  </View>
                  <View style={styles.resultDetails}>
                    <Text style={{ color: theme.textSecondary, fontSize: 13, marginTop: 4 }}>
                      Yürüme: {Math.round(itin.walkDistance)}m • Ayrılış: {formatTime(itin.startTime)} • Varış: {formatTime(itin.endTime)}
                    </Text>
                  </View>
                </TouchableOpacity>
              );
            })}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { padding: 16, paddingTop: 8, borderBottomWidth: 1 },
  headerTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 },
  backBtn: { padding: 4 },
  title: { fontSize: 20 },
  inputsContainer: { position: 'relative', gap: 12, marginBottom: 16 },
  inputBox: { flexDirection: 'row', alignItems: 'center', height: 48, borderWidth: 1, borderRadius: 12, paddingHorizontal: 16, paddingRight: 40 },
  swapBtn: { position: 'absolute', right: 20, top: 35, width: 36, height: 36, borderRadius: 18, borderWidth: 1, alignItems: 'center', justifyContent: 'center', zIndex: 10 },
  searchBtn: { height: 48, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  searchBtnText: { color: '#FFF', fontSize: 16, fontWeight: 'bold' },
  content: { flex: 1 },
  emptyState: { padding: 40, alignItems: 'center', justifyContent: 'center', marginTop: 60 },
  emptyText: { marginTop: 16, fontSize: 16, textAlign: 'center' },
  resultsContainer: { padding: 16 },
  resultsTitle: { fontSize: 18, fontWeight: 'bold', marginBottom: 16 },
  resultCard: { padding: 16, borderRadius: 16, borderWidth: 1, marginBottom: 12 },
  resultHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 },
  routeBadges: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', flex: 1, gap: 4 },
  badge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 6, marginRight: 4 },
  badgeText: { color: '#FFF', fontWeight: 'bold', fontSize: 12 },
  timeInfo: { flexDirection: 'row', alignItems: 'center', gap: 4, marginLeft: 8 },
  timeText: { fontWeight: 'bold', fontSize: 16 },
  resultDetails: { marginTop: 4 },
  
  modalContainer: { flex: 1 },
  modalHeader: { flexDirection: 'row', alignItems: 'center', padding: 16, borderBottomWidth: 1 },
  modalClose: { padding: 8, marginRight: 8 },
  modalSearchBox: { flex: 1, flexDirection: 'row', alignItems: 'center', height: 44, borderRadius: 10, paddingHorizontal: 12 },
  modalInput: { flex: 1, marginLeft: 8, fontSize: 16 },
  listContent: { padding: 16 },
  resultItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12, borderBottomWidth: StyleSheet.hairlineWidth },
  iconWrap: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center', marginRight: 12 },
  resultTextWrap: { flex: 1 },
  resultName: { fontSize: 16, fontWeight: '500', marginBottom: 4 },
  resultDesc: { fontSize: 13 }
});
