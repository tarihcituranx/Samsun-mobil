import React from 'react';
import { View, StyleSheet, Text } from 'react-native';
import MapboxGL from '@maplibre/maplibre-react-native';
import { Vehicle } from '../../types/transit';
import { Colors } from '../../constants/Colors';
import { Bus } from 'lucide-react-native';

interface VehicleMarkerProps {
  vehicle: Vehicle;
  onPress?: (vehicle: Vehicle) => void;
  color?: string; // Hat rengi
}

export function VehicleMarker({ vehicle, onPress, color = Colors.light.bus }: VehicleMarkerProps) {
  return (
    <MapboxGL.MarkerView
      id={`vehicle-${vehicle.arac_id}`}
      coordinate={[vehicle.konum.lng, vehicle.konum.lat]}
    >
      <View style={styles.container} onTouchEnd={() => onPress?.(vehicle)}>
        <View style={[styles.marker, { borderColor: color }]}>
          <Bus size={14} color={color} />
        </View>
        {vehicle.plaka && (
          <View style={styles.badge}>
            <Text style={styles.badgeText}>{vehicle.plaka}</Text>
          </View>
        )}
      </View>
    </MapboxGL.MarkerView>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  marker: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: 'white',
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  badge: {
    marginTop: 2,
    backgroundColor: 'rgba(0,0,0,0.7)',
    paddingHorizontal: 4,
    paddingVertical: 2,
    borderRadius: 4,
  },
  badgeText: {
    color: 'white',
    fontSize: 9,
    fontWeight: 'bold',
  }
});
