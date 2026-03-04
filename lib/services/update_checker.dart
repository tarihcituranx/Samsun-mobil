import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

// ── Ayarlar ──────────────────────────────────────────────
const String VERSION_JSON_URL =
    'https://github.com/tarihcituranx/test/raw/main/releases/version.json';

// ─────────────────────────────────────────────────────────
class UpdateChecker {
  /// Uygulama başlangıcında çağır.
  /// [context] dialog göstermek için gerekli.
  /// [forceCheck] true ise her seferinde kontrol eder.
  static Future<void> check(BuildContext context,
      {bool forceCheck = false}) async {
    try {
      // Sunucudaki version.json'ı çek
      final response = await http
          .get(Uri.parse(VERSION_JSON_URL))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final int latestCode = data['versionCode'] ?? 0;
      final String latestVersion = data['latestVersion'] ?? '';
      final String apkUrl = data['apkUrl'] ?? '';
      final String releaseNotes = data['releaseNotes'] ?? '';
      final bool forceUpdate = data['forceUpdate'] ?? false;

      // Mevcut sürümü al
      final PackageInfo info = await PackageInfo.fromPlatform();
      final int currentCode = int.tryParse(info.buildNumber) ?? 0;

      debugPrint('Mevcut build: $currentCode | Sunucu: $latestCode');

      if (latestCode <= currentCode) return; // Güncelleme yok

      // Güncelleme diyalogu göster
      if (context.mounted) {
        _showUpdateDialog(
          context,
          latestVersion: latestVersion,
          releaseNotes: releaseNotes,
          apkUrl: apkUrl,
          forceUpdate: forceUpdate,
        );
      }
    } catch (e) {
      debugPrint('Güncelleme kontrolü başarısız: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String releaseNotes,
    required String apkUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFF0D47A1)),
            const SizedBox(width: 8),
            Text('Yeni Sürüm: $latestVersion'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(releaseNotes),
            const SizedBox(height: 8),
            const Text(
              'Güncellemeyi yüklemek için "İndir" butonuna basın.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Sonra'),
            ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('İndir ve Güncelle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _downloadAndInstall(apkUrl);
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(String apkUrl) async {
    final uri = Uri.parse(apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
