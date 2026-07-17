export interface Coordinates {
  lat: number;
  lng: number;
}

export interface CityConfig {
  id: string;
  name: string;
  apiBaseUrl: string;
  center: Coordinates;
  bbox: {
    minLat: number;
    maxLat: number;
    minLng: number;
    maxLng: number;
  };
}

export const MapStyles = {
  light: 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
  dark: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json'
};

// ==========================================
// ASIS API WRAPPER TYPES
// ==========================================

export interface SuperStop {
  id: number | string;
  isim: string;
  yon: number;
  sira: number;
  konum: Coordinates;
}

export interface Vehicle {
  arac_id: string;
  plaka: string;
  konum: Coordinates;
  hiz: number;
  doluluk: number;
  guncelleme_vakti: string;
  durak_yaklasma?: string; // ETA from backend if any
}

export interface LineInfo {
  hat_kodu: string;
  kisa_isim: string;
  uzun_isim: string;
  kategori: string;
}

export interface DepartureTime {
  saat: string;
  yon?: string;
}

export interface LiveVehiclesInfo {
  count: number;
  data: Vehicle[];
}

export interface TicketPrice {
  tam_fiyat?: number | string;
  ogrenci_fiyat?: number | string;
  mesafe_bazli?: boolean;
  notlar?: string;
}

export interface BackendSuperLineStop {
  durak_id: string | number;
  durak_adi: string;
  yon: number;
  sira: number;
  enlem: string;
  boylam: string;
}

// /super-line/{code} endpoint response schema
export interface SuperLineResponse {
  hat_bilgisi: LineInfo;
  duraklar: BackendSuperLineStop[];
  saatler: Record<string, string[] | DepartureTime[]>; // "Hafta İçi": [...], "Cumartesi": [...]
  canli_araclar: LiveVehiclesInfo;
  fiyat: TicketPrice | null;
  alternatif_yonler?: string[];
}
