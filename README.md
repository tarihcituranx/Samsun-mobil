# Samsun Ulaşım 🇹🇷 | Samsun-mobill

A new Flutter project. By Turan

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

> ⚠️ **Production Notu:** Release build şu an debug key ile imzalanmaktadır. Production dağıtımı için gerçek keystore kullanılmalıdır. Bkz: `android/app/build.gradle.kts` → `signingConfig`.

---


---


---


---


---


---


---

## 🏗️ Proje Mimarisi

> Otomatik analiz ile oluşturuldu — 04.03.2026 22:36

### 📊 Genel Bakış

```
Samsun Ulaşım Sistemi v1.0.0
├── 📱 Flutter Mobil Uygulama
│   ├── lib/                    (21 dosya, 6603 satır)
│   │   ├── screens/             (10 dosya, 4301 satır)
│   │   ├── services/            (11 dosya, 2302 satır)
│   │   └── main.dart
│   ├── android/                (Native Android katmanı)
│   ├── ios/                    (Native iOS katmanı)
│   └── assets/                 (Görseller, fontlar, veriler)
├── 📡 API Katmanı
│   └── docs/openapi.yaml       (REST API şeması)
└── 📦 Dağıtım
    └── releases/               (Versiyonlu APK arşivi)
```

### 🧩 Katman Sorumluluğu

| Katman | Klasör | Görev | Dosya Sayısı |
|--------|--------|-------|-------------|
| 📱 Ekranlar (UI sayfaları) | `lib/screens/` | - | 10 |
| 🌐 Servisler (API, HTTP, veri katmanı) | `lib/services/` | - | 11 |

### 📦 Bağımlılık Haritası

```
┌─────────────────────────────────────────────┐
│          KULLANICI ARAYÜZÜ (UI)             │
│  Screens → Widgets → Theme                  │
└──────────────────┬──────────────────────────┘
                   │ State Yönetimi
                   │ (Provider/ChangeNotifier)
┌──────────────────▼──────────────────────────┐
│          İŞ MANTIĞI (Business Logic)        │
│  Controllers / Providers / Blocs            │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│           VERİ KATMANI (Data)               │
│  Repository → Services → Models             │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│          DIŞ KAYNAKLAR (External)           │
│  GTFS API │ SAMULAŞ API │ Google Maps       │
└─────────────────────────────────────────────┘
```

### 🔌 Kullanılan Paket Kategorileri

| Kategori | Paketler |
|----------|----------|
| 🌐 HTTP / API | http, |
| ⚡ State | provider, |
| 🗺️ Harita | flutter_map, |
| 💾 Depolama | shared_preferences,sqflite, |
| 🛠️ Yardımcılar | intl,geolocator,url_launcher, |

### 🔄 Veri Akışı

```
Kullanıcı Etkileşimi
        │
        ▼
   UI (Screen)
        │
        ▼
  State Manager ──→ Hata Yönetimi
        │
        ▼
   Repository
        │
        ├──→ GTFS-RT API (Anlık konum)
        ├──→ GTFS Static (Hat/durak)
        └──→ Yerel Cache (Çevrimdışı)
```

### 📈 Kod İstatistikleri

| Metrik | Değer |
|--------|-------|
| Toplam Dart dosyası | 21 |
| Toplam satır | 6603 |
| 📱 Ekranlar (UI sayfaları) | 10 dosya |
| 🌐 Servisler (API, HTTP, veri katmanı) | 11 dosya |

---
