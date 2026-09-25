import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/native_notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? otherUserId;
  final String? otherProfileId;
  final String otherUserName;
  final String otherUserRole; // e.g., 'طبيب معتمد', 'مريض'
  final String? otherUserPhone;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.otherUserId,
    this.otherProfileId,
    required this.otherUserName,
    this.otherUserRole = '',
    this.otherUserPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _conversationId;
  String? _patientPhone;
  int? _patientAge;
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isWindowOpen = true;
  String _windowReason = '';
  Map<String, dynamic>? _nextAppointment;
  bool _isDoctorUnlocked = false;
  String? _doctorUnlockedUntil;
  bool _isPatientWindowOpen = false;
  bool _isTogglingUnlock = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId?.toString();
    _initConversation();
    // Poll for new messages every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_conversationId != null) {
        _fetchMessages(isBackground: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    setState(() => _isLoading = true);
    try {
      if (_conversationId == null && (widget.otherUserId != null || widget.otherProfileId != null)) {
        final Map<String, dynamic> body = {};
        if (widget.otherUserId != null) {
          body['other_user_id'] = widget.otherUserId;
        }
        if (widget.otherProfileId != null) {
          body['other_user_id'] = widget.otherProfileId;
          body['doctor_id'] = widget.otherProfileId;
          body['patient_id'] = widget.otherProfileId;
        }

        // Start or retrieve conversation with other user
        final res = await ApiService.post('/messaging/conversations/start/', body);
        if (res['success'] == true && res['conversation'] != null) {
          _conversationId = res['conversation']['id']?.toString();
          final conv = res['conversation'] as Map<String, dynamic>;
          _patientPhone = conv['patient_phone']?.toString();
          _patientAge = conv['patient_age'] as int?;
          final status = (res['window_status'] as Map<String, dynamic>?) ?? (res as Map<String, dynamic>?);
          if (status != null) {
            _isWindowOpen = status['is_window_open'] == true || status['is_open'] == true;
            _windowReason = status['window_reason']?.toString() ?? status['reason']?.toString() ?? '';
            _nextAppointment = status['next_appointment'] as Map<String, dynamic>?;
            _isDoctorUnlocked = status['is_doctor_unlocked'] == true;
            _doctorUnlockedUntil = status['doctor_unlocked_until']?.toString();
            _isPatientWindowOpen = status['is_patient_window_open'] == true || _isDoctorUnlocked;
          }
        }
      }

      if (_conversationId != null) {
        await _fetchMessages();
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error init conversation: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    if (_conversationId == null) return;
    try {
      final res = await ApiService.get('/messaging/conversations/$_conversationId/messages/');
      if (res['success'] == true && mounted) {
        final messages = (res['messages'] as List?) ?? [];
        final status = (res['window_status'] as Map<String, dynamic>?) ?? (res as Map<String, dynamic>?);

        if (res['conversation'] != null) {
          final conv = res['conversation'] as Map<String, dynamic>;
          _patientPhone = conv['patient_phone']?.toString() ?? _patientPhone;
          _patientAge = conv['patient_age'] as int? ?? _patientAge;
        }

        if (status != null) {
          _isWindowOpen = status['is_window_open'] == true || status['is_open'] == true;
          _windowReason = status['window_reason']?.toString() ?? status['reason']?.toString() ?? '';
          _nextAppointment = status['next_appointment'] as Map<String, dynamic>?;
          _isDoctorUnlocked = status['is_doctor_unlocked'] == true;
          _doctorUnlockedUntil = status['doctor_unlocked_until']?.toString();
          _isPatientWindowOpen = status['is_patient_window_open'] == true || _isDoctorUnlocked;
        }

        final prevCount = _messages.length;
        setState(() {
          _messages = messages;
        });

        // If new message received from other party in background, scroll and alert
        if (isBackground && messages.length > prevCount && messages.isNotEmpty) {
          final lastMsg = messages.last;
          final lastSender = (lastMsg['sender_name'] ?? '').toString().trim();
          final currentOther = widget.otherUserName.trim();
          final cleanLast = lastSender.replaceAll('د. ', '').replaceAll('د.', '').trim();
          final cleanOther = currentOther.replaceAll('د. ', '').replaceAll('د.', '').trim();

          if (lastSender == currentOther || cleanLast == cleanOther) {
            final displayTitle = widget.otherUserRole.contains('طبيب') && !currentOther.startsWith('د.')
                ? 'د. $currentOther'
                : currentOther;
            NativeNotificationService.showNotification(
              title: displayTitle,
              body: lastMsg['content'] ?? '',
              tag: lastMsg['is_emergency'] == true ? 'crisis' : 'message',
            );
          }
          _scrollToBottom();
        } else if (!isBackground) {
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleDoctorUnlock({required bool unlock, int hours = 24}) async {
    if (_conversationId == null) {
      await _initConversation();
      if (_conversationId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحديد معرف المحادثة.'), backgroundColor: AppTheme.alertRose),
          );
        }
        return;
      }
    }
    setState(() => _isTogglingUnlock = true);
    try {
      final res = await ApiService.post(
        '/messaging/conversations/$_conversationId/doctor-unlock/',
        {
          'action': unlock ? 'unlock' : 'lock',
          'hours': hours,
        },
      );

      if (res['success'] == true && mounted) {
        final status = (res['window_status'] as Map<String, dynamic>?) ?? (res as Map<String, dynamic>?);
        if (status != null) {
          setState(() {
            _isDoctorUnlocked = status['is_doctor_unlocked'] == true;
            _doctorUnlockedUntil = status['doctor_unlocked_until']?.toString();
            _isPatientWindowOpen = status['is_patient_window_open'] == true || _isDoctorUnlocked;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (unlock ? 'تم فتح المحادثة للمريض' : 'تم قفل المحادثة')),
            backgroundColor: unlock ? AppTheme.sageGreen : AppTheme.alertRose,
          ),
        );
        _fetchMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingUnlock = false);
    }
  }

  void _showDoctorUnlockDialog() {
    int selectedHours = 24;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_open, color: AppTheme.primaryTeal, size: 24),
              SizedBox(width: 8),
              Text('فتح نافذة المحادثة للمريض', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يتيح هذا الإجراء للمريض (${widget.otherUserName}) إرسال الرسائل النصية والاستفسارات مباشرة حتى لو لم يكن لديه موعد نشط.',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              const Text('مدة الفتح الممنوحة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('24 ساعة'),
                    selected: selectedHours == 24,
                    selectedColor: AppTheme.primaryTeal,
                    onSelected: (s) => setDialogState(() => selectedHours = 24),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('48 ساعة'),
                    selected: selectedHours == 48,
                    selectedColor: AppTheme.primaryTeal,
                    onSelected: (s) => setDialogState(() => selectedHours = 48),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('72 ساعة'),
                    selected: selectedHours == 72,
                    selectedColor: AppTheme.primaryTeal,
                    onSelected: (s) => setDialogState(() => selectedHours = 72),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
              onPressed: () {
                Navigator.pop(ctx);
                _toggleDoctorUnlock(unlock: true, hours: selectedHours);
              },
              icon: const Icon(Icons.check, size: 16),
              label: Text('تأكيد الفتح ($selectedHours ساعة)'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('HH:mm yyyy/MM/dd').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({bool isEmergency = false, String emergencyReason = ''}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && !isEmergency) return;
    if (_conversationId == null) return;

    setState(() => _isSending = true);
    try {
      final res = await ApiService.post('/messaging/send/', {
        'conversation_id': _conversationId,
        'content': text.isNotEmpty ? text : emergencyReason,
        'is_emergency': isEmergency,
        'emergency_reason': emergencyReason,
      });

      if (res['success'] == true && mounted) {
        _messageController.clear();
        await _fetchMessages();
        if (isEmergency && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال نداء الطوارئ السريري بنجاح إلى الطبيب والمنصة عبر الإشعار والرسائل النصية SMS.'),
              backgroundColor: AppTheme.alertRose,
              duration: Duration(seconds: 6),
            ),
          );
        }
      } else if (mounted) {
        final err = res['error'] ?? res['message'] ?? 'فشل إرسال الرسالة';
        if (res['code'] == 'CHAT_WINDOW_CLOSED') {
          _showWindowClosedDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.toString()), backgroundColor: AppTheme.alertRose),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().replaceAll('Exception: ', '');
        if (errStr.contains('CHAT_WINDOW_CLOSED') || errStr.contains('مقفلة')) {
          _showWindowClosedDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errStr), backgroundColor: AppTheme.alertRose),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showWindowClosedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('نافذة المحادثة مقفلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _windowReason.isNotEmpty
                  ? _windowReason
                  : 'المحادثة متاحة فقط خلال يوم الجلسة المعتمدة ولمدة 24 ساعة بعدها.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'إذا كنت تواجه أزمة حادة أو أفكار إيذاء للنفس، يمكنك كسر القفل لإرسال نداء طوارئ عاجل.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.alertRose),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRose),
            onPressed: () {
              Navigator.pop(ctx);
              _openEmergencyDialog();
            },
            icon: const Icon(Icons.emergency, size: 18),
            label: const Text('كسر القفل للطوارئ'),
          ),
        ],
      ),
    );
  }

  void _openEmergencyDialog() {
    final reasonController = TextEditingController(text: _messageController.text.trim());
    bool agreed = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.alertRose, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'كسر القفل وإرسال نداء طوارئ سريري',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.alertRose),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.alertRoseLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.alertRose.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تنبيه هام للسلامة السريرية:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.alertRose),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• سيتم إرسال إنذار فوري للطبيب المشرف وإدارة المنصة عبر الإشعارات ورسائل SMS.\n'
                        '• سيتم تسجيل رقم هاتفك السوري والتوقيت الدقيق لإتاحة التدخل السريع.\n'
                        '• استخدم هذه الخاصية فقط في الحالات النفسية الحرجة التي تتطلب رعاية فورية.',
                        style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.slateNavy),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'رسالة الطوارئ أو سبب البلاغ العاجل:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'صف ما تشعر به الآن أو ما تحتاجه بشكل عاجل...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: agreed,
                  onChanged: (val) => setDialogState(() => agreed = val ?? false),
                  title: const Text(
                    'أؤكد أنني بحاجة إلى دعم سريري طارئ فوري.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                const Text(
                  'أرقام الطوارئ المعتمدة في سوريا:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slateMuted),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.local_hospital, size: 14, color: AppTheme.primaryTeal),
                    SizedBox(width: 4),
                    Text('منظومة الإسعاف الوطني: 110 | الهلال الأحمر: 133', style: TextStyle(fontSize: 11, color: AppTheme.slateNavy)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.alertRose,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              onPressed: agreed && !_isSending
                  ? () {
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى وصف الحالة الطارئة.')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _messageController.text = reason;
                      _sendMessage(isEmergency: true, emergencyReason: reason);
                    }
                  : null,
              icon: const Icon(Icons.emergency, size: 18),
              label: const Text('إرسال نداء الطوارئ الآن'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح تطبيق الاتصال: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  Future<void> _escalateCrisisByDoctor(String notes) async {
    if (_conversationId == null) return;
    try {
      final res = await ApiService.post(
        '/messaging/conversations/$_conversationId/escalate-crisis/',
        {'notes': notes},
      );
      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصعيد بلاغ الطوارئ السريري لإدارة المنصة بنجاح.'),
            backgroundColor: AppTheme.alertRose,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تصعيد البلاغ: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  void _showDoctorEscalateConfirmDialog() {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.emergency, color: AppTheme.alertRose, size: 24),
            SizedBox(width: 8),
            Text('تصعيد طوارئ سريري لإدارة المنصة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.alertRose)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سيتم إرسال بلاغ فوري (CRISIS_ALERT) لإدارة المنصة مع بيانات المريض (${widget.otherUserName}).', style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'ملاحظات الطبيب حول خطورة الحالة والتدخل المطلوب (اختياري)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRose),
            onPressed: () {
              Navigator.pop(ctx);
              _escalateCrisisByDoctor(notesController.text.trim());
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('تأكيد التصعيد الفوري'),
          ),
        ],
      ),
    );
  }

  void _openDoctorPatientSafetyModal() {
    final phone = _patientPhone ?? widget.otherUserPhone ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.health_and_safety, color: AppTheme.primaryTeal, size: 24),
                SizedBox(width: 8),
                Text(
                  'بيانات المريض والتدخل السريري السريع',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Patient Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.slateLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.oceanAzure.withValues(alpha: 0.15),
                        child: const Icon(Icons.person, color: AppTheme.oceanAzure, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.otherUserName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (_patientAge != null)
                              Text(
                                'العمر: $_patientAge سنة',
                                style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (phone.isNotEmpty) ...[
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.phone_iphone, size: 16, color: AppTheme.slateMuted),
                            SizedBox(width: 6),
                            Text('رقم الهاتف:', style: TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                          ],
                        ),
                        Text(
                          phone,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Direct Call Button
            if (phone.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.sageGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _callPhone(phone);
                  },
                  icon: const Icon(Icons.call, size: 18),
                  label: Text('اتصال هاتفي مباشر بالمريض ($phone)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),

            const SizedBox(height: 12),

            // Syrian Emergency Services
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('أرقام الطوارئ والإسعاف في سوريا:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.brown)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            foregroundColor: Colors.red.shade800,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                          onPressed: () => _callPhone('110'),
                          icon: const Icon(Icons.local_hospital, size: 15),
                          label: const Text('الإسعاف 110', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            foregroundColor: Colors.red.shade800,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                          onPressed: () => _callPhone('133'),
                          icon: const Icon(Icons.medical_services, size: 15),
                          label: const Text('الهلال الأحمر 133', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Clinical Escalation to Platform Admin
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.alertRose,
                  side: const BorderSide(color: AppTheme.alertRose),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDoctorEscalateConfirmDialog();
                },
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('تصعيد بلاغ طوارئ سريري لإدارة المنصة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDoctor = auth.user?['role'] == 'DOCTOR' || widget.otherUserRole == 'مريض';

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryTealLight.withValues(alpha: 0.2),
              child: Text(
                widget.otherUserName.isNotEmpty ? widget.otherUserName[0] : '؟',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal, fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDoctor
                              ? (_isDoctorUnlocked || _isPatientWindowOpen ? AppTheme.sageGreen : Colors.amber.shade700)
                              : (_isWindowOpen ? AppTheme.sageGreen : Colors.amber.shade700),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          isDoctor
                              ? (_isDoctorUnlocked
                                  ? 'مفتوحة للمريض استثنائياً'
                                  : (_isPatientWindowOpen ? 'مفتوحة للمريض (موعد نشط)' : 'مقفلة للمريض (خارج الجلسة)'))
                              : (_isWindowOpen
                                  ? (_isDoctorUnlocked ? 'مفتوحة بإذن الطبيب' : 'النافذة مفتوحة (جلسة نشطة)')
                                  : 'النافذة مقفلة (خارج الجلسة)'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDoctor
                                ? (_isDoctorUnlocked || _isPatientWindowOpen ? AppTheme.sageGreen : Colors.amber.shade800)
                                : (_isWindowOpen ? AppTheme.sageGreen : Colors.amber.shade800),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isDoctor)
            IconButton(
              icon: const Icon(Icons.phone_in_talk, color: AppTheme.sageGreen),
              tooltip: 'بيانات الطوارئ والاتصال بالمريض',
              onPressed: _openDoctorPatientSafetyModal,
            )
          else
            IconButton(
              icon: const Icon(Icons.emergency_outlined, color: AppTheme.alertRose),
              tooltip: 'نداء طوارئ فوري',
              onPressed: _openEmergencyDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Window status banner
                _buildWindowStatusBanner(isDoctor),

                // Message list
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['sender_name'] != widget.otherUserName;
                            return _buildMessageBubble(msg, isMe);
                          },
                        ),
                ),

                // Bottom input area or locked bar
                _buildInputArea(),
              ],
            ),
    );
  }

  Widget _buildWindowStatusBanner(bool isDoctor) {
    if (isDoctor) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _isDoctorUnlocked
              ? AppTheme.sageGreenLight.withValues(alpha: 0.45)
              : (_isPatientWindowOpen ? AppTheme.primaryTeal.withValues(alpha: 0.08) : Colors.amber.shade50),
          border: Border(
            bottom: BorderSide(
              color: _isDoctorUnlocked
                  ? AppTheme.sageGreen.withValues(alpha: 0.4)
                  : (_isPatientWindowOpen ? AppTheme.primaryTeal.withValues(alpha: 0.2) : Colors.amber.shade300),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isDoctorUnlocked
                  ? Icons.lock_open
                  : (_isPatientWindowOpen ? Icons.check_circle_outline : Icons.lock_clock),
              size: 18,
              color: _isDoctorUnlocked
                  ? AppTheme.sageGreen
                  : (_isPatientWindowOpen ? AppTheme.primaryTeal : Colors.amber.shade800),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDoctorUnlocked
                        ? 'تم فتح المحادثة استثنائياً للمريض'
                        : (_isPatientWindowOpen
                            ? 'المحادثة متاحة للمريض (ضمن نافذة الموعد)'
                            : 'المحادثة مقفلة للمريض حالياً (خارج نافذة الموعد)'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isDoctorUnlocked
                          ? AppTheme.sageGreen
                          : (_isPatientWindowOpen ? AppTheme.primaryTealDark : Colors.amber.shade900),
                    ),
                  ),
                  Text(
                    _isDoctorUnlocked
                        ? (_doctorUnlockedUntil != null
                            ? 'المريض قادر على مراسلتك (مفتوحة حتى: ${_formatDateTime(_doctorUnlockedUntil!)})'
                            : 'المريض قادر على مراسلتك الآن لمتابعة استفساراته.')
                        : (_isPatientWindowOpen
                            ? 'المريض قادر على مراسلتك ضمن نافذة الـ 24 ساعة.'
                            : 'يمكنك فتح المحادثة للمريض يدوياً لاستقبال استفساراته.'),
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.slateNavy),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_isTogglingUnlock)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else if (_isDoctorUnlocked) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.alertRose,
                  side: BorderSide(color: AppTheme.alertRose.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _toggleDoctorUnlock(unlock: false),
                icon: const Icon(Icons.lock, size: 13),
                label: const Text('قفل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.sageGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _toggleDoctorUnlock(unlock: true, hours: 24),
                icon: const Icon(Icons.more_time, size: 13),
                label: const Text('+24 س', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showDoctorUnlockDialog,
                icon: const Icon(Icons.lock_open, size: 14),
                label: const Text('فتح للمريض', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }
    if (_isWindowOpen) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.sageGreenLight.withValues(alpha: 0.4),
          border: Border(bottom: BorderSide(color: AppTheme.sageGreen.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.sageGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _windowReason.isNotEmpty
                    ? _windowReason
                    : 'نافذة المحادثة مفتوحة حالياً (ضمن موعد الجلسة المعتمدة ومتابعتها لمدة 24 ساعة).',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.slateDark, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(bottom: BorderSide(color: Colors.amber.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_clock, size: 18, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المحادثة المباشرة مقفلة خارج مواعيد الجلسات المعتمدة.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _windowReason.isNotEmpty
                ? _windowReason
                : 'يتاح التواصل النصي خلال يوم الجلسة المحجوزة ولمدة 24 ساعة من انتهائها.',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
          ),
          if (_nextAppointment != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available, size: 14, color: Colors.brown),
                  const SizedBox(width: 6),
                  Text(
                    'موعدك القادم: ${_nextAppointment!['date']} الساعة ${_nextAppointment!['time']}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.alertRose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _openEmergencyDialog,
                  icon: const Icon(Icons.emergency, size: 16),
                  label: const Text(
                    'كسر القفل لحالة طوارئ سريرية (Emergency Alert)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.slateMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'لا توجد رسائل سابقة مع ${widget.otherUserName}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.slateMuted),
          ),
          const SizedBox(height: 6),
          const Text(
            'يمكنك بدء الحديث خلال نافذة الجلسة المعتمدة، أو استخدام زر الطوارئ عند الحاجة.',
            style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final content = msg['content']?.toString() ?? '';
    final isEmergency = msg['is_emergency'] == true;
    final isRead = msg['is_read'] == true;
    final timestamp = msg['created_at']?.toString() ?? '';
    String timeStr = '';
    try {
      if (timestamp.isNotEmpty) {
        final dt = DateTime.parse(timestamp).toLocal();
        timeStr = DateFormat('h:mm a', 'ar').format(dt);
      }
    } catch (_) {
      timeStr = '';
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isEmergency
              ? AppTheme.alertRoseLight
              : isMe
                  ? AppTheme.primaryTeal
                  : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: isEmergency
              ? Border.all(color: AppTheme.alertRose, width: 1.5)
              : isMe
                  ? null
                  : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEmergency)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emergency, size: 14, color: AppTheme.alertRose),
                    const SizedBox(width: 4),
                    Text(
                      'نداء طوارئ سريري',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isMe ? AppTheme.alertRose : AppTheme.alertRose,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              content,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isEmergency
                    ? AppTheme.alertRose
                    : isMe
                        ? Colors.white
                        : AppTheme.slateNavy,
                fontWeight: isEmergency ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isEmergency
                        ? AppTheme.alertRose.withValues(alpha: 0.8)
                        : isMe
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.slateMuted,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 13,
                    color: isRead ? AppTheme.iceBlue : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    if (!_isWindowOpen) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              const Icon(Icons.lock, size: 20, color: AppTheme.slateMuted),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'المحادثة مقفلة حالياً. استخدم زر الطوارئ إذا كنت بحاجة لدعم عاجل.',
                  style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRose,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openEmergencyDialog,
                icon: const Icon(Icons.emergency, size: 15),
                label: const Text('طوارئ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.slateMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: AppTheme.slateLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryTeal,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _isSending ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
