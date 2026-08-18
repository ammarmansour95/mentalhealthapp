import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';

class NotificationSheet extends StatefulWidget {
  final VoidCallback? onNotificationsUpdated;
  const NotificationSheet({super.key, this.onNotificationsUpdated});

  static void show(BuildContext context, {VoidCallback? onUpdated}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationSheet(onNotificationsUpdated: onUpdated),
    );
  }

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/notifications/');
      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            _notifications = res['notifications'] ?? [];
            _unreadCount = res['unread_count'] ?? 0;
          });
        }
      }
    } catch (_) {
      // Handled
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    try {
      final res = await ApiService.patch('/notifications/$id/read/', {});
      if (res['success'] == true && mounted) {
        setState(() {
          _notifications[index]['is_read'] = true;
          _unreadCount = res['unread_count'] ?? (_unreadCount > 0 ? _unreadCount - 1 : 0);
        });
        widget.onNotificationsUpdated?.call();
      }
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      final res = await ApiService.post('/notifications/mark-all-read/', {});
      if (res['success'] == true && mounted) {
        setState(() {
          for (var n in _notifications) {
            n['is_read'] = true;
          }
          _unreadCount = 0;
        });
        widget.onNotificationsUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديد جميع الإشعارات كمقروءة.'), backgroundColor: AppTheme.sageGreen),
        );
      }
    } catch (_) {}
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'APPOINTMENT_REQUESTED':
        return Icons.calendar_today_outlined;
      case 'APPOINTMENT_CONFIRMED':
        return Icons.event_available_outlined;
      case 'APPOINTMENT_CANCELLED':
        return Icons.event_busy_outlined;
      case 'SESSION_REMINDER':
        return Icons.alarm_outlined;
      case 'DOCTOR_APPLICATION_SUBMITTED':
        return Icons.medical_information_outlined;
      case 'DOCTOR_VERIFIED':
        return Icons.verified_user_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'APPOINTMENT_CONFIRMED':
      case 'DOCTOR_VERIFIED':
        return AppTheme.sageGreen;
      case 'APPOINTMENT_CANCELLED':
      case 'DOCTOR_REJECTED':
        return AppTheme.alertRose;
      case 'SESSION_REMINDER':
        return AppTheme.primaryTeal;
      case 'DOCTOR_APPLICATION_SUBMITTED':
      case 'APPOINTMENT_REQUESTED':
        return AppTheme.oceanAzure;
      default:
        return AppTheme.slateNavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Modal Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active, color: AppTheme.primaryTeal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مركز الإشعارات والتنبيهات',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slateNavy),
                        ),
                        Text(
                          _unreadCount > 0 ? 'لديك $_unreadCount إشعارات جديدة غير مقروءة' : 'لا توجد إشعارات جديدة غير مقروءة',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            color: _unreadCount > 0 ? AppTheme.alertRose : AppTheme.slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_unreadCount > 0)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: _markAllAsRead,
                      icon: const Icon(Icons.done_all, size: 16, color: AppTheme.primaryTeal),
                      label: const Text('تحديد الكل كمقروء', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.slateMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 48, color: AppTheme.slateMuted.withOpacity(0.4)),
                              const SizedBox(height: 12),
                              const Text('صندوق الإشعارات فارغ حالياً.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            final isRead = n['is_read'] == true;
                            final nType = n['notification_type'] ?? 'SYSTEM_ALERT';
                            final icon = _getIconForType(nType);
                            final color = _getColorForType(nType);
                            final rawDate = n['created_at'] as String? ?? '';
                            final formattedDate = rawDate.contains('T')
                                ? rawDate.split('T').first + ' (' + rawDate.split('T').last.substring(0, 5) + ')'
                                : rawDate;

                            return InkWell(
                              onTap: isRead ? null : () => _markAsRead(n['id'], index),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isRead ? AppTheme.surfaceWhite : color.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isRead ? Colors.grey.withOpacity(0.15) : color.withOpacity(0.35),
                                    width: isRead ? 1 : 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(icon, color: color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n['title'] ?? 'إشعار جديد',
                                                  style: TextStyle(
                                                    fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                                                    fontSize: 13.5,
                                                    color: AppTheme.slateNavy,
                                                  ),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            n['message'] ?? '',
                                            style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.slateNavy),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                formattedDate,
                                                style: const TextStyle(fontSize: 10.5, color: AppTheme.slateMuted),
                                              ),
                                              if (!isRead)
                                                Text(
                                                  'اضغط للتعليم كمقروء',
                                                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
