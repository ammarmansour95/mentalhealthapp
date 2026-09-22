class NativeNotificationPlatform {
  static Future<String> requestPermission() async {
    return 'unsupported';
  }

  static bool showNotification({
    required String title,
    required String body,
    String tag = 'general',
  }) {
    return false;
  }
}
