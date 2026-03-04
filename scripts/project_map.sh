#!/bin/bash
# ============================================================
# Samsun Mobil — Proje Mimarisi Haritası + Alan Temizleyici
# Kullanım: bash project_map.sh [proje_yolu]
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}▶ $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $1${NC}"; }

# ── CI/Yerel ortam tespiti ────────────────────────────────
IS_CI="${CI:-false}"

# Proje dizini: argüman > CI workspace > yerel varsayılan
if [ -n "$1" ] && [ -d "$1" ]; then
  PROJECT_DIR="$1"
elif [ "$IS_CI" = "true" ] && [ -n "$GITHUB_WORKSPACE" ]; then
  PROJECT_DIR="$GITHUB_WORKSPACE"
else
  PROJECT_DIR="$HOME/Samsun-mobil"
fi

# APK deposu: CI'da RUNNER_TEMP, yerelde HOME
if [ "$IS_CI" = "true" ] && [ -n "$RUNNER_TEMP" ]; then
  APK_REPO_DIR="$RUNNER_TEMP/apk-dist"
else
  APK_REPO_DIR="$HOME/apk-dist"
fi

PUBSPEC=$(find "$PROJECT_DIR" -name "pubspec.yaml" | head -1)
[ -z "$PUBSPEC" ] && echo "pubspec.yaml bulunamadı" && exit 1
FLUTTER_DIR=$(dirname "$PUBSPEC")
DATE=$(date '+%d.%m.%Y %H:%M')

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Proje Haritası + Temizleyici           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ══════════════════════════════════════════════════════════
# BÖLÜM 1: TEMİZLİK
# ══════════════════════════════════════════════════════════
info "🧹 Eski derleme kalıntıları temizleniyor..."

freed=0

clean_and_count() {
  local path="$1"
  local label="$2"
  if [ -d "$path" ] || [ -f "$path" ]; then
    size=$(du -sk "$path" 2>/dev/null | awk '{print $1}')
    rm -rf "$path"
    freed=$((freed + size))
    echo -e "  ${RED}🗑  Silindi:${NC} $label (${size}KB)"
  fi
}

# Flutter build çıktıları
clean_and_count "$FLUTTER_DIR/build"                         "Flutter build/"
clean_and_count "$FLUTTER_DIR/.dart_tool"                    ".dart_tool/"
clean_and_count "$FLUTTER_DIR/.flutter-plugins-dependencies" ".flutter-plugins-dependencies"

# Android kalıntıları
clean_and_count "$FLUTTER_DIR/android/.gradle"               "android/.gradle"
clean_and_count "$FLUTTER_DIR/android/app/build"             "android/app/build/"
clean_and_count "$FLUTTER_DIR/android/build"                 "android/build/"

# iOS kalıntıları
clean_and_count "$FLUTTER_DIR/ios/build"                     "ios/build/"
clean_and_count "$FLUTTER_DIR/ios/Pods"                      "ios/Pods/"
clean_and_count "$FLUTTER_DIR/ios/.symlinks"                 "ios/.symlinks/"

# Geçici dosyalar
find "$FLUTTER_DIR" -name "*.g.dart.bak"       -delete 2>/dev/null || true
find "$FLUTTER_DIR" -name "*.freezed.dart.bak" -delete 2>/dev/null || true
find /tmp -name "flutter_*" -mtime +1 -delete  2>/dev/null || true
find /tmp -name "dart_*"    -mtime +1 -delete  2>/dev/null || true
find /tmp -name "gradle_*"  -mtime +1 -delete  2>/dev/null || true

# NOT: flutter pub cache clean KALDIRILDI — build öncesi temizlik
# build.sh zaten hallediyor, burada yapmak bir sonraki build'i yavaşlatır

# Eski APK kalıntıları (son 3 tutulur)
if [ -d "$APK_REPO_DIR/releases" ]; then
  DIRS=($(ls -dt "$APK_REPO_DIR/releases/v"* 2>/dev/null || true))
  if [ "${#DIRS[@]}" -gt 3 ]; then
    for i in $(seq 3 $((${#DIRS[@]}-1))); do
      size=$(du -sk "${DIRS[$i]}" 2>/dev/null | awk '{print $1}')
      rm -rf "${DIRS[$i]}"
      freed=$((freed + size))
      echo -e "  ${RED}🗑  Eski APK silindi:${NC} ${DIRS[$i]} (${size}KB)"
    done
  fi
fi

FREED_MB=$((freed / 1024))
success "Temizlik tamamlandı — yaklaşık ${FREED_MB}MB alan kazanıldı"

echo ""
echo -e "  💾 Mevcut disk durumu:"
df -h "$HOME" | tail -1 | awk '{printf "  Toplam: %s | Kullanılan: %s | Boş: %s (%s)\n",$2,$3,$4,$5}'

# ══════════════════════════════════════════════════════════
# BÖLÜM 2: PROJEYİ ANALİZ ET
# ══════════════════════════════════════════════════════════
echo ""
info "🔍 Proje yapısı analiz ediliyor..."

APP_VERSION=$(grep "^version:" "$PUBSPEC" | awk '{print $2}' | tr -d '\r')
VERSION_NAME=$(echo "$APP_VERSION" | cut -d'+' -f1)
LIB="$FLUTTER_DIR/lib"

declare -A CATEGORIES
declare -A CAT_FILES
declare -A CAT_LINES
declare -A CAT_DESC

detect_category() {
detect_category() {
  local file="$1"
  local dir=$(dirname "$file" | sed "s|$LIB/||")
  local base=$(basename "$file" .dart)

  if grep -q "class.*Screen\|class.*Page\|extends.*StatelessWidget\|extends.*StatefulWidget" "$file"; then
    if echo "$dir" | grep -qi "screen\|page\|view\|ui"; then
      echo "screens"
    elif grep -q "Dialog\|dialog\|BottomSheet\|bottomsheet" "$file"; then
      echo "widgets"
    else
      echo "screens"
    fi
  elif grep -q "class.*Widget\|extends.*StatelessWidget\|extends.*StatefulWidget" "$file"; then
    echo "widgets"
  elif grep -q "class.*Provider\|class.*Bloc\|class.*Cubit\|class.*Controller\|class.*ViewModel\|ChangeNotifier\|Riverpod" "$file"; then
    echo "state"
  elif grep -q "class.*Repository\|class.*Service\|http\|dio\|ApiClient\|Future.*fetch\|Future.*get" "$file"; then
    echo "services"
  elif grep -q "class.*Model\|fromJson\|toJson\|@JsonSerializable\|freezed" "$file"; then
    echo "models"
  elif grep -q "class.*Route\|GoRouter\|Navigator\|MaterialPageRoute" "$file"; then
    echo "routes"
  elif grep -q "ThemeData\|ColorScheme\|TextStyle\|AppColors\|AppTheme" "$file"; then
    echo "theme"
  elif grep -q "const\|final.*=\|static.*=" "$file"; then
    if echo "$base" | grep -qi "constant\|config\|env\|string"; then
      echo "constants"
    else
      echo "utils"
    fi
  elif grep -q "extension\|mixin\|typedef" "$file"; then
    echo "utils"
  elif echo "$dir" | grep -qi "util\|helper\|extension\|mixin"; then
    echo "utils"
  else
    echo "other"
  fi
}

CAT_DESC["screens"]="📱 Ekranlar (UI sayfaları)"
CAT_DESC["widgets"]="🧩 Widget'lar (tekrar kullanılabilir bileşenler)"
CAT_DESC["state"]="⚡ State Yönetimi (Provider/Bloc/Riverpod)"
CAT_DESC["services"]="🌐 Servisler (API, HTTP, veri katmanı)"
CAT_DESC["models"]="📦 Modeller (veri yapıları, JSON)"
CAT_DESC["routes"]="🗺️ Rotalar (navigasyon)"
CAT_DESC["theme"]="🎨 Tema (renkler, stiller)"
CAT_DESC["constants"]="🔧 Sabitler & Konfigürasyon"
CAT_DESC["utils"]="🛠️ Yardımcılar (extension, mixin, util)"
CAT_DESC["other"]="📄 Diğer"

while IFS= read -r file; do
  cat=$(detect_category "$file")
  lines=$(wc -l < "$file")
  CATEGORIES[$cat]=$((${CATEGORIES[$cat]:-0} + 1))
  CAT_LINES[$cat]=$((${CAT_LINES[$cat]:-0} + lines))
  CAT_FILES[$cat]="${CAT_FILES[$cat]}$(basename "$file" .dart), "
done < <(find "$LIB" -name "*.dart" 2>/dev/null)

DEPS_HTTP=$(grep -E "^\s+(http|dio|retrofit):" "$PUBSPEC" | head -5 | awk '{print $1}' | tr -d ':' | tr '\n' ', ')
DEPS_STATE=$(grep -E "^\s+(provider|riverpod|bloc|get|getx|mobx):" "$PUBSPEC" | head -5 | awk '{print $1}' | tr -d ':' | tr '\n' ', ')
DEPS_MAP=$(grep -E "^\s+(google_maps|flutter_map|mapbox):" "$PUBSPEC" | head -3 | awk '{print $1}' | tr -d ':' | tr '\n' ', ')
DEPS_STORAGE=$(grep -E "^\s+(hive|sqflite|shared_preferences|isar):" "$PUBSPEC" | head -3 | awk '{print $1}' | tr -d ':' | tr '\n' ', ')
DEPS_UTIL=$(grep -E "^\s+(intl|url_launcher|permission_handler|geolocator):" "$PUBSPEC" | head -5 | awk '{print $1}' | tr -d ':' | tr '\n' ', ')

# FIX: ** glob yerine find kullan (globstar gerektirmez)
STATE_LIB="Belirsiz"
[ -n "$DEPS_STATE" ] && STATE_LIB="$DEPS_STATE"
find "$LIB" -name "*.dart" | xargs grep -ql "ChangeNotifier\|Provider" 2>/dev/null && STATE_LIB="Provider/ChangeNotifier" || true
find "$LIB" -name "*.dart" | xargs grep -ql "Bloc\|Cubit"              2>/dev/null && STATE_LIB="BLoC/Cubit"             || true
find "$LIB" -name "*.dart" | xargs grep -ql "Riverpod\|ref\."          2>/dev/null && STATE_LIB="Riverpod"               || true

TOTAL_LINES=$(find "$LIB" -name "*.dart" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
TOTAL_FILES=$(find "$LIB" -name "*.dart" | wc -l)

# ══════════════════════════════════════════════════════════
# BÖLÜM 3: README'YE MİMARİ BÖLÜMÜ EKLE
# ══════════════════════════════════════════════════════════
info "📐 Mimari harita README'ye yazılıyor..."

README="$FLUTTER_DIR/README.md"
ARCH_SECTION=$(cat << ARCH

---

## 🏗️ Proje Mimarisi

> Otomatik analiz ile oluşturuldu — $DATE

### 📊 Genel Bakış

\`\`\`
Samsun Ulaşım Sistemi v${VERSION_NAME}
├── 📱 Flutter Mobil Uygulama
│   ├── lib/                    ($TOTAL_FILES dosya, $TOTAL_LINES satır)
$(for cat in screens widgets state services models routes theme constants utils other; do
  count=${CATEGORIES[$cat]:-0}
  [ "$count" -gt 0 ] && printf "│   │   ├── %-20s (%d dosya, %d satır)\n" "${cat}/" "$count" "${CAT_LINES[$cat]:-0}"
done)
│   │   └── main.dart
│   ├── android/                (Native Android katmanı)
│   ├── ios/                    (Native iOS katmanı)
│   └── assets/                 (Görseller, fontlar, veriler)
├── 📡 API Katmanı
│   └── docs/openapi.yaml       (REST API şeması)
└── 📦 Dağıtım
    └── releases/               (Versiyonlu APK arşivi)
\`\`\`

### 🧩 Katman Sorumluluğu

| Katman | Klasör | Görev | Dosya Sayısı |
|--------|--------|-------|-------------|
$(for cat in screens widgets state services models routes theme constants utils; do
  count=${CATEGORIES[$cat]:-0}
  [ "$count" -gt 0 ] && echo "| ${CAT_DESC[$cat]} | \`lib/$cat/\` | - | $count |"
done)

### 📦 Bağımlılık Haritası

\`\`\`
┌─────────────────────────────────────────────┐
│          KULLANICI ARAYÜZÜ (UI)             │
│  Screens → Widgets → Theme                  │
└──────────────────┬──────────────────────────┘
                   │ State Yönetimi
                   │ (${STATE_LIB})
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
\`\`\`

### 🔌 Kullanılan Paket Kategorileri

| Kategori | Paketler |
|----------|----------|
| 🌐 HTTP / API | ${DEPS_HTTP:-"http, dio"} |
| ⚡ State | ${DEPS_STATE:-"$STATE_LIB"} |
| 🗺️ Harita | ${DEPS_MAP:-"google_maps_flutter"} |
| 💾 Depolama | ${DEPS_STORAGE:-"shared_preferences"} |
| 🛠️ Yardımcılar | ${DEPS_UTIL:-"intl, url_launcher"} |

### 🔄 Veri Akışı

\`\`\`
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
\`\`\`

### 📈 Kod İstatistikleri

| Metrik | Değer |
|--------|-------|
| Toplam Dart dosyası | $TOTAL_FILES |
| Toplam satır | $TOTAL_LINES |
$(for cat in screens widgets state services models utils; do
  count=${CATEGORIES[$cat]:-0}
  [ "$count" -gt 0 ] && echo "| ${CAT_DESC[$cat]} | $count dosya |"
done)

---
ARCH
)

# README'deki eski mimari bölümü varsa sil, yenisini ekle
if grep -q "## 🏗️ Proje Mimarisi" "$README" 2>/dev/null; then
  python3 - << PYEOF
content = open("$README", encoding="utf-8").read()
start = content.find("## 🏗️ Proje Mimarisi")
end   = content.find("\n---\n", start + 10)
if start != -1 and end != -1:
    new = content[:start] + content[end+5:]
    open("$README", "w", encoding="utf-8").write(new)
PYEOF
fi

echo "$ARCH_SECTION" >> "$README"
success "README.md mimari bölümü güncellendi"

# ── Git push ──────────────────────────────────────────────
info "Değişiklikler kaydediliyor..."
cd "$FLUTTER_DIR"
git add README.md 2>/dev/null || true
if git diff --cached --quiet; then
  warn "README değişmedi, commit atlandı"
else
  git commit -m "docs: Proje mimari haritası güncellendi — v${VERSION_NAME}"
  git push origin main
  success "GitHub'a gönderildi"
fi

# ── Son özet ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         TAMAMLANDI! 🚀                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  🧹 Temizlenen alan : ${CYAN}~${FREED_MB}MB${NC}"
echo -e "  📁 Toplam dosya    : ${CYAN}${TOTAL_FILES} Dart${NC}"
echo -e "  📏 Toplam satır    : ${CYAN}${TOTAL_LINES}${NC}"
echo -e "  📖 README          : ${CYAN}$README${NC}"
echo ""
echo -e "  ${BOLD}Tespit edilen katmanlar:${NC}"
for cat in screens widgets state services models routes theme constants utils; do
  count=${CATEGORIES[$cat]:-0}
  [ "$count" -gt 0 ] && echo -e "  ${GREEN}✓${NC} ${CAT_DESC[$cat]} → $count dosya"
done
echo ""
