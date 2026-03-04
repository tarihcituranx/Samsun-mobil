# 🧠 Proje Beyin Dosyası — Samsun Ulaşım Sistemi

> Bu dosya Claude'un proje hafızasıdır. Her oturumda okunur, her önemli
> değişiklikte güncellenir. Alzheimer yaşamamak için burada!
> **Son güncelleme:** 04.03.2026 10:26

---

## 📌 Proje Özeti
- **Ad:** Samsun Ulaşım Sistemi
- **Paket:** com.tarihcituranx.samsun_ulasim
- **Sürüm:** 1.0.0+8
- **Platform:** Android (min SDK 24)
- **Geliştirici:** Turan Kaya
- **Ana Repo:** https://github.com/tarihcituranx/Samsun-mobil
- **APK Repo:** https://github.com/tarihcituranx/test

## 🏗️ Mimari
- **Framework:** Flutter / Dart
- **State Yönetimi:** (tespit edilecek)
- **API:** GTFS-RT + SAMULAŞ REST API
- **Ortam:** Google Firebase Studio (IDX) — Nix tabanlı

## 📊 Kod İstatistikleri
- Dart dosyası: 19
- Toplam satır: 5737

## 📁 Klasör Yapısı
lib/
├── helpers/  (1 dosya)
├── main.dart
├── screens/  (9 dosya)
├── services/  (8 dosya)

## ✅ Tamamlanan Görevler
- [x] Proje kurulumu
- [x] Splash screen (splash_logo.png)
- [x] Android icon seti
- [x] build_and_push.sh — otomatik derleme
- [x] bug_scan.sh — kaynak + APK tarayıcı
- [x] update_docs.sh — README/OpenAPI/KVKK
- [x] project_map.sh — mimari harita + temizleyici
- [x] rename_app.sh — paket adı güncelleyici
- [x] update_checker.dart — uygulama içi güncelleme
- [x] CI/CD workflow düzeltmesi (APK_REPO_TOKEN + continue-on-error)
- [x] DBService asset dosya adı düzeltmesi
- [x] SQL injection koruması (parameterized queries)
- [x] Admin key güvenlik düzeltmesi (URL→Header)
- [x] DatabaseHelper.createTables() paylaşımlı şema
- [x] Sync sonrası cache invalidation

## 🚧 Devam Eden Görevler
- [ ] ...

## 🐛 Bilinen Buglar
- [x] Android Build Tools 35.0.0 — Nix ortamında versiyon uyumsuzluğu
- [x] DBService yanlış asset adı (samsun_ulasim.db → samsun_mobil.db)
- [x] DBService read-only açılıyordu, sync yazamıyordu
- [x] CI workflow cross-repo push izin hatası (GITHUB_TOKEN → APK_REPO_TOKEN)
- [x] SQL injection riski (calculateRouteLocally)
- [x] Admin key URL'de açığa çıkıyordu

## 🔑 Kritik Kararlar
| Karar | Gerekçe | Tarih |
|-------|---------|-------|
| buildToolsVersion sabitlendi | Nix read-only SDK | 04.03.2026 09:26 |
| APK ayrı repoda tutulur | Ana repo büyümesin | 04.03.2026 09:26 |
| Son 3 APK tutulur, eskisi silinir | Alan tasarrufu | 04.03.2026 09:26 |
| Şeffaf PNG splash | Hem açık hem koyu tema | 04.03.2026 09:26 |

## 🔧 Özel Yapılandırmalar
- Build Tools: 34.0.0 (Nix'te kurulu olan)
- Min SDK: 24
- Target SDK: 34
- Gradle: 8.x uyumlu
- Ortam: Firebase Studio / IDX / Nix

## 📝 Son Oturum Notları
- Tarih: 04.03.2026 14:57
- Yapılan: CI/CD düzeltmesi, DB sorunları çözüldü, güvenlik açıkları kapatıldı
- Bırakılan: —

## ⚠️ Dikkat Edilecekler
- Firebase Studio'da SDK Manager çalışmaz, build.gradle ile çöz
- APK imzası her release build'de kontrol et
- flutter pub cache clean bazen gerekebilir
- local.properties silmek bazen build sorununu çözer

## 📜 Git Geçmişi (Son 5)
613a9ff Update build_and_push.sh
2b508f4 Add files via upload
2deeea6 Enhance APK build and deployment process
4731a3f Add files via upload
e4d80a0 build: v1.0.0+3 - APK yayınlandı ve proje güncellendi
