#!/bin/bash
set -e

ANDROID_SDK_ROOT="$HOME/android-sdk"
CMDLINE_TOOLS="$ANDROID_SDK_ROOT/cmdline-tools/latest"
SDKMANAGER="$CMDLINE_TOOLS/bin/sdkmanager"

echo "=== Android SDK Kurulum Scripti ==="
echo ""

# 1. Disk kontrolü
FREE=$(df -k $HOME | awk \'NR==2 {print $4}\')
echo "[1/6] Disk kontrolü: ${FREE}KB boş alan"
if [ "$FREE" -lt 2097152 ]; then
  echo "UYARI: 2GB\'dan az yer var, temizlik yapılıyor..."
  rm -rf ~/.gradle/caches 2>/dev/null && echo "  .gradle/caches temizlendi"
  flutter clean 2>/dev/null && echo "  flutter clean yapıldı" || true
  FREE=$(df -k $HOME | awk \'NR==2 {print $4}\')
  echo "  Temizlik sonrası: ${FREE}KB boş"
fi

# 2. Eski kurulumu temizle
echo "[2/6] Eski kurulum temizleniyor..."
rm -rf "$ANDROID_SDK_ROOT" /tmp/cmdtools.zip /tmp/cmdtools-tmp 2>/dev/null || true

# 3. cmdline-tools indir
echo "[3/6] cmdline-tools indiriliyor..."
mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
curl -# -L \
  "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" \
  -o /tmp/cmdtools.zip

# 4. Zip\'i çıkar
echo "[4/6] Çıkartılıyor..."
mkdir -p /tmp/cmdtools-tmp
unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools-tmp
mv /tmp/cmdtools-tmp/cmdline-tools "$CMDLINE_TOOLS"
rm -rf /tmp/cmdtools.zip /tmp/cmdtools-tmp
chmod +x "$CMDLINE_TOOLS/bin/"*
echo "  sdkmanager hazır: $SDKMANAGER"

# 5. Lisansları kabul et
echo "[5/6] Lisanslar kabul ediliyor..."
export ANDROID_SDK_ROOT
export PATH="$CMDLINE_TOOLS/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
yes 2>/dev/null | "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" --licenses || true

# 6. Paketleri kur
echo "[6/6] SDK paketleri kuruluyor..."
"$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0"

# Flutter\'a tanıt
echo ""
echo "=== Flutter yapılandırılıyor ==="
flutter config --android-sdk "$ANDROID_SDK_ROOT"
flutter config --no-analytics

# PATH kalıcı yap
grep -q "ANDROID_SDK_ROOT" "$HOME/.bashrc" || {
  echo "" >> "$HOME/.bashrc"
  echo "export ANDROID_SDK_ROOT=$HOME/android-sdk" >> "$HOME/.bashrc"
  echo "export ANDROID_HOME=$HOME/android-sdk" >> "$HOME/.bashrc"
  echo \'export PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH\' >> "$HOME/.bashrc"
  echo "PATH .bashrc\'ye eklendi"
}

echo ""
echo "=== Kurulum Tamamlandı ==="
df -h $HOME
echo ""
flutter doctor --android-licenses 2>/dev/null || true
flutter doctor
