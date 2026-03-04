#!/usr/bin/env python3
"""
Samsun Ulaşım API Test Scripti
- Direkt API testleri
- Mobil uygulamanın proxy'si üzerinden testler
- api_service.dart'tan proxy URL otomatik okunur
"""

import requests
import json
import re
import os
import sys
from datetime import datetime
from urllib.parse import quote

# ── Renkler ───────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BLUE   = "\033[94m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

def ok(msg):   print(f"{GREEN}✅ {msg}{RESET}")
def err(msg):  print(f"{RED}❌ {msg}{RESET}")
def warn(msg): print(f"{YELLOW}⚠  {msg}{RESET}")
def info(msg): print(f"{BLUE}ℹ  {msg}{RESET}")
def head(msg): print(f"\n{BOLD}{CYAN}{'─'*55}{RESET}\n{BOLD}{CYAN}  {msg}{RESET}\n{BOLD}{CYAN}{'─'*55}{RESET}")

# ── Test parametreleri ────────────────────────────────────
LINE_CODE    = "SAMULAŞ EKSPRES D"
LINE_CODE_ENC = quote(LINE_CODE)
STOP_ID      = "6119"
TODAY        = datetime.now().strftime("%Y-%m-%dT00:00:00")
TODAY_ENC    = quote(TODAY)

# ── Direkt API ────────────────────────────────────────────
DIRECT_BASE = "https://api.samsun.bel.tr/OHSSoapToJson/api/Asis"

ENDPOINTS = {
    "StopsStations":  f"{DIRECT_BASE}/StopsStations?lineCode={LINE_CODE_ENC}",
    "SmartStations":  f"{DIRECT_BASE}/SmartStations?stationId={STOP_ID}",
    "LineDirections": f"{DIRECT_BASE}/LineDirections?lineCode={LINE_CODE_ENC}",
    "RealTimeData":   f"{DIRECT_BASE}/RealTimeData?lineCode={LINE_CODE_ENC}",
    "Schedules":      f"{DIRECT_BASE}/Schedules?lineCode={LINE_CODE_ENC}&scheduleDate={TODAY_ENC}",
}

# ── Proxy URL'yi api_service.dart'tan otomatik bul ────────
def find_proxy_base():
    search_paths = [
        os.path.expanduser("~/Samsun-mobil/lib/services/api_service.dart"),
        os.path.expanduser("~/Samsun-mobil/samsun_mobil_app/lib/services/api_service.dart"),
        "lib/services/api_service.dart",
    ]

    # Klasik arama
    for path in search_paths:
        if os.path.exists(path):
            info(f"api_service.dart bulundu: {path}")
            with open(path, "r") as f:
                content = f.read()

            # Base URL pattern'larını ara
            patterns = [
                r'baseUrl\s*=\s*["\']([^"\']+)["\']',
                r'_baseUrl\s*=\s*["\']([^"\']+)["\']',
                r'BASE_URL\s*=\s*["\']([^"\']+)["\']',
                r'apiBase\s*=\s*["\']([^"\']+)["\']',
                r'https?://[^\s"\']+(?:proxy|api|backend)[^\s"\']*',
                r'"(https?://[^"]+)"',
                r"'(https?://[^']+)'",
            ]

            for pattern in patterns:
                matches = re.findall(pattern, content, re.IGNORECASE)
                for match in matches:
                    if "samsun" in match.lower() or "api" in match.lower():
                        if match != DIRECT_BASE and "bel.tr/OHSSoapToJson" not in match:
                            return match.rstrip("/")

            # Tüm URL'leri göster
            all_urls = re.findall(r'["\']?(https?://[^\s"\'<>]+)["\']?', content)
            unique_urls = list(set(all_urls))
            if unique_urls:
                print(f"\n{YELLOW}  api_service.dart içindeki tüm URL'ler:{RESET}")
                for u in unique_urls:
                    print(f"    {u}")

    return None

# ── Endpoint eşleme (proxy için) ──────────────────────────
def build_proxy_endpoints(proxy_base):
    """Proxy base URL'ye göre endpoint'leri oluştur."""
    # Yaygın proxy pattern'ları dene
    variants = [
        # Direkt yönlendirme
        {
            "StopsStations":  f"{proxy_base}/StopsStations?lineCode={LINE_CODE_ENC}",
            "SmartStations":  f"{proxy_base}/SmartStations?stationId={STOP_ID}",
            "LineDirections": f"{proxy_base}/LineDirections?lineCode={LINE_CODE_ENC}",
            "RealTimeData":   f"{proxy_base}/RealTimeData?lineCode={LINE_CODE_ENC}",
            "Schedules":      f"{proxy_base}/Schedules?lineCode={LINE_CODE_ENC}&scheduleDate={TODAY_ENC}",
        },
        # /Asis/ prefix'li
        {
            "StopsStations":  f"{proxy_base}/Asis/StopsStations?lineCode={LINE_CODE_ENC}",
            "SmartStations":  f"{proxy_base}/Asis/SmartStations?stationId={STOP_ID}",
            "LineDirections": f"{proxy_base}/Asis/LineDirections?lineCode={LINE_CODE_ENC}",
            "RealTimeData":   f"{proxy_base}/Asis/RealTimeData?lineCode={LINE_CODE_ENC}",
            "Schedules":      f"{proxy_base}/Asis/Schedules?lineCode={LINE_CODE_ENC}&scheduleDate={TODAY_ENC}",
        },
    ]
    return variants

# ── Tek endpoint test ─────────────────────────────────────
def test_endpoint(name, url, timeout=10):
    print(f"\n  {BOLD}{name}{RESET}")
    print(f"  {BLUE}URL: {url}{RESET}")
    try:
        r = requests.get(url, timeout=timeout, headers={
            "Accept": "application/json",
            "User-Agent": "SamsunMobil/1.0"
        })
        status = r.status_code

        if status == 200:
            try:
                data = r.json()
                item_count = len(data.get("data", data if isinstance(data, list) else []))
                ok(f"HTTP {status} — {item_count} kayıt")

                # İlk 2 kaydı göster
                records = data.get("data", data if isinstance(data, list) else [])
                if records and isinstance(records, list):
                    for i, rec in enumerate(records[:2]):
                        print(f"  {CYAN}  [{i+1}] {json.dumps(rec, ensure_ascii=False)}{RESET}")
                    if len(records) > 2:
                        print(f"  {CYAN}  ... ({len(records)-2} daha){RESET}")
                return True, status, item_count
            except Exception:
                ok(f"HTTP {status} — JSON değil, ham yanıt")
                print(f"  {CYAN}  {r.text[:200]}{RESET}")
                return True, status, 0
        else:
            err(f"HTTP {status}")
            print(f"  {RED}  {r.text[:200]}{RESET}")
            return False, status, 0

    except requests.exceptions.ConnectionError:
        err("Bağlantı hatası — sunucu erişilemiyor")
        return False, 0, 0
    except requests.exceptions.Timeout:
        err(f"Zaman aşımı ({timeout}s)")
        return False, 0, 0
    except Exception as e:
        err(f"Hata: {e}")
        return False, 0, 0

# ── Ana test akışı ────────────────────────────────────────
def main():
    print(f"\n{BOLD}{CYAN}{'═'*55}{RESET}")
    print(f"{BOLD}{CYAN}  Samsun Transit API Test Suite{RESET}")
    print(f"{BOLD}{CYAN}{'═'*55}{RESET}")
    print(f"  Hat Kodu : {LINE_CODE}")
    print(f"  Durak ID : {STOP_ID}")
    print(f"  Tarih    : {TODAY[:10]}")
    print(f"{BOLD}{CYAN}{'═'*55}{RESET}\n")

    results = {}

    # ── 1. Direkt API Testleri ────────────────────────────
    head("1. DİREKT API TESTLERİ")
    direct_results = {}
    for name, url in ENDPOINTS.items():
        success, code, count = test_endpoint(name, url)
        direct_results[name] = {"ok": success, "code": code, "count": count}

    results["direct"] = direct_results

    # ── 2. Proxy Tespiti ──────────────────────────────────
    head("2. PROXY TESPİTİ")
    proxy_base = find_proxy_base()

    if not proxy_base:
        warn("api_service.dart'ta proxy URL bulunamadı.")
        warn("Manuel girmek ister misin? (boş bırak = atla)")
        try:
            manual = input("  Proxy base URL: ").strip()
            proxy_base = manual if manual else None
        except (EOFError, KeyboardInterrupt):
            proxy_base = None

    if proxy_base:
        ok(f"Proxy base URL: {proxy_base}")

        # ── 3. Proxy Testleri ─────────────────────────────
        head("3. PROXY API TESTLERİ")
        variants = build_proxy_endpoints(proxy_base)

        for i, variant in enumerate(variants):
            print(f"\n{YELLOW}  Variant {i+1} ({list(variant.values())[0]}){RESET}")
            # Sadece ilk endpoint'i test et (proxy var mı diye)
            first_name = list(variant.keys())[0]
            success, code, _ = test_endpoint(first_name, variant[first_name])
            if success:
                ok(f"Variant {i+1} çalışıyor! Tüm endpoint'ler test ediliyor...")
                proxy_results = {}
                for name, url in variant.items():
                    s, c, cnt = test_endpoint(name, url)
                    proxy_results[name] = {"ok": s, "code": c, "count": cnt}
                results["proxy"] = proxy_results
                break
        else:
            err("Hiçbir proxy variant'ı çalışmadı.")
    else:
        warn("Proxy testi atlandı.")

    # ── Özet ──────────────────────────────────────────────
    head("ÖZET")
    print(f"{'Endpoint':<22} {'Direkt':^10} {'Proxy':^10}")
    print("─" * 45)
    for name in ENDPOINTS:
        d = results.get("direct", {}).get(name, {})
        p = results.get("proxy",  {}).get(name, {})
        d_str = f"{GREEN}✅ {d.get('count','-')}{RESET}" if d.get("ok") else f"{RED}❌{RESET}"
        p_str = f"{GREEN}✅ {p.get('count','-')}{RESET}" if p.get("ok") else (f"{YELLOW}—{RESET}" if not p else f"{RED}❌{RESET}")
        print(f"  {name:<22} {d_str:^18} {p_str:^18}")

    print(f"\n{BOLD}Tüm testler tamamlandı.{RESET}\n")

if __name__ == "__main__":
    main()
