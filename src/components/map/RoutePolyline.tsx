import React from 'react';
import MapboxGL from '@maplibre/maplibre-react-native';
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
    <MapboxGL.ShapeSource id={`${id}-source`} shape={shape}>
      <MapboxGL.LineLayer
        id={`${id}-layer`}
        style={{
          lineColor: color,
          lineWidth: lineWidth,
          lineJoin: 'round',
          lineCap: 'round',
        }}
      />
    </MapboxGL.ShapeSource>
  );
}
