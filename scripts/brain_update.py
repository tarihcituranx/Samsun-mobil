#!/usr/bin/env python3
"""
PROJECT_BRAIN.md otomatik güncelleyici
"""
import os, sys, subprocess, yaml
from datetime import datetime

PROJECT = os.path.expanduser("~/Samsun-mobil")
BRAIN   = os.path.join(PROJECT, "PROJECT_BRAIN.md")
PUBSPEC = None

for root, dirs, files in os.walk(PROJECT):
    if "pubspec.yaml" in files:
        PUBSPEC = os.path.join(root, "pubspec.yaml")
        break

def get_version():
    if not PUBSPEC: return "?"
    with open(PUBSPEC) as f:
        for line in f:
            if line.startswith("version:"):
                return line.split(":")[1].strip()
    return "?"

def get_git_log():
    try:
        out = subprocess.check_output(
            ["git", "-C", PROJECT, "log", "--oneline", "-5"],
            stderr=subprocess.DEVNULL
        ).decode()
        return out.strip()
    except:
        return "Git log alınamadı"

def get_dart_stats():
    count = 0
    lines = 0
    lib = os.path.join(PROJECT, "lib")
    if os.path.exists(lib):
        for root, _, files in os.walk(lib):
            for f in files:
                if f.endswith(".dart"):
                    count += 1
                    try:
                        with open(os.path.join(root, f)) as df:
                            lines += sum(1 for _ in df)
                    except:
                        pass
    return count, lines

def get_folder_tree():
    lib = os.path.join(PROJECT, "lib")
    tree = []
    if not os.path.exists(lib): return "lib/ bulunamadı"
    for item in sorted(os.listdir(lib)):
        path = os.path.join(lib, item)
        if os.path.isdir(path):
            sub = [f for f in os.listdir(path) if f.endswith(".dart")]
            tree.append(f"├── {item}/  ({len(sub)} dosya)")
        elif item.endswith(".dart"):
            tree.append(f"├── {item}")
    return "\n".join(tree) if tree else "Boş"

def init_brain():
    version = get_version()
    dart_count, dart_lines = get_dart_stats()
    now = datetime.now().strftime("%d.%m.%Y %H:%M")
    content = f"""# 🧠 Proje Beyin Dosyası — Samsun Ulaşım Sistemi

> Bu dosya Claude\'un proje hafızasıdır. Her oturumda okunur, her önemli
> değişiklikte güncellenir. Alzheimer yaşamamak için burada!
> **Son güncelleme:** {now}

---

## 📌 Proje Özeti
- **Ad:** Samsun Ulaşım Sistemi
- **Paket:** com.tarihcituranx.samsun_ulasim
- **Sürüm:** {version}
- **Platform:** Android (min SDK 24)
- **Geliştirici:** Turan Kaya
- **Ana Repo:** https://github.com/tarihcituranx/Samsun-mobil
- **APK Repo:** https://github.com/tarihcituranx/test

## 🏗️ Mimari
- **Framework:** Flutter / Dart
- **State Yönetimi:** (tespit edilecek)
- **API:** GTFS-RT + SAMULAŞ REST API
- **Ortam:** Google Firebase Studio (IDX) — Nix tabanlı

## 📊 Kod İstatistikleri
- Dart dosyası: {dart_count}
- Toplam satır: {dart_lines}

## 📁 Klasör Yapısı
lib/
{get_folder_tree()}

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

## 🚧 Devam Eden Görevler
- [ ] ...

## 🐛 Bilinen Buglar
- [ ] Android Build Tools 35.0.0 — Nix ortamında versiyon uyumsuzluğu

## 🔑 Kritik Kararlar
| Karar | Gerekçe | Tarih |
|-------|---------|-------|
| buildToolsVersion sabitlendi | Nix read-only SDK | {now} |
| APK ayrı repoda tutulur | Ana repo büyümesin | {now} |
| Son 3 APK tutulur, eskisi silinir | Alan tasarrufu | {now} |
| Şeffaf PNG splash | Hem açık hem koyu tema | {now} |

## 🔧 Özel Yapılandırmalar
- Build Tools: 34.0.0 (Nix\'te kurulu olan)
- Min SDK: 24
- Target SDK: 34
- Gradle: 8.x uyumlu
- Ortam: Firebase Studio / IDX / Nix

## 📝 Son Oturum Notları
- Tarih: {now}
- Yapılan: Proje beyin dosyası oluşturuldu
- Bırakılan: —

## ⚠️ Dikkat Edilecekler
- Firebase Studio\'da SDK Manager çalışmaz, build.gradle ile çöz
- APK imzası her release build\'de kontrol et
- flutter pub cache clean bazen gerekebilir
- local.properties silmek bazen build sorununu çözer

## 📜 Git Geçmişi (Son 5)
{get_git_log()}
"""
    with open(BRAIN, "w") as f:
        f.write(content)
    print(f"✅ PROJECT_BRAIN.md oluşturuldu: {BRAIN}")

def update_brain():
    if not os.path.exists(BRAIN):
        init_brain()
        return
    with open(BRAIN) as f:
        content = f.read()
    now = datetime.now().strftime("%d.%m.%Y %H:%M")
    version = get_version()
    dart_count, dart_lines = get_dart_stats()
    git_log = get_git_log()
    import re
    content = re.sub(r"- \*\*Sürüm:\*\*.*", f"- **Sürüm:** {version}", content)
    content = re.sub(r"- Dart dosyası:.*", f"- Dart dosyası: {dart_count}", content)
    content = re.sub(r"- Toplam satır:.*", f"- Toplam satır: {dart_lines}", content)
    content = re.sub(r"\*\*Son güncelleme:\*\*.*", f"**Son güncelleme:** {now}", content)
    content = re.sub(
        r"(## 📜 Git Geçmişi.*?```\n).*?(```)",
        f"\g<1>{git_log}\n\g<2>",
        content, flags=re.DOTALL
    )
    with open(BRAIN, "w") as f:
        f.write(content)
    print(f"✅ PROJECT_BRAIN.md güncellendi ({now})")
    try:
        subprocess.run(["git", "-C", PROJECT, "add", "PROJECT_BRAIN.md"], check=True)
        subprocess.run(["git", "-C", PROJECT, "commit", "-m",
                        f"brain: hafıza güncellendi — {now}"], check=True)
        subprocess.run(["git", "-C", PROJECT, "push", "origin", "main"], check=True)
        print("✅ GitHub\'a gönderildi")
    except Exception as e:
        print(f"⚠ Git push başarısız: {e}")

if __name__ == "__main__":
    if "--init" in sys.argv:
        init_brain()
    else:
        update_brain()
