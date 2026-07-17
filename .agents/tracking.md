# 📊 Transit App — Proje Takip

> Tüm fazlar, görevler ve ilerleme durumu burada izlenir.
> **Her oturum sonunda bu dosya güncellenMELİDİR.**
> **Son güncelleme:** 2026-07-17

---

## 🎯 Aktif Faz: FAZ 1 — Çekirdek MVP

**Hedef:** Harita + Canlı Araç Takibi + Hat Bilgisi + Rota Hesaplama + Hata Yönetimi
**Durum:** 🟢 Devam Ediyor (~%95)

---

## 📋 FAZ 1 Görev Listesi

### ✅ 1.1 Proje Kurulumu (TAMAMLANDI)
- [x] Expo SDK 57 (TypeScript) projesini `transit-app` dizininde başlat
- [x] `src/` yapısına taşı (app, components, services, store, types, utils, constants)
- [x] `tsconfig.json` path alias: `@/*` → `./src/*`, `@/assets/*` → `./assets/*`
- [x] `app.json` yapılandır (paket adı, splash, plugins, typedRoutes)
- [x] Inter font ailesi (5 ağırlık) + `SplashScreen.preventAutoHideAsync()` pattern
- [x] Bağımlılıklar: MapLibre, Zustand, TanStack Query, Reanimated, Blur, Location, SQLite

### ✅ 1.2 Temel Altyapı (TAMAMLANDI)
- [x] `Colors.ts` — Dark/Light tema + 9 kategori rengi (22 token)
- [x] `Typography.ts` — Inter 6-level scale (display→micro)
- [x] `_layout.tsx` — Root layout (QueryClient, tema, splash, bildirim izni 1.5s delay, 20s fetch timeout)
- [x] `useSettingsStore.ts` — Zustand + AsyncStorage (şehir, dil, apiBaseUrl)
- [x] `trFix.ts` — Türkçe karakter düzeltme (Ý→İ, Ð→Ğ, Þ→Ş)

### ✅ 1.3 API Katmanı (TAMAMLANDI)
- [x] `client.ts` — Fetch wrapper (timeout, error handling, apiBaseUrl from store)
- [x] `samsun.ts` — 7 fetch fonksiyonu + 7 TanStack Query hook:
  - [x] `useLines()` — Hat listesi (stale: 24h)
  - [x] `useSuperLine(code)` — Hat detay paketi (refetch: 15s)
  - [x] `useAllStops()` — Tüm duraklar (stale: 24h)
  - [x] `useSmartStation(id)` — Durağa yaklaşan araçlar (refetch: 15s)
  - [x] `useAnnouncements()` — Duyurular (stale: 1h)
  - [x] `useParkings()` — Otoparklar (stale: 24h)
  - [x] `useMarineVehicles()` — Deniz araçları (refetch: 30s)
- [x] `transit.ts` — Tip tanımları (SuperStop, Vehicle, LineInfo, SuperLineResponse, CityConfig)

### ✅ 1.4 Tab Navigasyon (TAMAMLANDI)
- [x] 4 tab: Harita (Map), Hatlar (Bus), Keşfet (Compass), Ayarlar (Settings)
- [x] Lucide ikonları
- [x] BlurView tab bar (iOS)
- [x] Themed styling

### ✅ 1.5 Harita Ekranı (TAMAMLANDI)
- [x] MapLibre MapView + CartoDB dark/light tile'ları
- [x] Kullanıcı konumu (UserLocation + heading indicator)
- [x] 1627 durak marker'ı (ShapeSource + CircleLayer ile optimize)
- [x] Durak tıklama → StopBottomSheet (yaklaşan araçlar + ETA, 15s refetch)
- [x] Canlı araç marker'ları (VehicleMarker component)
- [x] Güzergah polyline (RoutePolyline component)
- [x] **Durak arama barı** (üst overlay)
- [x] **Haritama dön FAB** (konuma geri dön butonu)
- [x] **Uzun basma → rota hesapla** dialog

### ✅ 1.6 Hat Listesi Ekranı (TAMAMLANDI)
- [x] FlatList ile hat listesi (`useLines()`)
- [x] Kart tasarımı (hat_kodu + uzun_isim)
- [x] Tıklama → `/line/[id]` detay ekranına yönlendirme
- [x] **Kategori chip'leri** (Otobüs, Ekspres, Tramvay, Ring, Tekne, Odak, Teleferik, Havalimanı, İlçe)
- [x] **Arama barı** (hat kodu veya isim ile arama)
- [x] **Favori hatlar** (yıldızlama)

### ✅ 1.7 Hat Detay Ekranı (TAMAMLANDI)
- [x] Tam ekran MapLibre harita
- [x] Güzergah polyline (guzergah_cizgisi)
- [x] Durak marker'ları (duraklar listesi)
- [x] Canlı araç marker'ları (canli_araclar, 15s)
- [x] Header overlay (hat_kodu + uzun_isim + geri butonu)
- [x] Alt panel: sonraki kalkışlar (Hafta İçi ilk 4)
- [x] Fiyat badge (tam_fiyat)
- [x] **Gün seçici** (Hafta İçi / Cumartesi / Pazar tab'ları)
- [x] **Tüm saatleri göster** (expand/collapse)
- [x] **Gidiş/Dönüş toggle** (ring hatlar için)
- [x] **Durak listesi** görünümü (haritasız liste modu)

### ✅ 1.8 Keşfet Ekranı (TAMAMLANDI)
- [x] Samulaş duyuru banner'ı (`useAnnouncements()`)
- [x] Otopark sayı kartı (`useParkings()`)
- [x] Deniz araçları radar kartı (`useMarineVehicles()`)

### ✅ 1.9 Yakın Duraklar (TAMAMLANDI)
- [x] GPS konum al
- [x] Haversine ile 1km filtre
- [x] Mesafe gösterimi (metre)
- [x] Durak detay bottom sheet (yaklaşan araçlar + ETA)

### ✅ 1.10 Rota Ekranı (TAMAMLANDI)
- [x] Tasarım ve UI bileşenleri (Başlangıç/Hedef seçimi, yürüme süreleri)
- [x] Arama çubuğu (Geocoding) algoritması:
  1. Yerel veritabanı (1627 durak - Offline)
  2. Google Places API (Samsun odaklı, VPS üzerinden limitli)
  3. Photon API (Kotaya takılırsa Fallback)
- [x] Rota API çağrısı (OTP2 entegrasyonu tamamlandı, store'a bağlandı)
- [x] Sonuç kartları (direkt + aktarmalı) (UI)
- [x] Haritada rota polyline gösterimi (useRouteStore ve MapLibre LineLayer ile)

### ✅ 1.11 Ayarlar Ekranı (TAMAMLANDI)
- [x] Tema toggle (Dark/Light/Otomatik)
- [x] Dil seçimi (TR/EN)
- [x] Şehir değiştir
- [x] Hakkında / Sürüm bilgisi
- [x] Önbellek temizleme

### ✅ 1.12 Özel Hatlar — SAMAIR + Odak (TAMAMLANDI)
- [x] SAMAIR ekranı/sekmesi (H1-H5, uçuş bağlantılı seferler)
- [x] Odak turistik rotalar ekranı (Hatlar ekranına kategori eklendi)
- [x] Canlı araç takibi (SAMAIR + Odak araçları)
- [x] API hook'ları: `useSamairVehicles()`, `useOdakVehicles()`, `useOdakLines()`, `useSamairSchedules()`

### ✅ 1.13 Polish, Test & Güvenlik (TAMAMLANDI)
- [x] Glassmorphism paneller (harita overlay'leri)
- [x] Animasyon geçişleri (ekran arası, kart açılış, bottom sheet)
- [x] Hata durumları (offline banner, API timeout, boş veri)
- [x] Global Error Boundary (Çökmeleri yakalayıp kullanıcıya gösteren kalkan)
- [x] Otomatik Github Issue (Uygulama çöktüğünde VPS üzerinden issue açma)
- [x] Google Places Kota Koruması (Aylık limit, aşılırsa Photon'a fallback)
- [x] EAS Build (APK) ile cihaz testleri hazır
- [x] Performance profiling (1600+ marker lag kontrolü) (MapLibre ShapeSource ile çözüldü)

---

## 📅 İleri Fazlar (Henüz Başlamadı)

### FAZ 2 — Erişilebilirlik & Çoklu Dil
- [ ] VoiceOver/TalkBack tam uyumu
- [ ] Sesli yönlendirme (TTS)
- [ ] i18n: react-i18next kurulum
- [ ] TR, EN temel çeviriler
- [ ] RU, AR dilleri ekleme

### FAZ 3 — Turizm Katmanı
- [ ] Turistik mekan profil sayfaları (`/tourism/landmarks` verisi)
- [ ] Çok dilli sesli rehber (AI TTS: ElevenLabs, Google Cloud TTS)
- [ ] Medya depolama (Cloudflare R2/S3)

### FAZ 4 — Çevrimdışı Mod
- [ ] MapLibre offline tile indirme (şehir merkezi)
- [ ] expo-sqlite ile sefer/durak/fiyat offline cache
- [ ] Senkronizasyon stratejisi (günlük/haftalık)
- [ ] Offline banner gösterimi

### FAZ 5 — Pratik Bilgiler
- [ ] Döviz kurları (TCMB EVDS)
- [ ] En yakın ATM/Banka (Overpass API)

### FAZ 6 — AI Asistanı
- [ ] Doğal dil etkileşimi ("Bana müzeye giden en hızlı rotayı çiz")
- [ ] LLM + Tool Calling (OTP2 + içerik DB)
- [ ] RAG ile halüsinasyonsuz cevaplar

### FAZ 7 — Ödeme Katmanı
- [ ] E-para entegrasyonu (BDDK lisanslı kurum)

---

## 📝 Kararlar Logu

| Tarih | Karar | Gerekçe |
|-------|-------|---------| 
| 2026-07-15 | Tek App + Şehir Seçici | Turistler için sürtünmesiz, bakım kolay |
| 2026-07-15 | Expo (React Native) + TypeScript | KutuphaneApp'te kanıtlanmış stack |
| 2026-07-15 | Expo Router (file-based) | Next.js tarzı, typedRoutes desteği |
| 2026-07-15 | Zustand + TanStack Query | Hafif state + akıllı API cache |
| 2026-07-15 | MapLibre GL Native | Açık kaynak, ücretsiz, vektör, 60fps |
| 2026-07-15 | Dark/Light otomatik + toggle | Sistem tercihine uygun |
| 2026-07-15 | API referansı sadece skill + anayasa | Tek kaynak ilkesi |
| 2026-07-15 | "Aptal İstemci" prensibi | Backend ağır iş, frontend sadece çizer |
| 2026-07-15 | FAZ 1 öncelik (MVP) | Belediye/yatırımcı ikna |
| 2026-07-16 | REST JSON (GTFS-RT protobuf değil) | Backend zaten sarmalıyor, mobilde protobuf parse gereksiz |
| 2026-07-16 | 3 katmanlı veri stratejisi | Canlı (polling) + Yarı-statik (cache) + Offline (SQLite) |
| 2026-07-16 | Anayasa oluşturuldu | Her oturum başında referans, tracking güncel tutulacak |
| 2026-07-17 | Google Places API (VPS Proxy) | Client'ta anahtar saklanmaz, VPS kotayı korur |
| 2026-07-17 | Error Boundary & Auto Issue | Çökmeler gizlice Github'a loglanır, kullanıcı reset atar |

---

## 🐛 Bilinen Sorunlar

| # | Sorun | Öncelik | Durum |
|---|-------|---------|-------|
| 1 | `transit.ts`'de bazı alanlar `any` tipli | Orta | Açık |
| 2 | `tracking.md` ilerleme güncellenmiyordu | Yüksek | ✅ Düzeltildi (2026-07-16) |
| 3 | Rota hesaplama API endpoint'i henüz yok (OTP2 gerekebilir) | Düşük | Açık |

---

## 📊 İstatistikler

| Metrik | Değer |
|--------|-------|
| Toplam kaynak dosya | 22 |
| Toplam satır (src/) | ~1,450 |
| Ekranlar | 6 (Harita, Hatlar, Keşfet, Ayarlar, Hat Detay, Error) |
| Componentler | 5 (StopMarker, StopBottomSheet, VehicleMarker, RoutePolyline, ErrorBoundary) |
| API hook'ları | 9 / ~14 planlanan |
| Aktif faz | FAZ 1 |
| FAZ 1 ilerleme | ~%95 |
| Toplam planlanan faz | 7 |
