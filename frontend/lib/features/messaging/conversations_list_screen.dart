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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المحادثات السريرية المباشرة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _fetchConversations,
          ),
          const NotificationBellButton(),
          const SizedBox(width: 8),
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
                        final otherName = isPatient
                            ? (conv['doctor_name'] ?? 'طبيب المنصة')
                            : (conv['patient_name'] ?? 'المريض');
                        final otherRole = isPatient ? 'طبيب معتمد' : 'مريض';
                        final lastMsg = conv['last_message'] as Map<String, dynamic>?;
                        final lastContent = lastMsg?['content']?.toString() ?? 'لا توجد رسائل سابقة';
                        final lastTimeRaw = lastMsg?['created_at']?.toString() ?? conv['updated_at']?.toString() ?? '';
                        String lastTime = '';
                        if (lastTimeRaw.isNotEmpty) {
                          try {
                            final dt = DateTime.parse(lastTimeRaw).toLocal();
                            lastTime = DateFormat('h:mm a - d/M', 'ar').format(dt);
                          } catch (_) {}
                        }

                        return Card(
                          elevation: 0,
                          color: AppTheme.surfaceWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
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
                                            Text(
                                              otherName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                                color: AppTheme.slateNavy,
                                              ),
                                            ),
                                            if (lastTime.isNotEmpty)
                                              Text(
                                                lastTime,
                                                style: const TextStyle(fontSize: 10.5, color: AppTheme.slateMuted),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          otherRole,
                                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lastContent,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: lastMsg?['is_read'] == false ? AppTheme.slateNavy : AppTheme.slateMuted,
                                            fontWeight: lastMsg?['is_read'] == false ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
