import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/widgets/notification_bell_button.dart';
import 'package:frontend/features/messaging/chat_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/messaging/conversations/');
      if (res is List) {
        if (mounted) setState(() => _conversations = res);
      } else if (res is Map && res['results'] is List) {
        if (mounted) setState(() => _conversations = res['results']);
      }
    } catch (e) {
      debugPrint('[ConversationsList] Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final isPatient = user?['role'] == 'PATIENT';
    final totalUnread = _conversations.fold<int>(0, (sum, c) => sum + ((c['unread_count'] as int?) ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'المحادثات المباشرة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
            ),
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.alertRose,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalUnread جديدة',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: const [
          NotificationBellButton(),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchConversations,
              child: _conversations.isEmpty
                  ? _buildEmptyState(isPatient)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final rawDocName = (conv['doctor_name'] ?? 'طبيب المنصة').toString().trim();
                        final docFormatted = rawDocName.startsWith('د.') ? rawDocName : 'د. $rawDocName';
                        final otherName = isPatient
                            ? docFormatted
                            : (conv['patient_name'] ?? 'المريض');
                        final otherRole = isPatient ? 'طبيب معتمد' : 'مريض';
                        final lastMsg = conv['last_message'] as Map<String, dynamic>?;
                        final lastContent = lastMsg?['content']?.toString() ?? 'لا توجد رسائل سابقة';
                        final lastTimeRaw = lastMsg?['created_at']?.toString() ?? conv['updated_at']?.toString() ?? '';
                        final unreadCount = (conv['unread_count'] as int?) ?? 0;
                        final isDoctorUnlocked = conv['is_doctor_unlocked'] == true;

                        String lastTime = '';
                        if (lastTimeRaw.isNotEmpty) {
                          try {
                            final dt = DateTime.parse(lastTimeRaw).toLocal();
                            lastTime = DateFormat('h:mm a - d/M', 'ar').format(dt);
                          } catch (_) {}
                        }

                        return Card(
                          elevation: 0,
                          color: unreadCount > 0 ? AppTheme.primaryTeal.withValues(alpha: 0.04) : AppTheme.surfaceWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: unreadCount > 0
                                  ? AppTheme.primaryTeal.withValues(alpha: 0.35)
                                  : Colors.grey.withValues(alpha: 0.15),
                              width: unreadCount > 0 ? 1.5 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: conv['id']?.toString(),
                                    otherUserName: otherName,
                                    otherUserRole: otherRole,
                                  ),
                                ),
                              );
                              _fetchConversations();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isPatient
                                        ? AppTheme.primaryTeal.withValues(alpha: 0.15)
                                        : AppTheme.oceanAzure.withValues(alpha: 0.15),
                                    child: Icon(
                                      isPatient ? Icons.medical_services : Icons.person,
                                      color: isPatient ? AppTheme.primaryTeal : AppTheme.oceanAzure,
                                      size: 22,
                                    ),
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
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      otherName,
                                                      style: TextStyle(
                                                        fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.bold,
                                                        fontSize: 14.5,
                                                        color: AppTheme.slateNavy,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isDoctorUnlocked) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.sageGreen.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.lock_open_rounded, size: 11, color: AppTheme.sageGreen),
                                                          SizedBox(width: 3),
                                                          Text(
                                                            'مفتوحة للمريض',
                                                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.sageGreen),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            if (lastTime.isNotEmpty)
                                              Text(
                                                lastTime,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                                  color: unreadCount > 0 ? AppTheme.primaryTeal : AppTheme.slateMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          otherRole,
                                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                lastContent,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: unreadCount > 0 ? AppTheme.slateNavy : AppTheme.slateMuted,
                                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            if (unreadCount > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.alertRose,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '$unreadCount',
                                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.slateMuted),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState(bool isPatient) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.iceBlue,
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.oceanAzure),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد محادثات نشطة بعد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
            ),
            const SizedBox(height: 8),
            Text(
              isPatient
                  ? 'يتم تفعيل المحادثة مع طبيبك المعالج تلقائياً عند حجز جلسة استشارة معتمدة، وتظل مفتوحة لمتابعة خطتك العلاجية.'
                  : 'ستظهر هنا محادثات مرضاك عند بدء المواعيد المقررة أو عند استقبال استشارات طارئة.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.slateMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
