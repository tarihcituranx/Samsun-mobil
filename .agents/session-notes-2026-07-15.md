# 🧠 Transit App — Oturum Notları ve Bulgular

> **Oturum:** 2026-07-15 18:39 — 19:01
> **Conversation ID:** b2fae39d-70ea-42fa-958a-3034d797d747

---

## 📌 Alınan Kararlar

| # | Karar | Gerekçe |
|---|-------|---------|
| 1 | Tek App + Şehir Seçici | Turist sürtünmesiz, bakım kolay, tek store listesi |
| 2 | Expo (React Native) + TypeScript | KutuphaneApp'te kanıtlanmış stack |
| 3 | Expo Router (file-based) | Next.js tarzı, typedRoutes desteği |
| 4 | Zustand + TanStack Query | Hafif state + akıllı API cache |
| 5 | MapLibre GL Native | Açık kaynak, vektör, 60fps, offline, ücretsiz |
| 6 | Dark/Light otomatik + toggle | Sistem tercihine uygun |
| 7 | FAZ 1 öncelik (MVP) | Harita + Canlı Araç + Rota |
| 8 | FastAPI backend direkt kullanılacak | localhost:8001, mock data yok |
| 9 | API referansı sadece skill dosyasından | `samsun-gtfs-rt-api` skill tek kaynak |
| 10 | Proje yolu | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/transit-app` |
| 11 | Çalışma adı | `transit-app` (son isim sonra belirlenecek) |

---

## 📂 Proje Konumları

| Proje | Yol | Açıklama |
|-------|-----|----------|
| **Yeni Transit App** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/transit-app` | Bu oturumda oluşturuldu |
| **Eski Flutter App** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/Samsun-mobil` | Feature referansı (kod değil!) |
| **FastAPI Backend** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/Samsun_Ulasim_ArGe/asis_api_wrapper` | Gerçek backend |
| **KutuphaneApp (Referans)** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/KutuphaneApp` | Expo stack referansı |
| **KutuphaneApp GitHub** | `tarihcituranx/Kutuphaneapp` | CI/CD workflow'ları burada |
| **Süper App Fikirleri** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/Samsun_Ulasim_ArGe/SUPER_APP_FIKIRLER.md` | Vizyon dokümanı |
| **Skill (API)** | `/home/turan/.gemini/config/skills/samsun_gtfs_rt_api/SKILL.md` | EN GÜNCEL API referansı |

---

## 🔍 Eski Flutter App Analizi (Samsun-mobil)

### Ekranlar
| Ekran | Dosya | Satır | Özellikler |
|-------|-------|-------|------------|
| Ana Ekran | `home_screen.dart` | 832 | 7 tab (BottomNav): Harita, Hatlar, Yakınım, Rota, Odak, SamAIR, Ayarlar |
| Hatlar | `hatlar_screen.dart` | 707 | Hat listesi (arama + kategori chip), hat detay (fiyat, sefer, canlı araç, durak) |
| SamAIR | `samair_screen.dart` | 537 | TabController 6 tab (Harita + H1-H5), uçuş seferleri, 15s polling |
| Odak | `odak_screen.dart` | 398 | Turistik rotalar listesi + detay, canlı araç takip |
| Ayarlar | `settings_screen.dart` | 630 | Tema, dil, bildirim, favori, önbellek, hakkında |
| Admin | `admin_screen.dart` | — | Admin paneli |
| Alarm | `alarm_screen.dart` | — | Alarm ekranı |
| Loading | `loading_screen.dart` | — | Yükleme ekranı |
| Offline | `offline_wakeup_screen.dart` | — | Çevrimdışı uyarı |

### Harita Widget (home_map_widget.dart — 400 satır)
- CartoDB Voyager tile'ları
- Kullanıcı konumu: Mavi daire (#2979FF) + glow
- Durak markerları: En yakın 300 veya 1km filtre
- Canlı araç: Beyaz daire + mavi border + bus.png
- Aktif hat: Teal (#00BFA5) polyline
- Teleferik: Pembe noktalı çizgi (#FF4081)
- Durak arama barı (üst overlay)
- Long press → rota hesapla dialog

### Renk Paleti (kanıtlanmış, aynen kullanılacak)
```
Dark:
  #0A1628  scaffold bg
  #0F1E36  appbar
  #152238  card bg
  #1A2940  nested card
  #1E3250  divider
  #2979FF  primary accent
  #00BFA5  teal (odak, ikincil)
  #FF5252  red (canlı araç, hata)
  #FF9100  orange (tramvay)
  #7C4DFF  purple (ekspres)
  #FF4081  pink (teleferik)
  #FFC400  yellow (ring)
  #00B0FF  light blue (tekne)
  #4CAF50  green (odak turist)
  #00C853  success
  #69F0AE  price green
  #FFAB00  amber warning
  #8899AA  muted text

Light:
  #F5F7FA  scaffold bg
  #FFFFFF  card bg
  #2979FF  appbar + accent
  #E0E6ED  divider
  #546E8A  muted text
```

### Hat Kategorileri
| Kategori | Emoji | Renk | Koşul |
|----------|-------|------|-------|
| Otobüs | 🚌 | #2979FF | Default |
| Ekspres | 🚀 | #7C4DFF | "EKSPRES" veya E+rakam |
| Tramvay | 🚋 | #FF9100 | "TRAMVAY" |
| Ring | 🔄 | #FFC400 | R+rakam |
| Tekne | 🛥️ | #00B0FF | "GEMİ/VAPUR/FERİBOT/TEKNE" |
| Odak | 🏕️ | #4CAF50 | Turistik |
| Teleferik | 🚠 | #FF4081 | "TELEFERİK" |
| Havalimanı | ✈️ | #FF5252 | H+rakam |
| İlçe | 🏘️ | #00BFA5 | İlçe adı (TERME, BAFRA vb.) |

### API Endpoint Haritası (23 endpoint — eski, skill'den güncelini al)
- Primary: `/super-line/{code}` — TÜM hat bilgisini tek pakette verir
- Canlı araçlar: `/api/hat/arac/{code}` — 15s polling
- Duraklar: `/api/hat/durak/{code}`
- Yakın: `/api/yakin?lat=&lon=`
- Rota: `/api/rota?lat1=&lon1=&lat2=&lon2=`
- Odak: `/api/odak`, `/api/odak/{id}/durak`
- SamAir: `/api/samair`, `/api/samair/{id}/sefer`
- GTFS-RT: `/gtfs-rt/vehicle-positions` (protobuf)

### Kritik Teknik Notlar
1. **Türkçe karakter düzeltme** zorunlu — ASIS Windows-1254 bozuk döner
2. **Samsun bbox**: lat 40-43, lon 34-38 dışını reddet
3. **`saatler` objesi Dictionary**, Array değil
4. **Tramvay GPS yok** — SCADA sinyalizasyon
5. **SAMAIR ID**: 1-2 iptal, geçerli: 3,4,5,9,10
6. **15s polling** canlı araç
7. **OSRM** road-following polyline
8. **Haversine** yakın durak (client-side)

---

## 📚 KutuphaneApp Bulguları (Expo Referans)

### Kanıtlanmış Stack (SDK 56, production'da çalışıyor)
```json
{
  "expo": "~56.0.15",
  "react-native": "0.85.3",
  "react": "19.2.3",
  "expo-router": "~56.2.14",
  "react-native-reanimated": "^4.3.1",
  "expo-blur": "^56.0.3",
  "expo-glass-effect": "~56.0.4",
  "expo-linear-gradient": "~56.0.4",
  "expo-location": "~56.0.20",
  "expo-notifications": "~56.0.20",
  "expo-updates": "~56.0.21",
  "lucide-react-native": "^1.20.0",
  "moti": "^0.30.0",
  "typescript": "~6.0.3"
}
```

### Proje Yapısı
```
KutuphaneApp/
├── src/
│   ├── app/          # Expo Router (file-based)
│   │   ├── (tabs)/   # Tab navigasyon
│   │   ├── _layout.tsx   # Root layout
│   │   ├── login.tsx
│   │   ├── settings.tsx
│   │   └── book/[id].tsx # Dinamik route
│   ├── components/   # UI bileşenleri
│   ├── constants/    # Colors.ts, Typography.ts
│   ├── services/     # API servisleri
│   └── utils/        # Yardımcı fonksiyonlar
├── assets/
│   ├── fonts/        # Inter font ailesi (5 ağırlık)
│   └── images/       # App icon, splash
├── app.json          # Expo config
├── eas.json          # EAS build config
└── tsconfig.json     # Path alias: @/* → ./src/*
```

### CI/CD Workflow'ları (GitHub Actions)
1. **auto-ota.yml** — Push to main → OTA güncelleme (eas update)
2. **build-apk.yml** — Manual → EAS build → GitHub Release + Pages QR

### Root Layout Pattern
- `SplashScreen.preventAutoHideAsync()` → fontlar yüklenince hide
- `Updates.checkForUpdateAsync()` → OTA kontrol
- `Appearance.setColorScheme()` → AsyncStorage'dan tema
- Global fetch timeout (20s)
- Error boundary → GitHub Issues raporlama
- Bildirim izni 1.5s gecikmeli

### Expo Plugins (transit-app'e de lazım)
- `expo-router`
- `expo-notifications`
- `expo-splash-screen` (backgroundColor config)
- `expo-build-properties` → `usesCleartextTraffic: true` (**localhost HTTP için şart**)
- `expo-audio` (sesli yönlendirme için ileride)
- `expo-asset`

---

## 🚀 FAZ 1 — Ne Yapılacak (Adım Adım)

### Adım 1: Proje Oluşturma
```bash
cd /home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/transit-app
npx -y create-expo-app@latest ./ --template blank-typescript
```
- `src/` yapısına taşı
- tsconfig path alias ekle (`@/*`)
- Inter fontları kur
- app.json yapılandır (Android package, splash, plugins)
- eas.json kopyala ve adapte et

### Adım 2: Temel Altyapı
- `Colors.ts` — transit app renk paleti (yukarıdaki palette)
- `Typography.ts` — KutuphaneApp'tekinin aynısı
- `_layout.tsx` — Root layout (OTA, tema, splash, error boundary)
- Zustand kurulumu: `useSettingsStore` (tema, dil, şehir)
- TanStack Query kurulumu: `QueryClientProvider`

### Adım 3: API Client
- `services/api/client.ts` — Base fetch wrapper (timeout, error handling, trFix)
- `services/api/samsun.ts` — Samsun API adapter (skill referansıyla)
- `types/transit.ts` — SuperLine, Vehicle, Stop, Route, Schedule tipleri
- `utils/trFix.ts` — Türkçe karakter düzeltme
- `utils/geo.ts` — Haversine, bbox validasyon
- TanStack Query hooks: `useLines()`, `useSuperLine(code)`, `useVehicles(code)`, `useNearbyStops(lat, lon)`

### Adım 4: Harita Ekranı (Ana Tab)
- MapLibre GL Native entegrasyonu
- Kullanıcı konumu (expo-location)
- Durak markerları
- Canlı araç markerları (15s refetchInterval)
- Durak arama overlay
- Long press → rota dialog

### Adım 5: Hat Listesi Ekranı
- Tüm hatlar listesi (FlatList + search)
- Kategori chip'leri (horizontal scroll, emoji + renk)
- Hat detay sayfası:
  - Fiyat kartı (gradient)
  - Mini harita (duraklar + canlı araç)
  - Sefer saatleri (Dictionary parse — gün bazlı)
  - Durak listesi

### Adım 6: Yakın Duraklar
- GPS konum al
- Haversine ile 1km filtre
- Durak detay bottom sheet (yaklaşan araçlar)

### Adım 7: Rota
- Başlangıç/bitiş input
- `/api/rota` çağrısı
- Sonuç kartları

### Adım 8: Unified Architecture (Backend Odaklı Tasarım)
- **Kritik Güncelleme:** Eski Flutter projesindeki karmaşık SAMAIR ve ODAK sekmeleri, local SQLite senkronizasyonları ve fiyat hesaplamaları tamamen kaldırıldı.
- Yeni `asis_api_wrapper` backend'i, `/super-line`, `/lines`, `/stops/all` ve `/smart-stations/{id}` uç noktaları üzerinden tüm SAMAIR, ODAK, Tramvay ve Ekspres araçları **tek bir çatı altında** (Unified) sunuyor.
- Frontend artık sadece veriyi çizen "Aptal İstemci" (Dumb Client) prensibiyle çalışıyor. Ayrıntılı senkronizasyon veya state yönetimi (ör. fiyat hesaplama) frontend'den çıkarıldı.

### Adım 9: Ayarlar
- Tema toggle
- Dil seçimi (TR/EN)
- Şehir değiştir
- Hakkında

### Adım 10: Polish
- Glassmorphism paneller
- Animasyon geçişleri (reanimated)
- Offline banner
- CI/CD workflow'ları adapte et

---

## ⚠️ Kritik Hatırlatmalar

1. **Skill dosyası tek API kaynağı** — dış markdown'lar referans alınmaz
2. **`/super-line/{code}`** birincil endpoint
3. **`saatler` Dictionary**, Array değil — `saatler["Hafta İçi"]`
4. **`usesCleartextTraffic: true`** — localhost HTTP için şart
5. **Sunucu Adresi & Port** — `164.92.219.87` (OTP2) & `localhost:8001` (asis_api_wrapper)
   - **Expo API Token:** `Hl9JypvC4Q3jonIxh7CNRDY0Z5ZuSjswWU6oz3Ed` (Derleme için kullanılır)
6. **KutuphaneApp workflow'ları** aynen kopyalanıp adapte edilecek
7. **GitHub user:** `tarihcituranx`
8. **Expo account:** project ID gerekecek (eas init)
9. **MapLibre** — `@maplibre/maplibre-react-native` paketi
10. **Telegram** — `/home/turan/İndirilenler/Telegram/Telegram` binary'si ile çalıştırılıyor
