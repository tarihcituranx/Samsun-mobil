#!/bin/bash
# ============================================================
# Samsun Mobil — Akıllı Bug & Sorun Tarayıcı
# Kullanım: bash bug_scan.sh
# Çıktı: bug_report_TARIH.md
# ============================================================

set -e

# ── Renkler ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}▶ $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $1${NC}"; }
fail()    { echo -e "${RED}❌ $1${NC}"; }

# ── Ayarlar ──────────────────────────────────────────────
PROJECT_DIR="${1:-$HOME/Samsun-mobil}"
DATE=$(date +"%Y%m%d_%H%M")
REPORT="$HOME/bug_report_${DATE}.md"

ISSUE_COUNT=0
WARN_COUNT=0
OK_COUNT=0

# Rapor dosyasına yaz + terminale bas
log()  { echo "$1" >> "$REPORT"; }
log_and_print() { echo -e "$1"; echo "$1" >> "$REPORT"; }

# ── Rapor başlığı ─────────────────────────────────────────
cat > "$REPORT" << MD
# 🐛 Samsun Mobil — Bug & Sorun Raporu
**Tarih:** $(date '+%d.%m.%Y %H:%M')
**Proje:** $PROJECT_DIR
**Sistem:** $(uname -a)

---
MD

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Samsun Mobil — Bug Tarayıcı Başladı   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Proje klasörü var mı?
if [ ! -d "$PROJECT_DIR" ]; then
  fail "Proje klasörü bulunamadı: $PROJECT_DIR"
  echo "Kullanım: bash bug_scan.sh /proje/yolu"
  exit 1
fi

# pubspec.yaml bul
PUBSPEC=$(find "$PROJECT_DIR" -name "pubspec.yaml" | head -1)
if [ -z "$PUBSPEC" ]; then
  fail "pubspec.yaml bulunamadı!"; exit 1
fi
FLUTTER_DIR=$(dirname "$PUBSPEC")
LIB_DIR="$FLUTTER_DIR/lib"

# ══════════════════════════════════════════════════════════
# 1. FLUTTER DOCTOR
# ══════════════════════════════════════════════════════════
info "Flutter ortamı kontrol ediliyor..."
log "## 1. Flutter Ortamı"
log ""

DOCTOR_OUT=$(flutter doctor 2>&1 || true)
echo "$DOCTOR_OUT" >> "$REPORT"

if echo "$DOCTOR_OUT" | grep -q "\[!\]"; then
  # Linux toolchain uyarısını sayma — sadece Android sorunlarını say
  ISSUES=$(echo "$DOCTOR_OUT" | grep "\[!\]" | grep -v "Linux toolchain" | wc -l)
  fail "Flutter Doctor: $ISSUES sorun bulundu"
  ISSUE_COUNT=$((ISSUE_COUNT + ISSUES))
  log "**❌ $ISSUES kritik sorun bulundu**"
elif echo "$DOCTOR_OUT" | grep -q "\[✗\]"; then
  fail "Flutter Doctor: Kritik hata var"
  ISSUE_COUNT=$((ISSUE_COUNT + 1))
else
  success "Flutter Doctor temiz"
  OK_COUNT=$((OK_COUNT + 1))
  log "**✅ Flutter ortamı sağlıklı**"
fi
log ""

# ══════════════════════════════════════════════════════════
# 2. FLUTTER ANALYZE (Dart statik analiz)
# ══════════════════════════════════════════════════════════
info "Dart kodu analiz ediliyor..."
log "## 2. Dart Kod Analizi (flutter analyze)"
log ""

cd "$FLUTTER_DIR"
ANALYZE_OUT=$(flutter analyze 2>&1 || true)
echo "$ANALYZE_OUT" >> "$REPORT"

ERRORS=$(echo "$ANALYZE_OUT"   | grep -c "error"   || true)
WARNINGS=$(echo "$ANALYZE_OUT" | grep -c "warning" || true)
HINTS=$(echo "$ANALYZE_OUT"    | grep -c "hint"    || true)
INFOS=$(echo "$ANALYZE_OUT"    | grep -c "info"    || true)

log ""
log "| Seviye | Adet |"
log "|--------|------|"
log "| ❌ Hata | $ERRORS |"
log "| ⚠️ Uyarı | $WARNINGS |"
log "| 💡 İpucu | $HINTS |"
log "| ℹ️ Bilgi | $INFOS |"
log ""

[ "$ERRORS" -gt 0 ]   && { fail "$ERRORS derleme hatası"; ISSUE_COUNT=$((ISSUE_COUNT+ERRORS)); }
[ "$WARNINGS" -gt 0 ] && { warn "$WARNINGS uyarı"; WARN_COUNT=$((WARN_COUNT+WARNINGS)); }
[ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ] && { success "Kod analizi temiz"; OK_COUNT=$((OK_COUNT+1)); }

# ══════════════════════════════════════════════════════════
# 3. BAĞIMLILIK SORUNLARI
# ══════════════════════════════════════════════════════════
info "Bağımlılıklar kontrol ediliyor..."
log "## 3. Bağımlılık Kontrolü"
log ""

PUB_OUT=$(flutter pub outdated 2>&1 || true)
echo "$PUB_OUT" >> "$REPORT"

OUTDATED=$(echo "$PUB_OUT" | grep -c "^\s*\*" || true)
OUTDATED_MSG=$(flutter pub get 2>&1 | grep -c "newer versions incompatible" || true)
[ "$OUTDATED_MSG" -gt 0 ] && OUTDATED=$((OUTDATED + OUTDATED_MSG))
if [ "$OUTDATED" -gt 0 ]; then
  warn "$OUTDATED eski/güncel olmayan paket var"
  WARN_COUNT=$((WARN_COUNT+OUTDATED))
  log "**⚠️ $OUTDATED paket güncel değil**"
else
  success "Tüm paketler güncel"
  OK_COUNT=$((OK_COUNT+1))
  log "**✅ Tüm paketler güncel**"
fi

# Pubspec lock çakışması
PUB_GET=$(flutter pub get 2>&1 || true)
if echo "$PUB_GET" | grep -qi "error\|conflict\|incompatible"; then
  fail "pubspec bağımlılık çakışması!"
  echo "$PUB_GET" >> "$REPORT"
  ISSUE_COUNT=$((ISSUE_COUNT+1))
  log "**❌ Bağımlılık çakışması tespit edildi**"
else
  success "pubspec.yaml temiz"
  OK_COUNT=$((OK_COUNT+1))
fi
log ""

# ══════════════════════════════════════════════════════════
# 4. ANDROID YAPILANDIRMA
# ══════════════════════════════════════════════════════════
info "Android yapılandırması kontrol ediliyor..."
log "## 4. Android Yapılandırması"
log ""

GRADLE_FILE=$(find "$FLUTTER_DIR/android" -name "build.gradle*" -path "*/app/*" | head -1)
if [ -f "$GRADLE_FILE" ]; then
  log "**Dosya:** \`$GRADLE_FILE\`"
  log '```'
  cat "$GRADLE_FILE" >> "$REPORT"
  log '```'
  log ""

  # Build Tools kontrolü
  INSTALLED_BT=$(ls "$ANDROID_HOME/build-tools/" 2>/dev/null | tail -1)
  REQUIRED_BT=$(grep "buildToolsVersion" "$GRADLE_FILE" | grep -o '"[0-9.]*"' | tr -d '"' || echo "")

  if [ -n "$REQUIRED_BT" ] && [ -n "$INSTALLED_BT" ]; then
    if [ "$REQUIRED_BT" != "$INSTALLED_BT" ]; then
      fail "Build Tools uyumsuz! Gereken: $REQUIRED_BT | Kurulu: $INSTALLED_BT"
      ISSUE_COUNT=$((ISSUE_COUNT+1))
      log "**❌ Build Tools uyumsuzluğu: Gereken=$REQUIRED_BT, Kurulu=$INSTALLED_BT**"
    else
      success "Build Tools versiyonu eşleşiyor: $INSTALLED_BT"
      OK_COUNT=$((OK_COUNT+1))
      log "**✅ Build Tools: $INSTALLED_BT**"
    fi
  fi

  # minSdk kontrolü
  MIN_SDK=$(grep "minSdk\b" "$GRADLE_FILE" | grep -o "[0-9]*" | head -1 || echo "0")
  if [ "$MIN_SDK" -lt 21 ] 2>/dev/null; then
    warn "minSdk=$MIN_SDK çok düşük, modern paketler için en az 21 önerilir"
    WARN_COUNT=$((WARN_COUNT+1))
    log "**⚠️ minSdk=$MIN_SDK — önerilen: 21+**"
  fi

  # Kotlin versiyonu
  KOTLIN_VER=$(grep "kotlin_version\|kotlinVersion" "$FLUTTER_DIR/android/build.gradle" 2>/dev/null | grep -o '"[0-9.]*"' | tr -d '"' || echo "")
  if [ -n "$KOTLIN_VER" ]; then
    log "**Kotlin:** $KOTLIN_VER"
  fi
else
  warn "android/app/build.gradle bulunamadı"
  WARN_COUNT=$((WARN_COUNT+1))
fi
log ""

# ══════════════════════════════════════════════════════════
# 5. DART KOD KALİTESİ (manuel tarama)
# ══════════════════════════════════════════════════════════
info "Dart kod kalitesi taranıyor..."
log "## 5. Kod Kalitesi Taraması"
log ""

if [ -d "$LIB_DIR" ]; then

  # TODO / FIXME / HACK yorumları
  TODO_COUNT=$(grep -rn "TODO\|FIXME\|HACK\|XXX" "$LIB_DIR" --include="*.dart" | wc -l || true)
  if [ "$TODO_COUNT" -gt 0 ]; then
    warn "$TODO_COUNT adet TODO/FIXME/HACK yorumu"
    WARN_COUNT=$((WARN_COUNT+1))
    log "### ⚠️ TODO/FIXME/HACK Listesi ($TODO_COUNT adet)"
    log '```'
    grep -rn "TODO\|FIXME\|HACK\|XXX" "$LIB_DIR" --include="*.dart" >> "$REPORT" || true
    log '```'
  fi

  # print() kullanımı (release'te kötü)
  PRINT_COUNT=$(grep -rn "^\s*print(" "$LIB_DIR" --include="*.dart" | wc -l || true)
  if [ "$PRINT_COUNT" -gt 0 ]; then
    warn "$PRINT_COUNT adet print() var — release'te debugPrint() kullanılmalı"
    WARN_COUNT=$((WARN_COUNT+1))
    log "### ⚠️ print() Kullanımları ($PRINT_COUNT adet) — debugPrint() önerilir"
    log '```'
    grep -rn "^\s*print(" "$LIB_DIR" --include="*.dart" >> "$REPORT" || true
    log '```'
  fi

  # Hardcoded HTTP (HTTPS olmalı)
  HTTP_COUNT=$(grep -rn '"http://' "$LIB_DIR" --include="*.dart" | wc -l || true)
  if [ "$HTTP_COUNT" -gt 0 ]; then
    fail "$HTTP_COUNT adet güvensiz http:// URL var — https:// kullanılmalı"
    ISSUE_COUNT=$((ISSUE_COUNT+1))
    log "### ❌ Güvensiz HTTP URL'leri ($HTTP_COUNT adet)"
    log '```'
    grep -rn '"http://' "$LIB_DIR" --include="*.dart" >> "$REPORT" || true
    log '```'
  fi

  # API key / token hardcoded
  SECRET_COUNT=$(grep -rn "apiKey\|api_key\|token\|secret\|password" "$LIB_DIR" --include="*.dart" -i | grep -v "//\|test\|mock\|example" | wc -l || true)
  if [ "$SECRET_COUNT" -gt 0 ]; then
    warn "$SECRET_COUNT potansiyel hardcoded gizli bilgi satırı"
    WARN_COUNT=$((WARN_COUNT+1))
    log "### ⚠️ Olası Hardcoded Gizli Bilgiler"
    log '```'
    grep -rn "apiKey\|api_key\|token\|secret\|password" "$LIB_DIR" --include="*.dart" -i | grep -v "//\|test\|mock" >> "$REPORT" || true
    log '```'
  fi

  # Boş catch blokları
  EMPTY_CATCH=$(grep -rn "catch.*{$\|catch.*{ }$\|} catch" "$LIB_DIR" --include="*.dart" | wc -l || true)
  if [ "$EMPTY_CATCH" -gt 0 ]; then
    warn "$EMPTY_CATCH olası boş catch bloğu"
    WARN_COUNT=$((WARN_COUNT+1))
    log "### ⚠️ Boş/Sessiz Catch Blokları ($EMPTY_CATCH adet)"
  fi

  # BuildContext async gap
  ASYNC_CTX=$(grep -rn "await.*\n.*context\|context.*mounted" "$LIB_DIR" --include="*.dart" | wc -l || true)
  if [ "$ASYNC_CTX" -gt 0 ]; then
    warn "Async sonrası BuildContext kullanımı — mounted kontrolü gerekebilir"
    WARN_COUNT=$((WARN_COUNT+1))
    log "### ⚠️ Async BuildContext Kullanımı"
  fi

  # Büyük dosyalar (500+ satır)
  log "### 📏 Büyük Dart Dosyaları (500+ satır)"
  log '```'
  find "$LIB_DIR" -name "*.dart" | while read f; do
    LINES=$(wc -l < "$f")
    if [ "$LINES" -gt 500 ]; then
      echo "$LINES satır: $f"
      WARN_COUNT=$((WARN_COUNT+1))
    fi
  done | sort -rn >> "$REPORT" || true
  log '```'
  log ""

  # Kullanılmayan import taraması (basit)
  log "### 🗑️ Olası Kullanılmayan Import'lar"
  log '```'
  grep -rn "^import " "$LIB_DIR" --include="*.dart" | \
    awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -20 >> "$REPORT" || true
  log '```'

else
  warn "lib/ klasörü bulunamadı: $LIB_DIR"
fi
log ""

# ══════════════════════════════════════════════════════════
# 6. ASSETS VE DOSYA KONTROLLERI
# ══════════════════════════════════════════════════════════
info "Assets ve dosyalar kontrol ediliyor..."
log "## 6. Assets Kontrolü"
log ""

# pubspec.yaml'daki assets gerçekten var mı?
ASSETS=$(grep -A50 "^assets:" "$PUBSPEC" | grep "^\s*-" | sed 's/.*- //' | tr -d ' \r' || true)
if [ -n "$ASSETS" ]; then
  MISSING_ASSETS=0
  log "| Dosya | Durum |"
  log "|-------|-------|"
  while IFS= read -r asset; do
    ASSET_PATH="$FLUTTER_DIR/$asset"
    if [ -f "$ASSET_PATH" ] || [ -d "$ASSET_PATH" ]; then
      log "| $asset | ✅ |"
    else
      log "| $asset | ❌ BULUNAMADI |"
      MISSING_ASSETS=$((MISSING_ASSETS+1))
      ISSUE_COUNT=$((ISSUE_COUNT+1))
    fi
  done <<< "$ASSETS"
  if [ "$MISSING_ASSETS" -gt 0 ]; then
    fail "$MISSING_ASSETS eksik asset dosyası!"
  else
    success "Tüm asset dosyaları mevcut"
    OK_COUNT=$((OK_COUNT+1))
  fi
else
  log "Assets tanımlanmamış."
fi
log ""

# ══════════════════════════════════════════════════════════
# 7. GIT DURUMU
# ══════════════════════════════════════════════════════════
info "Git durumu kontrol ediliyor..."
log "## 7. Git Durumu"
log ""

cd "$FLUTTER_DIR"
GIT_STATUS=$(git status --short 2>/dev/null || echo "Git repo değil")
UNCOMMITTED=$(echo "$GIT_STATUS" | grep -v "^$" | wc -l || true)

if [ "$UNCOMMITTED" -gt 0 ]; then
  warn "$UNCOMMITTED commit edilmemiş değişiklik"
  WARN_COUNT=$((WARN_COUNT+1))
  log "**⚠️ $UNCOMMITTED commit edilmemiş dosya:**"
  log '```'
  echo "$GIT_STATUS" >> "$REPORT"
  log '```'
else
  success "Git çalışma alanı temiz"
  OK_COUNT=$((OK_COUNT+1))
  log "**✅ Tüm değişiklikler commit edilmiş**"
fi

# Son 5 commit
log ""
log "### Son 5 Commit"
log '```'
git log --oneline -5 2>/dev/null >> "$REPORT" || true
log '```'
log ""

# ══════════════════════════════════════════════════════════
# 8. GENEL ÖZET
# ══════════════════════════════════════════════════════════
TOTAL=$((ISSUE_COUNT + WARN_COUNT + OK_COUNT))

log "---"
log "## 📊 Özet"
log ""
log "| Kategori | Adet |"
log "|----------|------|"
log "| ❌ Kritik Sorun | $ISSUE_COUNT |"
log "| ⚠️ Uyarı | $WARN_COUNT |"
log "| ✅ Tamam | $OK_COUNT |"
log "| 📋 Toplam Kontrol | $TOTAL |"
log ""

if [ "$ISSUE_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
  log "## 🎉 Proje gayet sağlıklı görünüyor!"
elif [ "$ISSUE_COUNT" -gt 0 ]; then
  log "## 🔴 $ISSUE_COUNT kritik sorun düzeltilmeli!"
else
  log "## 🟡 $WARN_COUNT uyarı gözden geçirilmeli."
fi

log ""
log "---"
log "*Rapor oluşturuldu: $(date '+%d.%m.%Y %H:%M')*"

# ── Terminal özeti ────────────────────────────────────────
echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  TARAMA TAMAMLANDI${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "  ${RED}❌ Kritik Sorun : $ISSUE_COUNT${NC}"
echo -e "  ${YELLOW}⚠️  Uyarı        : $WARN_COUNT${NC}"
echo -e "  ${GREEN}✅ Tamam        : $OK_COUNT${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""
echo -e "📄 Rapor kaydedildi: ${CYAN}$REPORT${NC}"
echo ""

# ══════════════════════════════════════════════════════════
# 9. APK ANALİZİ (Derlenmiş APK taraması)
# ══════════════════════════════════════════════════════════

scan_apk() {
  local APK_PATH="$1"

  echo ""
  info "APK taranıyor: $APK_PATH"
  log "## 8. APK Analizi"
  log "**Dosya:** \`$APK_PATH\`"
  log ""

  # ── APK boyutu ──────────────────────────────────────
  APK_SIZE_BYTES=$(wc -c < "$APK_PATH")
  APK_SIZE_MB=$(echo "scale=2; $APK_SIZE_BYTES/1048576" | bc)
  log "### 📦 APK Boyutu"
  log "**$APK_SIZE_MB MB** ($APK_SIZE_BYTES byte)"
  log ""

  if (( $(echo "$APK_SIZE_MB > 100" | bc -l) )); then
    fail "APK boyutu çok büyük: ${APK_SIZE_MB}MB (Google Play limiti 100MB)"
    ISSUE_COUNT=$((ISSUE_COUNT+1))
    log "**❌ APK boyutu aşırı büyük — kod küçültme ve tree-shaking kontrol edilmeli**"
  elif (( $(echo "$APK_SIZE_MB > 50" | bc -l) )); then
    warn "APK boyutu büyük: ${APK_SIZE_MB}MB"
    WARN_COUNT=$((WARN_COUNT+1))
    log "**⚠️ APK boyutu büyük — ProGuard/R8 etkin mi kontrol et**"
  else
    success "APK boyutu normal: ${APK_SIZE_MB}MB"
    OK_COUNT=$((OK_COUNT+1))
    log "**✅ APK boyutu normal**"
  fi

  # ── APK içeriğini python ile aç ──────────────────────
  log ""
  log "### 📂 APK İçerik Analizi"

  python3 << PYEOF
import zipfile, os, sys

apk = "$APK_PATH"
report = "$REPORT"

categories = {
    "DEX (Kod)":       [],
    "Native (.so)":    [],
    "Assets":          [],
    "Resources":       [],
    "Manifest":        [],
    "Diğer":           [],
}
size_by_cat = {}
all_strings  = []

with zipfile.ZipFile(apk, 'r') as z:
    infos = z.infolist()
    for item in infos:
        n = item.filename
        s = item.file_size
        if n.endswith('.dex'):
            categories["DEX (Kod)"].append((n, s))
        elif n.endswith('.so'):
            categories["Native (.so)"].append((n, s))
        elif n.startswith('assets/'):
            categories["Assets"].append((n, s))
        elif n.startswith('res/') or n.endswith('.arsc'):
            categories["Resources"].append((n, s))
        elif 'AndroidManifest' in n:
            categories["Manifest"].append((n, s))
        else:
            categories["Diğer"].append((n, s))

    # En büyük 10 dosya
    all_files = sorted(infos, key=lambda x: x.file_size, reverse=True)[:10]

    # AndroidManifest.xml içeriğini çıkar
    try:
        manifest_raw = z.read('AndroidManifest.xml')
        manifest_str = manifest_raw.decode('utf-8', errors='ignore')
    except:
        manifest_str = ""

    # classes.dex içinden string tara (gizli anahtar arama)
    suspicious = []
    for dex in [f for f in z.namelist() if f.endswith('.dex')]:
        try:
            data = z.read(dex).decode('latin-1', errors='ignore')
            keywords = ['apiKey','api_key','secret','password','token','Bearer',
                        'firebase','AWS','amazonaws','mongodb','mysql','postgres']
            for kw in keywords:
                if kw.lower() in data.lower():
                    suspicious.append(f"{kw} → {dex}")
        except:
            pass

with open(report, 'a') as r:
    # Kategori boyutları
    r.write("\n| Kategori | Dosya Sayısı | Toplam Boyut |\n")
    r.write("|----------|-------------|-------------|\n")
    for cat, files in categories.items():
        total = sum(s for _, s in files)
        r.write(f"| {cat} | {len(files)} | {total/1024:.1f} KB |\n")

    # En büyük dosyalar
    r.write("\n### 🏋️ En Büyük 10 Dosya\n")
    r.write("| Dosya | Boyut |\n|-------|-------|\n")
    for f in all_files:
        r.write(f"| {f.filename} | {f.file_size/1024:.1f} KB |\n")

    # Native mimari kontrolü
    archs = set()
    for n, _ in categories["Native (.so)"]:
        parts = n.split('/')
        if len(parts) > 2:
            archs.add(parts[1])  # lib/arm64-v8a/...
    if archs:
        r.write(f"\n### 🏗️ Native Mimariler\n")
        r.write("| Mimari | Durum |\n|--------|-------|\n")
        for arch in sorted(archs):
            durum = "✅ Önerilen" if arch == "arm64-v8a" else "⚠️ Ekstra boyut"
            r.write(f"| {arch} | {durum} |\n")
        if len(archs) > 1:
            r.write("\n**⚠️ Birden fazla mimari var — `flutter build apk --target-platform android-arm64` ile sadece arm64 hedefle, boyutu küçülür**\n")

    # Şüpheli string'ler
    if suspicious:
        r.write(f"\n### 🔐 APK İçinde Şüpheli Stringler ({len(suspicious)} adet)\n")
        r.write("```\n")
        for s in suspicious:
            r.write(s + "\n")
        r.write("```\n")
        r.write("**❌ Bunlar hardcoded gizli bilgi olabilir — .env veya dart-define kullan!**\n")

print(f"Kategoriler: {', '.join(f'{k}:{len(v)}' for k,v in categories.items())}")
print(f"Şüpheli: {len(suspicious)}")
PYEOF

  # ── İmza kontrolü ────────────────────────────────────
  log ""
  log "### 🔏 İmza Kontrolü"

  # ANDROID_HOME varsa apksigner ile kontrol
  APKSIGNER=$(find "${ANDROID_HOME:-/dev/null}/build-tools" -name "apksigner" 2>/dev/null | tail -1)
  if [ -n "$APKSIGNER" ]; then
    SIG_OUT=$("$APKSIGNER" verify --verbose "$APK_PATH" 2>&1 || true)
    if echo "$SIG_OUT" | grep -q "Verified using v2\|Verified using v3"; then
      success "APK geçerli imzayla imzalanmış (v2/v3)"
      OK_COUNT=$((OK_COUNT+1))
      log "**✅ İmza geçerli (v2/v3 scheme)**"
    elif echo "$SIG_OUT" | grep -q "Verified using v1"; then
      warn "Sadece v1 imzası var — v2/v3 önerilir"
      WARN_COUNT=$((WARN_COUNT+1))
      log "**⚠️ Sadece v1 imzası — Android 7+ için v2 şeması kullan**"
    else
      warn "İmza doğrulanamadı"
      WARN_COUNT=$((WARN_COUNT+1))
      log "**⚠️ İmza doğrulanamadı (debug APK olabilir)**"
    fi
  else
    # Python ile META-INF kontrolü
    python3 -c "
import zipfile
with zipfile.ZipFile('$APK_PATH') as z:
    names = z.namelist()
    has_sf  = any('.SF' in n for n in names)
    has_rsa = any('.RSA' in n or '.DSA' in n for n in names)
    if has_sf and has_rsa:
        print('SIGNED')
    else:
        print('UNSIGNED')
" | grep -q "SIGNED" && {
      success "APK imzalı (META-INF içeriği doğrulandı)"
      OK_COUNT=$((OK_COUNT+1))
      log "**✅ APK imzalı**"
    } || {
      fail "APK İMZASIZ! Release için imza zorunlu."
      ISSUE_COUNT=$((ISSUE_COUNT+1))
      log "**❌ APK imzasız — Google Play'e yüklenemez**"
    }
  fi

  # ── AndroidManifest izin taraması ────────────────────
  log ""
  log "### 🛡️ İzin Analizi (AndroidManifest.xml)"

  python3 << PYEOF2
import zipfile, re

DANGEROUS_PERMS = [
    'READ_CONTACTS','WRITE_CONTACTS','GET_ACCOUNTS',
    'READ_CALL_LOG','WRITE_CALL_LOG','PROCESS_OUTGOING_CALLS',
    'READ_SMS','RECEIVE_SMS','SEND_SMS','RECEIVE_MMS',
    'READ_EXTERNAL_STORAGE','WRITE_EXTERNAL_STORAGE','MANAGE_EXTERNAL_STORAGE',
    'ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION','ACCESS_BACKGROUND_LOCATION',
    'RECORD_AUDIO','CAMERA',
    'READ_PHONE_STATE','READ_PHONE_NUMBERS','CALL_PHONE',
    'BODY_SENSORS','ACTIVITY_RECOGNITION',
]

with zipfile.ZipFile("$APK_PATH") as z:
    try:
        raw = z.read('AndroidManifest.xml').decode('latin-1', errors='ignore')
    except:
        print("Manifest okunamadı")
        exit()

found = [p for p in DANGEROUS_PERMS if p in raw]
normal = re.findall(r'android\.permission\.([A-Z_]+)', raw)
normal = [p for p in set(normal) if p not in DANGEROUS_PERMS]

with open("$REPORT", 'a') as r:
    r.write(f"\n**Toplam izin:** {len(set(normal)) + len(found)}\n\n")
    if found:
        r.write(f"| ❗ Tehlikeli İzin | Not |\n|-----------------|-----|\n")
        for p in found:
            r.write(f"| {p} | Kullanıcı onayı gerektirir |\n")
    if normal:
        r.write(f"\n**Normal izinler ({len(normal)}):** {', '.join(normal[:15])}\n")

print(f"Tehlikeli: {len(found)}, Normal: {len(normal)}")
PYEOF2

  # ── ProGuard / R8 kontrolü ───────────────────────────
  log ""
  log "### 🔧 ProGuard / R8 Kontrolü"
  PROGUARD_FILE=$(find "$FLUTTER_DIR" -name "proguard-rules.pro" | head -1)
  if [ -f "$PROGUARD_FILE" ]; then
    success "proguard-rules.pro mevcut"
    OK_COUNT=$((OK_COUNT+1))
    log "**✅ proguard-rules.pro mevcut**"
    log '```'
    cat "$PROGUARD_FILE" >> "$REPORT"
    log '```'
  else
    warn "proguard-rules.pro bulunamadı — kod küçültme etkin olmayabilir"
    WARN_COUNT=$((WARN_COUNT+1))
    log "**⚠️ proguard-rules.pro yok — minifyEnabled kontrolü önerilir**"
  fi

  log ""
  success "APK analizi tamamlandı"
}

# ── APK'yı bul ve tara ───────────────────────────────────
echo ""
info "Derlenmiş APK aranıyor..."
log ""
log "---"

# Release APK
RELEASE_APK=$(find "$FLUTTER_DIR" -name "app-release.apk" 2>/dev/null | head -1)
# Debug APK
DEBUG_APK=$(find "$FLUTTER_DIR" -name "app-debug.apk" 2>/dev/null | head -1)

if [ -n "$RELEASE_APK" ]; then
  log "## 8. APK Analizi — Release"
  scan_apk "$RELEASE_APK"
elif [ -n "$DEBUG_APK" ]; then
  warn "Release APK bulunamadı, debug APK taranıyor..."
  log "## 8. APK Analizi — Debug"
  scan_apk "$DEBUG_APK"
else
  warn "Derlenmiş APK bulunamadı. Önce 'flutter build apk --release' çalıştır."
  log "## 8. APK Analizi"
  log "**⚠️ APK bulunamadı — önce derleme yapılmalı:**"
  log "\`\`\`bash"
  log "flutter build apk --release"
  log "\`\`\`"
  WARN_COUNT=$((WARN_COUNT+1))
fi

# ── Güncellenmiş özet ────────────────────────────────────
echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  TARAMA TAMAMLANDI (Kaynak + APK)${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "  ${RED}❌ Kritik Sorun : $ISSUE_COUNT${NC}"
echo -e "  ${YELLOW}⚠️  Uyarı        : $WARN_COUNT${NC}"
echo -e "  ${GREEN}✅ Tamam        : $OK_COUNT${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""
echo -e "📄 Rapor: ${CYAN}$REPORT${NC}"
echo ""
