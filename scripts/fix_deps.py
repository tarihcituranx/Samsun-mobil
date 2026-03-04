#!/usr/bin/env python3
"""
Samsun Mobil — Otomatik Pubspec Bağımlılık Düzeltici
Çalışma şekli:
  1. flutter pub get çalıştır
  2. Hata varsa çıktıyı parse et
  3. Bilinen çakışmaları otomatik düzelt
  4. flutter pub upgrade --major-versions ile de dene
  5. Değişiklikleri pubspec.yaml'a yaz
"""

import os, sys, subprocess, re, yaml
from pathlib import Path

# ── Renkler ───────────────────────────────────────────────
RED = '\033[0;31m'; GREEN = '\033[0;32m'; YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'; NC = '\033[0m'

def info(msg):  print(f"{CYAN}ℹ {msg}{NC}")
def ok(msg):    print(f"{GREEN}✅ {msg}{NC}")
def warn(msg):  print(f"{YELLOW}⚠  {msg}{NC}")
def fail(msg):  print(f"{RED}❌ {msg}{NC}")

# ── Pubspec yolunu bul ────────────────────────────────────
def find_pubspec(start=None):
    start = start or os.environ.get("GITHUB_WORKSPACE") or os.path.expanduser("~/Samsun-mobil")
    for root, dirs, files in os.walk(start):
        dirs[:] = [d for d in dirs if d not in ['.dart_tool', 'build', '.git', 'node_modules']]
        if "pubspec.yaml" in files:
            return os.path.join(root, "pubspec.yaml")
    return None

# ── Flutter pub get çalıştır ──────────────────────────────
def run_pub_get(pubspec_dir):
    result = subprocess.run(
        ["flutter", "pub", "get"],
        cwd=pubspec_dir,
        capture_output=True,
        text=True
    )
    return result.returncode, result.stdout + result.stderr

# ── Hata çıktısından çakışmaları çıkar ───────────────────
def parse_conflicts(error_output):
    """
    Çıktıdan çakışan paketleri ve önerilen sürümleri çıkarır.
    Örnek: 'Try upgrading your constraint on package_info_plus: flutter pub add package_info_plus:^9.0.0'
    """
    conflicts = {}

    # "Try upgrading your constraint on X: flutter pub add X:^Y.Z.W"
    pattern1 = re.findall(
        r'Try upgrading your constraint on (\S+): flutter pub add \S+\^\s*([\d.]+)',
        error_output
    )
    for pkg, ver in pattern1:
        conflicts[pkg.rstrip(':')] = f"^{ver}"

    # "flutter pub add X:^Y.Z.W" (genel öneri)
    pattern2 = re.findall(
        r'flutter pub add ([\w_]+):\^([\d.]+)',
        error_output
    )
    for pkg, ver in pattern2:
        if pkg not in conflicts:
            conflicts[pkg] = f"^{ver}"

    # "X is pinned to version Y.Z.W"
    pattern3 = re.findall(
        r'(\w+) is pinned to version ([\d.]+)',
        error_output
    )
    for pkg, ver in pattern3:
        if pkg not in conflicts:
            conflicts[pkg] = f"^{ver}"

    # "because X depends on Y Z.W" — versiyon kısıtı
    pattern4 = re.findall(
        r'depends on (\w+) ([\d.]+\+?[\d.]*)',
        error_output
    )
    for pkg, ver in pattern4:
        if pkg not in conflicts and ver[0].isdigit():
            # major version'u al
            major = ver.split('.')[0]
            conflicts[pkg] = f">={ver} <{int(major)+1}.0.0"

    return conflicts

# ── Bilinen sabit çakışmalar ──────────────────────────────
KNOWN_FIXES = {
    # Flutter SDK ile gelen intl versiyonları
    "intl":                     "^0.20.2",
    # package_info_plus + cached_network_image web uyumsuzluğu
    "package_info_plus":        "^9.0.0",
    # cached_network_image en son stabil
    "cached_network_image":     "^3.4.1",
    # flutter_localizations ile uyumlu
    "collection":               "^1.18.0",
    # Dart 3 uyumlu
    "meta":                     "^1.12.0",
    "path":                     "^1.9.0",
    "http":                     "^1.2.0",
    "url_launcher":             "^6.3.0",
    "shared_preferences":       "^2.3.0",
    "sqflite":                  "^2.3.3",
    "path_provider":            "^2.1.4",
    "permission_handler":       "^11.3.0",
    "geolocator":               "^13.0.0",
    "google_maps_flutter":      "^2.9.0",
    "flutter_local_notifications": "^18.0.0",
    "open_file":                "^3.5.4",
    "connectivity_plus":        "^6.0.3",
    "dio":                      "^5.7.0",
    "cached_network_image_web": "^1.3.1",
}

# ── pubspec.yaml'ı oku ────────────────────────────────────
def read_pubspec(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

# ── pubspec.yaml'da versiyon güncelle ────────────────────
def update_version(content, pkg, new_ver):
    """
    dependencies veya dev_dependencies altındaki paketi günceller.
    Hem 'pkg: ^x.y.z' hem 'pkg: "^x.y.z"' formatını destekler.
    """
    # Satır bazlı güncelleme — daha güvenli
    lines = content.split('\n')
    updated = False
    for i, line in enumerate(lines):
        # "  package_info_plus: ^5.0.1" veya "  package_info_plus: "^5.0.1""
        stripped = line.lstrip()
        if stripped.startswith(f"{pkg}:"):
            indent = len(line) - len(stripped)
            lines[i] = ' ' * indent + f'{pkg}: {new_ver}'
            updated = True
            break
    return '\n'.join(lines), updated

# ── Ana düzeltme fonksiyonu ───────────────────────────────
def fix_pubspec(pubspec_path, conflicts):
    content = read_pubspec(pubspec_path)
    original = content
    fixed = []
    skipped = []

    for pkg, suggested_ver in conflicts.items():
        # Önce bilinen sabit düzeltmeye bak, yoksa önerilen versiyonu kullan
        fix_ver = KNOWN_FIXES.get(pkg, suggested_ver)
        content, updated = update_version(content, pkg, fix_ver)
        if updated:
            fixed.append(f"{pkg}: {fix_ver}")
        else:
            skipped.append(pkg)

    if content != original:
        with open(pubspec_path, 'w', encoding='utf-8') as f:
            f.write(content)

    return fixed, skipped

# ── flutter pub upgrade --major-versions ─────────────────
def run_pub_upgrade(pubspec_dir):
    info("flutter pub upgrade --major-versions deneniyor...")
    result = subprocess.run(
        ["flutter", "pub", "upgrade", "--major-versions"],
        cwd=pubspec_dir,
        capture_output=True,
        text=True
    )
    return result.returncode, result.stdout + result.stderr

# ── Pubspec'teki tüm paketleri tara ve bilinen fix'leri uygula ──
def apply_known_fixes(pubspec_path):
    content = read_pubspec(pubspec_path)
    fixed = []

    for pkg, fix_ver in KNOWN_FIXES.items():
        if f"{pkg}:" in content:
            new_content, updated = update_version(content, pkg, fix_ver)
            if updated and new_content != content:
                content = new_content
                fixed.append(f"{pkg} → {fix_ver}")

    if fixed:
        with open(pubspec_path, 'w', encoding='utf-8') as f:
            f.write(content)

    return fixed

# ── Ana akış ─────────────────────────────────────────────
def main():
    project_dir = sys.argv[1] if len(sys.argv) > 1 else None
    pubspec_path = find_pubspec(project_dir)

    if not pubspec_path:
        fail("pubspec.yaml bulunamadı!")
        sys.exit(1)

    pubspec_dir = os.path.dirname(pubspec_path)
    info(f"pubspec.yaml: {pubspec_path}")

    # Adım 1: Önce bilinen fix'leri direkt uygula
    info("Bilinen versiyon uyumsuzlukları kontrol ediliyor...")
    known_fixed = apply_known_fixes(pubspec_path)
    if known_fixed:
        ok(f"Önceden düzeltildi: {', '.join(known_fixed)}")
    else:
        info("Bilinen çakışma yok")

    # Adım 2: flutter pub get dene
    info("flutter pub get çalıştırılıyor...")
    code, output = run_pub_get(pubspec_dir)

    if code == 0:
        ok("flutter pub get başarılı — bağımlılıklar temiz!")
        sys.exit(0)

    # Adım 3: Hata var — çakışmaları parse et
    warn("flutter pub get başarısız, çakışmalar analiz ediliyor...")
    print(output[-2000:])  # Son 2000 karakteri göster

    conflicts = parse_conflicts(output)
    if conflicts:
        info(f"Tespit edilen çakışmalar: {list(conflicts.keys())}")
        fixed, skipped = fix_pubspec(pubspec_path, conflicts)
        if fixed:
            ok(f"Düzeltilen paketler: {', '.join(fixed)}")
        if skipped:
            warn(f"Bulunamadı (pubspec'te yok olabilir): {', '.join(skipped)}")

        # Tekrar dene
        info("flutter pub get tekrar deneniyor...")
        code, output = run_pub_get(pubspec_dir)
        if code == 0:
            ok("flutter pub get başarılı!")
            sys.exit(0)
        warn("Hâlâ başarısız, upgrade deneniyor...")
    else:
        warn("Parse edilebilir çakışma bulunamadı, upgrade deneniyor...")

    # Adım 4: flutter pub upgrade --major-versions
    code, output = run_pub_upgrade(pubspec_dir)
    if code == 0:
        ok("flutter pub upgrade başarılı!")
        sys.exit(0)

    # Adım 5: Son çare — pub get tekrar
    info("Son deneme: flutter pub get...")
    code, output = run_pub_get(pubspec_dir)
    if code == 0:
        ok("flutter pub get başarılı!")
        sys.exit(0)

    fail("Bağımlılık sorunu otomatik çözülemedi!")
    fail("Manuel müdahale gerekiyor. pubspec.yaml kontrol et.")
    print(output[-3000:])
    sys.exit(1)

if __name__ == "__main__":
    main()
