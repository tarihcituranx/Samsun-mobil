import React, { useMemo, useState, useEffect } from 'react';
import { View, Text, StyleSheet, ActivityIndicator, useColorScheme, TouchableOpacity, ScrollView } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
// @ts-ignore
import MapboxGL from '@maplibre/maplibre-react-native';
import { BlurView } from 'expo-blur';
import { Colors } from '../../constants/Colors';
import { Typography } from '../../constants/Typography';
import { useSuperLine } from '../../services/api/samsun';
import { MapStyles } from '../../types/transit';
import { StopMarkers } from '../../components/map/StopMarker';
import { VehicleMarker } from '../../components/map/VehicleMarker';
import { RoutePolyline } from '../../components/map/RoutePolyline';
import { ArrowLeft, Clock, List, Map as MapIcon, RefreshCcw } from 'lucide-react-native';

export default function LineDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  
  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';
  const theme = Colors[isDark ? 'dark' : 'light'];

  const { data: superLine, isLoading, isError } = useSuperLine(id as string);

  const [activeTab, setActiveTab] = useState<string>('Hafta İçi');
  const [showAllSchedules, setShowAllSchedules] = useState(false);
  const [viewMode, setViewMode] = useState<'map'|'list'>('map');

  // Set default tab if Hafta İçi doesn't exist
  useEffect(() => {
    if (superLine?.saatler && !superLine.saatler[activeTab]) {
      const keys = Object.keys(superLine.saatler);
      if (keys.length > 0) {
        setActiveTab(keys[0]);
      }
    }
  }, [superLine]);

  // Parse polyline from stops
  const routeCoords = useMemo(() => {
    if (!superLine?.duraklar) return [];
    return superLine.duraklar.map(d => ({ lat: parseFloat(d.enlem), lng: parseFloat(d.boylam) }));
  }, [superLine]);
  
  // Format stops for map component
  const stopsForMap = useMemo(() => {
    if (!superLine?.duraklar) return [];
    return superLine.duraklar.map(d => ({
      id: d.durak_id,
      isim: d.durak_adi,
      yon: d.yon,
      sira: d.sira,
      konum: { lat: parseFloat(d.enlem), lng: parseFloat(d.boylam) }
    }));
  }, [superLine]);

  if (isLoading) {
    return (
      <View style={[styles.center, { backgroundColor: theme.background }]}>
        <ActivityIndicator size="large" color={theme.tint} />
        <Text style={[styles.loadingText, { color: theme.text }]}>Hat verileri birleştiriliyor...</Text>
      </View>
    );
  }

  if (isError || !superLine) {
    return (
      <View style={[styles.center, { backgroundColor: theme.background }]}>
        <Text style={[styles.errorText, { color: theme.error }]}>Bu hat bilgisine ulaşılamadı.</Text>
        <TouchableOpacity style={styles.backButton} onPress={() => router.back()}>
          <Text style={{ color: 'white' }}>Geri Dön</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const centerCoord = routeCoords.length > 0 
    ? [routeCoords[Math.floor(routeCoords.length / 2)].lng, routeCoords[Math.floor(routeCoords.length / 2)].lat]
    : [36.33, 41.28667]; // Default Samsun

  return (
    <View style={styles.container}>
      {viewMode === 'map' ? (
        <MapboxGL.MapView
          style={styles.map}
          styleURL={isDark ? MapStyles.dark : MapStyles.light}
          logoEnabled={false}
          attributionEnabled={false}
        >
          <MapboxGL.Camera
            zoomLevel={12}
            centerCoordinate={centerCoord}
            animationMode="flyTo"
            animationDuration={1500}
          />
          
          {/* Güzergah Çizgisi */}
          {routeCoords.length > 0 && (
            <RoutePolyline route={routeCoords} color={theme.tint} lineWidth={5} />
          )}
          
          {/* Duraklar */}
          {stopsForMap.length > 0 && (
            <StopMarkers stops={stopsForMap} color={isDark ? '#FFF' : '#333'} />
          )}

          {/* Canlı Araçlar */}
          {superLine.canli_araclar && Array.isArray(superLine.canli_araclar) && superLine.canli_araclar.map((v: any) => (
            <VehicleMarker
              key={v.arac_id || v.id}
              vehicle={{
                arac_id: v.arac_id || v.id,
                plaka: v.plaka,
                hiz: v.hiz,
                doluluk: v.doluluk,
                guncelleme_vakti: v.guncelleme_vakti,
                konum: { lat: parseFloat(v.enlem), lng: parseFloat(v.boylam) }
              }}
              color={theme.tint}
            />
          ))}
        </MapboxGL.MapView>
      ) : (
        <ScrollView style={[styles.listContainer, { backgroundColor: theme.background }]}>
           <View style={{height: 120}} />
           {stopsForMap.map((stop, i) => (
             <View key={i} style={[styles.listItem, { borderBottomColor: theme.border }]}>
               <View style={[styles.siraBadge, { backgroundColor: theme.tint + '20' }]}>
                 <Text style={[styles.listSira, { color: theme.tint }]}>{stop.sira}</Text>
               </View>
               <Text style={[styles.listIsim, { color: theme.text }]}>{stop.isim}</Text>
             </View>
           ))}
           <View style={{height: 300}} />
        </ScrollView>
      )}

      {/* HEADER OVERLAY */}
      <BlurView 
        intensity={80} 
        tint={isDark ? 'dark' : 'light'}
        style={[styles.headerOverlay, { backgroundColor: isDark ? 'rgba(0,0,0,0.4)' : 'rgba(255,255,255,0.4)' }]}
      >
        <TouchableOpacity onPress={() => router.back()} style={styles.iconButton}>
          <ArrowLeft color={theme.text} size={24} />
        </TouchableOpacity>
        <View style={styles.headerInfo}>
          <Text style={[styles.hatKodu, { color: theme.tint, ...Typography.subheading }]}>
            {superLine.hat_bilgisi?.kisa_isim || id}
          </Text>
          <Text style={[styles.hatAdi, { color: theme.text, ...Typography.body }]} numberOfLines={1}>
            {superLine.hat_bilgisi?.uzun_isim || "Yükleniyor..."}
          </Text>
        </View>
        <TouchableOpacity onPress={() => setViewMode(viewMode === 'map' ? 'list' : 'map')} style={styles.iconButton}>
          {viewMode === 'map' ? <List color={theme.text} size={24} /> : <MapIcon color={theme.text} size={24} />}
        </TouchableOpacity>
      </BlurView>

      {/* ALTERNATIVE DIRECTION */}
      {superLine.alternatif_yonler && superLine.alternatif_yonler.length > 0 && (
        <TouchableOpacity 
          style={[styles.altBtn, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}
          onPress={() => router.replace(`/line/${encodeURIComponent(superLine.alternatif_yonler?.[0].split(' ')[0] || '')}`)}
        >
          <RefreshCcw size={16} color={theme.tint} style={{marginRight: 6}} />
          <Text style={{color: theme.tint, fontWeight: 'bold'}}>Diğer Yönü Gör</Text>
        </TouchableOpacity>
      )}

      {/* BOTTOM INFO PANEL */}
      <View style={[styles.bottomPanel, { backgroundColor: theme.cardBackground, borderTopColor: theme.border }]}>
        <View style={styles.panelHeader}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ flex: 1, marginRight: 16 }}>
            {superLine.saatler && Object.keys(superLine.saatler).map((day) => (
              <TouchableOpacity 
                key={day} 
                onPress={() => { setActiveTab(day); setShowAllSchedules(false); }}
                style={[styles.dayTab, activeTab === day && { backgroundColor: theme.tint }]}
              >
                <Text style={[styles.dayTabText, { color: activeTab === day ? '#FFF' : theme.textSecondary }]}>{day}</Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
          
          {superLine.fiyat && superLine.fiyat.tam_fiyat && (
            <View style={[styles.priceTag, { backgroundColor: theme.tint }]}>
              <Text style={styles.priceText}>{superLine.fiyat.tam_fiyat} ₺</Text>
            </View>
          )}
        </View>
        <ScrollView style={{maxHeight: showAllSchedules ? 300 : undefined}} showsVerticalScrollIndicator={false}>
          <View style={styles.scheduleList}>
            {superLine.saatler && superLine.saatler[activeTab] ? (
              <>
                {superLine.saatler[activeTab].slice(0, showAllSchedules ? undefined : 8).map((s: any, idx: number) => (
                  <View key={idx} style={[styles.timeBadge, { backgroundColor: theme.tint + '15' }]}>
                    <Text style={[styles.timeText, { color: theme.tint }]}>{s.saat}</Text>
                  </View>
                ))}
                {!showAllSchedules && superLine.saatler[activeTab].length > 8 && (
                  <TouchableOpacity 
                    style={[styles.timeBadge, { backgroundColor: theme.border }]}
                    onPress={() => setShowAllSchedules(true)}
                  >
                    <Text style={[styles.timeText, { color: theme.textSecondary }]}>+{superLine.saatler[activeTab].length - 8} Daha</Text>
                  </TouchableOpacity>
                )}
                {showAllSchedules && (
                  <TouchableOpacity 
                    style={[styles.timeBadge, { backgroundColor: theme.border, width: '100%', alignItems: 'center' }]}
                    onPress={() => setShowAllSchedules(false)}
                  >
                    <Text style={[styles.timeText, { color: theme.textSecondary }]}>Kapat</Text>
                  </TouchableOpacity>
                )}
              </>
            ) : (
              <Text style={{ color: theme.textSecondary }}>Bu gün için saat bilgisi yok.</Text>
            )}
          </View>
        </ScrollView>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  map: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  loadingText: { marginTop: 12, ...Typography.body },
  errorText: { marginBottom: 12, ...Typography.subheading },
  backButton: { backgroundColor: '#ef4444', paddingHorizontal: 16, paddingVertical: 8, borderRadius: 8 },
  
  headerOverlay: {
    position: 'absolute',
    top: 50,
    left: 16,
    right: 16,
    borderRadius: 16,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  iconButton: {
    padding: 8,
  },
  headerInfo: {
    marginLeft: 12,
    flex: 1,
  },
  hatKodu: {
    fontWeight: 'bold',
  },
  hatAdi: {
    opacity: 0.8,
  },
  
  bottomPanel: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: 20,
    borderTopWidth: 1,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.1,
    shadowRadius: 12,
    elevation: 10,
    paddingBottom: 40,
  },
  panelHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  panelTitle: {
    marginLeft: 8,
    fontWeight: '600',
    ...Typography.body,
  },
  priceTag: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  priceText: {
    color: 'white',
    fontWeight: 'bold',
    fontSize: 12,
  },
  scheduleList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  timeBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
  },
  timeText: {
    fontWeight: 'bold',
  },
  dayTab: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    marginRight: 8,
  },
  dayTabText: {
    fontWeight: '600',
    fontSize: 14,
  },
  altBtn: {
    position: 'absolute',
    top: 130,
    right: 16,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    borderWidth: 1,
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  listContainer: {
    flex: 1,
    paddingHorizontal: 16,
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  siraBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  listSira: {
    fontWeight: 'bold',
    fontSize: 12,
  },
  listIsim: {
    fontSize: 15,
    flex: 1,
  }
});
