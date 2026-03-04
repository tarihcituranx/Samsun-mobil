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

# ── CI mi yerel mi? ───────────────────────────────────────
IS_CI="${CI:-false}"   # GitHub Actions otomatik CI=true set eder

# ── Sabitler ──────────────────────────────────────────────
APK_REPO_URL_HTTPS="https://github.com/tarihcituranx/test"
APK_REPO_GIT="https://github.com/tarihcituranx/test.git"
MAX_APK_KEEP=3

# CI'da proje zaten checkout edilmiş olur
if [ "$IS_CI" = "true" ]; then
  PROJECT_DIR="$GITHUB_WORKSPACE"
  APK_REPO_DIR="$RUNNER_TEMP/apk-dist"
else
  PROJECT_DIR="$HOME/Samsun-mobil"
  APK_REPO_DIR="$HOME/apk-dist"
fi

PUBSPEC="$PROJECT_DIR/pubspec.yaml"
APK_SOURCE="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"

# ── Log sistemi ───────────────────────────────────────────
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
BUILD_START=$(date +"%Y%m%d_%H%M%S")
STEP_LOG=$(mktemp /tmp/build_XXXXXX.log)
LOG_FILE=""
BUILD_TAG=""

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
    ERROR)   echo -e "${RED}❌ $msg${NC}"; exit 1 ;;
  esac
}

# ── Hata yakalayıcı ───────────────────────────────────────
on_error() {
  local exit_code=$?
  local line_no=$1
  local ts=$(date +"%Y-%m-%d %H:%M:%S")
  local err_file="$LOG_DIR/ERROR_${BUILD_TAG:-unknown}_${BUILD_START}.log"

  {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  HATA RAPORU"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Zaman     : $ts"
    echo "  Sürüm     : ${BUILD_TAG:-bilinmiyor}"
    echo "  Exit kodu : $exit_code"
    echo "  Satır no  : $line_no"
    echo "  Flutter   : $(flutter --version 2>/dev/null | head -1 || echo 'bulunamadı')"
    echo "  Disk      : $(df -h $HOME | awk 'NR==2{print $3"/"$2" ("$5" dolu)"}')"
    echo ""
    echo "  Son 40 satır çıktı:"
    echo "  ─────────────────────────────────────────────"
    tail -40 "$STEP_LOG" 2>/dev/null || true
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  } > "$err_file"

  cp "$STEP_LOG" "$err_file" 2>/dev/null || true

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
  local reason="$1"
  log INFO "🧹 Disk temizliği başlatılıyor ($reason)..."
  local freed=0

  if [ -d "$HOME/.gradle/caches" ]; then
    local s=$(du -sm "$HOME/.gradle/caches" 2>/dev/null | cut -f1)
    rm -rf "$HOME/.gradle/caches"
    log OK "Gradle cache silindi (~${s}MB)"
    freed=$((freed + s))
  fi

  if [ -d "$PROJECT_DIR/build" ]; then
    local s=$(du -sm "$PROJECT_DIR/build" 2>/dev/null | cut -f1)
    flutter clean --suppress-analytics 2>/dev/null || rm -rf "$PROJECT_DIR/build"
    log OK "Flutter build temizlendi (~${s}MB)"
    freed=$((freed + s))
  fi

  rm -rf /tmp/cmdtools* /tmp/gradle* /tmp/flutter* /tmp/dart* /tmp/*.zip /tmp/*.apk 2>/dev/null || true
  log OK "/tmp temizlendi"

  if [ -d "$HOME/.pub-cache/hosted" ]; then
    local s=$(du -sm "$HOME/.pub-cache/hosted" 2>/dev/null | cut -f1)
    rm -rf "$HOME/.pub-cache/hosted"
    log OK "Pub cache temizlendi (~${s}MB)"
    freed=$((freed + s))
  fi

  rm -rf "$HOME/.android/cache" 2>/dev/null || true

  ls -1t "$LOG_DIR"/*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

  local free_after=$(df -k $HOME | awk 'NR==2 {print int($4/1024)}')
  log OK "Temizlik bitti — Boş: ${free_after}MB (~${freed}MB kazanıldı)"
}

# ── Disk kontrol ──────────────────────────────────────────
check_disk() {
  local min_mb="${1:-1500}"
  local free_mb=$(df -k $HOME | awk 'NR==2 {print int($4/1024)}')
  local used_pct=$(df $HOME | awk 'NR==2 {print int($5)}')
  log INFO "Disk: ${free_mb}MB boş (%${used_pct} dolu)"
  if [ "$free_mb" -lt "$min_mb" ]; then
    log WARN "Yetersiz disk! ${free_mb}MB < ${min_mb}MB — temizlik zorunlu"
    cleanup_disk "low_disk"
  fi
}

# ── Git token ayarla (CI için) ────────────────────────────
setup_git_auth() {
  if [ "$IS_CI" = "true" ] && [ -n "$APK_REPO_TOKEN" ]; then
    git config --global url."https://x-access-token:${APK_REPO_TOKEN}@github.com/".insteadOf "https://github.com/"
    log OK "Git kimlik doğrulaması ayarlandı"
  fi
  git config --global user.name  "${GIT_USER_NAME:-GitHub Actions}"
  git config --global user.email "${GIT_USER_EMAIL:-actions@github.com}"
}

# ════════════════════════════════════════════════
#  ANA AKIM
# ════════════════════════════════════════════════
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Samsun Mobil — Akıllı Build Sistemi   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

setup_git_auth

# ── 1. Repo hazırla (yerel modda klonla/güncelle) ─────────
if [ "$IS_CI" = "false" ]; then
  if [ -d "$PROJECT_DIR/.git" ]; then
    log INFO "Repo güncelleniyor..."
    git -C "$PROJECT_DIR" pull origin main >> "$STEP_LOG" 2>&1
    log OK "Repo güncellendi"
  else
    log INFO "Repo klonlanıyor..."
    git clone "https://github.com/tarihcituranx/Samsun-mobil.git" "$PROJECT_DIR" >> "$STEP_LOG" 2>&1
    log OK "Repo klonlandı"
  fi
fi

cd "$PROJECT_DIR"

# ── 2. Sürüm tespit ───────────────────────────────────────
log INFO "Sürüm tespit ediliyor..."
[ ! -f "$PUBSPEC" ] && PUBSPEC=$(find "$PROJECT_DIR" -name "pubspec.yaml" | head -1)

CURRENT_VERSION=$(grep "^version:" "$PUBSPEC" | awk '{print $2}' | tr -d '\r')
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)
[ -z "$VERSION_NAME" ] && VERSION_NAME="1.0.0" && VERSION_CODE="1"

NEW_CODE=$((VERSION_CODE + 1))
DATE=$(date +"%Y%m%d_%H%M")
BUILD_TAG="v${VERSION_NAME}+${NEW_CODE}"
FOLDER_NAME="v${VERSION_NAME}_build${NEW_CODE}_${DATE}"
APK_FINAL_NAME="samsun-mobil-${BUILD_TAG}.apk"

LOG_FILE="$LOG_DIR/build_${BUILD_TAG}_${BUILD_START}.log"
{
  echo "════════════════════════════════════════════════"
  echo "  Samsun Mobil — Build Log"
  echo "  Sürüm   : $BUILD_TAG"
  echo "  Başlangıç: $(date '+%d.%m.%Y %H:%M:%S')"
  echo "  CI      : $IS_CI"
  echo "  Flutter : $(flutter --version 2>/dev/null | head -1 || echo 'N/A')"
  echo "  Disk    : $(df -h $HOME | awk 'NR==2{print $3"/"$2" ("$5" dolu)"}')"
  echo "════════════════════════════════════════════════"
} > "$LOG_FILE"

cat "$STEP_LOG" >> "$LOG_FILE"
STEP_LOG="$LOG_FILE"

log INFO "Mevcut sürüm : $VERSION_NAME+$VERSION_CODE"
log INFO "Yeni build   : $BUILD_TAG"

# ── 3. pubspec güncelle ───────────────────────────────────
log INFO "pubspec.yaml güncelleniyor..."
sed -i "s/^version: .*/version: ${VERSION_NAME}+${NEW_CODE}/" "$PUBSPEC"
log OK "pubspec.yaml → version: ${VERSION_NAME}+${NEW_CODE}"

# ── 4. Sürüm notları ──────────────────────────────────────
log INFO "Sürüm notları oluşturuluyor..."

# CI'da commit mesajından al, yerel modda kullanıcıdan sor
if [ "$IS_CI" = "true" ]; then
  CHANGELOG="${COMMIT_MESSAGE:-Otomatik build - $BUILD_TAG}"
else
  echo -e "${CYAN}Bu sürüm için değişiklikleri yaz (Enter ile bitir):${NC}"
  read -r CHANGELOG
  [ -z "$CHANGELOG" ] && CHANGELOG="Hata düzeltmeleri ve iyileştirmeler"
fi

LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$LATEST_TAG" ]; then
  RELEASE_NOTES=$(git log --pretty=format:"- %s" 2>/dev/null || echo "- İlk sürüm")
else
  RELEASE_NOTES=$(git log "${LATEST_TAG}..HEAD" --pretty=format:"- %s" 2>/dev/null || echo "- Değişiklik yok")
fi
[ -z "$RELEASE_NOTES" ] && RELEASE_NOTES="- Çeşitli iyileştirmeler ve hata düzeltmeleri."
echo "$RELEASE_NOTES" >> "$LOG_FILE"

# ── 5. Disk kontrolü ──────────────────────────────────────
cleanup_disk "pre_build"
check_disk 1500

# ── 6. Flutter build ──────────────────────────────────────
log INFO "Flutter bağımlılıkları yükleniyor..."
flutter pub get 2>&1 | tee -a "$LOG_FILE"

log INFO "APK derleniyor (release)... ☕"
FLUTTER_BUILD_START=$(date +%s)
flutter build apk --release 2>&1 | tee -a "$LOG_FILE"
FLUTTER_BUILD_END=$(date +%s)
BUILD_DURATION=$((FLUTTER_BUILD_END - FLUTTER_BUILD_START))

[ ! -f "$APK_SOURCE" ] && log ERROR "APK bulunamadı: $APK_SOURCE"

APK_SIZE=$(du -sh "$APK_SOURCE" | cut -f1)
log OK "APK derlendi — Boyut: $APK_SIZE — Süre: ${BUILD_DURATION}s"

# ── 7. APK deposu hazırla ─────────────────────────────────
log INFO "APK deposu hazırlanıyor..."
if [ -d "$APK_REPO_DIR/.git" ]; then
  git -C "$APK_REPO_DIR" pull origin main 2>&1 | tee -a "$LOG_FILE"
else
  git clone "$APK_REPO_GIT" "$APK_REPO_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

cd "$APK_REPO_DIR"
mkdir -p "releases/$FOLDER_NAME" "releases/latest"

cp "$APK_SOURCE" "releases/$FOLDER_NAME/$APK_FINAL_NAME"
cp "$APK_SOURCE" "releases/latest/app-release.apk"
cp "$APK_SOURCE" "releases/latest/$APK_FINAL_NAME"

# ── 8. Eski APK temizle ───────────────────────────────────
log INFO "Eski APK'lar temizleniyor (son $MAX_APK_KEEP tutulacak)..."
RELEASE_DIRS=($(ls -dt releases/v* 2>/dev/null || true))
TOTAL=${#RELEASE_DIRS[@]}
if [ "$TOTAL" -gt "$MAX_APK_KEEP" ]; then
  for i in $(seq "$MAX_APK_KEEP" $((TOTAL - 1))); do
    log WARN "Siliniyor: ${RELEASE_DIRS[$i]}"
    git rm -rf "${RELEASE_DIRS[$i]}" 2>/dev/null || rm -rf "${RELEASE_DIRS[$i]}"
  done
fi

# ── 9. version.json ───────────────────────────────────────
log INFO "version.json güncelleniyor..."
APK_DOWNLOAD_URL="${APK_REPO_URL_HTTPS}/raw/main/releases/latest/app-release.apk"

cat > releases/version.json << JSON
{
  "latestVersion": "${VERSION_NAME}",
  "versionCode": ${NEW_CODE},
  "buildTag": "${BUILD_TAG}",
  "apkUrl": "${APK_DOWNLOAD_URL}",
  "releaseDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "changelog": "${CHANGELOG}",
  "releaseNotes": "${RELEASE_NOTES}",
  "buildDuration": "${BUILD_DURATION}s",
  "apkSize": "${APK_SIZE}",
  "minSupportedVersion": "1.0.0",
  "forceUpdate": false
}
JSON
log OK "version.json güncellendi"

# ── 10. APK repo push ─────────────────────────────────────
log INFO "APK deposu GitHub'a gönderiliyor..."
git add . 2>&1 | tee -a "$LOG_FILE"
git commit -m "release: ${BUILD_TAG} - $(date '+%d.%m.%Y %H:%M')" 2>&1 | tee -a "$LOG_FILE"
git push origin main 2>&1 | tee -a "$LOG_FILE"
log OK "APK deposu güncellendi"

# ── 11. Ana repo push ─────────────────────────────────────
log INFO "Ana repo GitHub'a gönderiliyor..."
cd "$PROJECT_DIR"
git add pubspec.yaml 2>&1 | tee -a "$LOG_FILE"
git commit -m "build: ${BUILD_TAG} - APK yayınlandı" 2>&1 | tee -a "$LOG_FILE"
git push origin main 2>&1 | tee -a "$LOG_FILE"
git tag -a "${BUILD_TAG}" -m "Sürüm ${BUILD_TAG}" 2>&1 | tee -a "$LOG_FILE"
git push origin --tags 2>&1 | tee -a "$LOG_FILE"
log OK "Ana repo güncellendi"

# ── 12. Ek scriptler (varsa çalıştır) ────────────────────
run_optional() {
  local script="$1"
  if [ -f "$PROJECT_DIR/scripts/$script" ]; then
    log INFO "$script çalıştırılıyor..."
    bash "$PROJECT_DIR/scripts/$script" "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE"
    log OK "$script tamamlandı"
  else
    log WARN "$script bulunamadı, atlanıyor"
  fi
}

run_optional "project_map.sh"
run_optional "bug_scan.sh"

if [ -f "$PROJECT_DIR/scripts/brain_update.py" ]; then
  log INFO "brain_update.py çalıştırılıyor..."
  python3 "$PROJECT_DIR/scripts/brain_update.py" 2>&1 | tee -a "$LOG_FILE"
  log OK "Beyin güncellendi"
fi

# ── 13. Log kapanış ───────────────────────────────────────
{
  echo ""
  echo "════════════════════════════════════════════════"
  echo "  BUILD BAŞARILI ✅"
  echo "  Bitiş   : $(date '+%d.%m.%Y %H:%M:%S')"
  echo "  Süre    : ${BUILD_DURATION}s"
  echo "  APK     : $APK_SIZE"
  echo "════════════════════════════════════════════════"
} >> "$LOG_FILE"

# ── 14. Eski logları temizle ──────────────────────────────
ls -1t "$LOG_DIR"/build_*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

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

echo -e "${BLUE}── Son Build Logları ──────────────────────${NC}"
ls -1t "$LOG_DIR"/*.log 2>/dev/null | head -5 | while read f; do
  SIZE=$(du -sh "$f" | cut -f1)
  NAME=$(basename "$f")
  if [[ "$NAME" == ERROR_* ]]; then
    echo -e "  ${RED}❌ $NAME ($SIZE)${NC}"
  else
    echo -e "  ${GREEN}✅ $NAME ($SIZE)${NC}"
  fi
done
echo ""
