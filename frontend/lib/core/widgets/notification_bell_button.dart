import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/services/native_notification_service.dart';
import 'package:frontend/core/widgets/notification_sheet.dart';

class NotificationBellButton extends StatefulWidget {
  final VoidCallback? onOpened;
  const NotificationBellButton({super.key, this.onOpened});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount(isInitial: true);
    // Request device notification permission on dashboard load
    NativeNotificationService.requestPermission();
    // Poll for notifications every 4 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchUnreadCount(isInitial: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadCount({bool isInitial = false}) async {
    try {
      final res = await ApiService.get('/notifications/unread-count/');
      if (res['success'] == true && mounted) {
        final newCount = res['unread_count'] as int? ?? 0;
        if (!isInitial && newCount > _unreadCount) {
          // New notification arrived! Fetch latest to show native notification banner
          _showNativeAlertForNewNotification();
        }
        setState(() {
          _unreadCount = newCount;
        });
      }
    } catch (_) {}
  }

  Future<void> _showNativeAlertForNewNotification() async {
    try {
      final res = await ApiService.get('/notifications/');
      if (res['success'] == true && res['notifications'] != null) {
        final list = res['notifications'] as List;
        final unreadList = list.where((n) => n['is_read'] == false).toList();
        if (unreadList.isNotEmpty) {
          final top = unreadList.first;
          final type = top['notification_type'] ?? '';
          final title = top['title'] ?? 'إشعار جديد';
          final message = top['message'] ?? '';
          final tag = (type == 'CRISIS_ALERT' || type == 'EMERGENCY') ? 'crisis' : 'general';

          NativeNotificationService.showNotification(
            title: title,
            body: message,
            tag: tag,
          );
        }
      }
    } catch (_) {}
  }

  void _openNotifications() {
    NativeNotificationService.requestPermission();
    NotificationSheet.show(
      context,
      onUpdated: () {
        _fetchUnreadCount();
        widget.onOpened?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openNotifications,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: (_unreadCount > 0 ? AppTheme.alertRose : AppTheme.slateNavy).withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              _unreadCount > 0 ? Icons.notifications_active : Icons.notifications_none_outlined,
              size: 20,
              color: _unreadCount > 0 ? AppTheme.alertRose : AppTheme.slateNavy,
            ),
            if (_unreadCount > 0)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.alertRose,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.alertRose.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
