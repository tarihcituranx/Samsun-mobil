#!/usr/bin/env python3
"""
PROJECT_BRAIN.md otomatik güncelleyici
CI ve yerel ortamda çalışır.
"""
import os, sys, subprocess, re
from datetime import datetime

# ── Proje dizinini CI/yerel ortama göre bul ──────────────
def find_project():
    # CI ortamı
    if os.environ.get("CI") == "true":
        ws = os.environ.get("GITHUB_WORKSPACE")
        if ws and os.path.exists(ws):
            return ws
    # Argüman verilmişse kullan
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        return sys.argv[1]
    # Yerel varsayılan
    local = os.path.expanduser("~/Samsun-mobil")
    if os.path.exists(local):
        return local
    # Mevcut dizin
    return os.getcwd()

PROJECT = find_project()
BRAIN   = os.path.join(PROJECT, "PROJECT_BRAIN.md")
PUBSPEC = None

for root, dirs, files in os.walk(PROJECT):
    dirs[:] = [d for d in dirs if d not in ['.git', 'build', '.dart_tool', 'node_modules']]
    if "pubspec.yaml" in files:
        PUBSPEC = os.path.join(root, "pubspec.yaml")
        break

print(f"📂 Proje dizini : {PROJECT}")
print(f"📄 pubspec.yaml : {PUBSPEC}")
print(f"🧠 BRAIN dosyası: {BRAIN}")

# ── Yardımcılar ───────────────────────────────────────────
def get_version():
    if not PUBSPEC: return "?"
    with open(PUBSPEC, encoding='utf-8') as f:
        for line in f:
            if line.startswith("version:"):
                return line.split(":", 1)[1].strip()
    return "?"

def get_git_log():
    try:
        out = subprocess.check_output(
            ["git", "-C", PROJECT, "log", "--oneline", "-5"],
            stderr=subprocess.DEVNULL
        ).decode('utf-8', errors='replace')
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
                        with open(os.path.join(root, f), encoding='utf-8', errors='ignore') as df:
                            lines += sum(1 for _ in df)
                    except:
                        pass
    return count, lines

def get_folder_tree():
    lib = os.path.join(PROJECT, "lib")
    tree = []
    if not os.path.exists(lib):
        return "lib/ bulunamadı"
    for item in sorted(os.listdir(lib)):
        path = os.path.join(lib, item)
        if os.path.isdir(path):
            sub = [f for f in os.listdir(path) if f.endswith(".dart")]
            tree.append(f"├── {item}/  ({len(sub)} dosya)")
        elif item.endswith(".dart"):
            tree.append(f"├── {item}")
    return "\n".join(tree) if tree else "Boş"

def get_last_session_notes():
    """Son build tag ve commit mesajını bul."""
    try:
        msg = subprocess.check_output(
            ["git", "-C", PROJECT, "log", "--pretty=format:%s", "-1"],
            stderr=subprocess.DEVNULL
        ).decode('utf-8', errors='replace').strip()
        return msg
    except:
        return "—"

def get_known_bugs():
    """Mevcut BRAIN'deki bug listesini koru, silme."""
    if not os.path.exists(BRAIN):
        return """- [ ] Android Build Tools 35.0.0 — Nix ortamında versiyon uyumsuzluğu"""
    with open(BRAIN, encoding='utf-8') as f:
        content = f.read()
    match = re.search(r'## 🐛 Bilinen Buglar\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
    if match:
        return match.group(1).strip()
    return "- [ ] —"

def get_completed_tasks():
    """Mevcut BRAIN'deki tamamlanan görevleri koru."""
    if not os.path.exists(BRAIN):
        return """- [x] Proje kurulumu
- [x] CI/CD workflow kurulumu
- [x] Otomatik bağımlılık düzeltici (fix_deps.py)"""
    with open(BRAIN, encoding='utf-8') as f:
        content = f.read()
    match = re.search(r'## ✅ Tamamlanan Görevler\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
    if match:
        return match.group(1).strip()
    return "- [x] Proje kurulumu"

def get_wip_tasks():
    """Mevcut BRAIN'deki devam eden görevleri koru."""
    if not os.path.exists(BRAIN):
        return "- [ ] ..."
    with open(BRAIN, encoding='utf-8') as f:
        content = f.read()
    match = re.search(r'## 🚧 Devam Eden Görevler\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
    if match:
        return match.group(1).strip()
    return "- [ ] ..."

def get_critical_decisions():
    """Mevcut BRAIN'deki kritik kararları koru."""
    if not os.path.exists(BRAIN):
        return ""
    with open(BRAIN, encoding='utf-8') as f:
        content = f.read()
    match = re.search(r'## 🔑 Kritik Kararlar\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
    if match:
        return match.group(1).strip()
    return ""

# ── Ana güncelleme ────────────────────────────────────────
def update_brain():
    now     = datetime.now().strftime("%d.%m.%Y %H:%M")
    version = get_version()
    dart_count, dart_lines = get_dart_stats()
    git_log  = get_git_log()
    last_msg = get_last_session_notes()
    bugs     = get_known_bugs()
    done     = get_completed_tasks()
    wip      = get_wip_tasks()
    decisions = get_critical_decisions()

    content = f"""# 🧠 Proje Beyin Dosyası — Samsun Ulaşım Sistemi

> Bu dosya Claude'un proje hafızasıdır. Her oturumda okunur, her önemli
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
- **State Yönetimi:** Provider / ChangeNotifier
- **API:** GTFS-RT + SAMULAŞ REST API
- **Ortam:** Google Firebase Studio (IDX) — Nix tabanlı
- **CI/CD:** GitHub Actions → scripts/build.sh

## 📊 Kod İstatistikleri
- Dart dosyası: {dart_count}
- Toplam satır: {dart_lines}

## 📁 Klasör Yapısı
lib/
{get_folder_tree()}

## ✅ Tamamlanan Görevler
{done}

## 🚧 Devam Eden Görevler
{wip}

## 🐛 Bilinen Buglar
{bugs}

## 🔑 Kritik Kararlar
{decisions if decisions else """| Karar | Gerekçe | Tarih |
|-------|---------|-------|
| buildToolsVersion sabitlendi | Nix read-only SDK | {now} |
| APK ayrı repoda tutulur | Ana repo büyümesin | {now} |
| Son 3 APK tutulur | Alan tasarrufu | {now} |
| fix_deps.py eklendi | Otomatik bağımlılık çakışması çözümü | {now} |"""}

## 🔧 Özel Yapılandırmalar
- Build Tools: 34.0.0 (Nix'te kurulu olan)
- Min SDK: 24
- Target SDK: 34
- Gradle: 8.x uyumlu
- Ortam: Firebase Studio / IDX / Nix
- version.json: https://github.com/tarihcituranx/test/raw/main/releases/version.json

## 📝 Son Oturum Notları
- Tarih: {now}
- Son commit: {last_msg}
- Bırakılan: —

## ⚠️ Dikkat Edilecekler
- Firebase Studio'da SDK Manager çalışmaz, build.gradle ile çöz
- APK imzası her release build'de kontrol et
- flutter pub cache clean bazen gerekebilir
- local.properties silmek bazen build sorununu çözer
- Bağımlılık çakışması → scripts/fix_deps.py otomatik halleder

## 📜 Git Geçmişi (Son 5)
```
{git_log}
```
"""

    with open(BRAIN, "w", encoding='utf-8') as f:
        f.write(content)
    print(f"✅ PROJECT_BRAIN.md güncellendi ({now})")
    print(f"   Sürüm      : {version}")
    print(f"   Dart dosya : {dart_count} dosya, {dart_lines} satır")

    # Git push
    try:
        subprocess.run(["git", "-C", PROJECT, "add", "PROJECT_BRAIN.md"], check=True)
        result = subprocess.run(
            ["git", "-C", PROJECT, "diff", "--cached", "--quiet"],
            capture_output=True
        )
        if result.returncode != 0:  # değişiklik var
            subprocess.run(["git", "-C", PROJECT, "commit", "-m",
                            f"brain: hafıza güncellendi — {now}"], check=True)
            subprocess.run(["git", "-C", PROJECT, "push", "origin", "main"], check=True)
            print("✅ GitHub'a gönderildi")
        else:
            print("ℹ️  Değişiklik yok, commit atlandı")
    except Exception as e:
        print(f"⚠️  Git push başarısız: {e}")

if __name__ == "__main__":
    update_brain()
