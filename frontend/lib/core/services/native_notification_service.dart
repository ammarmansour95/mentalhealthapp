import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service_stub.dart'
    if (dart.library.js_interop) 'notification_service_web.dart';

class NativeNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initialize native notification channels and settings
  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
      );
      _isInitialized = true;
      debugPrint('[NativeNotification] Local notifications initialized successfully');
    } catch (e) {
      debugPrint('[NativeNotification] Error initializing notifications: $e');
    }
  }

  /// Request browser / device notification permission
  static Future<String> requestPermission() async {
    if (kIsWeb) {
      try {
        final perm = await NativeNotificationPlatform.requestPermission();
        debugPrint('[NativeNotification] Web Permission: $perm');
        return perm;
      } catch (e) {
        return 'denied';
      }
    }

    try {
      await initialize();
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        debugPrint('[NativeNotification] Android Permission granted: $granted');
        return granted == true ? 'granted' : 'denied';
      }
      return 'granted';
    } catch (e) {
      debugPrint('[NativeNotification] Error requesting permission: $e');
      return 'denied';
    }
  }

  /// Trigger a native device push notification banner + sound
  static Future<bool> showNotification({
    required String title,
    required String body,
    String tag = 'general',
  }) async {
    if (kIsWeb) {
      try {
        return NativeNotificationPlatform.showNotification(
          title: title,
          body: body,
          tag: tag,
        );
      } catch (e) {
        return false;
      }
    }

    try {
      await initialize();
      final bool isCrisis = tag == 'crisis' || tag == 'emergency';

      final androidDetails = AndroidNotificationDetails(
        isCrisis ? 'crisis_alerts_channel' : 'general_notifications_channel',
        isCrisis ? 'تنبيهات الطوارئ والحالات الحرجة' : 'إشعارات المواعيد والتنبيهات العامة',
        channelDescription: isCrisis
            ? 'تنبيهات عاجلة للحالات النفسية الحرجة وإشارات الخطر'
            : 'إشعارات تأكيد المواعيد، التذكيرات، والرسائل السريرية',
        importance: isCrisis ? Importance.max : Importance.high,
        priority: isCrisis ? Priority.max : Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
      );
      return true;
    } catch (e) {
      debugPrint('[NativeNotification] Error displaying native notification: $e');
      return false;
    }
  }
}
