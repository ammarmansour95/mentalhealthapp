import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/ai_interview/ai_interview_screen.dart';
import 'package:frontend/features/doctors/doctor_list_screen.dart';

class AssessmentQuizScreen extends StatefulWidget {
  final String assessmentCode; // 'PHQ-9' or 'GAD-7'

  const AssessmentQuizScreen({super.key, required this.assessmentCode});

  @override
  State<AssessmentQuizScreen> createState() => _AssessmentQuizScreenState();
}

class _AssessmentQuizScreenState extends State<AssessmentQuizScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _assessmentData;
  final Map<String, String> _selectedAnswers = {}; // question_id -> option_id
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;
  Map<String, dynamic>? _submissionResult;

  @override
  void initState() {
    super.initState();
    _fetchAssessment();
  }

  Future<void> _fetchAssessment() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/assessments/${widget.assessmentCode}/');
      setState(() {
        _assessmentData = res;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل المقياس: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAssessment() async {
    final questions = _assessmentData?['questions'] as List? ?? [];
    if (_selectedAnswers.length < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الإجابة على جميع الأسئلة للمتابعة.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final answersPayload = _selectedAnswers.entries.map((e) {
      return {'question_id': e.key, 'option_id': e.value};
    }).toList();

    try {
      final res = await ApiService.post('/assessments/submit/', {
        'assessment_code': widget.assessmentCode,
        'answers': answersPayload,
      });

      if (res['success'] == true) {
        setState(() {
          _submissionResult = res['submission'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إرسال الإجابات: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _getSeverityColor(String severity) {
    if (severity.contains('شديد') || severity.contains('Severe') || severity.contains('متوسط الشدة')) {
      return AppTheme.alertRose;
    } else if (severity.contains('معتدل') || severity.contains('Moderate')) {
      return const Color(0xFFF59E0B);
    }
    return AppTheme.sageGreen;
  }

  String get _appBarTitle =>
      _assessmentData?['title_ar'] ?? _assessmentData?['title_en'] ?? widget.assessmentCode;

  @override
  Widget build(BuildContext context) {
    final bool hasUnsavedAnswers = _selectedAnswers.isNotEmpty && _submissionResult == null;

    return PopScope(
      canPop: !hasUnsavedAnswers,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تأكيد المغادرة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: const Text('هل تريد الخروج؟ سيتم فقدان إجاباتك.', style: TextStyle(fontSize: 14)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('تراجع', style: TextStyle(color: AppTheme.slateMuted, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('خروج', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_appBarTitle)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryTeal),
              SizedBox(height: 16),
              Text('جاري تحميل أسئلة المقياس المعتمد...', style: TextStyle(color: AppTheme.slateMuted)),
            ],
          ),
        ),
      );
    }

    if (_submissionResult != null) {
      return _buildResultScreen();
    }

    final questions = _assessmentData?['questions'] as List? ?? [];
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_appBarTitle)),
        body: const Center(child: Text('لا توجد أسئلة متاحة لهذا المقياس حالياً.')),
      );
    }

    final currentQ = questions[_currentQuestionIndex];
    final qId = currentQ['id'];
    final options = currentQ['options'] as List? ?? [];
    // Shows 11% on Q1 of 9 questions
    final progress = questions.isEmpty ? 0.0 : ((_currentQuestionIndex + 1) / questions.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _appBarTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Progress & Step Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.slateLight),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryTeal.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.quiz_outlined, color: AppTheme.primaryTeal, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'السؤال ${_currentQuestionIndex + 1} من ${questions.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.slateNavy, fontSize: 13.5),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppTheme.slateLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Prompt Header
                const Text(
                  'خلال الأسبوعين الماضيين، كم مرة تكرر معك هذا الشعور:',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.slateMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),

                // Question Card
                Card(
                  elevation: 0,
                  color: AppTheme.surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppTheme.slateLight, width: 1.2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Text(
                      currentQ['text_ar'] ?? currentQ['text_en'],
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slateNavy,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Likert Options
                ...options.map((opt) {
                  final optId = opt['id'];
                  final isSelected = _selectedAnswers[qId] == optId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAnswers[qId] = optId;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryTeal.withOpacity(0.08) : AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryTeal : AppTheme.slateLight,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryTeal.withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade400,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                opt['label_ar'] ?? opt['label_en'],
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppTheme.primaryTealDark : AppTheme.slateNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 22),

                // Navigation Buttons (Clean Typography)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    children: [
                      // Back Button (Right side in Arabic RTL)
                      if (_currentQuestionIndex > 0) ...[
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () => setState(() => _currentQuestionIndex--),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              foregroundColor: AppTheme.slateNavy,
                              side: const BorderSide(color: AppTheme.slateLight, width: 1.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Center(
                              child: Text(
                                'السابق',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Next / Submit Button (Left side in Arabic RTL)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _selectedAnswers[qId] == null
                              ? null
                              : () {
                                  if (_currentQuestionIndex < questions.length - 1) {
                                    setState(() => _currentQuestionIndex++);
                                  } else {
                                    _submitAssessment();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.slateLight,
                            disabledForegroundColor: AppTheme.slateMuted,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Center(
                                  child: Text(
                                    _currentQuestionIndex == questions.length - 1 ? 'إرسال وعرض التقرير' : 'السؤال التالي',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final score = _submissionResult?['total_score'] ?? 0;
    final severity = _submissionResult?['severity_level_display'] ?? '';
    final interp = _submissionResult?['interpretation_ar'] ?? '';
    final sevColor = _getSeverityColor(severity);
    final maxScore = widget.assessmentCode.toUpperCase().contains('PHQ') ? 27 : 21;
    final scoreRatio = (score / maxScore).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('نتائج $_appBarTitle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Clinical Scale Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_outlined, size: 16, color: AppTheme.primaryTeal),
                      const SizedBox(width: 6),
                      Text(
                        'مقياس سريري معتمد وفق معايير DSM-5 (${widget.assessmentCode})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Radial Score Gauge Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: sevColor.withOpacity(0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: sevColor.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Radial Score Ring
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: scoreRatio,
                                strokeWidth: 10,
                                backgroundColor: AppTheme.slateLight,
                                valueColor: AlwaysStoppedAnimation<Color>(sevColor),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$score',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: sevColor,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'من أصل $maxScore',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: sevColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: sevColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          severity,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: sevColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Severity Scale Guide Indicator
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.slateNavy.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.slateNavy.withOpacity(0.07)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune, size: 16, color: AppTheme.slateMuted),
                          SizedBox(width: 6),
                          Text('دليل تصنيف درجات المقياس:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slateNavy)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSeverityLevelBadge('طبيعي/بسيط', '0-4', score <= 4),
                          const SizedBox(width: 4),
                          _buildSeverityLevelBadge('خفيف', '5-9', score >= 5 && score <= 9),
                          const SizedBox(width: 4),
                          _buildSeverityLevelBadge('معتدل', '10-14', score >= 10 && score <= 14),
                          const SizedBox(width: 4),
                          _buildSeverityLevelBadge('شديد', '15+', score >= 15),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Clinical Interpretation Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology_outlined, color: AppTheme.primaryTeal, size: 20),
                            SizedBox(width: 8),
                            Text('التفسير السريري والتوجيه الطبي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                          ],
                        ),
                        const Divider(height: 20),
                        Text(
                          interp.isNotEmpty ? interp : 'بناءً على إجاباتك، يوصى بمتابعة الحالة والتحدث مع أخصائي نفسي معتمد.',
                          style: const TextStyle(fontSize: 13.5, height: 1.65, color: AppTheme.slateNavy),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Referral Actions
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DoctorListScreen()),
                    );
                  },
                  icon: const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                  label: const Text('حجز استشارة مع طبيب نفسي معتمد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AIInterviewScreen()),
                    );
                  },
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('بدء تقييم سريري ذكي معمق مع المساعد الإكلينيكي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityLevelBadge(String label, String range, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryTeal : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppTheme.primaryTeal : AppTheme.slateLight,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : AppTheme.slateNavy,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              range,
              style: TextStyle(
                fontSize: 9,
                color: isActive ? Colors.white.withOpacity(0.9) : AppTheme.slateMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
