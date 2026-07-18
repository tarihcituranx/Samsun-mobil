import { useQuery } from '@tanstack/react-query';
import { fetchClient } from './client';
import { SuperLineResponse, SuperStop, Vehicle } from '../../types/transit';

/**
 * Samsun (ASIS) API servisleri.
 * Referans: `samsun-gtfs-rt-api` skill & asis_api_wrapper
 */

// Tüm hatları listeleme
export const fetchLines = async (): Promise<any[]> => {
  return await fetchClient<any[]>('/lines');
};

// Super-Line (Hattın TÜM verilerini tek JSON'da çeken hibrit motor)
export const fetchSuperLine = async (code: string): Promise<SuperLineResponse> => {
  const res = await fetchClient<any>(`/super-line/${encodeURIComponent(code)}`);
  if (res.duraklar) {
    res.duraklar = res.duraklar.map((d: any) => ({
      ...d,
      durak_adi: d.durak_adi || d.ad || d.isim,
      enlem: d.enlem || d.lat?.toString(),
      boylam: d.boylam || d.lon?.toString() || d.lng?.toString()
    }));
  }
  return res as SuperLineResponse;
};

// Tüm durakları çekme (Haritaya basmak için 1627 durak)
export const fetchAllStops = async (): Promise<SuperStop[]> => {
  const data = await fetchClient<any[]>('/stops/all');
  
  return data.map((d: any) => ({
    id: d.durak_id || d.id,
    isim: d.durak_adi || d.isim || d.ad || "Bilinmeyen Durak",
    yon: 0,
    sira: 0,
    konum: {
      lat: parseFloat(d.enlem || d.lat || "0"),
      lng: parseFloat(d.boylam || d.lng || d.lon || "0")
    }
  }));
};

// Akıllı Durak (Belirli bir durağa yaklaşan araçlar ve ETA)
export const fetchSmartStation = async (stationId: string | number): Promise<any[]> => {
  return await fetchClient<any[]>(`/smart-stations/${stationId}`);
};

// Samulaş Duyuruları
export const fetchAnnouncements = async (): Promise<any> => {
  return await fetchClient<any>('/announcements');
};

// Otoparklar
export const fetchParkings = async (): Promise<any[]> => {
  return await fetchClient<any[]>('/parkings');
};

// Deniz Araçları (Canlı)
export const fetchMarineVehicles = async (): Promise<any[]> => {
  return await fetchClient<any[]>('/marine/realtime');
};

// SAMAIR Araçları (Canlı)
export const fetchSamairVehicles = async (): Promise<Vehicle[]> => {
  const res = await fetchClient<any>('/samair/vehicles');
  const araclar = res.araçlar || [];
  return araclar.map((v: any) => ({
    arac_id: v.plaka,
    plaka: v.plaka,
    konum: { lat: parseFloat(v.enlem || "0"), lng: parseFloat(v.boylam || "0") },
    hiz: parseFloat(v.hiz || "0"),
    doluluk: parseInt(v.gunlukYolcu || "0"),
    guncelleme_vakti: v.tarih || v.editDate || new Date().toISOString()
  }));
};

// ODAK Araçları (Canlı)
export const fetchOdakVehicles = async (): Promise<Vehicle[]> => {
  const res = await fetchClient<any>('/odak/vehicles');
  const araclar = res.araçlar || [];
  return araclar.map((v: any) => ({
    arac_id: v.plaka,
    plaka: v.plaka,
    konum: { lat: parseFloat(v.enlem || "0"), lng: parseFloat(v.boylam || "0") },
    hiz: parseFloat(v.hiz || "0"),
    doluluk: parseInt(v.gunlukYolcu || "0"),
    guncelleme_vakti: v.tarih || v.editDate || new Date().toISOString()
  }));
};

// --- HOOKS ---

export const useLines = () => {
  return useQuery({
    queryKey: ['lines'],
    queryFn: fetchLines,
    staleTime: 1000 * 60 * 60 * 24, // Hat listesi nadir değişir
  });
};

export const useSuperLine = (code: string) => {
  return useQuery({
    queryKey: ['superLine', code],
    queryFn: () => fetchSuperLine(code),
    refetchInterval: 15000, // Canlı araçlar ve ETA için 15 saniyede bir otomatik yenilenmeli!
  });
};

export const useAllStops = () => {
  return useQuery({
    queryKey: ['allStops'],
    queryFn: fetchAllStops,
    staleTime: 1000 * 60 * 60 * 24,
  });
};

export const useSmartStation = (stationId: string | number | null) => {
  return useQuery({
    queryKey: ['smartStation', stationId],
    queryFn: () => fetchSmartStation(stationId!),
    enabled: !!stationId, // Sadece ID varsa çalışır
    refetchInterval: 15000,
  });
};

export const useAnnouncements = () => {
  return useQuery({
    queryKey: ['announcements'],
    queryFn: fetchAnnouncements,
    staleTime: 1000 * 60 * 60, // 1 saat
  });
};

export const useParkings = () => {
  return useQuery({
    queryKey: ['parkings'],
    queryFn: fetchParkings,
    staleTime: 1000 * 60 * 60 * 24, // 24 saat
  });
};

export const useMarineVehicles = () => {
  return useQuery({
    queryKey: ['marine'],
    queryFn: fetchMarineVehicles,
    refetchInterval: 30000, // gemiler daha yavaş hareket eder
  });
};

export const useSamairVehicles = () => {
  return useQuery({
    queryKey: ['samairVehicles'],
    queryFn: fetchSamairVehicles,
    refetchInterval: 15000,
  });
};

export const useOdakVehicles = () => {
  return useQuery({
    queryKey: ['odakVehicles'],
    queryFn: fetchOdakVehicles,
    refetchInterval: 15000,
  });
};
