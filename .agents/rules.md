# 🏛️ Transit App — Proje Anayasası

> Bu dosya, projeye dahil olan tüm AI ajanları ve geliştiriciler için **bağlayıcı anayasadır**.
> Yeni bir oturuma başlayan her ajan, önce bu dosyayı okumalıdır.
> **Son güncelleme:** 2026-07-16

---

## 📌 1. Proje Kimliği ve Vizyon

- **Çalışma Adı:** transit-app (son isim belirlenecek)
- **Platform:** Expo (React Native) — iOS + Android
- **Dil:** TypeScript (strict mode)
- **İlk Şehir:** Samsun
- **GitHub Kullanıcı:** `tarihcituranx`
- **Paket Adı:** `com.tarihcituranx.transitapp`

### Bu Sadece Bir Toplu Taşıma Uygulaması DEĞİLDİR

Bu bir **Akıllı Şehir Süper App**'tir. Fazlar halinde inşa edilecek katmanlar:

| Faz | Katman | Açıklama |
|-----|--------|----------|
| 1 | 🚌 Canlı Ulaşım (MVP) | Harita, canlı araç takibi, rotalama, hat bilgisi |
| 2 | ♿ Erişilebilirlik + 🌍 Çoklu Dil | VoiceOver/TalkBack, sesli yönlendirme, TR/EN/RU/AR |
| 3 | 🏛️ Turizm Katmanı | Mekan profilleri, çok dilli sesli rehber, medya |
| 4 | 📴 Çevrimdışı Mod | Offline harita tile'ları, SQLite sefer tarifeleri |
| 5 | 💱 Pratik Bilgi | Döviz kurları (TCMB), en yakın ATM/Banka |
| 6 | 🤖 AI Asistanı | Doğal dil sorgu, RAG, Tool Calling (OTP2 + içerik DB) |
| 7 | 💳 Ödeme | E-para entegrasyonu |

**Hedef Kitle:** Samsun sakinleri + turistler (yerli/yabancı) + engelli kullanıcılar
**Nihai Amaç:** Belediyeye veya yatırımcıya sunulabilecek, "Samsun'da yapıldığına inanılamayacak kadar premium" bir ürün.

---

## 🏗️ 2. Sistem Mimarisi (Büyük Resim)

```
┌──────────────────────────────────────────────────────────────────┐
│                        MOBİL APP (Expo/RN)                       │
│                       "Aptal İstemci" Prensibi                   │
│  İş mantığı YOK — backend'den gelen veriyi çiziyor              │
│                                                                  │
│  ┌──────────────┐  ┌───────────────┐  ┌────────────────────┐    │
│  │ 🔴 CANLI     │  │ 🟡 YARI-STATİK│  │ 🟢 ÇEVRİMDIŞI     │    │
│  │ TanStack Q.  │  │ REST → SQLite │  │ SQLite + MapLibre  │    │
│  │ 15-30s poll  │  │ cache-first   │  │ offline tiles      │    │
│  └──────┬───────┘  └──────┬────────┘  └────────────────────┘    │
└─────────┼─────────────────┼──────────────────────────────────────┘
          │    REST/JSON     │
          ▼                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                 FastAPI Backend (asis_api_wrapper)                │
│                 Port: 8001 (localhost → ileride VPS)             │
│                                                                  │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────────┐ │
│  │ 31 REST  │  │ In-Process   │  │ Data Pipeline              │ │
│  │ Endpoint │  │ Scheduler    │  │                            │ │
│  │          │  │              │  │ build_db.py (Haftalık)     │ │
│  │ X-API-Key│  │ Saatlik:     │  │ gtfs_builder.py (Günlük)  │ │
│  │ korumalı │  │  SAMAIR sync │  │ update_samair (Saatlik)   │ │
│  └──────────┘  │ Günlük:      │  │ update_tram (Manuel)      │ │
│                │  GTFS build  │  └────────────────────────────┘ │
│                │ Haftalık:     │                                  │
│                │  DB rebuild  │  ┌────────────────────────────┐ │
│                └──────────────┘  │ data/samsun_transit.db     │ │
│                                  │ Tablolar: hat, hat_durak,  │ │
│                                  │           sefer            │ │
│                                  └────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
          │
          ▼ (Veri Kaynakları)
┌─────────────┐  ┌──────────────┐  ┌───────────────┐  ┌──────────┐
│ ASIS API    │  │ samair.      │  │ odak.samsun.  │  │ samulas. │
│ samsun.bel  │  │ samsun.bel   │  │ bel.tr        │  │ com.tr   │
│ (Canlı GPS) │  │ (Havalimanı) │  │ (Turist)      │  │ (Fiyat)  │
└─────────────┘  └──────────────┘  └───────────────┘  └──────────┘
```

### Otomasyon Takvimi (Backend In-Process Scheduler)

| Görev | Sıklık | Script | Ne Yapıyor |
|-------|--------|--------|-----------|
| SAMAIR Sync | **Her saat** | `update_samair_schedules.py` | Uçuş saatlerini çekip DB'ye yazar |
| GTFS Build | **Her gece 04:00** | `gtfs_builder.py` | Tam GTFS feed üretir (google_transit.zip) |
| DB Rebuild | **Pazar 03:00** | `build_db.py` | ASIS'ten tüm hat/durak/sefer verisini sıfırdan çeker |

---

## 📡 3. API Endpoint Haritası (31 Endpoint)

### Referans Hiyerarşisi
1. **`samsun-gtfs-rt-api` skill dosyası** — en güncel mimari referans
2. **Bu dosya** — endpoint listesi ve mobil kullanım stratejisi
3. Backend Swagger — `{apiBaseUrl}/docs`

### 🔴 Canlı Veri (Online — Polling ile)

| Endpoint | Mobil Hook | Polling | Ne Döner |
|----------|-----------|---------|----------|
| `/super-line/{code}` | `useSuperLine(code)` | **15s** | ⭐ TEK PAKET: hat_bilgisi + duraklar + saatler (Dictionary!) + canli_araclar (ETA dahil) + fiyat + guzergah_cizgisi |
| `/smart-stations/{id}` | `useSmartStation(id)` | **15s** | Durağa yaklaşan araçlar + kalan süre |
| `/marine/realtime` | `useMarineVehicles()` | **30s** | Deniz araçları canlı GPS |
| `/samair/vehicles` | — | **15s** | SAMAIR araçları canlı GPS |
| `/odak/vehicles` | — | **15s** | Odak araçları canlı GPS |

### 🟡 Yarı-Statik Veri (Cache-first — App açılışı + pull-to-refresh)

| Endpoint | Mobil Hook | Stale Süresi | Ne Döner |
|----------|-----------|-------------|----------|
| `/lines` | `useLines()` | **24 saat** | Aktif hat listesi (~73 hat) |
| `/stops/all` | `useAllStops()` | **24 saat** | Tüm duraklar (~1627) |
| `/fares` | — | **24 saat** | Tüm tarife tabloları (tramvay, otobüs, aktarma, abonelik, teleferik, samkart, tekne) |
| `/fares/line?lineCode=X` | — | **24 saat** | Tek hat fiyatı (kategori bazlı) |
| `/parkings` | `useParkings()` | **24 saat** | Otopark konumları (Samulaş KMZ) |
| `/announcements` | `useAnnouncements()` | **1 saat** | Aktif duyuru banner'ı |
| `/odak/lines` | — | **24 saat** | Odak turistik hat listesi |
| `/odak/stops/{hatId}` | — | **24 saat** | Odak hat durakları + fiyat |
| `/samair/stops` | — | **24 saat** | SAMAIR durakları + fiyat |
| `/samair/schedules/{hatId}` | — | **1 saat** | SAMAIR uçuş bağlantılı sefer saatleri |
| `/tourism/landmarks` | — | **7 gün** | Müze/turistik mekan listesi |
| `/statistics/fleet` | — | **30 gün** | Filo envanter bilgisi (hardcoded) |
| `/corporate/{page}` | — | **7 gün** | Kurumsal bilgiler (KVKK, SSS, kart merkezleri) |
| `/corporate/about` | — | **7 gün** | SAMULAŞ şirket bilgisi |

### 🟢 Çevrimdışı Katman (SQLite + MapLibre)

| Veri | Kaynak | SQLite'a Yazılacak | Güncelleme |
|------|--------|-------------------|-----------|
| Sefer saatleri | `/super-line` → saatler | ✅ | Günlük senkron |
| Durak koordinatları | `/stops/all` | ✅ | Haftalık senkron |
| Hat bilgileri | `/lines` | ✅ | Haftalık senkron |
| Güzergah polyline'ları | `/super-line` → guzergah_cizgisi | ✅ | Haftalık senkron |
| Fiyat bilgileri | `/fares` | ✅ | Haftalık senkron |
| Harita tile'ları | MapLibre offline regions | ✅ | Kullanıcı tetiklemeli |

### ⚫ Mobil Tarafından KULLANILMAYACAK Endpoint'ler

| Endpoint | Neden |
|----------|-------|
| `/gtfs-rt/vehicle-positions` | Protobuf — Google Maps/OTP2 için |
| `/gtfs-rt/trip-updates` | Protobuf — Google Maps/OTP2 için |
| `/orjlines` | Ham/debug — tüm gizli hatlar dahil |
| `/realtime` | Ham GPS — super-line zaten sarmalıyor |
| `/stops` (filtreli) | Tekil — stops/all ve super-line yeterli |
| `/schedules` | Ham — super-line zaten sarmalıyor |
| `/line-directions` | Ham — super-line duraklar zaten veriyor |
| `/tram/stops` | Özel — super-line zaten veriyor |
| `/download-db`, `/db-version` | Admin/debug |
| `/health`, `/ready` | Altyapı izleme |

---

## 🔑 4. Kritik API Kuralları

### `/super-line/{code}` — Birincil Endpoint

Bu endpoint **tüm hat bilgisini tek pakette** verir. Mobil app çoğu durumda sadece bunu çağırmalıdır.

```typescript
SuperLineResponse {
  hat_bilgisi: { code, name, kat, tip, alias }
  duraklar: [{ durak_id, ad, sira, lat, lon, bearing }]
  saatler: {                          // ⚠️ DİCTİONARY — Array DEĞİL!
    "Hafta İçi": [{ saat, yon, tabela }],
    "Cumartesi": [...],
    "Pazar": [...]
  }
  canli_araclar: {
    data: [{
      plaka, enlem, boylam, hiz, yon,
      bulundugu_durak: { durak_id, ad, sira, mesafe_metre },
      gelecek_duraklar: [{ durak_id, ad, sira, tahmini_varis_dk }]
    }]
  }
  fiyat: { kategori, tam_fiyat, egitim_fiyat, aktarma }
  guzergah_cizgisi: [[lat, lon], ...]
}
```

### Kritik Uyarılar
1. **`saatler` Dictionary'dir**, Array değil → `saatler["Hafta İçi"]` şeklinde erişilmeli
2. **Tramvay GPS verisi yoktur** — SCADA sinyalizasyon sistemi kullanır, `/realtime`'da tramvay gelmez
3. **SAMAIR ID'leri:** 1-2 iptal, geçerli: 3, 4, 5, 9, 10
4. **Samsun bbox:** lat 40-43, lon 34-38 dışındaki araç konumları reddedilmeli
5. **Türkçe karakter düzeltme** zorunlu — ASIS API Windows-1254 bozuk döner (trFix.ts)
6. **SAMAIR sefer saatleri** uçuş bağlantılı — saatlik güncellenir, tabela alanında uçak firması yazar
7. **ETA algoritması** backend'de çalışır — Haversine + 20km/h + durak başı +1dk bekleme
8. **Tüm endpoint'ler `X-API-Key` header** gerektirir

---

## 🛠️ 5. Teknoloji Yığını

| Katman | Teknoloji | Gerekçe |
|--------|-----------|---------|
| Framework | Expo SDK 57 | OTA güncelleme, hızlı geliştirme |
| Runtime | React Native 0.86, React 19 | En güncel |
| Dil | TypeScript 6 (strict) | Tip güvenliği |
| Navigasyon | Expo Router (file-based) | Next.js tarzı, typedRoutes |
| State | Zustand 5 | Hafif, Provider/Redux'a göre temiz |
| API Cache | TanStack Query 5 | Otomatik cache, stale-while-revalidate, refetchInterval |
| Harita | MapLibre GL Native | Açık kaynak, vektör, 60fps, offline tile |
| Yerel DB | expo-sqlite | Çevrimdışı cache |
| Animasyon | react-native-reanimated 4 | 60fps donanımsal ivmelenme |
| Blur | expo-blur | Glassmorphism paneller |
| İkonlar | lucide-react-native | Modern, temiz ikon seti |
| Konum | expo-location | GPS |
| Bildirim | expo-notifications | Push notification |
| i18n | react-i18next (FAZ 2) | Çoklu dil |

### Referans Proje
**KutuphaneApp** (`tarihcituranx/Kutuphaneapp`) — Aynı stack ile production'da çalışan Expo projesi. CI/CD workflow'ları, font sistemi, root layout pattern'leri buradan devralınmıştır.

---

## 🎨 6. Tasarım Kuralları

### Renk Paleti

```
Dark Theme:
  Background:     #0A1628 (derin lacivert)
  Surface:        #152238 (kart arka planı)
  AppBar:         #0F1E36
  Accent:         #2979FF (birincil mavi)
  Teal:           #00BFA5 (ikincil — Odak, başarı)
  Red:            #FF5252 (canlı araç, hata)
  Orange:         #FF9100 (tramvay)
  Purple:         #7C4DFF (ekspres)
  Pink:           #FF4081 (teleferik)
  Yellow:         #FFC400 (ring)
  Divider:        #1E3250
  Muted Text:     #8899AA

Light Theme:
  Background:     #F5F7FA
  Surface:        #FFFFFF
  AppBar:         #2979FF
  Divider:        #E0E6ED
  Muted Text:     #546E8A
```

### Hat Kategori Renkleri

| Kategori | Emoji | Renk | Koşul |
|----------|-------|------|-------|
| Otobüs | 🚌 | #2979FF | Default |
| Ekspres | 🚀 | #7C4DFF | "EKSPRES" veya E+rakam |
| Tramvay | 🚋 | #FF9100 | "TRAMVAY" |
| Ring | 🔄 | #FFC400 | R+rakam |
| Tekne | 🛥️ | #00B0FF | "GEMİ/VAPUR/FERİBOT/TEKNE" |
| Odak | 🏕️ | #4CAF50 | Turistik rotalar |
| Teleferik | 🚠 | #FF4081 | "TELEFERİK" |
| Havalimanı | ✈️ | #FF5252 | H+rakam (SAMAIR) |
| İlçe | 🏘️ | #00BFA5 | İlçe adı (TERME, BAFRA vb.) |

### UI İlkeleri
- **Glassmorphism:** Harita üzerindeki paneller yarı şeffaf, blur efektli
- **Sıvı animasyonlar:** Menü geçişlerinde, kart açılışlarında 60fps
- **Premium his:** Samsun'da yapıldığına inanılamayacak kadar kaliteli
- **Klişe tasarımlardan kaçın:** Standart Material/Cupertino klonları YASAK
- **Harita merkezli:** Harita uygulamanın kalbi, her zaman erişilebilir
- **Border radius:** Kartlar 14px, butonlar 12px
- **Tipografi:** Inter font ailesi (Regular/Medium/SemiBold/Bold/Black), 6-level scale

---

## 📂 7. Dosya Yapısı

```
transit-app/
├── .agents/              # AI ajan kuralları ve proje takibi
│   ├── rules.md          # Bu dosya (ANAYASA)
│   └── tracking.md       # Proje ilerleme takibi
├── src/
│   ├── app/              # Expo Router sayfaları (file-based routing)
│   │   ├── _layout.tsx   # Root layout (tema, splash, OTA, QueryClient)
│   │   ├── index.tsx     # → /(tabs) redirect
│   │   ├── (tabs)/       # Tab navigasyon grubu
│   │   │   ├── _layout.tsx   # 4 tab: Harita, Hatlar, Keşfet, Ayarlar
│   │   │   ├── index.tsx     # Harita ekranı (ana sayfa)
│   │   │   ├── lines.tsx     # Hat listesi
│   │   │   ├── explore.tsx   # Keşfet (duyurular, otopark, deniz)
│   │   │   └── settings.tsx  # Ayarlar (henüz stub)
│   │   └── line/
│   │       └── [id].tsx      # Hat detay (harita + güzergah + canlı araç + saatler)
│   ├── components/
│   │   └── map/          # Harita bileşenleri
│   │       ├── StopMarker.tsx      # ShapeSource+CircleLayer (1600+ durak)
│   │       ├── StopBottomSheet.tsx  # Durak detay + yaklaşan araçlar
│   │       ├── VehicleMarker.tsx    # Canlı araç marker'ı
│   │       └── RoutePolyline.tsx    # Hat güzergah çizgisi
│   ├── services/
│   │   └── api/
│   │       ├── client.ts     # Fetch wrapper (timeout, error, apiBaseUrl)
│   │       └── samsun.ts     # 7 fetch + 7 TanStack Query hook
│   ├── store/
│   │   └── useSettingsStore.ts  # Zustand (şehir, dil, tema) + AsyncStorage
│   ├── types/
│   │   └── transit.ts    # SuperStop, Vehicle, LineInfo, SuperLineResponse, CityConfig
│   ├── constants/
│   │   ├── Colors.ts     # Dark/Light tema + kategori renkleri
│   │   └── Typography.ts # Inter 6-level type scale
│   └── utils/
│       └── trFix.ts      # Türkçe karakter düzeltme
├── assets/               # Görseller, fontlar
├── app.json              # Expo config
├── tsconfig.json         # Path alias: @/* → ./src/*
└── package.json          # Bağımlılıklar
```

### Dosya Kuralları
- Bir dosya **300 satırı** geçmemeli — geçiyorsa parçala
- Her component kendi klasöründe olabilir: `ComponentName/index.tsx` + `ComponentName/styles.ts`
- API tiplemeleri `types/` altında, servis dosyalarında inline type YASAK
- `any` tipi kullanma — her şey tipli olmalı

---

## 🏗️ 8. Çoklu Şehir Mimarisi

### Config-Driven Yaklaşım

```typescript
interface CityConfig {
  id: string;                      // "samsun"
  name: string;                    // "Samsun"
  apiBaseUrl: string;              // "https://deflation-shaded-sterility.ngrok-free.dev"
  defaultCenter: [number, number]; // [41.2867, 36.3300]
  bbox: { minLat, maxLat, minLon, maxLon };
  categories: CategoryConfig[];
  features: FeatureFlags;          // hangi özellikler açık
}
```

### Kurallar
- Şehre özel iş mantığı `services/cities/{cityId}/` altında
- Ortak mantık (harita, rota, haversine) şehirden bağımsız
- Yeni şehir eklemek = yeni config + yeni API adapter, UI değişikliği YOK
- Şu an `useSettingsStore.ts` içinde `CITIES` objesi ile Samsun tanımlı

---

## 🔗 9. Proje Konumları

| Proje | Yol | Açıklama |
|-------|-----|----------|
| **Transit App** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/transit-app` | Bu proje |
| **FastAPI Backend** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/Samsun_Ulasim_ArGe/asis_api_wrapper` | Gerçek backend |
| **KutuphaneApp** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/KutuphaneApp` | Expo stack referansı |
| **Eski Flutter App** | `/home/turan/Masaüstü/Düzenli_Masaüstü/Projeler/Samsun-mobil` | Sadece feature ilhamı |
| **Süper App Vizyon** | `Samsun_Ulasim_ArGe/SUPER_APP_FIKIRLER.md` | Vizyon dokümanı |
| **API Skill** | `~/.gemini/config/skills/samsun_gtfs_rt_api/SKILL.md` | EN GÜNCEL API mimari referansı |
| **Backend Swagger** | `{apiBaseUrl}/docs` | Otomatik endpoint dökümantasyonu |

---

## 🚫 10. Yapılmaması Gerekenler

1. **Monolitik dosya yazma** — 300+ satır dosyalar YASAK
2. **setState() ile global state** — Zustand kullan
3. **Hardcoded API URL** — Config'den al (`useSettingsStore` → `CITIES`)
4. **Console.log debugging** — Kaldırmadan commit YASAK
5. **`any` tipi kullanma** — Her şey tipli olmalı
6. **GTFS-RT Protobuf'u mobilde parse etme** — REST JSON endpoint'leri kullan
7. **`/realtime` endpoint'ini direkt çağırma** — `/super-line` zaten sarmalıyor
8. **`/schedules` endpoint'ini direkt çağırma** — `/super-line` zaten sarmalıyor
9. **Backend iş mantığını frontend'e taşıma** — "Aptal İstemci" prensibi
10. **Eski Flutter kodunu kopyalama** — Sadece feature ilhamı al
11. **Proje dışı markdown dosyalarını referans alma** — Skill + bu anayasa yeterli
12. **Tracking'i güncellememek** — Her oturum sonunda `tracking.md` güncellenMELİ

## 🚨 API Entegrasyon Kritik Notları: Gidiş/Dönüş Alternatifleri
Backend API'de `/super-line/{lineCode}` endpointine sorgu atarken:
1. **Asla Kısa Kod Gönderme**: "22" veya "E3" gibi eksik hat kodları yollanırsa, API veritabanında `LIKE` araması yapar ve ilk eşleşen yönü (Örn: Sadece Dönüş) döndürür. Bu durum kullanıcı tarafında kafa karışıklığı yaratır.
2. **alternatif_yonler Alanı**: Eğer kullanıcı eksik arama yaparsa, API arka planda diğer olası yönleri de bulur ve JSON cevabının en altına `alternatif_yonler: ["22 TÜRKİŞ-SOĞUKSU"]` adında bir liste ekler.
3. **UI Görevi (Frontend)**: Uygulamada `LineDetailScreen` veya harita ekranında, eğer `alternatif_yonler` dizisi dolu gelmişse (örn: length > 0), ekrana "🔄 Diğer Yönü Gör" şeklinde belirgin bir buton koymalısın. Bu butona basıldığında, o alternatif kod ile API'ye yeniden istek atılmalı.

---

## 🛑 11. Oturum Kapanış Kuralları

1. **"Bugünlük proje bitti"** veya benzeri bir kapanış komutu verildiğinde, AI ajanı derhal aşağıdaki işlemleri yapmakla yükümlüdür:
   - O günkü ilerlemeyi `tracking.md` dosyasına kaydetmek.
   - Yerel projedeki tüm değişiklikleri otomatik olarak GitHub'a (`git add .`, `git commit`, `git push`) gönderip yedeklemek.
