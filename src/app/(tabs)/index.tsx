import { View, StyleSheet, useColorScheme } from 'react-native';
// @ts-ignore
import { Map, Camera, UserLocation, GeoJSONSource, Layer, SymbolLayerStyle, LineLayerStyle, CameraRef } from '@maplibre/maplibre-react-native';
import { Colors } from '../../constants/Colors';
import { useSettingsStore } from '../../store/useSettingsStore';
import { MapStyles } from '../../types/transit';
import { StopMarkers } from '../../components/map/StopMarker';
import { StopBottomSheet } from '../../components/map/StopBottomSheet';
import { useAllStops, useSamairVehicles, useOdakVehicles } from '../../services/api/samsun';
import { SuperStop, Vehicle } from '../../types/transit';
import { useState, useRef, useEffect, useMemo } from 'react';
import { MapSearchBar } from '../../components/map/MapSearchBar';
import { LocationFAB } from '../../components/map/LocationFAB';
import { VehicleMarker } from '../../components/map/VehicleMarker';
import * as Location from 'expo-location';
import { Alert, TouchableOpacity, Text } from 'react-native';
import { useRouter } from 'expo-router';
import { useRouteStore } from '../../store/useRouteStore';
import polyline from '@mapbox/polyline';
// Set access token if required (MapLibre doesn't require one for their own styles, 
// but since we are using CartoDB styles, they are open as well).


export default function MapScreen() {
  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';
  
  
  const city = useSettingsStore(state => state.getCurrentCity());
  const [selectedStop, setSelectedStop] = useState<SuperStop | null>(null);
  const cameraRef = useRef<CameraRef>(null);
  const [userLocation, setUserLocation] = useState<Location.LocationObject | null>(null);
  const router = useRouter();
  
  // 1627 durak önbellekten 0 milisaniyede gelir
  const { data: stops = [] } = useAllStops();
  const { data: samairVehicles = [] } = useSamairVehicles();
  const { data: odakVehicles = [] } = useOdakVehicles();

  const activeItinerary = useRouteStore(state => state.activeItinerary);
  const clearActiveItinerary = useRouteStore(state => state.clearActiveItinerary);

  const theme = Colors[isDark ? 'dark' : 'light'];

  const routeLineData = useMemo(() => {
    if (!activeItinerary) return null;
    
    let allCoordinates: number[][] = [];
    
    activeItinerary.legs.forEach(leg => {
      if (leg.legGeometry?.points) {
        const points = polyline.decode(leg.legGeometry.points);
        const geojsonCoords = points.map(([lat, lng]) => [lng, lat]);
        allCoordinates = [...allCoordinates, ...geojsonCoords];
      }
    });

    if (allCoordinates.length === 0) return null;

    return {
      type: 'FeatureCollection',
      features: [
        {
          type: 'Feature',
          properties: {},
          geometry: {
            type: 'LineString',
            coordinates: allCoordinates
          }
        }
      ]
    };
  }, [activeItinerary]);

  useEffect(() => {
    (async () => {
      let { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') return;
      let location = await Location.getLastKnownPositionAsync({});
      if (location) setUserLocation(location);
    })();
  }, []);

  const handleSearch = (text: string) => {
    // Arama mantığı buraya gelecek
  };

  const handleCenterLocation = async () => {
    let location = await Location.getCurrentPositionAsync({});
    setUserLocation(location);
    if (location && cameraRef.current) {
      cameraRef.current.flyTo({
        center: [location.coords.longitude, location.coords.latitude],
        zoom: 15,
        duration: 1000
      });
    }
  };

  const handleMapLongPress = (feature: any) => {
    const coords = feature?.geometry?.coordinates;
    if (coords) {
      Alert.alert(
        "Rota Hesapla",
        "Bu noktaya yol tarifi almak ister misiniz?",
        [
          { text: "İptal", style: "cancel" },
          { 
            text: "Rota Çiz", 
            onPress: () => router.push({
              pathname: '/route',
              params: { destLat: coords[1], destLon: coords[0] }
            }) 
          }
        ]
      );
    }
  };

  return (
    <View style={styles.container}>
      <MapSearchBar onSearch={handleSearch} />
      <Map
        style={styles.map}
        mapStyle={isDark ? MapStyles.dark : MapStyles.light}
        onLongPress={handleMapLongPress}
      >
        <Camera
          ref={cameraRef}
          zoom={13}
          center={[city.center.lng, city.center.lat]}
          easing="fly"
          duration={2000}
        />
        
        {/* Tüm durakları render et (ShapeSource + CircleLayer sayesinde kasmaz) */}
        {stops.length > 0 && (
          <StopMarkers 
            stops={stops} 
            color={isDark ? '#4b5563' : '#9ca3af'} 
            onPress={(stop) => setSelectedStop(stop)}
          />
        )}

        {/* Canlı Araçlar (SAMAIR) */}
        {samairVehicles.map((vehicle: Vehicle) => (
          <VehicleMarker 
            key={`samair-${vehicle.arac_id}`} 
            vehicle={vehicle} 
            color={theme.airport} 
          />
        ))}

        {/* Canlı Araçlar (ODAK) */}
        {odakVehicles.map((vehicle: Vehicle) => (
          <VehicleMarker 
            key={`odak-${vehicle.arac_id}`} 
            vehicle={vehicle} 
            color={theme.odak} 
          />
        ))}
        
        {/* Rota Çizgisi */}
        {routeLineData && (
          <GeoJSONSource id="routeSource" data={routeLineData as any}>
            <Layer type="line"
              id="routeLine"
              style={{
                lineColor: theme.tint,
                lineWidth: 5,
                lineJoin: 'round',
                lineCap: 'round'
              }}
            />
          </GeoJSONSource>
        )}

        <UserLocation />
      </Map>

      <LocationFAB onPress={handleCenterLocation} />
      
      {activeItinerary && (
        <TouchableOpacity 
          style={[styles.clearRouteBtn, { backgroundColor: theme.cardBackground }]}
          onPress={() => clearActiveItinerary()}
        >
          <Text style={{ color: theme.error, fontWeight: 'bold' }}>Rotayı Temizle</Text>
        </TouchableOpacity>
      )}

      <StopBottomSheet stop={selectedStop} onClose={() => setSelectedStop(null)} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  map: {
    flex: 1,
  },
  clearRouteBtn: {
    position: 'absolute',
    top: 120,
    right: 16,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
    elevation: 4,
    shadowColor: '#000',
    shadowOpacity: 0.1,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 2 },
  }
});
