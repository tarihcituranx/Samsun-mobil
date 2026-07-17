import { useQuery } from '@tanstack/react-query';

export interface OTPItinerary {
  duration: number;
  startTime: number;
  endTime: number;
  walkDistance: number;
  transfers: number;
  legs: OTPLeg[];
}

export interface OTPLeg {
  mode: 'WALK' | 'BUS' | 'TRAM' | string;
  startTime: number;
  endTime: number;
  distance: number;
  routeShortName?: string;
  from: {
    name: string;
    lat: number;
    lon: number;
  };
  to: {
    name: string;
    lat: number;
    lon: number;
  };
  legGeometry: {
    points: string;
  };
}

export interface OTPResponse {
  plan: {
    itineraries: OTPItinerary[];
  };
  error?: {
    msg: string;
  };
}

export const useRouteSearch = (fromCoords: string, toCoords: string, enabled: boolean) => {
  return useQuery<OTPItinerary[]>({
    queryKey: ['route', fromCoords, toCoords],
    queryFn: async () => {
      // OTP2 endpoint
      const baseUrl = process.env.EXPO_PUBLIC_OTP_URL || 'http://164.92.219.87:8080';
      // format: lat,lon
      
      const params = new URLSearchParams({
        fromPlace: fromCoords,
        toPlace: toCoords,
        mode: 'TRANSIT,WALK',
        arriveBy: 'false',
        wheelchair: 'false',
        locale: 'tr'
      });

      const url = `${baseUrl}/otp/routers/default/plan?${params.toString()}`;

      const res = await fetch(url);
      if (!res.ok) {
        throw new Error('Rota hesaplanamadı');
      }

      const data: OTPResponse = await res.json();
      if (data.error) {
        throw new Error(data.error.msg);
      }

      return data.plan.itineraries || [];
    },
    enabled: enabled && !!fromCoords && !!toCoords,
  });
};
