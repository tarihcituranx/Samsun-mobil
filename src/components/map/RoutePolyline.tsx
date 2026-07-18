import React from 'react';
// @ts-ignore
import { Map, Camera, UserLocation, GeoJSONSource, Layer, SymbolLayerStyle, LineLayerStyle, CameraRef } from '@maplibre/maplibre-react-native';
import { Coordinates } from '../../types/transit';

interface RoutePolylineProps {
  route: Coordinates[];
  color?: string;
  lineWidth?: number;
  id?: string;
}

export function RoutePolyline({ route, color = '#2979FF', lineWidth = 4, id = 'route' }: RoutePolylineProps) {
  if (!route || route.length < 2) return null;

  const shape = {
    type: 'Feature',
    geometry: {
      type: 'LineString',
      coordinates: route.map(coord => [coord.lng, coord.lat]),
    },
  } as any;

  return (
    <GeoJSONSource id={`${id}-source`} data={shape}>
      <Layer type="line"
        id={`${id}-layer`}
        style={{
          lineColor: color,
          lineWidth: lineWidth,
          lineJoin: 'round',
          lineCap: 'round',
        }}
      />
    </GeoJSONSource>
  );
}
