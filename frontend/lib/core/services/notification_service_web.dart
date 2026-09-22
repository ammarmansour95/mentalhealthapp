import 'dart:js_interop';

@JS('requestDeviceNotificationPermission')
external JSPromise<JSString> _requestPermissionJS();

@JS('showDeviceNotification')
external JSBoolean _showNotificationJS(JSString title, JSString body, JSString tag);

class NativeNotificationPlatform {
  static Future<String> requestPermission() async {
    try {
      final res = await _requestPermissionJS().toDart;
      return res.toDart;
    } catch (e) {
      return 'denied';
    }
  }

  static bool showNotification({
    required String title,
    required String body,
    String tag = 'general',
  }) {
    try {
      final res = _showNotificationJS(title.toJS, body.toJS, tag.toJS);
      return res.toDart;
    } catch (e) {
      return false;
    }
  }
}
