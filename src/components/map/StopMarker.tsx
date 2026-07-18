import React from 'react';
// @ts-ignore
import { Map, Camera, UserLocation, GeoJSONSource, Layer, SymbolLayerStyle, LineLayerStyle, CameraRef } from '@maplibre/maplibre-react-native';
import { SuperStop } from '../../types/transit';

interface StopMarkerProps {
  stops: SuperStop[];
  color?: string;
  onPress?: (stop: SuperStop) => void;
}

export function StopMarkers({ stops, color = '#8899AA', onPress }: StopMarkerProps) {
  // Optimizasyon için ShapeSource ve SymbolLayer/CircleLayer kullanıyoruz.
  // Çok sayıda durak olduğunda MarkerView performansı düşürür.
  
  const features = stops.map(stop => ({
    type: 'Feature',
    id: stop.id.toString(),
    properties: {
      id: stop.id,
      name: stop.isim,
    },
    geometry: {
      type: 'Point',
      coordinates: [stop.konum.lng, stop.konum.lat],
    },
  }));

  const shape = {
    type: 'FeatureCollection',
    features,
  } as any;

  return (
    <GeoJSONSource 
      id="stopsSource" 
      data={shape} 
      onPress={(e: any) => {
        if (e.features && e.features.length > 0 && onPress) {
          // feature.properties includes id, name
          const feature = e.features[0];
          onPress({
            id: feature.properties?.id,
            isim: feature.properties?.name,
            yon: 0,
            sira: 0,
            konum: {
              lng: feature.geometry.coordinates[0],
              lat: feature.geometry.coordinates[1]
            }
          });
        }
      }}
    >
      <Layer type="circle"
        id="stopsLayer"
        style={{
          circleColor: color,
          circleRadius: 4,
          circleStrokeWidth: 1.5,
          circleStrokeColor: '#FFFFFF',
        }}
      />
    </GeoJSONSource>
  );
}
