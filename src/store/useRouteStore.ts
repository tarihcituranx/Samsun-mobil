import { create } from 'zustand';
import { OTPItinerary } from '../api/useRouteSearch';

interface RouteState {
  activeItinerary: OTPItinerary | null;
  setActiveItinerary: (itinerary: OTPItinerary | null) => void;
  clearActiveItinerary: () => void;
}

export const useRouteStore = create<RouteState>((set) => ({
  activeItinerary: null,
  setActiveItinerary: (itinerary) => set({ activeItinerary: itinerary }),
  clearActiveItinerary: () => set({ activeItinerary: null }),
}));
