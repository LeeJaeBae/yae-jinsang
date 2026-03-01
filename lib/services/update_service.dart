import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const _repo = 'LeeJaeBae/yae-jinsang';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';
  static const _downloadUrl = 'https://github.com/$_repo/releases/latest/download/app-release.apk';

  /// 최신 버전 확인, 업데이트 있으면 다이얼로그 표시
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final latestTag = (data['tag_name'] as String?)?.replaceFirst('v', '') ?? '';

      if (latestTag.isEmpty) return;
      if (!_isNewerVersion(latestTag, currentVersion)) return;

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('🆕 업데이트 알림'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v$currentVersion → v$latestTag',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF3B30),
                ),
              ),
              const SizedBox(height: 12),
              if (data['body'] != null && (data['body'] as String).isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data['body'],
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                '최신 버전으로 업데이트하면\n새로운 기능과 버그 수정을 받을 수 있습니다.',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('나중에', style: TextStyle(color: Colors.white38)),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final uri = Uri.parse(_downloadUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {
                  final pageUri = Uri.parse('https://github.com/$_repo/releases/latest');
                  await launchUrl(pageUri, mode: LaunchMode.externalApplication);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('업데이트'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('업데이트 확인 실패: $e');
    }
  }

  /// 현재 앱 버전 가져오기
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// 버전 비교 (semver)
  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final l = (i < latestParts.length ? latestParts[i] : 0) ?? 0;
      final c = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}
