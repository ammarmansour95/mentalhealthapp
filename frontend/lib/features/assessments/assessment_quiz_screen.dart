import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/ai_interview/ai_interview_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_submissionResult != null) {
      return _buildResultScreen();
    }

    final questions = _assessmentData?['questions'] as List? ?? [];
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('لا توجد أسئلة متاحة لهذا المقياس.')),
      );
    }

    final currentQ = questions[_currentQuestionIndex];
    final qId = currentQ['id'];
    final options = currentQ['options'] as List? ?? [];
    final progress = (_currentQuestionIndex + 1) / questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_assessmentData?['title_ar'] ?? widget.assessmentCode),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'السؤال ${_currentQuestionIndex + 1} من ${questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal, fontSize: 13),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.slateMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.slateLight,
              color: AppTheme.primaryTeal,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 22),

            // Instruction Prompt
            const Text(
              'خلال الأسبوعين الماضيين، كم مرة شعرت بالآتي:',
              style: TextStyle(fontSize: 12.5, color: AppTheme.slateMuted),
            ),
            const SizedBox(height: 10),

            // Question Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  currentQ['text_ar'] ?? currentQ['text_en'],
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slateNavy,
                    height: 1.4,
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryTeal.withOpacity(0.08) : AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryTeal : AppTheme.slateLight,
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppTheme.primaryTeal : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt['label_ar'] ?? opt['label_en'],
                            style: TextStyle(
                              fontSize: 14,
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
            const SizedBox(height: 20),

            // Navigation Buttons
            Row(
              children: [
                if (_currentQuestionIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentQuestionIndex--),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('السابق'),
                    ),
                  ),
                if (_currentQuestionIndex > 0) const SizedBox(width: 10),
                Expanded(
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_currentQuestionIndex == questions.length - 1 ? 'إرسال وعرض النتيجة' : 'التالي'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final score = _submissionResult?['total_score'] ?? 0;
    final severity = _submissionResult?['severity_level_display'] ?? '';
    final interp = _submissionResult?['interpretation_ar'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة التقييم السريري')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline, size: 42, color: AppTheme.primaryTeal),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'مجموع الدرجات: $score',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.oceanAzure.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'مستوى الشدة: $severity',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.oceanAzure),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      interp,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13.5, color: AppTheme.slateMuted, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const AIInterviewScreen()),
                        );
                      },
                      icon: const Icon(Icons.psychology, size: 20),
                      label: const Text('المتابعة إلى المقابلة الذكية (AraBART AI)'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('العودة للرئيسية', style: TextStyle(color: AppTheme.slateMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
