import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, useColorScheme, TouchableOpacity } from 'react-native';
import { Colors } from '../../constants/Colors';
import { Typography } from '../../constants/Typography';
import { useParkings, useMarineVehicles, useAnnouncements, useAllStops } from '../../services/api/samsun';
import { Anchor, Car, Megaphone, MapPin, Bus } from 'lucide-react-native';
import * as Location from 'expo-location';
import { getDistance, formatDistance } from '../../utils/haversine';
import { StopBottomSheet } from '../../components/map/StopBottomSheet';
import { SuperStop } from '../../types/transit';

export default function ExploreScreen() {
  const colorScheme = useColorScheme();
  const theme = Colors[colorScheme === 'light' ? 'light' : 'dark'];

  const { data: parkings, isLoading: loadingParkings } = useParkings();
  const { data: marine, isLoading: loadingMarine } = useMarineVehicles();
  const { data: announcement } = useAnnouncements();
  const { data: allStops = [] } = useAllStops();

  const [userLocation, setUserLocation] = useState<Location.LocationObject | null>(null);
  const [nearestStops, setNearestStops] = useState<{stop: SuperStop, distance: number}[]>([]);
  const [selectedStop, setSelectedStop] = useState<SuperStop | null>(null);

  useEffect(() => {
    (async () => {
      let { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') return;
      let location = await Location.getCurrentPositionAsync({});
      setUserLocation(location);
    })();
  }, []);

  useEffect(() => {
    if (userLocation && allStops.length > 0) {
      const lat = userLocation.coords.latitude;
      const lon = userLocation.coords.longitude;
      
      const stopsWithDistance = allStops.map(stop => {
        const distance = getDistance(lat, lon, stop.konum.lat, stop.konum.lng);
        return { stop, distance };
      });
      
      const nearby = stopsWithDistance
        .filter(s => s.distance <= 1000)
        .sort((a, b) => a.distance - b.distance)
        .slice(0, 5); // top 5
        
      setNearestStops(nearby);
    }
  }, [userLocation, allStops]);

  return (
    <ScrollView style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={styles.header}>
        <Text style={[styles.title, { color: theme.text, ...Typography.heading }]}>Keşfet</Text>
        <Text style={[styles.subtitle, { color: theme.textSecondary, ...Typography.body }]}>
          Samsun Ulaşım ArGe Servisleri
        </Text>
      </View>

      {/* Yakın Duraklar Card */}
      <View style={[styles.card, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}>
        <View style={styles.cardHeader}>
          <MapPin color={theme.text} size={24} />
          <Text style={[styles.cardTitle, { color: theme.text }]}>Yakın Duraklar (1km)</Text>
        </View>
        
        {!userLocation ? (
          <Text style={{ color: theme.textSecondary }}>Konum bilgisi alınıyor...</Text>
        ) : nearestStops.length === 0 ? (
          <Text style={{ color: theme.textSecondary }}>Çevrenizde durak bulunamadı.</Text>
        ) : (
          nearestStops.map(({ stop, distance }, index) => (
            <TouchableOpacity 
              key={stop.id.toString()} 
              style={[
                styles.stopItem, 
                { borderBottomColor: theme.border },
                index === nearestStops.length - 1 && { borderBottomWidth: 0 }
              ]}
              onPress={() => setSelectedStop(stop)}
            >
              <View style={[styles.stopIconBox, { backgroundColor: theme.tint + '20' }]}>
                <Bus size={20} color={theme.tint} />
              </View>
              <View style={styles.stopInfo}>
                <Text style={[styles.stopName, { color: theme.text }]} numberOfLines={1}>
                  {stop.isim}
                </Text>
                <Text style={{ color: theme.textSecondary, fontSize: 12 }}>
                  {stop.id}
                </Text>
              </View>
              <Text style={[styles.distanceText, { color: theme.accent }]}>
                {formatDistance(distance)}
              </Text>
            </TouchableOpacity>
          ))
        )}
      </View>

      {/* Otoparklar Card */}
      <View style={[styles.card, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}>
        <View style={styles.cardHeader}>
          <Car color={theme.text} size={24} />
          <Text style={[styles.cardTitle, { color: theme.text }]}>Otoparklar</Text>
        </View>
        {loadingParkings ? (
          <ActivityIndicator size="small" color={theme.tint} />
        ) : (
          <Text style={{ color: theme.textSecondary }}>
            {parkings?.length || 0} adet Samulaş otopark verisi KMZ haritasından senkronize ediliyor.
          </Text>
        )}
      </View>

      {/* Deniz Araçları Card */}
      <View style={[styles.card, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}>
        <View style={styles.cardHeader}>
          <Anchor color={theme.text} size={24} />
          <Text style={[styles.cardTitle, { color: theme.text }]}>Deniz Araçları Radarı</Text>
        </View>
        {loadingMarine ? (
          <ActivityIndicator size="small" color={theme.tint} />
        ) : (
          <Text style={{ color: theme.textSecondary }}>
            Samsunum-1 ve diğer deniz araçlarından {marine?.length || 0} tanesi şu an hareket halinde.
          </Text>
        )}
      </View>

      {/* Duyuru Banner */}
      {announcement?.has_announcement && (
        <View style={[styles.banner, { backgroundColor: theme.tint + '15', borderColor: theme.tint }]}>
          <Megaphone color={theme.tint} size={24} />
          <View style={styles.bannerText}>
            <Text style={{ color: theme.tint, fontWeight: 'bold' }}>Önemli Duyuru</Text>
            <Text style={{ color: theme.textSecondary, fontSize: 12 }}>Samulaş'tan yeni bir duyuru var.</Text>
          </View>
        </View>
      )}

      <StopBottomSheet stop={selectedStop} onClose={() => setSelectedStop(null)} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  title: { marginBottom: 4 },
  subtitle: { opacity: 0.8 },
  banner: {
    marginHorizontal: 16,
    padding: 16,
    borderRadius: 16,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 24,
  },
  bannerText: {
    marginLeft: 16,
  },
  card: {
    marginHorizontal: 16,
    padding: 20,
    borderRadius: 16,
    borderWidth: 1,
    marginBottom: 16,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginLeft: 12,
  },
  stopItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
  },
  stopIconBox: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  stopInfo: {
    flex: 1,
  },
  stopName: {
    fontWeight: '600',
    fontSize: 15,
  },
  distanceText: {
    fontWeight: 'bold',
    fontSize: 14,
  }
});
