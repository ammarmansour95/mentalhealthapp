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
  bool _showSuggestions = true;
  String _currentStage = 'GREETING';

  final List<Map<String, dynamic>> _messages = [];
  List<String> _quickReplies = [];

  // Exactly matches backend STAGE_PROMPTS keys: GREETING, MAIN_COMPLAINT, SLEEP_ROUTINE, MOOD_EMOTIONS, RISK_CHECK, SUMMARY_WRAPUP
  static const Map<String, Map<String, dynamic>> _stageMetadata = {
    'GREETING': {
      'step': 1,
      'label': 'الترحيب والتعريف',
      'icon': Icons.waving_hand_outlined,
      'progress': 0.16,
    },
    'MAIN_COMPLAINT': {
      'step': 2,
      'label': 'الشكوى الأساسية والأعراض',
      'icon': Icons.chat_bubble_outline_rounded,
      'progress': 0.33,
    },
    'SLEEP_ROUTINE': {
      'step': 3,
      'label': 'النوم والروتين اليومي',
      'icon': Icons.bedtime_outlined,
      'progress': 0.50,
    },
    'MOOD_EMOTIONS': {
      'step': 4,
      'label': 'المزاج والحالة الشعورية',
      'icon': Icons.sentiment_neutral_outlined,
      'progress': 0.67,
    },
    'RISK_CHECK': {
      'step': 5,
      'label': 'فحص السلامة والدعم',
      'icon': Icons.health_and_safety_outlined,
      'progress': 0.84,
    },
    'SUMMARY_WRAPUP': {
      'step': 6,
      'label': 'التلخيص والختام',
      'icon': Icons.verified_outlined,
      'progress': 1.0,
    },
  };

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _isInitializing = true);
    try {
      final res = await ApiService.post('/ai/interview/start/', {});
      if (res['success'] == true) {
        setState(() {
          _sessionId = res['session_id'];
          _currentStage = res['stage'] ?? 'GREETING';
          _quickReplies = List<String>.from(res['quick_replies'] ?? []);
          _showSuggestions = true;
          _messages.add({
            'sender': 'AI',
            'content': res['ai_message']['content_encrypted'],
            'time': _formatCurrentTime(),
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل بدء جلسة التقييم: $e'),
            backgroundColor: AppTheme.alertRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sessionId == null || _isSending) return;

    final userText = text.trim();

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
      _messages.add({
        'sender': 'PATIENT',
        'content': userText,
        'time': _formatCurrentTime(),
      });
      _quickReplies = [];
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
            'time': _formatCurrentTime(),
          });
          _currentStage = res['current_stage'] ?? _currentStage;
          _quickReplies = List<String>.from(res['suggested_quick_replies'] ?? []);
          _showSuggestions = true;
          _isFinished = res['is_complete'] ?? (_currentStage == 'SUMMARY_WRAPUP');
        });

        if (res['crisis_detected'] == true && mounted) {
          _showCrisisSafetyDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الاتصال: $e'),
            backgroundColor: AppTheme.alertRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _showCrisisSafetyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.alertRose, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'سلامتك وأمانك أولويتنا القصوى 🌿',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.alertRose),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نحن نأخذ ما تشعر به الآن بمنتهى الجدية والاهتمام. تم إرسال إشعار فوري للفريق الطبي المشرف مع بياناتك للتدخل ومتابعة سلامتك.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.slateNavy),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.alertRoseLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.alertRose.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أرقام الطوارئ المعتمدة في سوريا للتدخل الفوري:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.alertRose),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.call, size: 14, color: AppTheme.alertRose),
                      SizedBox(width: 6),
                      Text('منظومة الإسعاف الوطني: 110', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.local_hospital, size: 14, color: AppTheme.alertRose),
                      SizedBox(width: 6),
                      Text('الهلال الأحمر السوري: 133', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'لست وحدك في هذا الألم. هناك دائماً دعم متخصص لمساعدتك في تجاوز هذه اللحظات.',
              style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('أنا في مكان آمن حالياً', style: TextStyle(color: AppTheme.slateMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            onPressed: () {
              Navigator.pop(ctx);
              _completeAndBookDoctor();
            },
            icon: const Icon(Icons.medical_services, size: 16),
            label: const Text('حجز استشارة عاجلة مع طبيب'),
          ),
        ],
      ),
    );
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
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stageInfo = _stageMetadata[_currentStage] ?? {
      'step': 1,
      'label': _currentStage,
      'icon': Icons.chat_bubble_outline_rounded,
      'progress': 0.16,
    };

    final bool showCompletionCard = _isFinished || _currentStage == 'SUMMARY_WRAPUP';
    final int currentStep = stageInfo['step'] as int;
    final double currentProgress = stageInfo['progress'] as double;
    final String stageLabel = stageInfo['label'] as String;
    final IconData stageIcon = stageInfo['icon'] as IconData;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.spa_outlined, color: AppTheme.primaryTeal, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المساعد الإكلينيكي الذكي',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                ),
                Text(
                  'مساحة آمنة ومحمية بالكامل 🌿',
                  style: TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _isInitializing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryTeal),
                  const SizedBox(height: 16),
                  Text(
                    'جاري إعداد جلستك السريرية الآمنة...',
                    style: TextStyle(fontSize: 13.5, color: AppTheme.slateMuted),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Top Progress Tracker - consistent with Main Dashboard card styling
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.slateLight, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(stageIcon, size: 16, color: AppTheme.primaryTeal),
                              const SizedBox(width: 8),
                              Text(
                                showCompletionCard ? 'اكتملت المقابلة السريرية ✓' : 'المرحلة $currentStep من 6: $stageLabel',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.slateNavy,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${(currentProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTealDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: currentProgress,
                          minHeight: 5,
                          backgroundColor: AppTheme.slateLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat Messages Stream
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isAI = msg['sender'] == 'AI';
                      final time = msg['time'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
                          children: [
                            if (isAI) ...[
                              Container(
                                width: 34,
                                height: 34,
                                margin: const EdgeInsets.only(left: 8, top: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryTeal.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.psychology_outlined, color: AppTheme.primaryTeal, size: 18),
                              ),
                            ],
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isAI ? AppTheme.surfaceWhite : AppTheme.primaryTeal,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isAI ? 4 : 18),
                                    bottomRight: Radius.circular(isAI ? 18 : 4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: isAI
                                      ? Border.all(color: AppTheme.slateLight, width: 1.2)
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      isAI ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                  children: [
                                    SelectableText(
                                      msg['content'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.55,
                                        color: isAI ? AppTheme.slateNavy : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isAI ? AppTheme.slateMuted : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Typing indicator (Three staggered pulsing dots)
                if (_isSending)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _ThreeDotsTypingIndicator(),
                        SizedBox(width: 10),
                        Text(
                          'المساعد السريري يحلل الإفادة ويكتب الرد...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.slateMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Supportive Quick Replies Ribbon - styled with main page theme
                if (_quickReplies.isNotEmpty && !_isSending && !showCompletionCard) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.slateLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.primaryTeal),
                                SizedBox(width: 5),
                                Text(
                                  'اقتراحات للمساعدة في التعبير:',
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.slateNavy, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => setState(() => _showSuggestions = !_showSuggestions),
                              child: Text(
                                _showSuggestions ? 'إخفاء ▴' : 'عرض ▾',
                                style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (_showSuggestions)
                          Container(
                            height: 38,
                            margin: const EdgeInsets.only(top: 8),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _quickReplies.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final chipText = _quickReplies[index];
                                return InkWell(
                                  onTap: () {
                                    _sendMessage(chipText);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryTeal.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      chipText,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppTheme.primaryTealDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Completion Card or Bottom Input Bar
                if (showCompletionCard)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.slateLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryTeal.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle_outline, color: AppTheme.primaryTeal, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'اكتملت المقابلة السريرية بنجاح 🌿',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.slateNavy),
                                    ),
                                    Text(
                                      'تم تحليل الإفادات وتوليد التقرير السريري للطبيب',
                                      style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isCompleting ? null : _completeAndGenerateReport,
                            icon: _isCompleting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.assessment_outlined),
                            label: const Text(
                              '📊 استعراض التقرير السريري المبدئي',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryTealDark,
                              side: const BorderSide(color: AppTheme.primaryTeal, width: 1.4),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isCompleting ? null : _completeAndBookDoctor,
                            icon: const Icon(Icons.calendar_month_outlined, color: AppTheme.primaryTealDark),
                            label: const Text(
                              '🩺 حجز استشارة مع التخصص الموصى به',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Bottom Chat Input Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      border: Border(top: BorderSide(color: AppTheme.slateLight, width: 1.2)),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: _sendMessage,
                              maxLines: null,
                              decoration: InputDecoration(
                                hintText: 'عبّر عما تشعر به بكلماتك الخاصة (مشفر وسري)...',
                                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.slateMuted),
                                filled: true,
                                fillColor: AppTheme.backgroundLight,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppTheme.slateLight),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppTheme.slateLight),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(16)),
                                  borderSide: BorderSide(color: AppTheme.primaryTeal, width: 1.6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isSending ? null : () => _sendMessage(_messageController.text),
                            icon: const Icon(Icons.send_rounded, size: 20),
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

/// Three-dot animated typing indicator with staggered scaling & fading
class _ThreeDotsTypingIndicator extends StatefulWidget {
  const _ThreeDotsTypingIndicator();

  @override
  State<_ThreeDotsTypingIndicator> createState() => _ThreeDotsTypingIndicatorState();
}

class _ThreeDotsTypingIndicatorState extends State<_ThreeDotsTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        // Staggered intervals: 0ms, 150ms, 300ms equivalent in [0, 1] range
        final double start = index * 0.18;
        final double end = (start + 0.5).clamp(0.0, 1.0);
        double progress = 0.0;
        if (_animController.value >= start && _animController.value <= end) {
          progress = (_animController.value - start) / (end - start);
        }
        final double wave = progress > 0.0
            ? (progress <= 0.5 ? progress * 2 : (1.0 - progress) * 2)
            : 0.0;
        final double scale = 0.8 + 0.5 * wave;
        final double opacity = 0.35 + 0.65 * wave;

        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }
}
