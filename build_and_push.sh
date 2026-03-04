#!/bin/bash
# ============================================================
# Samsun Mobil - Akıllı APK Derle, Versiyonla ve Dağıt
# Repo: https://github.com/tarihcituranx/Samsun-mobil.git
# APK Deposu: https://github.com/tarihcituranx/test
# ============================================================

set -e

# ── Renkli çıktı ──────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}ℹ $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ── Ayarlar ───────────────────────────────────────────────
MAIN_REPO="$HOME/Samsun-mobil"
MAIN_REPO_URL="https://github.com/tarihcituranx/Samsun-mobil.git"
APK_REPO_URL="https://github.com/tarihcituranx/test.git"
APK_REPO_DIR="$HOME/samsun-apk-store"
FLUTTER_PROJECT="$MAIN_REPO"                         # pubspec.yaml neredeyse
APK_SOURCE="$FLUTTER_PROJECT/build/app/outputs/flutter-apk/app-release.apk"
MAX_APK_KEEP=3     # Her zaman son 3 APK tutulur, eskisi silinir

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Samsun Mobil — Akıllı Build Sistemi   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── 1. Ana repo hazırla ───────────────────────────────────
info "Ana repo kontrol ediliyor..."
if [ ! -d "$MAIN_REPO" ]; then
  info "Repo klonlanıyor..."
  git clone "$MAIN_REPO_URL" "$MAIN_REPO"
fi

cd "$MAIN_REPO"
git pull origin main
success "Kod güncellendi"

# ── 2. Mevcut sürümü tespit et ────────────────────────────
info "Sürüm tespit ediliyor..."

PUBSPEC="$FLUTTER_PROJECT/pubspec.yaml"
if [ ! -f "$PUBSPEC" ]; then
  PUBSPEC=$(find "$MAIN_REPO" -name "pubspec.yaml" | head -1)
fi

CURRENT_VERSION=$(grep "^version:" "$PUBSPEC" | awk '{print $2}' | tr -d '\r')
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

if [ -z "$VERSION_NAME" ]; then
  VERSION_NAME="1.0.0"
  VERSION_CODE="1"
fi

# Yeni version code hesapla (mevcut + 1)
NEW_CODE=$((VERSION_CODE + 1))
DATE=$(date +"%Y%m%d_%H%M")
BUILD_TAG="v${VERSION_NAME}+${NEW_CODE}"
FOLDER_NAME="v${VERSION_NAME}_build${NEW_CODE}_${DATE}"
APK_FINAL_NAME="samsun-mobil-${BUILD_TAG}.apk"

info "Mevcut sürüm : $VERSION_NAME+$VERSION_CODE"
info "Yeni build   : $BUILD_TAG"
info "APK adı      : $APK_FINAL_NAME"

# ── 3. pubspec.yaml version code güncelle ─────────────────
info "pubspec.yaml güncelleniyor..."
sed -i "s/^version: .*/version: ${VERSION_NAME}+${NEW_CODE}/" "$PUBSPEC"
success "pubspec.yaml → version: ${VERSION_NAME}+${NEW_CODE}"

# ── 3.1 Sürüm notlarını otomatik oluştur ──────────────────
info "Sürüm notları oluşturuluyor..."
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LATEST_TAG" ]; then
  info "İlk sürüm, tüm commit geçmişi alınıyor."
  RELEASE_NOTES=$(git log --pretty=format:"- %s")
else
  info "Değişiklikler ${LATEST_TAG}'den bu yana alınıyor."
  RELEASE_NOTES=$(git log ${LATEST_TAG}..HEAD --pretty=format:"- %s")
fi

if [ -z "$RELEASE_NOTES" ]; then
  RELEASE_NOTES="- Çeşitli iyileştirmeler ve hata düzeltmeleri yapıldı."
fi

info "Sürüm Notları:"
echo -e "${CYAN}$RELEASE_NOTES${NC}"


# ── 4. Flutter build ──────────────────────────────────────
info "Flutter bağımlılıkları yükleniyor..."
FLUTTER_DIR=$(dirname "$PUBSPEC")
cd "$FLUTTER_DIR"
flutter pub get

info "APK derleniyor (release)..."
flutter build apk --release

if [ ! -f "$APK_SOURCE" ]; then
  error "APK bulunamadı: $APK_SOURCE"
fi
success "APK derlendi"

# ── 5. APK deposuna gönder (test repo) ───────────────────
info "APK deposu hazırlanıyor..."

if [ ! -d "$APK_REPO_DIR" ]; then
  git clone "$APK_REPO_URL" "$APK_REPO_DIR"
fi

cd "$APK_REPO_DIR"
git pull origin main

# Versiyonlu klasör oluştur
mkdir -p "releases/$FOLDER_NAME"
cp "$APK_SOURCE" "releases/$FOLDER_NAME/$APK_FINAL_NAME"

# latest klasörünü güncelle
mkdir -p releases/latest
cp "$APK_SOURCE" "releases/latest/app-release.apk"
cp "$APK_SOURCE" "releases/latest/$APK_FINAL_NAME"

# ── 6. Eski APK temizle (son MAX_APK_KEEP tanesi kalır) ──
info "Eski APK'lar temizleniyor (son $MAX_APK_KEEP tutulacak)..."

RELEASE_DIRS=($(ls -dt releases/v* 2>/dev/null || true))
TOTAL=${#RELEASE_DIRS[@]}

if [ "$TOTAL" -gt "$MAX_APK_KEEP" ]; then
  DELETE_COUNT=$((TOTAL - MAX_APK_KEEP))
  warn "$DELETE_COUNT eski sürüm silinecek..."
  for i in $(seq $((MAX_APK_KEEP)) $((TOTAL - 1))); do
    DIR="${RELEASE_DIRS[$i]}"
    warn "Siliniyor: $DIR"
    rm -rf "$DIR"
    git rm -rf "$DIR" 2>/dev/null || true
  done
  success "Temizlik tamamlandı"
fi

# ── 7. version.json güncelle (uygulama içi güncelleme için) ──
info "version.json güncelleniyor..."

APK_DOWNLOAD_URL="https://github.com/tarihcituranx/test/raw/main/releases/latest/app-release.apk"

# JSON içeriğini tırnak sorunlarından kaçınarak oluştur
JSON_CONTENT=$(cat <<JSON
{
  "latestVersion": "${VERSION_NAME}",
  "versionCode": ${NEW_CODE},
  "buildTag": "${BUILD_TAG}",
  "apkUrl": "${APK_DOWNLOAD_URL}",
  "releaseDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "releaseNotes": "${RELEASE_NOTES}",
  "minSupportedVersion": "1.0.0",
  "forceUpdate": false
}
JSON
)
echo "$JSON_CONTENT" > releases/version.json

success "version.json güncellendi"
cat releases/version.json

# ── 8. APK deposunu commit & push ────────────────────────
info "APK deposu GitHub'a gönderiliyor..."
git add .
git commit -m "release: ${BUILD_TAG} - $(date '+%d.%m.%Y %H:%M')"
git push origin main
success "APK deposu güncellendi"

# ── 9. Ana repo commit & push ────────────────────────────
info "Ana repo GitHub'a gönderiliyor..."
cd "$MAIN_REPO"
git add .
git commit -m "build: ${BUILD_TAG} - APK yayınlandı ve proje güncellendi"
git push origin main

info "Yeni sürüm etiketleniyor: ${BUILD_TAG}"
git tag -a "${BUILD_TAG}" -m "Sürüm ${BUILD_TAG}"
git push origin --tags

success "Ana repo güncellendi"

# ── 10. OTOMATİK ANALİZ & RAPORLAMA ────────────────────────
info "Proje mimarisi haritası ve sağlık taraması başlatılıyor..."
bash "$MAIN_REPO/scripts/project_map.sh" "$MAIN_REPO"
bash "$MAIN_REPO/scripts/bug_scan.sh" "$MAIN_REPO"
success "Analiz ve raporlama tamamlandı."

# ── 11. BEYNİ GÜNCELLE ───────────────────────────────────
info "Proje beyni güncelleniyor..."
python3 "$MAIN_REPO/scripts/brain_update.py"
success "Beyin, projenin en güncel haliyle beslendi."


# ── Özet ─────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            TAMAMLANDI! 🚀                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "📱 Sürüm    : ${CYAN}${BUILD_TAG}${NC}"
echo -e "📂 Klasör   : ${CYAN}releases/${FOLDER_NAME}${NC}"
echo -e "🔗 İndir    : ${CYAN}${APK_DOWNLOAD_URL}${NC}"
echo -e "📋 Versiyon : ${CYAN}https://github.com/tarihcituranx/test/raw/main/releases/version.json${NC}"
echo ""
