import 'package:flutter/foundation.dart';
import 'notification_service_stub.dart'
    if (dart.library.js_interop) 'notification_service_web.dart';

class NativeNotificationService {
  static bool permissionRequested = false;
  static bool hasAsked = false;

  /// Request browser/device notification permission
  static Future<String> requestPermission() async {
    if (!kIsWeb) return 'unsupported';
    hasAsked = true;
    try {
      final perm = await NativeNotificationPlatform.requestPermission();
      debugPrint('[NativeNotification] Permission result: $perm');
      return perm;
    } catch (e) {
      debugPrint('[NativeNotification] Error requesting permission: $e');
      return 'denied';
    }
  }

  /// Trigger a native device notification banner + sound
  static bool showNotification({
    required String title,
    required String body,
    String tag = 'general',
  }) {
    if (!kIsWeb) return false;
    try {
      return NativeNotificationPlatform.showNotification(
        title: title,
        body: body,
        tag: tag,
      );
    } catch (e) {
      debugPrint('[NativeNotification] Error showing notification: $e');
      return false;
    }
  }
}
