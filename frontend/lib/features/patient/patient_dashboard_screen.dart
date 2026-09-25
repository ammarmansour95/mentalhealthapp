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
import 'package:frontend/features/messaging/chat_screen.dart';
import 'package:frontend/features/messaging/conversations_list_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _selectedNavIndex = 0;
  int _appointmentsTabIndex = 0; // 0: Upcoming, 1: Past
  List<dynamic> _appointments = [];
  List<dynamic> _reports = [];
  bool _isLoadingData = true;
  bool _showAllAppointments = false;
  bool _showAllReports = false;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير ';
    } else if (hour < 17) {
      return 'مساء الخير والعافية';
    } else {
      return 'مساء الخير والراحة';
    }
  }

  bool _isUpcomingAppointment(dynamic a) {
    final status = a['status'] ?? '';
    if (status != 'CONFIRMED' && status != 'PENDING') return false;

    final dateStr = a['appointment_date']?.toString() ?? '';
    if (dateStr.isEmpty) return false;

    final endTime = a['end_time']?.toString();
    final startTime = a['start_time']?.toString();
    final timeStr = (endTime != null && endTime.isNotEmpty)
        ? endTime
        : ((startTime != null && startTime.isNotEmpty) ? startTime : '23:59:59');

    DateTime? dt = DateTime.tryParse('$dateStr $timeStr') ?? DateTime.tryParse('${dateStr}T$timeStr');
    if (dt == null) {
      dt = DateTime.tryParse('$dateStr 23:59:59');
    }
    if (dt == null) return false;

    return dt.isAfter(DateTime.now());
  }

  int _compareAppointments(dynamic a, dynamic b) {
    final bool isUpcomingA = _isUpcomingAppointment(a);
    final bool isUpcomingB = _isUpcomingAppointment(b);

    // 1. Upcoming active appointments strictly rank before past/cancelled
    if (isUpcomingA && !isUpcomingB) return -1;
    if (!isUpcomingA && isUpcomingB) return 1;

    // 2. Parse date and time
    final dateStrA = '${a['appointment_date']} ${a['start_time'] ?? '00:00'}';
    final dateStrB = '${b['appointment_date']} ${b['start_time'] ?? '00:00'}';
    final dtA = DateTime.tryParse(dateStrA) ?? DateTime(1970);
    final dtB = DateTime.tryParse(dateStrB) ?? DateTime(1970);

    if (isUpcomingA && isUpcomingB) {
      // Nearest upcoming appointment first (ascending chronological)
      return dtA.compareTo(dtB);
    } else {
      // Most recent past/cancelled appointment first (descending)
      return dtB.compareTo(dtA);
    }
  }

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

      final rawApps = List<dynamic>.from(appRes['results'] ?? []);
      rawApps.sort(_compareAppointments);

      setState(() {
        _appointments = rawApps;
        _reports = repRes['results'] ?? [];
      });
    } catch (e) {
      // Handled silently for smooth UI
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
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
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryTeal.withValues(alpha: 0.15),
                                AppTheme.oceanAzure.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.psychology_outlined, color: AppTheme.primaryTeal, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getGreeting()}، $userName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'مساحتك الآمنة للرعاية والدعم النفسي',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ConversationsListScreen()),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.oceanAzure.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.chat_outlined, size: 18, color: AppTheme.oceanAzure),
                        ),
                      ),
                      const SizedBox(width: 6),
                      NotificationBellButton(onOpened: _fetchDashboardData),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          await auth.logout();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
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
                      color: AppTheme.primaryTeal.withOpacity(0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                              SizedBox(width: 5),
                              Text(
                                'المساعد الإكلينيكي الذكي',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'جلسة الاستماع والفرز الذكي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تحدث بحرية وأمان لاستكشاف مشاعرك وتلخيص حالتك بسرية تامة لتقديم التوصيات الطبية وتوجيهك للأخصائي الأنسب.',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryTealDark,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      label: const Text('بدء المقابلة الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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
                      title: 'مقياس الاكتئاب',
                      subtitle: '9 أسئلة لتقييم المزاج والطاقة',
                      code: 'PHQ-9',
                      icon: Icons.mood_bad_outlined,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildScaleCard(
                      title: 'مقياس القلق',
                      subtitle: '7 أسئلة لقياس درجات التوتر',
                      code: 'GAD-7',
                      icon: Icons.waves,
                      color: AppTheme.oceanAzure,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Unified Appointments Section (Segmented Upcoming vs Past)
              _buildUnifiedAppointmentsSection(),

              // Recent Reports Section (Progressive Disclosure with Clinical Badges)
              if (_reports.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, color: AppTheme.primaryTeal, size: 18),
                        SizedBox(width: 6),
                        Text('تقارير التقييم والفرز الذكي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy)),
                      ],
                    ),
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
                  final riskDisplay = rep['preliminary_risk_level_display'] ?? rep['preliminary_risk_level'] ?? 'مكتمل';
                  final specialty = rep['recommended_specialty_display'] ?? rep['recommended_specialty'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AIReportScreen(reportData: rep)),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: iconColor.withOpacity(0.12),
                              child: Icon(Icons.description_outlined, color: iconColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'تقرير تقييم: $riskDisplay',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slateNavy),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'التخصص المقترح: $specialty',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('عرض', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark)),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_left, size: 14, color: AppTheme.primaryTealDark),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildUnifiedAppointmentsSection() {
    final upcomingApps = _appointments.where(_isUpcomingAppointment).toList();
    final pastApps = _appointments.where((a) => !_isUpcomingAppointment(a)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header with Segmented Pill Switcher
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_outlined, color: AppTheme.primaryTeal, size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'جدول المواعيد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                ),
              ],
            ),
            // Segmented Switcher
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.slateLight.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppointmentFilterPill(
                    label: 'القادمة (${upcomingApps.length})',
                    index: 0,
                  ),
                  _buildAppointmentFilterPill(
                    label: 'السابقة (${pastApps.length})',
                    index: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Body: Depending on tab
        if (_appointmentsTabIndex == 0) ...[
          if (upcomingApps.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.slateLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_available_outlined, color: AppTheme.primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('لا توجد مواعيد قادمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slateNavy)),
                        SizedBox(height: 2),
                        Text('احجز جلسة استشارية جديدة مع أطبائنا المعتمدين', style: TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedNavIndex = 2),
                    child: const Text('حجز الآن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                  ),
                ],
              ),
            )
          else ...[
            ...(_showAllAppointments ? upcomingApps : [upcomingApps.first]).map((app) {
              final isConfirmed = app['status'] == 'CONFIRMED';
              final rawDoc = (app['doctor_details']?['full_name'] ?? 'الطبيب').toString().trim();
              final docDisplayName = rawDoc.startsWith('د.') ? rawDoc : 'د. $rawDoc';

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
                              color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryTeal, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'جلسة مع: $docDisplayName',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isConfirmed ? AppTheme.sageGreen : AppTheme.oceanAzure).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isConfirmed ? 'مؤكد' : 'قيد الموافقة',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isConfirmed ? AppTheme.sageGreen : AppTheme.oceanAzure,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'التاريخ: ${app['appointment_date']} | الوقت: ${app['start_time']}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isConfirmed ? AppTheme.primaryTeal : AppTheme.oceanAzure,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 14),
                              label: Text(
                                isConfirmed ? 'دخول الجلسة / المحادثة' : 'محادثة الطبيب',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      otherProfileId: app['doctor']?.toString(),
                                      otherUserName: 'د. ${app['doctor_details']?['full_name'] ?? 'الطبيب'}',
                                      otherUserRole: 'طبيب معتمد',
                                    ),
                                  ),
                                );
                              },
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.alertRose,
                                side: BorderSide(color: AppTheme.alertRose.withValues(alpha: 0.3)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 13),
                              label: const Text('إلغاء الموعد', style: TextStyle(fontSize: 11)),
                              onPressed: () => _cancelAppointment(app['id']),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (upcomingApps.length > 1)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => setState(() => _showAllAppointments = !_showAllAppointments),
                  child: Text(
                    _showAllAppointments ? 'عرض الأقرب فقط ▴' : 'عرض كافة المواعيد القادمة (${upcomingApps.length}) ▾',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ] else ...[
          // Past Appointments Tab
          if (pastApps.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.slateLight),
              ),
              child: const Center(
                child: Text(
                  'لا توجد مواعيد سابقة مسجلة.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.slateMuted),
                ),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.slateLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: pastApps.map((app) {
                    final status = app['status'] ?? '';
                    final isCancelled = status == 'CANCELLED';
                    final isCompleted = status == 'COMPLETED';
                    final statusLabel = isCancelled ? 'ملغي' : (isCompleted ? 'مكتمل' : 'منتهي');
                    final statusColor = isCancelled ? AppTheme.alertRose : AppTheme.slateMuted;

                    final rawDoc = (app['doctor_details']?['full_name'] ?? 'الطبيب').toString().trim();
                    final docName = rawDoc.startsWith('د.') ? rawDoc : 'د. $rawDoc';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.slateLight),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCancelled ? Icons.event_busy_outlined : Icons.event_available_outlined,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'جلسة مع: $docName',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                                Text(
                                  '${app['appointment_date']} (${app['start_time'] ?? ''}) - $statusLabel',
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.slateMuted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildAppointmentFilterPill({required String label, required int index}) {
    final isSelected = _appointmentsTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _appointmentsTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.slateNavy,
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
