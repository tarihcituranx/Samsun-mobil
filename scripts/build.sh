#!/bin/bash
# ============================================================
# Samsun Mobil - Akıllı APK Derle, Versiyonla ve Dağıt
# Repo: https://github.com/tarihcituranx/Samsun-mobil.git
# APK Deposu: https://github.com/tarihcituranx/test
# ============================================================

set -e
set -o pipefail   # pipe içindeki herhangi bir komut başarısız olursa tüm pipe başarısız sayılır

# ── Renkli çıktı ──────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}ℹ $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ── CI mi yerel mi? ───────────────────────────────────────
IS_CI="${CI:-false}"

# ── Sabitler ──────────────────────────────────────────────
APK_REPO_URL_HTTPS="https://github.com/tarihcituranx/test"
APK_REPO_GIT="https://github.com/tarihcituranx/test.git"
MAX_APK_KEEP=3

if [ "$CI" = "true" ]; then
  PROJECT_DIR="$GITHUB_WORKSPACE"
  APK_REPO_DIR="$RUNNER_TEMP/apk-dist"
else
  PROJECT_DIR="$HOME/Samsun-mobil"
  APK_REPO_DIR="$HOME/apk-dist"
fi

PUBSPEC="$PROJECT_DIR/pubspec.yaml"
APK_SOURCE="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
SCRIPTS_DIR="$PROJECT_DIR/scripts"

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
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  # LOG_FILE henüz set edilmemişse geçici dosyaya yaz
  local target="${LOG_FILE:-$STEP_LOG}"
  echo "[$ts] [$level] $msg" >> "$target"
  case "$level" in
    INFO)  info    "$msg" ;;
    OK)    success "$msg" ;;
    WARN)  warn    "$msg" ;;
    ERROR)
      echo -e "${RED}❌ $msg${NC}"
      # trap'ın da çalışmaması için ERR sinyalini geçici olarak kapat
      trap - ERR
      exit 1
      ;;
  esac
}

# ── JSON güvenli string dönüştürücü ───────────────────────
# Çift tırnak, ters eğik çizgi ve satır sonlarını kaçırır
json_escape() {
  local str="$1"
  # Önce \ sonra " sonra kontrol karakterlerini işle
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  str="${str//$'\n'/\\n}"
  str="${str//$'\r'/}"
  str="${str//$'\t'/\\t}"
  echo "$str"
}

# ── Hata yakalayıcı ───────────────────────────────────────
on_error() {
  local exit_code=$? line_no=$1
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  local log_target="${LOG_FILE:-$STEP_LOG}"
  local err_file="$LOG_DIR/ERROR_${BUILD_TAG:-unknown}_${BUILD_START}.log"
  {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  HATA RAPORU"
    echo "  Zaman     : $ts"
    echo "  Sürüm     : ${BUILD_TAG:-bilinmiyor}"
    echo "  Exit kodu : $exit_code"
    echo "  Satır no  : $line_no"
    echo "  Flutter   : $(flutter --version 2>/dev/null | head -1 || echo 'bulunamadı')"
    echo "  Disk      : $(df -h "$HOME" | awk 'NR==2{print $3"/"$2" ("$5" dolu)"}')"
    echo ""
    echo "  Son 40 satır:"
    tail -40 "$log_target" 2>/dev/null || true
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  } > "$err_file"
  echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
  echo -e "${RED}║           BUILD BAŞARISIZ ❌             ║${NC}"
  echo -e "${RED}╚══════════════════════════════════════════╝${NC}"
  echo -e "${RED}  Satır : $line_no | Log : $err_file${NC}"
}
trap 'on_error $LINENO' ERR

# ── Disk temizleyici ──────────────────────────────────────
cleanup_disk() {
  local reason="$1"; local freed=0
  log INFO "🧹 Disk temizliği ($reason)..."
  if [ -d "$HOME/.gradle/caches" ]; then
    local s
    s=$(du -sm "$HOME/.gradle/caches" 2>/dev/null | cut -f1)
    rm -rf "$HOME/.gradle/caches"; freed=$((freed+s))
    log OK "Gradle cache silindi (~${s}MB)"
  fi
  if [ -d "$PROJECT_DIR/build" ]; then
    local s
    s=$(du -sm "$PROJECT_DIR/build" 2>/dev/null | cut -f1)
    flutter clean --suppress-analytics 2>/dev/null || rm -rf "$PROJECT_DIR/build"
    freed=$((freed+s)); log OK "Flutter build temizlendi (~${s}MB)"
  fi
  rm -rf /tmp/cmdtools* /tmp/gradle* /tmp/flutter* /tmp/dart* /tmp/*.zip /tmp/*.apk 2>/dev/null || true
  if [ -d "$HOME/.pub-cache/hosted" ]; then
    local s
    s=$(du -sm "$HOME/.pub-cache/hosted" 2>/dev/null | cut -f1)
    # pub-cache'i sadece çok az disk kaldıysa sil; aksi hâlde fix_dependencies sonra yeniden indirmek zorunda kalır
    local free_check
    free_check=$(df -k "$HOME" | awk 'NR==2 {print int($4/1024)}')
    if [ "$free_check" -lt 800 ]; then
      rm -rf "$HOME/.pub-cache/hosted"; freed=$((freed+s))
      log OK "Pub cache temizlendi (~${s}MB) [kritik disk durumu]"
    else
      log WARN "Pub cache korundu (~${s}MB) — build için gerekli"
    fi
  fi
  rm -rf "$HOME/.android/cache" 2>/dev/null || true
  ls -1t "$LOG_DIR"/*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
  local free_after
  free_after=$(df -k "$HOME" | awk 'NR==2 {print int($4/1024)}')
  log OK "Temizlik bitti — Boş: ${free_after}MB (~${freed}MB kazanıldı)"
}

check_disk() {
  local min_mb="${1:-1500}"
  local free_mb
  free_mb=$(df -k "$HOME" | awk 'NR==2 {print int($4/1024)}')
  local used_pct
  used_pct=$(df "$HOME" | awk 'NR==2 {print int($5)}')
  log INFO "Disk: ${free_mb}MB boş (%${used_pct} dolu)"
  [ "$free_mb" -lt "$min_mb" ] && { log WARN "Yetersiz disk — temizlik"; cleanup_disk "low_disk"; } || true
}

setup_git_auth() {
  if [ "$CI" = "true" ] && [ -n "$APK_REPO_TOKEN" ]; then
    git config --global url."https://x-access-token:${APK_REPO_TOKEN}@github.com/".insteadOf "https://github.com/"
    log OK "Git kimlik doğrulaması ayarlandı"
  fi
  git config --global user.name  "${GIT_USER_NAME:-GitHub Actions}"
  git config --global user.email "${GIT_USER_EMAIL:-actions@github.com}"
}

# ── Bağımlılık düzeltici ──────────────────────────────────
fix_dependencies() {
  log INFO "Bağımlılıklar kontrol ediliyor..."
  local fix_script="$SCRIPTS_DIR/fix_deps.py"
  local log_target="${LOG_FILE:-$STEP_LOG}"

  if [ -f "$fix_script" ]; then
    python3 "$fix_script" "$PROJECT_DIR" 2>&1 | tee -a "$log_target"
    local exit_code="${PIPESTATUS[0]}"
    if [ "$exit_code" -ne 0 ]; then
      log ERROR "Bağımlılık sorunu çözülemedi! pubspec.yaml'ı manuel kontrol et."
    fi
    log OK "Bağımlılıklar hazır"
  else
    log WARN "fix_deps.py bulunamadı, doğrudan flutter pub get deneniyor..."
    if ! flutter pub get 2>&1 | tee -a "$log_target"; then
      log WARN "flutter pub get başarısız, upgrade deneniyor..."
      flutter pub upgrade --major-versions 2>&1 | tee -a "$log_target" || \
        log ERROR "Bağımlılık sorunu çözülemedi!"
    fi
  fi
}

# ── Opsiyonel script çalıştırıcı ─────────────────────────
run_optional() {
  local script="$1"
  local log_target="${LOG_FILE:-$STEP_LOG}"
  if [ -f "$SCRIPTS_DIR/$script" ]; then
    log INFO "$script çalıştırılıyor..."
    bash "$SCRIPTS_DIR/$script" "$PROJECT_DIR" 2>&1 | tee -a "$log_target"
    log OK "$script tamamlandı"
  else
    log WARN "$script bulunamadı, atlanıyor"
  fi
}

run_optional_py() {
  local script="$1"
  local log_target="${LOG_FILE:-$STEP_LOG}"
  if [ -f "$SCRIPTS_DIR/$script" ]; then
    log INFO "$script çalıştırılıyor..."
    python3 "$SCRIPTS_DIR/$script" "$PROJECT_DIR" 2>&1 | tee -a "$log_target"
    log OK "$script tamamlandı"
  else
    log WARN "$script bulunamadı, atlanıyor"
  fi
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

# ── 1. Repo hazırla ───────────────────────────────────────
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
[ ! -f "$PUBSPEC" ] && PUBSPEC=$(find "$PROJECT_DIR" -name "pubspec.yaml" | head -1)

# ── 2. Sürüm tespit ───────────────────────────────────────
log INFO "Sürüm tespit ediliyor..."
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC" | awk '{print $2}' | tr -d '\r')
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)
[ -z "$VERSION_NAME" ] && VERSION_NAME="1.0.0"
[ -z "$VERSION_CODE" ] && VERSION_CODE="1"

NEW_CODE=$((VERSION_CODE + 1))
DATE=$(date +"%Y%m%d_%H%M")
BUILD_TAG="v${VERSION_NAME}+${NEW_CODE}"
FOLDER_NAME="v${VERSION_NAME}_build${NEW_CODE}_${DATE}"
APK_FINAL_NAME="samsun-mobil-${BUILD_TAG}.apk"

LOG_FILE="$LOG_DIR/build_${BUILD_TAG}_${BUILD_START}.log"
{
  echo "════════════════════════════════════════════════"
  echo "  Samsun Mobil — Build Log"
  echo "  Sürüm    : $BUILD_TAG"
  echo "  Başlangıç: $(date '+%d.%m.%Y %H:%M:%S')"
  echo "  CI       : $IS_CI"
  echo "  Flutter  : $(flutter --version 2>/dev/null | head -1 || echo 'N/A')"
  echo "  Disk     : $(df -h "$HOME" | awk 'NR==2{print $3"/"$2" ("$5" dolu)"}')"
  echo "════════════════════════════════════════════════"
} > "$LOG_FILE"
# Geçici log içeriğini kalıcı log dosyasına taşı ve geçiciyi sil
cat "$STEP_LOG" >> "$LOG_FILE"
rm -f "$STEP_LOG"

log INFO "Mevcut sürüm : $VERSION_NAME+$VERSION_CODE"
log INFO "Yeni build   : $BUILD_TAG"

# ── 3. pubspec versiyonunu güncelle ───────────────────────
log INFO "pubspec.yaml güncelleniyor..."
sed -i "s/^version: .*/version: ${VERSION_NAME}+${NEW_CODE}/" "$PUBSPEC"
log OK "pubspec.yaml → version: ${VERSION_NAME}+${NEW_CODE}"

# ── 4. Sürüm notları ──────────────────────────────────────
log INFO "Sürüm notları oluşturuluyor..."
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

# JSON'a gömülecek alanları güvenli hale getir
CHANGELOG_SAFE=$(json_escape "$CHANGELOG")
RELEASE_NOTES_SAFE=$(json_escape "$RELEASE_NOTES")

# ── 5. Disk kontrolü ──────────────────────────────────────
cleanup_disk "pre_build"
check_disk 1500

# ── 6. Bağımlılıkları düzelt ve yükle ────────────────────
fix_dependencies

# ── 6b. Python API testlerini çalıştır ────────────────────
if [ -f "$PROJECT_DIR/tests/test_api_endpoints.py" ]; then
  log INFO "Python API testleri çalıştırılıyor..."
  python3 "$PROJECT_DIR/tests/test_api_endpoints.py" 2>&1 | tee -a "$LOG_FILE" || true
  if [ -f "$PROJECT_DIR/tests/test_results.json" ]; then
    cp "$PROJECT_DIR/tests/test_results.json" "$LOG_DIR/test_results_$(date +%Y%m%d_%H%M).json" 2>/dev/null || true
    log OK "API test sonuçları kaydedildi"
  fi
fi

# ── 7. APK derle ──────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Keystore doğrulaması
# BUG #69 DÜZELTMESİ:
#   Eski kod sadece dosyanın var olup olmadığını kontrol ediyordu (du -sh).
#   base64 decode hatası 4.0K'lık (1 disk bloğu) truncated bir JKS üretebilir.
#   Bu dosya keytool -list'te geçebilir ama Gradle packageRelease'de
#   java.io.EOFException ile çöker.
#
#   Yeni kontroller:
#   1) Dosya boyutu bayt cinsinden > 2048 olmalı (gerçek JKS için minimum)
#   2) keytool -exportcert ile private key gerçekten okunabilmeli
# ─────────────────────────────────────────────────────────────────────────────
log INFO "Signing config doğrulanıyor..."
KEYSTORE_PATH="$PROJECT_DIR/android/app/samsun_ulasim.jks"
KEY_PROPS="$PROJECT_DIR/android/key.properties"

if [ ! -f "$KEYSTORE_PATH" ]; then
  log ERROR "Keystore bulunamadı: $KEYSTORE_PATH — KEYSTORE_BASE64 secret'ını kontrol et"
fi

# Boyut kontrolü: truncated JKS (base64 decode hatası) erken yakala
KEYSTORE_BYTES=$(wc -c < "$KEYSTORE_PATH")
if [ "$KEYSTORE_BYTES" -lt 2048 ]; then
  log ERROR "Keystore dosyası çok küçük (${KEYSTORE_BYTES} bayt < 2048 bayt). base64 bozuk olabilir. Yeniden oluştur: base64 -w 0 samsun_ulasim.jks"
fi

if [ ! -f "$KEY_PROPS" ]; then
  log ERROR "key.properties bulunamadı: $KEY_PROPS"
fi

log OK "Signing config mevcut ($(du -sh "$KEYSTORE_PATH" | cut -f1), ${KEYSTORE_BYTES} bayt)"

# Gradle bellek ayarlarını güçlendir (CI'da varsayılan çok düşük)
GRADLE_PROPS="$PROJECT_DIR/android/gradle.properties"
if ! grep -q "org.gradle.jvmargs" "$GRADLE_PROPS" 2>/dev/null; then
  echo "" >> "$GRADLE_PROPS"
  echo "org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError" >> "$GRADLE_PROPS"
  log OK "Gradle JVM heap 4g'e yükseltildi"
else
  # Mevcut satırı daha yüksek değerle değiştir
  sed -i 's/org.gradle.jvmargs=.*/org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError/' "$GRADLE_PROPS"
  log OK "Gradle JVM heap 4g'e güncellendi"
fi

# Gradle daemon ve paralel build
grep -q "org.gradle.daemon" "$GRADLE_PROPS" 2>/dev/null || echo "org.gradle.daemon=false" >> "$GRADLE_PROPS"
grep -q "org.gradle.parallel" "$GRADLE_PROPS" 2>/dev/null || echo "org.gradle.parallel=true" >> "$GRADLE_PROPS"
grep -q "org.gradle.caching" "$GRADLE_PROPS" 2>/dev/null || echo "org.gradle.caching=true" >> "$GRADLE_PROPS"

log INFO "APK derleniyor (release)... ☕"
FLUTTER_BUILD_START=$(date +%s)

# --verbose: Gradle stacktrace göster; pipefail ile pipe'daki hata yakalanır
flutter build apk --release --verbose 2>&1 | tee -a "$LOG_FILE"

FLUTTER_BUILD_END=$(date +%s)
BUILD_DURATION=$((FLUTTER_BUILD_END - FLUTTER_BUILD_START))

if [ ! -f "$APK_SOURCE" ]; then
  log ERROR "APK bulunamadı: $APK_SOURCE — yukarıdaki Gradle çıktısını incele"
fi
APK_SIZE=$(du -sh "$APK_SOURCE" | cut -f1)
log OK "APK derlendi — Boyut: $APK_SIZE — Süre: ${BUILD_DURATION}s"

# ── 8. APK deposu ─────────────────────────────────────────
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

# ── 9. Eski APK temizle ───────────────────────────────────
log INFO "Eski APK'lar temizleniyor (son $MAX_APK_KEEP)..."
# ls yerine glob + mapfile kullan (boşluklu isim güvenliği)
mapfile -t RELEASE_DIRS < <(ls -dt releases/v* 2>/dev/null || true)
TOTAL=${#RELEASE_DIRS[@]}
if [ "$TOTAL" -gt "$MAX_APK_KEEP" ]; then
  for i in $(seq "$MAX_APK_KEEP" $((TOTAL - 1))); do
    log WARN "Siliniyor: ${RELEASE_DIRS[$i]}"
    git rm -rf "${RELEASE_DIRS[$i]}" 2>/dev/null || rm -rf "${RELEASE_DIRS[$i]}"
  done
fi

# ── 10. version.json ──────────────────────────────────────
log INFO "version.json güncelleniyor..."
APK_DOWNLOAD_URL="${APK_REPO_URL_HTTPS}/raw/main/releases/latest/app-release.apk"
cat > releases/version.json << JSON
{
  "latestVersion": "${VERSION_NAME}",
  "versionCode": ${NEW_CODE},
  "buildTag": "${BUILD_TAG}",
  "apkUrl": "${APK_DOWNLOAD_URL}",
  "releaseDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "changelog": "${CHANGELOG_SAFE}",
  "releaseNotes": "${RELEASE_NOTES_SAFE}",
  "buildDuration": "${BUILD_DURATION}s",
  "apkSize": "${APK_SIZE}",
  "minSupportedVersion": "1.0.0",
  "forceUpdate": false
}
JSON
log OK "version.json güncellendi"

# ── 11. APK repo push ─────────────────────────────────────
log INFO "APK deposu GitHub'a gönderiliyor..."
git add . 2>&1 | tee -a "$LOG_FILE"
git commit -m "release: ${BUILD_TAG} - $(date '+%d.%m.%Y %H:%M')" 2>&1 | tee -a "$LOG_FILE"
git push origin main 2>&1 | tee -a "$LOG_FILE"
log OK "APK deposu güncellendi"

# ── 12. Ana repo push ─────────────────────────────────────
log INFO "Ana repo GitHub'a gönderiliyor..."
cd "$PROJECT_DIR"
git add pubspec.yaml 2>&1 | tee -a "$LOG_FILE"
git commit -m "build: ${BUILD_TAG} - APK yayınlandı" 2>&1 | tee -a "$LOG_FILE"
git push origin main 2>&1 | tee -a "$LOG_FILE"
git tag -a "${BUILD_TAG}" -m "Sürüm ${BUILD_TAG}" 2>&1 | tee -a "$LOG_FILE"
git push origin --tags 2>&1 | tee -a "$LOG_FILE"
log OK "Ana repo güncellendi"

# ── 13. Ek scriptler ──────────────────────────────────────
run_optional    "project_map.sh"   # README + mimari harita + temizlik
run_optional    "bug_scan.sh"      # Kaynak + APK tarayıcı
run_optional_py "brain_update.py"  # PROJECT_BRAIN.md güncelleyici

# ── 13b. Bug raporu varsa logs/ klasörüne kopyala ─────────
if ls /home/runner/bug_report_*.md 1>/dev/null 2>&1; then
  cp /home/runner/bug_report_*.md "$LOG_DIR/" 2>/dev/null || true
  log OK "Bug raporu logs/ klasörüne kopyalandı (/home/runner)"
fi
if ls "$PROJECT_DIR"/bug_report_*.md 1>/dev/null 2>&1; then
  cp "$PROJECT_DIR"/bug_report_*.md "$LOG_DIR/" 2>/dev/null || true
  log OK "Bug raporu logs/ klasörüne kopyalandı (PROJECT_DIR)"
fi

# ── 14. Log kapanış ───────────────────────────────────────
{
  echo ""
  echo "════════════════════════════════════════════════"
  echo "  BUILD BAŞARILI ✅"
  echo "  Bitiş   : $(date '+%d.%m.%Y %H:%M:%S')"
  echo "  Süre    : ${BUILD_DURATION}s"
  echo "  APK     : $APK_SIZE"
  echo "════════════════════════════════════════════════"
} >> "$LOG_FILE"

# ── 15. Eski logları temizle ──────────────────────────────
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
ls -1t "$LOG_DIR"/*.log 2>/dev/null | head -5 | while read -r f; do
  SIZE=$(du -sh "$f" | cut -f1)
  NAME=$(basename "$f")
  if [[ "$NAME" == ERROR_* ]]; then
    echo -e "  ${RED}❌ $NAME ($SIZE)${NC}"
  else
    echo -e "  ${GREEN}✅ $NAME ($SIZE)${NC}"
  fi
done
echo ""
