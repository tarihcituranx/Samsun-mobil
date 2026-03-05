# 🧠 Proje Beyin Dosyası — Samsun Ulaşım Sistemi

> Bu dosya Claude'un proje hafızasıdır. Her oturumda okunur, her önemli
> değişiklikte güncellenir. Alzheimer yaşamamak için burada!
> **Son güncelleme:** 05.03.2026 11:28

---

## 📌 Proje Özeti
- **Ad:** Samsun Ulaşım Sistemi
- **Paket:** com.tarihcituranx.samsun_ulasim
- **Sürüm:** 1.0.0+22
- **Platform:** Android (min SDK 24)
- **Geliştirici:** Turan Kaya
- **Ana Repo:** https://github.com/tarihcituranx/Samsun-mobil
- **APK Repo:** https://github.com/tarihcituranx/test

## 🏗️ Mimari
- **Framework:** Flutter / Dart
- **State Yönetimi:** Provider / ChangeNotifier
- **API:** GTFS-RT + SAMULAŞ REST API
- **Ortam:** Google Firebase Studio (IDX) — Nix tabanlı
- **CI/CD:** GitHub Actions → scripts/build.sh

## 📊 Kod İstatistikleri
- Dart dosyası: 28
- Toplam satır: 7247

## 📁 Klasör Yapısı
lib/
├── constants.dart
├── helpers/  (1 dosya)
├── l10n/  (0 dosya)
├── main.dart
├── screens/  (9 dosya)
├── services/  (12 dosya)
├── widgets/  (4 dosya)

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
- version.json: https://github.com/tarihcituranx/test/raw/main/releases/version.json

## 📝 Son Oturum Notları
- Tarih: 05.03.2026 11:28
- Son commit: build: v1.0.0+22 - APK yayınlandı
- Bırakılan: —

## ⚠️ Dikkat Edilecekler
- Firebase Studio'da SDK Manager çalışmaz, build.gradle ile çöz
- APK imzası her release build'de kontrol et
- flutter pub cache clean bazen gerekebilir
- local.properties silmek bazen build sorununu çözer
- Bağımlılık çakışması → scripts/fix_deps.py otomatik halleder

## 📜 Git Geçmişi (Son 5)
```
bc2b7b8 build: v1.0.0+22 - APK yayınlandı
d3e0d8a brain: hafıza güncellendi — 05.03.2026 11:09
5835b6e build: v1.0.0+21 - APK yayınlandı
4eec786 brain: hafıza güncellendi — 05.03.2026 10:53
9da1feb build: v1.0.0+20 - APK yayınlandı
```
