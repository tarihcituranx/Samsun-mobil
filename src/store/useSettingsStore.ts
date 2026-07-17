import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { CityConfig } from '../types/transit';

// Gelecekte başka şehirler eklemek için config listesi
export const CITIES: Record<string, CityConfig> = {
  samsun: {
    id: 'samsun',
    name: 'Samsun',
    // Geliştirme (Localhost), VPS'e geçince config'den veya .env'den alacağız
    apiBaseUrl: process.env.EXPO_PUBLIC_API_URL || 'http://164.92.219.87:8001',
    center: { lat: 41.28667, lng: 36.33 },
    bbox: {
      minLat: 40.5,
      maxLat: 42.0,
      minLng: 34.5,
      maxLng: 37.5
    }
  }
};

interface SettingsState {
  currentCityId: string;
  language: 'tr' | 'en';
  theme: 'system' | 'light' | 'dark';
  setCity: (cityId: string) => void;
  setLanguage: (lang: 'tr' | 'en') => void;
  setTheme: (theme: 'system' | 'light' | 'dark') => void;
  getCurrentCity: () => CityConfig;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set, get) => ({
      currentCityId: 'samsun',
      language: 'tr',
      theme: 'system',
      setCity: (cityId) => set({ currentCityId: cityId }),
      setLanguage: (lang) => set({ language: lang }),
      setTheme: (theme) => set({ theme }),
      getCurrentCity: () => {
        const id = get().currentCityId;
        return CITIES[id] || CITIES['samsun'];
      }
    }),
    {
      name: 'transit-settings-storage',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);
