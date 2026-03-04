#!/bin/bash
# ============================================================
# Samsun Mobil — Uygulama Adı & Paket Adı Güncelleyici
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}▶ $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
fail()    { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ── Yeni değerler ─────────────────────────────────────────
NEW_APP_NAME="Samsun Ulaşım Sistemi"
NEW_PACKAGE="com.tarihcituranx.samsun_ulasim"
OLD_PACKAGE="com.example.samsun_transit"   # mevcut paket adı

# ── Proje klasörünü bul ───────────────────────────────────
PROJECT_DIR="${1:-$HOME/Samsun-mobil}"
PUBSPEC=$(find "$PROJECT_DIR" -name "pubspec.yaml" | head -1)
[ -z "$PUBSPEC" ] && fail "pubspec.yaml bulunamadı: $PROJECT_DIR"
FLUTTER_DIR=$(dirname "$PUBSPEC")

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Uygulama Adı & Paket Güncelleyici   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "📱 Yeni ad     : ${GREEN}$NEW_APP_NAME${NC}"
echo -e "📦 Yeni paket  : ${GREEN}$NEW_PACKAGE${NC}"
echo -e "📂 Proje       : $FLUTTER_DIR"
echo ""

# ── 1. pubspec.yaml — uygulama adı ───────────────────────
info "pubspec.yaml güncelleniyor..."
sed -i "s/^name: .*/name: samsun_ulasim_sistemi/" "$PUBSPEC"
success "pubspec.yaml güncellendi"

# ── 2. AndroidManifest.xml — label + package ─────────────
info "AndroidManifest.xml güncelleniyor..."
MANIFEST="$FLUTTER_DIR/android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  sed -i "s/android:label=\"[^\"]*\"/android:label=\"$NEW_APP_NAME\"/" "$MANIFEST"
  sed -i "s/package=\"[^\"]*\"/package=\"$NEW_PACKAGE\"/" "$MANIFEST"
  success "AndroidManifest.xml güncellendi"
else
  echo "⚠ AndroidManifest.xml bulunamadı: $MANIFEST"
fi

# Debug manifest da güncelle
DEBUG_MANIFEST="$FLUTTER_DIR/android/app/src/debug/AndroidManifest.xml"
[ -f "$DEBUG_MANIFEST" ] && \
  sed -i "s/package=\"[^\"]*\"/package=\"$NEW_PACKAGE\"/" "$DEBUG_MANIFEST"

PROFILE_MANIFEST="$FLUTTER_DIR/android/app/src/profile/AndroidManifest.xml"
[ -f "$PROFILE_MANIFEST" ] && \
  sed -i "s/package=\"[^\"]*\"/package=\"$NEW_PACKAGE\"/" "$PROFILE_MANIFEST"

# ── 3. build.gradle.kts — namespace + applicationId ──────
info "build.gradle.kts güncelleniyor..."
GRADLE="$FLUTTER_DIR/android/app/build.gradle.kts"
GRADLE_OLD="$FLUTTER_DIR/android/app/build.gradle"

update_gradle() {
  local FILE="$1"
  if [ -f "$FILE" ]; then
    sed -i "s/namespace = \"[^\"]*\"/namespace = \"$NEW_PACKAGE\"/" "$FILE"
    sed -i "s/applicationId = \"[^\"]*\"/applicationId = \"$NEW_PACKAGE\"/" "$FILE"
    sed -i 's/namespace "[^"]*"/namespace "'"$NEW_PACKAGE"'"/' "$FILE"
    sed -i 's/applicationId "[^"]*"/applicationId "'"$NEW_PACKAGE"'"/' "$FILE"
    success "$FILE güncellendi"
  fi
}

update_gradle "$GRADLE"
update_gradle "$GRADLE_OLD"

# ── 4. Kotlin/Java klasör yapısını yeniden oluştur ───────
info "Paket klasör yapısı yeniden oluşturuluyor..."

OLD_PATH=$(echo "$OLD_PACKAGE" | tr '.' '/')
NEW_PATH=$(echo "$NEW_PACKAGE" | tr '.' '/')

MAIN_SRC="$FLUTTER_DIR/android/app/src/main/kotlin"
[ ! -d "$MAIN_SRC" ] && MAIN_SRC="$FLUTTER_DIR/android/app/src/main/java"

if [ -d "$MAIN_SRC" ]; then
  OLD_DIR="$MAIN_SRC/$OLD_PATH"
  NEW_DIR="$MAIN_SRC/$NEW_PATH"

  if [ -d "$OLD_DIR" ]; then
    mkdir -p "$NEW_DIR"
    cp -r "$OLD_DIR/"* "$NEW_DIR/" 2>/dev/null || true

    # MainActivity içindeki package adını güncelle
    find "$NEW_DIR" -name "*.kt" -o -name "*.java" | while read f; do
      sed -i "s/package $OLD_PACKAGE/package $NEW_PACKAGE/g" "$f"
    done

    success "Kotlin/Java paket yapısı güncellendi"
    echo "   $OLD_DIR → $NEW_DIR"
  else
    info "Eski klasör bulunamadı, yeni yapı oluşturuluyor: $NEW_DIR"
    mkdir -p "$NEW_DIR"
    # MainActivity.kt yoksa oluştur
    if [ ! -f "$NEW_DIR/MainActivity.kt" ]; then
      cat > "$NEW_DIR/MainActivity.kt" << KOTLIN
package $NEW_PACKAGE

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
KOTLIN
      success "MainActivity.kt oluşturuldu"
    fi
  fi
fi

# ── 5. strings.xml — uygulama adı ────────────────────────
info "strings.xml güncelleniyor..."
STRINGS="$FLUTTER_DIR/android/app/src/main/res/values/strings.xml"
if [ -f "$STRINGS" ]; then
  sed -i "s|<string name=\"app_name\">.*</string>|<string name=\"app_name\">$NEW_APP_NAME</string>|" "$STRINGS"
  success "strings.xml güncellendi"
else
  # Oluştur
  mkdir -p "$(dirname "$STRINGS")"
  cat > "$STRINGS" << XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$NEW_APP_NAME</string>
</resources>
XML
  success "strings.xml oluşturuldu"
fi

# ── 6. iOS — info.plist (varsa) ──────────────────────────
PLIST="$FLUTTER_DIR/ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  info "iOS Info.plist güncelleniyor..."
  sed -i "s|<string>samsun_transit</string>|<string>$NEW_APP_NAME</string>|g" "$PLIST"
  success "Info.plist güncellendi"
fi

# ── 7. Temizle ───────────────────────────────────────────
info "Proje temizleniyor..."
cd "$FLUTTER_DIR"
flutter clean
flutter pub get
success "Temizleme tamamlandı"

# ── Özet ─────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          GÜNCELLEME TAMAMLANDI! ✅       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "📱 Uygulama adı : ${CYAN}$NEW_APP_NAME${NC}"
echo -e "📦 Paket adı    : ${CYAN}$NEW_PACKAGE${NC}"
echo ""
echo -e "${YELLOW}⚠️  Sonraki adım: flutter build apk --release${NC}"
echo ""
