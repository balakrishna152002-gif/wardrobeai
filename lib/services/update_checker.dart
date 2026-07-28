import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String notes;

  const UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.notes,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      versionName: json['versionName'] as String? ?? '',
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      apkUrl: json['apkUrl'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Checks a hosted `version.json` manifest against the installed app's own
/// build number to decide whether a newer APK is available.
class UpdateChecker {
  static const _manifestUrl = 'https://wardrob-ai.web.app/version.json';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_manifestUrl))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final remote = UpdateInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      final info = await PackageInfo.fromPlatform();
      final installedCode = int.tryParse(info.buildNumber) ?? 0;

      return remote.versionCode > installedCode ? remote : null;
    } catch (_) {
      // Offline, manifest unreachable, or malformed - just skip the check.
      return null;
    }
  }
}
