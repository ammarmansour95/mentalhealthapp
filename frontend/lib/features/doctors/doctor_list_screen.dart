import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';

class DoctorListScreen extends StatefulWidget {
  final String? initialSpecialty;

  const DoctorListScreen({super.key, this.initialSpecialty});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final _searchController = TextEditingController();
  String? _selectedSpecialty;
  List<dynamic> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedSpecialty = widget.initialSpecialty;
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, String>{};
      if (_selectedSpecialty != null && _selectedSpecialty!.isNotEmpty) {
        queryParams['specialty'] = _selectedSpecialty!;
      }
      if (_searchController.text.trim().isNotEmpty) {
        queryParams['search'] = _searchController.text.trim();
      }

      final res = await ApiService.get('/doctors/', queryParams: queryParams);
      setState(() {
        _doctors = res['results'] ?? [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل قائمة الأطباء: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDoctorScheduleModal(Map<String, dynamic> doctor) {
    final List<dynamic> availabilities = (doctor['availabilities'] as List? ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month, color: AppTheme.primaryTeal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جدول وأوقات عمل ${doctor['title'] ?? 'د.'} ${doctor['full_name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slateNavy),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doctor['specialty_display'] ?? doctor['specialty'] ?? '',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryTealDark),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 24),

            if (availabilities.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.sageGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.sageGreen.withOpacity(0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppTheme.sageGreen, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الطبيب متاح لاستقبال الاستشارات طوال أيام الأسبوع (من 09:00 ص إلى 05:00 م).',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.slateNavy, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: availabilities.map((av) {
                  final dayDisplay = av['day_display'] ?? 'يوم عمل';
                  final start = (av['start_time'] as String? ?? '09:00').substring(0, 5);
                  final end = (av['end_time'] as String? ?? '17:00').substring(0, 5);
                  final duration = av['slot_duration_minutes'] ?? 45;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.slateNavy.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.slateNavy.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available, color: AppTheme.primaryTeal, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              dayDisplay,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slateNavy),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$start - $end',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTealDark),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($duration د)',
                              style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openBookingSheet(doctor);
              },
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('الانتقال لحجز موعد', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openBookingSheet(Map<String, dynamic> doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingModal(
        doctor: doctor,
        onViewSchedule: () => _openDoctorScheduleModal(doctor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPushedRoute = Navigator.canPop(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Fluid Top Header
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (isPushedRoute) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppTheme.slateNavy),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'دليل الأطباء والأخصائيين 🩺',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'استشارات وجلسات مجانية مع أطباء معتمدين',
                            style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _fetchDoctors,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.slateNavy.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.refresh, size: 20, color: AppTheme.slateNavy),
                    ),
                  ),
                ],
              ),
            ),

            // Search & Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم الطبيب أو التخصص...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _fetchDoctors();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _fetchDoctors(),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', null),
                        const SizedBox(width: 8),
                        _buildFilterChip('علاج سلوكي معرفي (CBT)', 'CBT_SPECIALIST'),
                        const SizedBox(width: 8),
                        _buildFilterChip('طب نفسي', 'PSYCHIATRY'),
                        const SizedBox(width: 8),
                        _buildFilterChip('علم نفس إكلينيكي', 'CLINICAL_PSYCHOLOGY'),
                        const SizedBox(width: 8),
                        _buildFilterChip('أطفال ومراهقين', 'CHILD_ADOLESCENT'),
                        const SizedBox(width: 8),
                        _buildFilterChip('قلق ومزاج', 'ANXIETY_MOOD'),
                        const SizedBox(width: 8),
                        _buildFilterChip('علاج الصدمات', 'TRAUMA_PTSD'),
                        const SizedBox(width: 8),
                        _buildFilterChip('إرشاد أسري', 'FAMILY_COUNSELING'),
                        const SizedBox(width: 8),
                        _buildFilterChip('علاج الإدمان', 'ADDICTION'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Doctor List Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _doctors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined, size: 64, color: AppTheme.slateMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              const Text('لا يوجد أطباء مطابقين للبحث حالياً.', style: TextStyle(fontSize: 14, color: AppTheme.slateMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _doctors.length,
                          itemBuilder: (context, index) {
                            final doc = _doctors[index];
                            return _buildDoctorCard(doc);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? specialtyCode) {
    final isSelected = _selectedSpecialty == specialtyCode;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.slateNavy),
      onSelected: (selected) {
        setState(() {
          _selectedSpecialty = selected ? specialtyCode : null;
        });
        _fetchDoctors();
      },
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doc) {
    final specialty = doc['specialty_display'] ?? doc['specialty'] ?? 'استشاري نفسي';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openDoctorProfileSheet(doc),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.12),
                    child: const Icon(Icons.person, size: 28, color: AppTheme.primaryTeal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${doc['title'] ?? 'د.'} ${doc['full_name']}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.sageGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('✓ معتمد', style: TextStyle(fontSize: 9.5, color: AppTheme.sageGreen, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Specialty Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                          ),
                          child: Text(
                            specialty,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTealDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppTheme.oceanAzure, size: 16),
                            const SizedBox(width: 3),
                            Text('${doc['rating']} (${doc['total_reviews']})', style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMuted)),
                            const SizedBox(width: 12),
                            const Icon(Icons.work_history_outlined, size: 14, color: AppTheme.slateMuted),
                            const SizedBox(width: 3),
                            Text('${doc['years_of_experience']} سنوات خبرة', style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: AppTheme.slateMuted, size: 18),
                ],
              ),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppTheme.slateNavy.withOpacity(0.15)),
                      ),
                      onPressed: () => _openDoctorProfileSheet(doc),
                      child: const Text(
                        'عرض النبذة والملف',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _openBookingSheet(doc),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.event_available, size: 16),
                      label: const Text(
                        'حجز موعد مجاني',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDoctorProfileSheet(Map<String, dynamic> doc) {
    final specialty = doc['specialty_display'] ?? doc['specialty'] ?? 'استشاري نفسي';
    final bio = doc['bio'] ?? '';
    final quals = doc['qualifications'] as List? ?? [];
    final licenseNo = doc['license_number'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Doctor Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.12),
                    child: const Icon(Icons.person, size: 34, color: AppTheme.primaryTeal),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${doc['title'] ?? 'د.'} ${doc['full_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.slateNavy),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            specialty,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildProfileStatCard('التقييم', '${doc['rating']} ⭐', '${doc['total_reviews']} مراجعة', AppTheme.oceanAzure),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProfileStatCard('الخبرة السريرية', '${doc['years_of_experience']} سنوات', 'ممارسة معتمدة', AppTheme.sageGreen),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bio
              if (bio.isNotEmpty) ...[
                const Text('النبذة المهنية والمنهج العلاجي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slateNavy)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.slateLight),
                  ),
                  child: Text(
                    bio,
                    style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.slateNavy),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Credentials & License
              const Text('المؤهلات والتراخيص الرسمية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slateNavy)),
              const SizedBox(height: 8),
              if (licenseNo.isNotEmpty)
                _buildProfileDetailRow(Icons.badge_outlined, 'رقم ترخيص الهيئة', licenseNo),
              if (quals.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildProfileDetailRow(
                  Icons.school_outlined,
                  'المؤهل الطبي',
                  '${quals.first['degree_title'] ?? 'شهادة معتمدة'} - ${quals.first['institution_name'] ?? 'جامعة معتمدة'}',
                ),
              ],
              const SizedBox(height: 20),

              // Book Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openBookingSheet(doc);
                },
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('متابعة وحجز موعد مع الطبيب', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStatCard(String title, String mainVal, String subVal, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
          const SizedBox(height: 4),
          Text(mainVal, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subVal, style: const TextStyle(fontSize: 10.5, color: AppTheme.slateMuted)),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.slateLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.slateMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateNavy)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingModal extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback? onViewSchedule;

  const BookingModal({super.key, required this.doctor, this.onViewSchedule});

  @override
  State<BookingModal> createState() => _BookingModalState();
}

class _BookingModalState extends State<BookingModal> {
  late DateTime _selectedDate;
  String? _selectedSlot;
  final _notesController = TextEditingController();
  bool _isBooking = false;
  bool _isLoadingSlots = true;
  bool _isAvailableDay = true;
  String _dayName = '';
  List<String> _bookedSlots = [];
  List<String> _timeSlots = [];
  List<String> _activeDaysSummary = [];

  Set<int> get _activeDows {
    final List<dynamic> availabilities = (widget.doctor['availabilities'] as List? ?? []);
    return availabilities
        .where((av) => av['is_active'] == true)
        .map((av) => av['day_of_week'] as int)
        .toSet();
  }

  DateTime _findNextAvailableDate() {
    DateTime d = DateTime.now().add(const Duration(days: 1));
    final active = _activeDows;
    if (active.isEmpty) return d;

    for (int i = 0; i < 14; i++) {
      final backendDow = (d.weekday - 1) % 7;
      if (active.contains(backendDow)) {
        return d;
      }
      d = d.add(const Duration(days: 1));
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _findNextAvailableDate();
    _fetchBookedSlots();
  }

  String get _formattedDate =>
      "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

  Future<void> _fetchBookedSlots() async {
    setState(() => _isLoadingSlots = true);
    try {
      final res = await ApiService.get(
        '/doctors/${widget.doctor['id']}/booked-slots/',
        queryParams: {'date': _formattedDate},
      );
      if (res['success'] == true) {
        final isAvail = res['is_available_day'] == true;
        final available = List<String>.from(res['available_slots'] ?? []);
        final booked = List<String>.from(res['booked_slots'] ?? []);
        final dayName = res['day_name'] ?? '';
        final activeDays = List<String>.from(res['active_days_summary'] ?? []);

        setState(() {
          _isAvailableDay = isAvail;
          _timeSlots = available;
          _bookedSlots = booked;
          _dayName = dayName;
          _activeDaysSummary = activeDays;

          if (!_isAvailableDay || _timeSlots.isEmpty) {
            _selectedSlot = null;
          } else {
            // Pick first non-booked slot
            final firstFree = _timeSlots.firstWhere(
              (s) => !_bookedSlots.contains(s),
              orElse: () => '',
            );
            _selectedSlot = firstFree.isNotEmpty ? firstFree : null;
          }
        });
      }
    } catch (e) {
      // Handled
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _pickDate() async {
    final active = _activeDows;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      selectableDayPredicate: (DateTime date) {
        // Only allow selecting dates on which the doctor actually works
        if (active.isEmpty) return true;
        final backendDow = (date.weekday - 1) % 7;
        return active.contains(backendDow);
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchBookedSlots();
    }
  }

  Future<void> _confirmBooking() async {
    if (!_isAvailableDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، الطبيب غير متاح في هذا اليوم. يرجى اختيار تاريخ آخر يتوافق مع جدول الطبيب.'),
          backgroundColor: AppTheme.alertRose,
        ),
      );
      return;
    }

    if (_selectedSlot == null || _bookedSlots.contains(_selectedSlot)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، يرجى اختيار موعد متاح.'),
          backgroundColor: AppTheme.alertRose,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      final res = await ApiService.post('/appointments/book/', {
        'doctor_id': widget.doctor['id'],
        'appointment_date': _formattedDate,
        'start_time': _selectedSlot,
        'end_time': '10:45:00',
        'patient_notes': _notesController.text.trim(),
      });

      if (res['success'] == true && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الحجز بنجاح! بانتظار موافقة الطبيب.'),
            backgroundColor: AppTheme.sageGreen,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'تعذر إتمام الحجز.'),
            backgroundColor: AppTheme.alertRose,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحجز: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'حجز موعد مع ${widget.doctor['title'] ?? 'د.'} ${widget.doctor['full_name']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),

          // Clean Option to View Doctor's Schedule
          if (widget.onViewSchedule != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: widget.onViewSchedule,
                icon: const Icon(Icons.calendar_month, size: 15, color: AppTheme.primaryTeal),
                label: const Text(
                  'عرض جدول وأوقات عمل الطبيب',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                ),
              ),
            ),
          const SizedBox(height: 6),

          // Date Picker Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryTeal),
                    const SizedBox(width: 8),
                    Text(
                      'تاريخ الجلسة: $_formattedDate${_dayName.isNotEmpty ? ' ($_dayName)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('تغيير التاريخ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingSlots)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (!_isAvailableDay) ...[
            // Doctor Not Available on this Day Notice Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.alertRose.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.alertRose.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_busy, color: AppTheme.alertRose, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الطبيب غير متاح لاستقبال الاستشارات في هذا اليوم ($_dayName)',
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.alertRose, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (_activeDaysSummary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'أيام عمل الطبيب: ${_activeDaysSummary.join(' • ')}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.slateNavy),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Greyed out / Disabled Time Slots
            const Text('فترات اليوم (غير متاحة للحجز):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.slateMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeSlots.map((slot) {
                final display = slot.substring(0, 5);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '$display (غير متاح)',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const Text('اختر وقت الجلسة المتاح:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),
            if (_timeSlots.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('لا توجد فترات متاحة في هذا اليوم.', style: TextStyle(color: AppTheme.slateMuted)),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSlots.map((slot) {
                  final isBooked = _bookedSlots.contains(slot);
                  final isSel = _selectedSlot == slot && !isBooked;
                  final display = slot.substring(0, 5);

                  if (isBooked) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '$display (محجوز)',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return ChoiceChip(
                    label: Text(display, style: TextStyle(color: isSel ? Colors.white : AppTheme.slateNavy, fontWeight: FontWeight.bold)),
                    selected: isSel,
                    selectedColor: AppTheme.primaryTeal,
                    onSelected: (_) => setState(() => _selectedSlot = slot),
                  );
                }).toList(),
              ),
          ],

          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات أو سبب الاستشارة (اختياري)',
            ),
          ),
          const SizedBox(height: 14),

          // Cancellation Policy Notice Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.primaryTeal),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'سياسة الإلغاء: يمكنك إلغاء أو تعديل الموعد مجاناً حتى ساعتين قبل موعد بدء الجلسة.',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.slateNavy, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: (_isBooking || !_isAvailableDay || _selectedSlot == null || _bookedSlots.contains(_selectedSlot))
                ? null
                : _confirmBooking,
            child: _isBooking
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('إرسال طلب الحجز'),
          ),
        ],
      ),
    );
  }
}
