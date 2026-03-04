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

# ── Log sistemi ───────────────────────────────────────────
LOG_DIR="$HOME/Samsun-mobil/logs"
mkdir -p "$LOG_DIR"

BUILD_START=$(date +"%Y%m%d_%H%M%S")
LOG_FILE=""       # build sonrası versiyon belli olunca set edilir
STEP_LOG=""       # her adımın çıktısı buraya

# Her adımı hem ekrana hem log'a yazar
log() {
  local level="$1"; shift
  local msg="$*"
  local ts=$(date +"%Y-%m-%d %H:%M:%S")
  local line="[$ts] [$level] $msg"
  echo "$line" >> "$STEP_LOG"
  case "$level" in
    INFO)    info    "$msg" ;;
    OK)      success "$msg" ;;
    WARN)    warn    "$msg" ;;
    ERROR)   echo -e "${RED}❌ $msg${NC}" ;;
  esac
}

# Hata yakalayıcı — script herhangi bir yerden patlarsa çağrılır
on_error() {
  local exit_code=$?
  local line_no=$1
  local ts=$(date +"%Y-%m-%d %H:%M:%S")

  echo "" >> "$STEP_LOG"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$STEP_LOG"
  echo "  HATA RAPORU" >> "$STEP_LOG"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$STEP_LOG"
  echo "  Zaman     : $ts" >> "$STEP_LOG"
  echo "  Sürüm     : ${BUILD_TAG:-bilinmiyor}" >> "$STEP_LOG"
  echo "  Exit kodu : $exit_code" >> "$STEP_LOG"
  echo "  Satır no  : $line_no" >> "$STEP_LOG"
  echo "  Flutter   : $(flutter --version 2>/dev/null | head -1 || echo 'bulunamadı')" >> "$STEP_LOG"
  echo "  Disk      : $(df -h $HOME | awk 'NR==2{print $3"/"$2" ("$5" dolu)"}')" >> "$STEP_LOG"
  echo "  Son 40 satır çıktı:" >> "$STEP_LOG"
  echo "  ─────────────────────────────────────────────" >> "$STEP_LOG"
  tail -40 "$STEP_LOG" >> "$STEP_LOG" 2>/dev/null || true
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$STEP_LOG"

  # Hata logunu ayrı dosyaya da kaydet
  local err_file="$LOG_DIR/ERROR_${BUILD_TAG:-unknown}_${BUILD_START}.log"
  cp "$STEP_LOG" "$err_file"

  echo ""
  echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
  echo -e "${RED}║           BUILD BAŞARISIZ ❌             ║${NC}"
  echo -e "${RED}╚══════════════════════════════════════════╝${NC}"
  echo -e "${RED}  Satır    : $line_no${NC}"
  echo -e "${RED}  Sürüm    : ${BUILD_TAG:-bilinmiyor}${NC}"
  echo -e "${RED}  Log      : $err_file${NC}"
  echo ""
}

trap 'on_error $LINENO' ERR

# ── Disk temizleyici ──────────────────────────────────────
cleanup_disk() {
  local reason="$1"   # "pre_build" veya "low_disk"
  log INFO "🧹 Disk temizliği başlatılıyor ($reason)..."
  local freed=0

  # 1. Gradle cache (en büyük suçlu, genelde 5-7GB)
  if [ -d "$HOME/.gradle/caches" ]; then
    local s=$(du -sm "$HOME/.gradle/caches" 2>/dev/null | cut -f1)
    rm -rf "$HOME/.gradle/caches"
    log OK "Gradle cache silindi (~${s}MB)"
    freed=$((freed + s))
  fi

  # 2. Flutter build artifacts
  if [ -d "$HOME/Samsun-mobil/build" ]; then
    local s=$(du -sm "$HOME/Samsun-mobil/build" 2>/dev/null | cut -f1)
    flutter clean --suppress-analytics 2>/dev/null || rm -rf "$HOME/Samsun-mobil/build"
    log OK "Flutter build temizlendi (~${s}MB)"
    freed=$((freed + s))
  fi

  # 3. /tmp çöpleri
  local s=$(du -sm /tmp 2>/dev/null | cut -f1)
  rm -rf /tmp/cmdtools* /tmp/gradle* /tmp/flutter* /tmp/dart* /tmp/*.zip /tmp/*.apk 2>/dev/null || true
  log OK "/tmp temizlendi (~${s}MB)"

  # 4. Dart pub cache (yeniden indirilir)
  if [ -d "$HOME/.pub-cache/hosted" ]; then
    local s=$(du -sm "$HOME/.pub-cache/hosted" 2>/dev/null | cut -f1)
    rm -rf "$HOME/.pub-cache/hosted"
    log OK "Pub cache temizlendi (~${s}MB)"
    freed=$((freed + s))
  fi

  # 5. Android build cache
  rm -rf "$HOME/.android/cache" 2>/dev/null || true

  # 6. Eski log dosyaları (10'dan fazlaysa sil)
  if [ -d "$LOG_DIR" ]; then
    ls -1t "$LOG_DIR"/*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
  fi

  # 7. APK store'da son MAX_APK_KEEP dışındakileri sil
  if [ -d "$HOME/samsun-apk-store/releases" ]; then
    local dirs=($(ls -dt "$HOME/samsun-apk-store/releases/v"* 2>/dev/null || true))
    local total=${#dirs[@]}
    if [ "$total" -gt "$MAX_APK_KEEP" ]; then
      for i in $(seq $((MAX_APK_KEEP)) $((total - 1))); do
        rm -rf "${dirs[$i]}"
        log WARN "Eski APK silindi: ${dirs[$i]}"
      done
    fi
  fi

  local free_after=$(df -k $HOME | awk 'NR==2 {print int($4/1024)}')
  log OK "Temizlik bitti — Şu an boş: ${free_after}MB (~${freed}MB kazanıldı)"
  echo "[CLEANUP] reason=$reason freed=${freed}MB free_after=${free_after}MB" >> "$STEP_LOG"
}

# ── Disk kontrol fonksiyonu ───────────────────────────────
check_disk() {
  local min_mb="${1:-1500}"   # minimum MB
  local free_mb=$(df -k $HOME | awk 'NR==2 {print int($4/1024)}')
  local used_pct=$(df -k $HOME | awk 'NR==2 {print int($5)}')
  echo "[DISK] free=${free_mb}MB used=${used_pct}%" >> "$STEP_LOG"
  log INFO "Disk durumu: ${free_mb}MB boş (%${used_pct} dolu)"
  if [ "$free_mb" -lt "$min_mb" ]; then
    log WARN "Yetersiz disk! ${free_mb}MB < ${min_mb}MB — temizlik zorunlu"
    cleanup_disk "low_disk"
  fi
}

# ── Ayarlar ───────────────────────────────────────────────
MAIN_REPO="$HOME/Samsun-mobil"
MAIN_REPO_URL="https://github.com/tarihcituranx/Samsun-mobil.git"
APK_REPO_URL="https://github.com/tarihcituranx/test.git"
APK_REPO_DIR="$HOME/samsun-apk-store"
FLUTTER_PROJECT="$MAIN_REPO"
APK_SOURCE="$FLUTTER_PROJECT/build/app/outputs/flutter-apk/app-release.apk"
MAX_APK_KEEP=3

# Geçici log (versiyon belli olmadan önce)
STEP_LOG=$(mktemp /tmp/build_XXXXXX.log)

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Samsun Mobil — Akıllı Build Sistemi   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── 1. Ana repo hazırla ───────────────────────────────────
log INFO "Ana repo kontrol ediliyor..."
if [ ! -d "$MAIN_REPO" ]; then
  log INFO "Repo klonlanıyor..."
  git clone "$MAIN_REPO_URL" "$MAIN_REPO" 2>&1 | tee -a "$STEP_LOG"
fi

cd "$MAIN_REPO"
git pull origin main 2>&1 | tee -a "$STEP_LOG"
log OK "Kod güncellendi"

# ── 2. Sürüm tespit et ────────────────────────────────────
log INFO "Sürüm tespit ediliyor..."
PUBSPEC="$FLUTTER_PROJECT/pubspec.yaml"
[ ! -f "$PUBSPEC" ] && PUBSPEC=$(find "$MAIN_REPO" -name "pubspec.yaml" | head -1)

CURRENT_VERSION=$(grep "^version:" "$PUBSPEC" | awk '{print $2}' | tr -d '\r')
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)
[ -z "$VERSION_NAME" ] && VERSION_NAME="1.0.0" && VERSION_CODE="1"

NEW_CODE=$((VERSION_CODE + 1))
DATE=$(date +"%Y%m%d_%H%M")
BUILD_TAG="v${VERSION_NAME}+${NEW_CODE}"
FOLDER_NAME="v${VERSION_NAME}_build${NEW_CODE}_${DATE}"
APK_FINAL_NAME="samsun-mobil-${BUILD_TAG}.apk"

# Artık BUILD_TAG biliniyor — kalıcı log dosyasını ayarla
LOG_FILE="$LOG_DIR/build_${BUILD_TAG}_${BUILD_START}.log"
{
  echo "════════════════════════════════════════════════"
  echo "  Samsun Mobil — Build Log"
  echo "  Sürüm   : $BUILD_TAG"
  echo "  Başlangıç: $(date '+%d.%m.%Y %H:%M:%S')"
  echo "  Makine  : $(uname -a)"
  echo "  Flutter : $(flutter --version 2>/dev/null | head -1)"
  echo "  Disk    : $(df -h $HOME | awk 'NR==2{print $3"/"$2" ("$5" dolu)"}')"
  echo "════════════════════════════════════════════════"
  echo ""
} > "$LOG_FILE"

# Geçici logu kalıcıya taşı
cat "$STEP_LOG" >> "$LOG_FILE"
STEP_LOG="$LOG_FILE"

log INFO "Mevcut sürüm : $VERSION_NAME+$VERSION_CODE"
log INFO "Yeni build   : $BUILD_TAG"
log INFO "Log dosyası  : $LOG_FILE"

# ── 3. pubspec güncelle ───────────────────────────────────
log INFO "pubspec.yaml güncelleniyor..."
sed -i "s/^version: .*/version: ${VERSION_NAME}+${NEW_CODE}/" "$PUBSPEC"
log OK "pubspec.yaml → version: ${VERSION_NAME}+${NEW_CODE}"

# ── 3.1 Sürüm notları ────────────────────────────────────
log INFO "Sürüm notları oluşturuluyor..."
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$LATEST_TAG" ]; then
  RELEASE_NOTES=$(git log --pretty=format:"- %s" 2>&1)
else
  RELEASE_NOTES=$(git log ${LATEST_TAG}..HEAD --pretty=format:"- %s" 2>&1)
fi
[ -z "$RELEASE_NOTES" ] && RELEASE_NOTES="- Çeşitli iyileştirmeler ve hata düzeltmeleri."
echo "[RELEASE NOTES]" >> "$LOG_FILE"
echo "$RELEASE_NOTES"  >> "$LOG_FILE"

# ── 4. Build öncesi disk kontrolü ve temizlik ────────────
cleanup_disk "pre_build"
check_disk 1500

# ── 4. Flutter build ──────────────────────────────────────
log INFO "Flutter bağımlılıkları yükleniyor..."
FLUTTER_DIR=$(dirname "$PUBSPEC")
cd "$FLUTTER_DIR"
flutter pub get 2>&1 | tee -a "$LOG_FILE"

log INFO "APK derleniyor (release)..."
FLUTTER_BUILD_START=$(date +%s)
flutter build apk --release 2>&1 | tee -a "$LOG_FILE"
FLUTTER_BUILD_END=$(date +%s)
BUILD_DURATION=$((FLUTTER_BUILD_END - FLUTTER_BUILD_START))

if [ ! -f "$APK_SOURCE" ]; then
  log ERROR "APK bulunamadı: $APK_SOURCE"
  error "APK bulunamadı"
fi

APK_SIZE=$(du -sh "$APK_SOURCE" | cut -f1)
log OK "APK derlendi — Boyut: $APK_SIZE — Süre: ${BUILD_DURATION}s"
echo "[BUILD_STATS] duration=${BUILD_DURATION}s size=${APK_SIZE}" >> "$LOG_FILE"

# ── 5. APK deposu ─────────────────────────────────────────
log INFO "APK deposu hazırlanıyor..."
if [ ! -d "$APK_REPO_DIR" ]; then
  git clone "$APK_REPO_URL" "$APK_REPO_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

cd "$APK_REPO_DIR"
git pull origin main 2>&1 | tee -a "$LOG_FILE"

mkdir -p "releases/$FOLDER_NAME"
cp "$APK_SOURCE" "releases/$FOLDER_NAME/$APK_FINAL_NAME"
mkdir -p releases/latest
cp "$APK_SOURCE" "releases/latest/app-release.apk"
cp "$APK_SOURCE" "releases/latest/$APK_FINAL_NAME"

# ── 6. Eski APK temizle ───────────────────────────────────
log INFO "Eski APK'lar temizleniyor (son $MAX_APK_KEEP tutulacak)..."
RELEASE_DIRS=($(ls -dt releases/v* 2>/dev/null || true))
TOTAL=${#RELEASE_DIRS[@]}
if [ "$TOTAL" -gt "$MAX_APK_KEEP" ]; then
  for i in $(seq $((MAX_APK_KEEP)) $((total - 1))); do
    DIR="${RELEASE_DIRS[$i]}"
    log WARN "Siliniyor: $DIR"
    rm -rf "$DIR"
    git rm -rf "$DIR" 2>/dev/null | tee -a "$LOG_FILE" || true
  done
fi

# ── 7. version.json ───────────────────────────────────────
log INFO "version.json güncelleniyor..."
APK_DOWNLOAD_URL="https://github.com/tarihcituranx/test/raw/main/releases/latest/app-release.apk"
cat > releases/version.json << JSON
{
  "latestVersion": "${VERSION_NAME}",
  "versionCode": ${NEW_CODE},
  "buildTag": "${BUILD_TAG}",
  "apkUrl": "${APK_DOWNLOAD_URL}",
  "releaseDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "releaseNotes": "${RELEASE_NOTES}",
  "buildDuration": "${BUILD_DURATION}s",
  "apkSize": "${APK_SIZE}",
  "minSupportedVersion": "1.0.0",
  "forceUpdate": false
}
JSON
log OK "version.json güncellendi"

# ── 8. APK repo push ──────────────────────────────────────
log INFO "APK deposu GitHub'a gönderiliyor..."
git add . 2>&1 | tee -a "$LOG_FILE"
git commit -m "release: ${BUILD_TAG} - $(date '+%d.%m.%Y %H:%M')" 2>&1 | tee -a "$LOG_FILE"
git push origin main 2>&1 | tee -a "$LOG_FILE"
log OK "APK deposu güncellendi"

# ── 9. Ana repo push ──────────────────────────────────────
log INFO "Ana repo GitHub'a gönderiliyor..."
cd "$MAIN_REPO"
git add . 2>&1 | tee -a "$LOG_FILE"
git commit -m "build: ${BUILD_TAG} - APK yayınlandı" 2>&1 | tee -a "$LOG_FILE"
git push origin main 2>&1 | tee -a "$LOG_FILE"
git tag -a "${BUILD_TAG}" -m "Sürüm ${BUILD_TAG}" 2>&1 | tee -a "$LOG_FILE"
git push origin --tags 2>&1 | tee -a "$LOG_FILE"
log OK "Ana repo güncellendi"

# ── 10. Analiz ────────────────────────────────────────────
log INFO "Proje analizi başlatılıyor..."
bash "$MAIN_REPO/scripts/project_map.sh" "$MAIN_REPO" 2>&1 | tee -a "$LOG_FILE"
bash "$MAIN_REPO/scripts/bug_scan.sh"    "$MAIN_REPO" 2>&1 | tee -a "$LOG_FILE"
log OK "Analiz tamamlandı"

# ── 11. Beyin güncelle ────────────────────────────────────
log INFO "Proje beyni güncelleniyor..."
python3 "$MAIN_REPO/scripts/brain_update.py" 2>&1 | tee -a "$LOG_FILE"
log OK "Beyin güncellendi"

# ── Eski logları temizle (son 10 log tutulsun) ────────────
LOG_COUNT=$(ls -1 "$LOG_DIR"/build_*.log 2>/dev/null | wc -l)
if [ "$LOG_COUNT" -gt 10 ]; then
  ls -1t "$LOG_DIR"/build_*.log | tail -n +11 | xargs rm -f
  log INFO "Eski loglar temizlendi (son 10 tutuldu)"
fi

# ── Log kapanış ───────────────────────────────────────────
{
  echo ""
  echo "════════════════════════════════════════════════"
  echo "  BUILD BAŞARILI ✅"
  echo "  Bitiş   : $(date '+%d.%m.%Y %H:%M:%S')"
  echo "  Süre    : ${BUILD_DURATION}s"
  echo "  APK     : $APK_SIZE"
  echo "════════════════════════════════════════════════"
} >> "$LOG_FILE"

# ── Özet ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            TAMAMLANDI! 🚀                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "📱 Sürüm    : ${CYAN}${BUILD_TAG}${NC}"
echo -e "📦 APK      : ${CYAN}${APK_SIZE}${NC}"
echo -e "⏱ Süre     : ${CYAN}${BUILD_DURATION}s${NC}"
echo -e "📂 Klasör   : ${CYAN}releases/${FOLDER_NAME}${NC}"
echo -e "🔗 İndir    : ${CYAN}${APK_DOWNLOAD_URL}${NC}"
echo -e "📋 Log      : ${CYAN}${LOG_FILE}${NC}"
echo ""

# Son 3 logu listele
echo -e "${BLUE}── Son Build Logları ──────────────────────${NC}"
ls -1t "$LOG_DIR"/*.log 2>/dev/null | head -5 | while read f; do
  SIZE=$(du -sh "$f" | cut -f1)
  NAME=$(basename "$f")
  # Hata logu mu?
  if [[ "$NAME" == ERROR_* ]]; then
    echo -e "  ${RED}❌ $NAME ($SIZE)${NC}"
  else
    echo -e "  ${GREEN}✅ $NAME ($SIZE)${NC}"
  fi
done
echo ""