import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/reports/ai_report_screen.dart';
import 'package:frontend/features/doctors/doctor_list_screen.dart';

class AIInterviewScreen extends StatefulWidget {
  const AIInterviewScreen({super.key});

  @override
  State<AIInterviewScreen> createState() => _AIInterviewScreenState();
}

class _AIInterviewScreenState extends State<AIInterviewScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _sessionId;
  bool _isInitializing = true;
  bool _isSending = false;
  bool _isCompleting = false;
  bool _isFinished = false;
  bool _showSuggestions = false;
  String _currentStage = 'GREETING';

  final List<Map<String, dynamic>> _messages = [];
  List<String> _quickReplies = [];

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    setState(() => _isInitializing = true);
    try {
      final res = await ApiService.post('/ai/interview/start/', {});
      if (res['success'] == true) {
        setState(() {
          _sessionId = res['session_id'];
          _currentStage = res['stage'];
          _quickReplies = List<String>.from(res['quick_replies'] ?? []);
          _showSuggestions = false; // Kept minimized to encourage typing
          _messages.add({
            'sender': 'AI',
            'content': res['ai_message']['content_encrypted'],
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل بدء المقابلة: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sessionId == null || _isSending) return;

    final userText = text.trim();

    // Check if user tapped or sent report/booking actions
    if (userText.contains('عرض التقرير')) {
      _completeAndGenerateReport();
      return;
    }
    if (userText.contains('حجز موعد')) {
      _completeAndBookDoctor();
      return;
    }

    _messageController.clear();

    setState(() {
      _messages.add({'sender': 'PATIENT', 'content': userText});
      _quickReplies = [];
      _showSuggestions = false;
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final res = await ApiService.post('/ai/interview/$_sessionId/message/', {
        'message': userText,
      });

      if (res['success'] == true) {
        setState(() {
          _messages.add({
            'sender': 'AI',
            'content': res['ai_reply']['content_encrypted'],
          });
          _currentStage = res['current_stage'] ?? _currentStage;
          _quickReplies = List<String>.from(res['suggested_quick_replies'] ?? []);
          _showSuggestions = false; // Stay minimized so patient is encouraged to type next answer
          _isFinished = res['is_complete'] ?? (_currentStage == 'SUMMARY_WRAPUP');
        });

        if (res['crisis_detected'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تنبيه: تم رصد مؤشرات حادة، فريق الرعاية والدعم متاح لمساعدتك فوراً.'),
              backgroundColor: AppTheme.alertRose,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إرسال الرسالة: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  Future<void> _completeAndGenerateReport() async {
    if (_sessionId == null || _isCompleting) return;

    setState(() => _isCompleting = true);
    try {
      final res = await ApiService.post('/ai/interview/$_sessionId/complete/', {});
      if (res['success'] == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AIReportScreen(reportData: res['report']),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء التقرير: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _completeAndBookDoctor() async {
    if (_sessionId == null || _isCompleting) return;

    setState(() => _isCompleting = true);
    try {
      final res = await ApiService.post('/ai/interview/$_sessionId/complete/', {});
      if (res['success'] == true && mounted) {
        final specialty = res['report']?['recommended_specialty'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorListScreen(initialSpecialty: specialty),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DoctorListScreen(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showCompletionButtons = _isFinished || _currentStage == 'SUMMARY_WRAPUP' || _messages.length >= 8;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.primaryTeal, size: 20),
            SizedBox(width: 8),
            Text('المقابلة والتقييم السريري (AraBART AI)', style: TextStyle(fontSize: 15)),
          ],
        ),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Progress indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppTheme.primaryTeal.withOpacity(0.06),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.sageGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            showCompletionButtons ? 'المقابلة مكتملة ✓' : 'المرحلة: $_currentStage',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                          ),
                        ],
                      ),
                      Text(
                        '${_messages.where((m) => m['sender'] == 'PATIENT').length} ردود',
                        style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                      ),
                    ],
                  ),
                ),

                // Chat Messages List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isAI = msg['sender'] == 'AI';
                      return Align(
                        alignment: isAI ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
                          decoration: BoxDecoration(
                            color: isAI ? AppTheme.surfaceWhite : AppTheme.primaryTeal,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isAI ? 18 : 4),
                              bottomRight: Radius.circular(isAI ? 4 : 18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: isAI ? Border.all(color: Colors.grey.withOpacity(0.15)) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAI ? Icons.psychology_outlined : Icons.person_outline,
                                    size: 14,
                                    color: isAI ? AppTheme.primaryTeal : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isAI ? 'المساعد السريري الذكي' : 'أنت',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isAI ? AppTheme.primaryTeal : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg['content'],
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: isAI ? AppTheme.slateNavy : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Typing indicator when waiting for AraBART
                if (_isSending)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal)),
                        const SizedBox(width: 10),
                        Text(
                          'المساعد الذكي يقوم بالتحليل والصياغة السريرية...',
                          style: TextStyle(fontSize: 12, color: AppTheme.slateMuted.withOpacity(0.8), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),

                // Collapsible Minimized Suggestion Toggle (to encourage typing)
                if (_quickReplies.isNotEmpty && !_isSending && !showCompletionButtons) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => setState(() => _showSuggestions = !_showSuggestions),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showSuggestions ? Icons.keyboard_arrow_down : Icons.lightbulb_outline,
                                size: 14,
                                color: AppTheme.primaryTeal,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showSuggestions ? 'إخفاء الاقتراحات المساعدة ▴' : '💡 اقتراحات للمساعدة (اضغط للعرض) ▾',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryTealDark, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Expandable Suggestion Chips
                  if (_showSuggestions)
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _quickReplies.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final chipText = _quickReplies[index];
                          return ActionChip(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: AppTheme.primaryTeal.withOpacity(0.3)),
                            label: Text(chipText, style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryTealDark)),
                            onPressed: () {
                              _messageController.text = chipText;
                              setState(() => _showSuggestions = false);
                            },
                          );
                        },
                      ),
                    ),
                ],

                // End-of-interview Direct Action Buttons
                if (showCompletionButtons)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
                      ],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _isCompleting ? null : _completeAndGenerateReport,
                          icon: _isCompleting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.assessment_outlined),
                          label: const Text('📊 عرض التقرير والنتائج الطبية (AraBART)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.sageGreen,
                            side: const BorderSide(color: AppTheme.sageGreen, width: 1.5),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isCompleting ? null : _completeAndBookDoctor,
                          icon: const Icon(Icons.calendar_month_outlined, color: AppTheme.sageGreen),
                          label: const Text('🩺 حجز موعد مجاني مع طبيب مختص', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),
                  )
                else
                  // Bottom Text Input Bar (encouraging natural expressions)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: _sendMessage,
                              decoration: const InputDecoration(
                                hintText: 'عبّر عما تشعر به بكلماتك الخاصة (مشفر وسري)...',
                                contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: _isSending ? null : () => _sendMessage(_messageController.text),
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
