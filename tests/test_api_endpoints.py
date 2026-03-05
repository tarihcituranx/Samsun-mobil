#!/usr/bin/env python3
"""
Samsun Mobil — API Endpoint Kapsamlı Test Suite

İki modda çalışır:
  1. OFFLINE (varsayılan, CI): Dart kod yapısını doğrular — proxy eşleşmeleri,
     alan adları, tip dönüşümleri, fiyat servisi, test helper'lar.
  2. ONLINE (yerel, Türkiye): Gerçek API endpoint'lerini test eder.
     Sadece `RUN_ONLINE_TESTS=1` ortam değişkeni ile aktif olur.
     (ASIS API yalnızca Türkiye'den erişilebilir, GitHub Actions çalıştıramaz.)

Kullanım:
    python3 tests/test_api_endpoints.py                     # Sadece offline
    RUN_ONLINE_TESTS=1 python3 tests/test_api_endpoints.py  # Online + offline

Çıktı: tests/test_results.json
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
import urllib.parse
import unittest
from datetime import datetime

BASE = "https://samsun-gtfs-rt.onrender.com/api"
RESULTS = []
REQUEST_DELAY = 1.5  # saniye — rate limit önleme
ONLINE_ENABLED = os.environ.get("RUN_ONLINE_TESTS", "").strip() == "1"
SERVER_REACHABLE = None  # lazy check


def _check_server():
    """Sunucuya ulaşılabiliyor mu?"""
    global SERVER_REACHABLE
    if SERVER_REACHABLE is not None:
        return SERVER_REACHABLE
    try:
        req = urllib.request.Request(f"{BASE}/health", headers={
            "User-Agent": "samsun_test/1.0"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            SERVER_REACHABLE = resp.status == 200
    except Exception:
        SERVER_REACHABLE = False
    return SERVER_REACHABLE


def api_get(path, timeout=15):
    """GET isteği yap, JSON parse et, hata varsa None dön."""
    url = f"{BASE}{path}"
    req = urllib.request.Request(url, headers={
        "User-Agent": "samsun_ulasim_test/1.0",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            data = json.loads(raw.decode("utf-8"))
            return resp.status, data
    except urllib.error.HTTPError as e:
        return e.code, None
    except Exception as e:
        return 0, str(e)


def record(name, status, ok, detail=""):
    """Test sonucunu kaydet."""
    RESULTS.append({
        "test": name,
        "status": status,
        "ok": ok,
        "detail": detail,
        "time": datetime.now().isoformat(),
    })


def _extract_list(data):
    """ASIS zarflı veya düz liste çıkar."""
    if isinstance(data, dict) and "data" in data:
        return data["data"] if data["data"] else []
    if isinstance(data, list):
        return data
    return []


def _get_first_hat_code(hatlar):
    """Hat listesinden ilk hat kodunu çıkar (farklı formatları destekler)."""
    if not hatlar or not isinstance(hatlar, list):
        return None
    first = hatlar[0]
    if isinstance(first, dict):
        return first.get("code") or first.get("lineCode") or first.get("hat_code")
    return None


def _require_server(test_func):
    """Sunucuya erişim gerekli testler için dekoratör.
    ASIS API sadece Türkiye'den erişilebilir — CI'da her zaman atlanır.
    Yerel çalıştırmak için: RUN_ONLINE_TESTS=1 python3 tests/test_api_endpoints.py
    """
    def wrapper(self):
        if not ONLINE_ENABLED:
            self.skipTest("Online testler devre dışı (RUN_ONLINE_TESTS=1 ile aktif et)")
        if not _check_server():
            self.skipTest("API sunucusu erişilemez (Türkiye dışından çalışıyor olabilirsiniz)")
        return test_func(self)
    wrapper.__name__ = test_func.__name__
    wrapper.__doc__ = test_func.__doc__
    return wrapper


class TestProxyEndpoints(unittest.TestCase):
    """Render proxy endpoint'lerini test eder."""

    # ── 1. Sağlık Kontrolü ──────────────────────────────────
    @_require_server
    def test_01_health(self):
        """GET /api/health — Sunucu durumu"""
        code, data = api_get("/health")
        self.assertEqual(code, 200, f"Health endpoint HTTP {code}")
        self.assertIsInstance(data, dict)
        record("health", code, True, str(data))
        time.sleep(REQUEST_DELAY)

    # ── 2. Tüm Hatlar (DB) ──────────────────────────────────
    @_require_server
    def test_02_hatlar(self):
        """GET /api/hat — Tüm hat listesi"""
        code, data = api_get("/hat")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        self.assertGreater(len(items), 0, "Hat listesi boş")
        first = items[0]
        if isinstance(first, dict):
            has_code = "code" in first or "lineCode" in first
            self.assertTrue(has_code, f"Hat kaydında code alanı yok: {first.keys()}")
        record("hat", code, True, f"{len(items)} hat")
        time.sleep(REQUEST_DELAY)

    # ── 3. SmartStations (Durağa Yaklaşan Araçlar) ───────────
    @_require_server
    def test_03_smart_stations(self):
        """GET /api/proxy/smart_stations?stationId={id}"""
        code, data = api_get("/proxy/smart_stations?stationId=6119")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        record("smart_stations", code, True, f"{len(items)} araç")
        time.sleep(REQUEST_DELAY)

    # ── 4. RealTimeData (Canlı Araç Takibi) ──────────────────
    @_require_server
    def test_04_realtime(self):
        """GET /api/proxy/realtime?lineCode={code} — Canlı araç"""
        _, hatlar_raw = api_get("/hat")
        hatlar = _extract_list(hatlar_raw)
        hat_code = _get_first_hat_code(hatlar)
        if not hat_code:
            self.skipTest("Hat kodu alınamadı")
        time.sleep(REQUEST_DELAY)

        code, data = api_get(f"/proxy/realtime?lineCode={urllib.parse.quote(hat_code)}")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        if items and isinstance(items[0], dict):
            keys = set(items[0].keys())
            rt_fields = {"enlem", "boylam", "plaka", "hiz"}
            found = keys & rt_fields
            record("realtime", code, True,
                   f"{len(items)} araç, RT alanlar: {found}")
        else:
            record("realtime", code, True, f"0 araç (hat: {hat_code})")
        time.sleep(REQUEST_DELAY)

    # ── 5. hat/arac (DB eşleşmeli canlı araç) ────────────────
    @_require_server
    def test_05_hat_arac(self):
        """GET /api/hat/arac/{code} — DB eşleşmeli canlı araç"""
        _, hatlar_raw = api_get("/hat")
        hatlar = _extract_list(hatlar_raw)
        hat_code = _get_first_hat_code(hatlar)
        if not hat_code:
            self.skipTest("Hat kodu alınamadı")
        time.sleep(REQUEST_DELAY)

        code, data = api_get(f"/hat/arac/{urllib.parse.quote(hat_code)}")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        record("hat_arac", code, True, f"{len(items)} araç (hat: {hat_code})")
        time.sleep(REQUEST_DELAY)

    # ── 6. StopsStations (Durak Listesi) ──────────────────────
    @_require_server
    def test_06_stops_stations(self):
        """GET /api/proxy/stops_stations?lineCode={code}"""
        _, hatlar_raw = api_get("/hat")
        hatlar = _extract_list(hatlar_raw)
        hat_code = _get_first_hat_code(hatlar)
        if not hat_code:
            self.skipTest("Hat kodu alınamadı")
        time.sleep(REQUEST_DELAY)

        code, data = api_get(f"/proxy/stops_stations?lineCode={urllib.parse.quote(hat_code)}")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        if items and isinstance(items[0], dict):
            for field in ["stopId", "stopName"]:
                self.assertIn(field, items[0], f"'{field}' alanı yok")
        record("stops_stations", code, True, f"{len(items)} durak")
        time.sleep(REQUEST_DELAY)

    # ── 7. Schedules (Sefer Saatleri) ─────────────────────────
    @_require_server
    def test_07_schedules(self):
        """GET /api/proxy/schedules?lineCode={code}&scheduleDate={date}"""
        _, hatlar_raw = api_get("/hat")
        hatlar = _extract_list(hatlar_raw)
        hat_code = _get_first_hat_code(hatlar)
        if not hat_code:
            self.skipTest("Hat kodu alınamadı")
        today = datetime.now().strftime("%Y-%m-%d")
        time.sleep(REQUEST_DELAY)

        code, data = api_get(
            f"/proxy/schedules?lineCode={urllib.parse.quote(hat_code)}&scheduleDate={today}")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        record("schedules", code, True, f"{len(items)} sefer")
        time.sleep(REQUEST_DELAY)

    # ── 8. Yakın Duraklar ────────────────────────────────────
    @_require_server
    def test_08_yakin_duraklar(self):
        """GET /api/yakin?lat={lat}&lon={lon}"""
        code, data = api_get("/yakin?lat=41.2867&lon=36.3300")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        record("yakin_duraklar", code, True, f"{len(items)} yakın durak")
        time.sleep(REQUEST_DELAY)

    # ── 9. Odak Hatlar ───────────────────────────────────────
    @_require_server
    def test_09_odak(self):
        """GET /api/odak"""
        code, data = api_get("/odak")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        record("odak", code, True, f"{len(items)} odak hat")
        time.sleep(REQUEST_DELAY)

    # ── 10. Samair Hatlar ─────────────────────────────────────
    @_require_server
    def test_10_samair(self):
        """GET /api/samair"""
        code, data = api_get("/samair")
        self.assertEqual(code, 200)
        items = _extract_list(data)
        record("samair", code, True, f"{len(items)} samair hat")
        time.sleep(REQUEST_DELAY)


class TestDartCodeStructure(unittest.TestCase):
    """api_service.dart proxy eşleşmelerini offline doğrular."""

    def setUp(self):
        repo = os.environ.get("REPO_DIR",
                              os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        self.api_path = os.path.join(repo, "lib", "services", "api_service.dart")
        with open(self.api_path, "r", encoding="utf-8") as f:
            self.code = f.read()

    def test_base_url(self):
        """Base URL: samsun-gtfs-rt.onrender.com/api"""
        self.assertIn("samsun-gtfs-rt.onrender.com/api", self.code)
        record("dart_base_url", 200, True, "Base URL doğru")

    def test_proxy_smart_stations(self):
        """proxy/smart_stations endpoint var"""
        self.assertIn("proxy/smart_stations", self.code)
        record("dart_smart_stations", 200, True)

    def test_proxy_realtime(self):
        """proxy/realtime endpoint var"""
        self.assertIn("proxy/realtime", self.code)
        record("dart_realtime", 200, True)

    def test_proxy_stops_stations(self):
        """proxy/stops_stations endpoint var"""
        self.assertIn("proxy/stops_stations", self.code)
        record("dart_stops_stations", 200, True)

    def test_proxy_line_directions(self):
        """proxy/line_directions endpoint var"""
        self.assertIn("proxy/line_directions", self.code)
        record("dart_line_directions", 200, True)

    def test_proxy_schedules(self):
        """proxy/schedules endpoint var"""
        self.assertIn("proxy/schedules", self.code)
        record("dart_schedules", 200, True)

    def test_parse_vehicles_lat_lon(self):
        """_parseVehicles: enlem/boylam doğru parse"""
        self.assertIn("'enlem'", self.code, "enlem alanı _parseVehicles'da yok")
        self.assertIn("'boylam'", self.code, "boylam alanı _parseVehicles'da yok")
        record("dart_rt_latlon", 200, True)

    def test_parse_vehicles_fields(self):
        """_parseVehicles: tüm RT alanları mevcut"""
        fields = ["plaka", "hiz", "HatKodu", "seferYolcu",
                  "gunlukYolcu", "toplamHasilat", "maxHiz", "mesafe"]
        missing = [f for f in fields if f"'{f}'" not in self.code]
        self.assertEqual(missing, [], f"Eksik RT alanları: {missing}")
        record("dart_rt_fields", 200, True, f"Tüm {len(fields)} alan mevcut")

    def test_smart_station_type_parsing(self):
        """getDuragaYaklasanAraclar: string→number dönüşümü"""
        # RemainingTimeCurr'un int.tryParse ile parse edildiğini doğrula
        self.assertIn("int.tryParse", self.code)
        self.assertIn("double.tryParse", self.code)
        record("dart_type_parsing", 200, True)

    def test_skip_keywords(self):
        """_skipKeywords: OTOPARK, KENT MÜZESİ vb. filtreler"""
        for kw in ["OTOPARK", "KENT MÜZESİ"]:
            self.assertIn(kw, self.code, f"_skipKeywords: '{kw}' eksik")
        record("dart_skip_keywords", 200, True)

    def test_test_helpers_exist(self):
        """Test helper metotları mevcut"""
        helpers = [
            "parseRealTimeDataForTest",
            "cleanSmartStationDataForTest",
            "extractDataListForTest",
            "fixAndCleanTextForTest",
        ]
        missing = [h for h in helpers if h not in self.code]
        self.assertEqual(missing, [], f"Eksik test helpers: {missing}")
        record("dart_test_helpers", 200, True, f"Tüm {len(helpers)} helper mevcut")

    def test_coordinate_validation(self):
        """Samsun koordinat doğrulaması (40-43 enlem, 34-38 boylam)"""
        # _parseVehicles'da lat/lon filtresi var mı?
        self.assertTrue(
            re.search(r'lat\s*[<>]', self.code) or
            re.search(r'40\.0|43\.0|34\.0|38\.0', self.code),
            "Koordinat doğrulaması bulunamadı"
        )
        record("dart_coord_validation", 200, True)

    def test_no_update_checker_import(self):
        """update_checker.dart import'u kalmamış olmalı"""
        dart_files = []
        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        for root, _, files in os.walk(os.path.join(repo, "lib")):
            for f in files:
                if f.endswith(".dart"):
                    dart_files.append(os.path.join(root, f))
        for fp in dart_files:
            with open(fp, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertNotIn("update_checker.dart", content,
                             f"{fp}: update_checker.dart import'u hâlâ var!")
        record("dart_no_update_checker", 200, True)

    def test_price_service_static(self):
        """price_service.dart: sabit fiyat tablosu, GitHub fetch yok"""
        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        ps = os.path.join(repo, "lib", "services", "price_service.dart")
        with open(ps, "r", encoding="utf-8") as f:
            pcode = f.read()
        # GitHub URL olmamalı
        self.assertNotIn("raw.githubusercontent.com", pcode,
                         "price_service hâlâ GitHub'dan fiyat çekiyor")
        # Sabit fiyat tablosu olmalı
        self.assertIn("_staticPrices", pcode, "Sabit fiyat tablosu yok")
        # Odak/samair proxy'den çekilmeli
        self.assertIn("odak", pcode)
        self.assertIn("samair", pcode)
        record("dart_price_static", 200, True)


def main():
    """Testleri çalıştır ve sonuçları kaydet."""
    print("=" * 60)
    print("  Samsun Mobil — API Endpoint Test Suite")
    print(f"  Base URL: {BASE}")
    print(f"  Zaman: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Sunucu: {'Erişilebilir' if _check_server() else 'Erişilemez (offline mod)'}")
    print("=" * 60)
    print()

    # unittest çalıştır
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(TestDartCodeStructure))
    suite.addTests(loader.loadTestsFromTestCase(TestProxyEndpoints))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Sonuçları dosyaya yaz
    output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_results.json")
    summary = {
        "timestamp": datetime.now().isoformat(),
        "base_url": BASE,
        "server_reachable": SERVER_REACHABLE,
        "total": result.testsRun,
        "failures": len(result.failures),
        "errors": len(result.errors),
        "skipped": len(result.skipped),
        "success": result.testsRun - len(result.failures) - len(result.errors) - len(result.skipped),
        "results": RESULTS,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    print()
    print("=" * 60)
    total = summary["total"]
    ok = summary["success"]
    fail = summary["failures"] + summary["errors"]
    skip = summary["skipped"]
    print(f"  SONUÇ: {ok}/{total} başarılı | {fail} hata | {skip} atlanan")
    print(f"  Detay: {output_path}")
    print("=" * 60)

    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
