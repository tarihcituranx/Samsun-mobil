import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _versionJsonUrl =
      'https://github.com/tarihcituranx/test/raw/main/releases/version.json';

  /// Uygulama açılışında çağrılır. Network yoksa sessizce geçer.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http
          .get(Uri.parse(_versionJsonUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final int latestCode = data['versionCode'] ?? 0;
      final String latestVersion = data['latestVersion'] ?? '';
      final String apkUrl = data['apkUrl'] ?? '';
      final String releaseNotes = data['releaseNotes'] ?? '';
      final bool forceUpdate = data['forceUpdate'] ?? false;

      final PackageInfo info = await PackageInfo.fromPlatform();
      final int currentCode = int.tryParse(info.buildNumber) ?? 0;

      debugPrint('UpdateService — Mevcut: $currentCode | Sunucu: $latestCode');

      if (latestCode <= currentCode) return;
      if (!context.mounted) return;

      if (context.mounted) {
        _showUpdateDialog(context,
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            apkUrl: apkUrl,
            forceUpdate: forceUpdate);
      }
    } catch (e) {
      // UPD-7: Network yoksa sessizce geç
      debugPrint('UpdateService kontrol hatası (sessiz): $e');
    }
  }

  static void _showUpdateDialog(BuildContext context,
      {required String latestVersion,
      required String releaseNotes,
      required String apkUrl,
      required bool forceUpdate}) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.system_update, color: Color(0xFF0D47A1)),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Yeni Sürüm: $latestVersion',
                    style: const TextStyle(fontSize: 16))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(releaseNotes),
              const SizedBox(height: 8),
              const Text(
                  'Güncellemeyi yüklemek için "Güncelle" butonuna basın.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
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
              label: const Text('Güncelle'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _downloadWithProgress(context, apkUrl);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// APK'yı arka planda indir, progress bar göster
  static Future<void> _downloadWithProgress(
      BuildContext context, String apkUrl) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('İndiriliyor...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.downloading, color: Color(0xFF0D47A1)),
            SizedBox(width: 8),
            Text('Güncelleme İndiriliyor', style: TextStyle(fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, value, __) => Column(children: [
                  LinearProgressIndicator(
                      value: value > 0 ? value : null,
                      backgroundColor: Colors.grey.shade300,
                      color: const Color(0xFF0D47A1)),
                  const SizedBox(height: 8),
                  Text('${(value * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (_, value, __) => Text(value,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 120));
      final contentLength = streamedResponse.contentLength ?? 0;

      final tempDir = Directory.systemTemp;
      final filePath = p.join(tempDir.path, 'samsun_update.apk');
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          progressNotifier.value = received / contentLength;
        }
        statusNotifier.value =
            '${(received / 1024 / 1024).toStringAsFixed(1)} MB indirildi';
      }

      await sink.close();
      progressNotifier.value = 1.0;
      statusNotifier.value = 'İndirme tamamlandı, kuruluyor...';

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      await _installApk(filePath);
    } catch (e) {
      debugPrint('APK indirme hatası: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Güncelleme indirilemedi. Lütfen tekrar deneyin.')),
        );
      }
    }
  }

  /// İndirilen APK'yı FileProvider ile aç (UPD-5)
  static Future<void> _installApk(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('APK dosyası açılamadı: $filePath');
      }
    } catch (e) {
      debugPrint('APK kurulum hatası: $e');
    }
  }
}
