import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/widgets/notification_bell_button.dart';
import 'package:frontend/features/ai_interview/ai_interview_screen.dart';
import 'package:frontend/features/assessments/assessment_quiz_screen.dart';
import 'package:frontend/features/reports/ai_report_screen.dart';
import 'package:frontend/features/doctors/doctor_list_screen.dart';
import 'package:frontend/features/analytics/mood_sleep_analytics_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _selectedNavIndex = 0;
  List<dynamic> _appointments = [];
  List<dynamic> _reports = [];
  bool _isLoadingData = true;
  int? _selectedMoodIndex;
  bool _showAllAppointments = false;
  bool _showAllReports = false;

  final List<Map<String, dynamic>> _quickMoods = [
    {'label': 'مرتاح', 'emoji': '🌿', 'score': 10},
    {'label': 'هادئ', 'emoji': '😊', 'score': 8},
    {'label': 'مستقر', 'emoji': '😐', 'score': 6},
    {'label': 'مجهد', 'emoji': '🌧️', 'score': 4},
    {'label': 'قلق', 'emoji': '💭', 'score': 2},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoadingData = true);
    try {
      final appRes = await ApiService.get('/appointments/');
      final repRes = await ApiService.get('/ai/reports/');

      setState(() {
        _appointments = appRes['results'] ?? [];
        _reports = repRes['results'] ?? [];
      });
    } catch (e) {
      // Handled silently for smooth UI
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _recordQuickMood(int index) async {
    setState(() => _selectedMoodIndex = index);
    final mood = _quickMoods[index];
    try {
      await ApiService.post('/treatment/progress/log/', {
        'mood_score': mood['score'],
        'sleep_hours': 7.5,
        'anxiety_level': (mood['score'] as int) <= 4 ? 3 : 1,
        'notes': 'تسجيل سريع من الصفحة الرئيسية: ${mood['label']}',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسجيل حالتك اليومية: ${mood['label']} ${mood['emoji']} وتحديث سجل التحليلات 🌿'),
            backgroundColor: AppTheme.primaryTeal,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _cancelAppointment(String apptId) async {
    final reasonController = TextEditingController();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.alertRose, size: 22),
            SizedBox(width: 8),
            Text('إلغاء الموعد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هل أنت متأكد من رغبتك في إلغاء هذا الموعد؟\n(يمكنك الإلغاء مجاناً حتى ساعتين قبل بدء الجلسة).',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.slateNavy),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء (اختياري)',
                hintText: 'اكتب سبب الإلغاء إن رغبت...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع', style: TextStyle(color: AppTheme.slateMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      try {
        final res = await ApiService.patch('/appointments/$apptId/status/', {
          'status': 'CANCELLED',
          'cancellation_reason': reasonController.text.trim(),
        });

        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الموعد بنجاح.'),
              backgroundColor: AppTheme.sageGreen,
            ),
          );
          _fetchDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'.replaceAll('Exception: ', '')),
              backgroundColor: AppTheme.alertRose,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          _buildHomeDashboard(context),
          const MoodSleepAnalyticsScreen(),
          const DoctorListScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: BottomNavigationBar(
            currentIndex: _selectedNavIndex,
            onTap: (index) => setState(() => _selectedNavIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'الرئيسية',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights),
                label: 'التحليلات والمزاج',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.medical_services_outlined),
                activeIcon: Icon(Icons.medical_services),
                label: 'دليل الأطباء',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeDashboard(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userName = auth.user?['first_name'] ?? 'مستخدمنا العزيز';

    return SafeArea(
      child: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Calming Greeting Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.spa_outlined, color: AppTheme.primaryTeal, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً بك، $userName',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'مساحتك الآمنة للراحة والتعافي 🌿',
                            style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      NotificationBellButton(onOpened: _fetchDashboardData),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _fetchDashboardData,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppTheme.slateNavy.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.refresh, size: 18, color: AppTheme.slateNavy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          await auth.logout();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRose.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.logout_outlined, size: 18, color: AppTheme.alertRose),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Daily Mood / Wellness Check-in Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'كيف تشعر في هذه اللحظة؟',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_quickMoods.length, (index) {
                        final mood = _quickMoods[index];
                        final isSelected = _selectedMoodIndex == index;
                        return InkWell(
                          onTap: () => _recordQuickMood(index),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryTeal.withOpacity(0.12)
                                  : AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryTeal : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(mood['emoji'], style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 4),
                                Text(
                                  mood['label'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? AppTheme.primaryTealDark : AppTheme.slateMuted,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Hero AI Companion Card (Calm Green-to-Blue Gradient)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryTeal, AppTheme.oceanAzure],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'المساعد النفسي الذكي (AraBART)',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'جلسة الاستماع والتقييم السريري',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تحدث بحرية وأمان لاستكشاف مشاعرك وتلخيص حالتك بسرية تامة لتقديم التوصيات المناسبة.',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryTealDark,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AIInterviewScreen()),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('بدء المقابلة السريرية الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Standard Clinical Assessment Scales (PHQ-9 & GAD-7)
              const Text(
                'المقاييس النفسية المعتمدة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
              ),
              const SizedBox(height: 2),
              const Text(
                'اختبارات سريرية دقيقة لقياس مستويات الاكتئاب والقلق',
                style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildScaleCard(
                      title: 'مقياس الاكتئاب (PHQ-9)',
                      subtitle: '9 أسئلة لتقييم المزاج والطاقة',
                      code: 'PHQ-9',
                      icon: Icons.mood_bad_outlined,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildScaleCard(
                      title: 'مقياس القلق (GAD-7)',
                      subtitle: '7 أسئلة لقياس درجات التوتر',
                      code: 'GAD-7',
                      icon: Icons.waves,
                      color: AppTheme.oceanAzure,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Upcoming Appointments Section (Progressive Disclosure)
              if (_appointments.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مواعيدك القادمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy)),
                    if (_appointments.length > 1)
                      TextButton(
                        onPressed: () => setState(() => _showAllAppointments = !_showAllAppointments),
                        child: Text(
                          _showAllAppointments ? 'عرض الأقرب فقط' : 'عرض الكل (${_appointments.length})',
                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Display either top appointment or all if expanded
                ...(_showAllAppointments ? _appointments : [_appointments.first]).map((app) {
                  final isCancelable = app['status'] == 'PENDING' || app['status'] == 'CONFIRMED';
                  final isConfirmed = app['status'] == 'CONFIRMED';
                  final isPending = app['status'] == 'PENDING';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryTeal.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryTeal, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'جلسة مع: ${app['doctor_details']?['title'] ?? 'د.'} ${app['doctor_details']?['full_name'] ?? 'الطبيب'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isConfirmed
                                          ? AppTheme.sageGreen
                                          : isPending
                                              ? AppTheme.oceanAzure
                                              : AppTheme.alertRose)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isPending
                                      ? 'قيد الموافقة'
                                      : isConfirmed
                                          ? '✓ مؤكد'
                                          : 'ملغي',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isConfirmed
                                        ? AppTheme.sageGreen
                                        : isPending
                                            ? AppTheme.oceanAzure
                                            : AppTheme.alertRose,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('التاريخ: ${app['appointment_date']} | الوقت: ${app['start_time']}', style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                          if (isCancelable) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.alertRose,
                                  side: BorderSide(color: AppTheme.alertRose.withOpacity(0.3)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.cancel_outlined, size: 13),
                                label: const Text('إلغاء الموعد', style: TextStyle(fontSize: 11)),
                                onPressed: () => _cancelAppointment(app['id']),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),
              ],

              // Recent Reports Section (Progressive Disclosure)
              if (_reports.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تقاريرك النفسية السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy)),
                    if (_reports.length > 1)
                      TextButton(
                        onPressed: () => setState(() => _showAllReports = !_showAllReports),
                        child: Text(
                          _showAllReports ? 'عرض الأحدث فقط' : 'عرض الكل (${_reports.length})',
                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ...(_showAllReports ? _reports : [_reports.first]).map((rep) {
                  final isHigh = rep['preliminary_risk_level'] == 'HIGH';
                  final iconColor = isHigh ? AppTheme.alertRose : AppTheme.oceanAzure;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: iconColor.withOpacity(0.12),
                        child: Icon(Icons.description_outlined, color: iconColor, size: 20),
                      ),
                      title: Text(
                        'تقرير تقييم أولي (${rep['preliminary_risk_level_display'] ?? rep['preliminary_risk_level']})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text('التخصص المقترح: ${rep['recommended_specialty_display'] ?? rep['recommended_specialty']}', style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMuted)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.slateMuted),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AIReportScreen(reportData: rep)),
                        );
                      },
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaleCard({
    required String title,
    required String subtitle,
    required String code,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssessmentQuizScreen(assessmentCode: code),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.slateLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('⏱️ ~3 دقائق', style: TextStyle(fontSize: 9.5, color: AppTheme.slateMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted, height: 1.3),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'بدء الاختبار',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 12, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
