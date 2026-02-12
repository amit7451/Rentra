import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('android')
          .get();

      if (!doc.exists) return null;

      final latestVersion = doc['latest_version'];
      final apkUrl = doc['apk_url'];
      final forceUpdate = doc['force_update'] ?? false;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (latestVersion != currentVersion) {
        return {
          'needs_update': true,
          'apk_url': apkUrl,
          'force_update': forceUpdate,
        };
      }
      return {'needs_update': false};
    } catch (e) {
      debugPrint("Update check failed: $e");
      return null;
    }
  }

  static void showUpdateDialog(
    BuildContext context,
    String apkUrl,
    bool forceUpdate,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (_) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          title: const Text("Update Available"),
          content: const Text(
            "A new version of the app is available. Please update to continue.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                launchUrl(
                  Uri.parse(apkUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }
}
