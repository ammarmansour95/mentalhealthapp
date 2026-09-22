import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/widgets/notification_bell_button.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'package:frontend/features/messaging/chat_screen.dart';
import 'package:frontend/features/messaging/conversations_list_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  Map<String, dynamic>? _doctorProfile;
  List<dynamic> _appointments = [];
  List<dynamic> _reports = [];
  List<dynamic> _assessments = [];
  List<dynamic> _availabilities = [];
  bool _isLoading = true;
  bool _isSubmittingCredentials = false;
  int _selectedDoctorTab = 0; // 0: Appointments, 1: AI Reports & Assessments, 2: Schedule & Profile
  String _appointmentStatusFilter = 'ALL'; // 'ALL', 'PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED'

  // Onboarding / Credentialing Form Controllers
  String _selectedSpecialty = 'CBT_SPECIALIST';
  final _licenseController = TextEditingController();
  final _yearsExpController = TextEditingController();
  final _degreeController = TextEditingController();
  final _institutionController = TextEditingController();
  final _bioController = TextEditingController();
  String? _attachedDocumentName;
  String? _selectedFilePath;

  final List<Map<String, String>> _specialties = [
    {'value': 'CBT_SPECIALIST', 'label': 'علاج سلوكي معرفي (CBT Specialist)'},
    {'value': 'PSYCHIATRY', 'label': 'طب نفسي واستشارات دوائية (Psychiatry)'},
    {'value': 'CLINICAL_PSYCHOLOGY', 'label': 'علم نفس إكلينيكي (Clinical Psychology)'},
    {'value': 'CHILD_ADOLESCENT', 'label': 'طب نفسي للأطفال والمراهقين (Child & Adolescent)'},
    {'value': 'ANXIETY_MOOD', 'label': 'اضطرابات القلق والمزاج (Anxiety & Mood)'},
    {'value': 'TRAUMA_PTSD', 'label': 'علاج الصدمات النفسية (Trauma & PTSD)'},
    {'value': 'FAMILY_COUNSELING', 'label': 'إرشاد أسري وزوجي (Family & Couples)'},
    {'value': 'ADDICTION', 'label': 'علاج وتأهيل الإدمان (Addiction Rehab)'},
  ];

  final List<Map<String, dynamic>> _weekDays = [
    {'day_of_week': 6, 'name': 'الأحد', 'name_en': 'Sunday'},
    {'day_of_week': 0, 'name': 'الاثنين', 'name_en': 'Monday'},
    {'day_of_week': 1, 'name': 'الثلاثاء', 'name_en': 'Tuesday'},
    {'day_of_week': 2, 'name': 'الأربعاء', 'name_en': 'Wednesday'},
    {'day_of_week': 3, 'name': 'الخميس', 'name_en': 'Thursday'},
    {'day_of_week': 4, 'name': 'الجمعة', 'name_en': 'Friday'},
    {'day_of_week': 5, 'name': 'السبت', 'name_en': 'Saturday'},
  ];

  int _compareAppointments(dynamic a, dynamic b) {
    final statusA = a['status'] ?? '';
    final statusB = b['status'] ?? '';
    final bool isActiveA = statusA == 'CONFIRMED' || statusA == 'PENDING';
    final bool isActiveB = statusB == 'CONFIRMED' || statusB == 'PENDING';

    if (isActiveA && !isActiveB) return -1;
    if (!isActiveA && isActiveB) return 1;

    final dateStrA = '${a['appointment_date']} ${a['start_time'] ?? '00:00'}';
    final dateStrB = '${b['appointment_date']} ${b['start_time'] ?? '00:00'}';
    final dtA = DateTime.tryParse(dateStrA) ?? DateTime(1970);
    final dtB = DateTime.tryParse(dateStrB) ?? DateTime(1970);

    if (isActiveA && isActiveB) {
      return dtA.compareTo(dtB);
    } else {
      return dtB.compareTo(dtA);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  Future<void> _fetchDoctorData() async {
    setState(() => _isLoading = true);
    try {
      final profRes = await ApiService.get('/doctors/profile/me/');
      if (profRes['success'] == true) {
        _doctorProfile = profRes['doctor'];
        final isVerified = _doctorProfile?['is_verified'] == true;

        if (_doctorProfile != null) {
          if (_licenseController.text.isEmpty && _doctorProfile!['license_number'] != null) {
            _licenseController.text = _doctorProfile!['license_number'];
          }
          if (_yearsExpController.text.isEmpty && _doctorProfile!['years_of_experience'] != null) {
            _yearsExpController.text = '${_doctorProfile!['years_of_experience']}';
          }
          if (_bioController.text.isEmpty && _doctorProfile!['bio'] != null) {
            _bioController.text = _doctorProfile!['bio'];
          }
          if (_doctorProfile!['specialty'] != null) {
            _selectedSpecialty = _doctorProfile!['specialty'];
          }
        }

        if (isVerified) {
          try {
            final appRes = await ApiService.get('/appointments/');
            List<dynamic> rawApps = [];
            if (appRes is List) {
              rawApps = List<dynamic>.from(appRes);
            } else if (appRes is Map && appRes.containsKey('results')) {
              rawApps = List<dynamic>.from(appRes['results'] ?? []);
            } else if (appRes is Map && appRes.containsKey('appointments')) {
              rawApps = List<dynamic>.from(appRes['appointments'] ?? []);
            }
            rawApps.sort(_compareAppointments);
            _appointments = rawApps;
          } catch (_) {
            _appointments = [];
          }

          try {
            final repRes = await ApiService.get('/ai/reports/');
            if (repRes is List) {
              _reports = repRes;
            } else if (repRes is Map && repRes.containsKey('results')) {
              _reports = repRes['results'] ?? [];
            } else if (repRes is Map && repRes.containsKey('reports')) {
              _reports = repRes['reports'] ?? [];
            }
          } catch (_) {
            _reports = [];
          }

          try {
            final assessRes = await ApiService.get('/assessments/history/');
            if (assessRes is List) {
              _assessments = assessRes;
            } else if (assessRes is Map && assessRes.containsKey('results')) {
              _assessments = assessRes['results'] ?? [];
            }
          } catch (_) {
            _assessments = [];
          }

          try {
            final availRes = await ApiService.get('/doctors/availability/');
            _availabilities = availRes['availabilities'] ?? [];
          } catch (_) {
            _availabilities = [];
          }
        }
      }
    } catch (e) {
      // Handled
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFileFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _attachedDocumentName = result.files.single.name;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم اختيار الملف: $_attachedDocumentName'),
              backgroundColor: AppTheme.sageGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح منتقي الملفات: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedFilePath = image.path;
          _attachedDocumentName = image.name;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم اختيار صورة الوثيقة: $_attachedDocumentName'),
              backgroundColor: AppTheme.sageGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الصورة: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedFilePath = photo.path;
          _attachedDocumentName = photo.name;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم التقاط صورة الوثيقة: $_attachedDocumentName'),
              backgroundColor: AppTheme.sageGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الكاميرا: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  Future<void> _submitDoctorCredentials() async {
    if (_licenseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم الترخيص المهني.'), backgroundColor: AppTheme.alertRose),
      );
      return;
    }

    setState(() => _isSubmittingCredentials = true);
    try {
      final fields = {
        'specialty': _selectedSpecialty,
        'license_number': _licenseController.text.trim(),
        'years_of_experience': (_yearsExpController.text.trim().isNotEmpty ? _yearsExpController.text.trim() : '1'),
        'degree_title': _degreeController.text.trim().isNotEmpty ? _degreeController.text.trim() : 'شهادة تصنيف مهني معتمدة',
        'institution_name': _institutionController.text.trim().isNotEmpty ? _institutionController.text.trim() : 'الهيئة السعودية للتخصصات الصحية',
        'bio': _bioController.text.trim(),
        'document_name': _attachedDocumentName ?? 'وثيقة_الترخيص_المهني_المعتمدة.pdf',
      };

      dynamic res;
      if (_selectedFilePath != null) {
        res = await ApiService.patchMultipart(
          '/doctors/profile/me/',
          fields,
          filePath: _selectedFilePath,
          fileField: 'document_file',
        );
      } else {
        res = await ApiService.patch('/doctors/profile/me/', fields);
      }

      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']), backgroundColor: AppTheme.sageGreen),
        );
        _fetchDoctorData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingCredentials = false);
    }
  }

  void _openDocumentPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.upload_file, color: AppTheme.primaryTeal, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'رفع وثيقة أو صورة الترخيص الطبي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slateNavy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'اختر ملف الترخيص (PDF) أو التقط صورة لشهادة المزاولة (JPG/PNG)',
              style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
            ),
            const Divider(height: 20),

            // Option 1: Pick File (PDF/Image)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_open, color: AppTheme.primaryTeal),
                ),
                title: const Text('اختيار ملف PDF / مستند من الجهاز', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('الملفات بصيغة PDF, JPG, PNG', style: TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                trailing: const Icon(Icons.chevron_left, color: AppTheme.slateMuted, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFileFromDevice();
                },
              ),
            ),

            // Option 2: Gallery Image
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.oceanAzure.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppTheme.oceanAzure),
                ),
                title: const Text('اختيار صورة الوثيقة من المعرض (Gallery)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('صور الشهادات والوثائق المحفوظة', style: TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                trailing: const Icon(Icons.chevron_left, color: AppTheme.slateMuted, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromGallery();
                },
              ),
            ),

            // Option 3: Camera Photo
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.sageGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppTheme.sageGreen),
                ),
                title: const Text('التقاط صورة مباشرة للشهادة بالكاميرا', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('تصوير رخصة المزاولة الورقية فوراً', style: TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                trailing: const Icon(Icons.chevron_left, color: AppTheme.slateMuted, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _takePhotoWithCamera();
                },
              ),
            ),

            // Option 4: Quick Sample Certified License
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_outlined, color: AppTheme.primaryTeal),
                ),
                title: const Text('استخدام وثيقة ترخيص نموذجية (تجريبي)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('SCFHS_Medical_License_Certified.pdf', style: TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primaryTeal, size: 18),
                onTap: () {
                  setState(() {
                    _selectedFilePath = null;
                    _attachedDocumentName = 'شهادة_التصنيف_والترخيص_المهني_SCFHS.pdf';
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديد الوثيقة النموذجية بنجاح.'),
                      backgroundColor: AppTheme.sageGreen,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openScheduleManagerModal() {
    final Map<int, Map<String, dynamic>> scheduleMap = {};
    for (var day in _weekDays) {
      final dow = day['day_of_week'] as int;
      scheduleMap[dow] = {
        'day_of_week': dow,
        'name': day['name'],
        'is_active': false,
        'start_time': const TimeOfDay(hour: 9, minute: 0),
        'end_time': const TimeOfDay(hour: 17, minute: 0),
        'duration': 45,
      };
    }

    for (var av in _availabilities) {
      final dow = av['day_of_week'] as int;
      if (scheduleMap.containsKey(dow)) {
        final startParts = (av['start_time'] as String).split(':');
        final endParts = (av['end_time'] as String).split(':');
        scheduleMap[dow] = {
          'day_of_week': dow,
          'name': scheduleMap[dow]!['name'],
          'is_active': av['is_active'] == true,
          'start_time': TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1])),
          'end_time': TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1])),
          'duration': av['slot_duration_minutes'] ?? 45,
        };
      }
    }

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.schedule, color: AppTheme.primaryTeal, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'جدول وساعات العمل الأسبوعية',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slateNavy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'حدد أيام وساعات استقبال المرضى للجلسات الاستشارية',
                  style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                ),
                const SizedBox(height: 12),

                // Quick Apply Action
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تطبيق سريع على الأيام المفعلة:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slateNavy),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                final st = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                                if (st == null) return;
                                if (!context.mounted) return;
                                final et = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 17, minute: 0));
                                if (et == null) return;

                                setModalState(() {
                                  scheduleMap.forEach((dow, item) {
                                    if (item['is_active'] == true) {
                                      item['start_time'] = st;
                                      item['end_time'] = et;
                                    }
                                  });
                                });
                              },
                              icon: const Icon(Icons.copy_all, size: 14),
                              label: const Text('تطبيق التوقيت للكل', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                scheduleMap.forEach((dow, item) {
                                  item['is_active'] = (dow == 6 || dow == 0 || dow == 1 || dow == 2 || dow == 3);
                                });
                              });
                            },
                            child: const Text('تفعيل (الأحد - الخميس)', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),

                // Days list
                ..._weekDays.map((day) {
                  final dow = day['day_of_week'] as int;
                  final item = scheduleMap[dow]!;
                  final bool isActive = item['is_active'];
                  final TimeOfDay startTime = item['start_time'];
                  final TimeOfDay endTime = item['end_time'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      isActive ? Icons.event_available : Icons.event_busy,
                                      color: isActive ? AppTheme.primaryTeal : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      day['name']!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: isActive ? AppTheme.slateNavy : AppTheme.slateMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isActive,
                                activeColor: AppTheme.primaryTeal,
                                onChanged: (val) {
                                  setModalState(() => item['is_active'] = val);
                                },
                              ),
                            ],
                          ),
                          if (isActive) ...[
                            const Divider(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: startTime,
                                      );
                                      if (picked != null) {
                                        setModalState(() => item['start_time'] = picked);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.slateNavy.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('من الساعة', style: TextStyle(fontSize: 10, color: AppTheme.slateMuted)),
                                          const SizedBox(height: 2),
                                          Text(
                                            startTime.format(context),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.slateNavy),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: endTime,
                                      );
                                      if (picked != null) {
                                        setModalState(() => item['end_time'] = picked);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.slateNavy.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('إلى الساعة', style: TextStyle(fontSize: 10, color: AppTheme.slateMuted)),
                                          const SizedBox(height: 2),
                                          Text(
                                            endTime.format(context),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.slateNavy),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // Save Schedule Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);

                          final List<Map<String, dynamic>> payload = [];
                          scheduleMap.forEach((dow, item) {
                            if (item['is_active'] == true) {
                              final TimeOfDay st = item['start_time'];
                              final TimeOfDay et = item['end_time'];
                              payload.add({
                                'day_of_week': dow,
                                'start_time': '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')}:00',
                                'end_time': '${et.hour.toString().padLeft(2, '0')}:${et.minute.toString().padLeft(2, '0')}:00',
                                'slot_duration_minutes': item['duration'] ?? 45,
                                'is_active': true,
                              });
                            }
                          });

                          try {
                            final res = await ApiService.post('/doctors/availability/', {
                              'schedules': payload,
                            });
                            nav.pop();
                            _fetchDoctorData();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'تم حفظ جدول المواعيد بنجاح.'),
                                backgroundColor: AppTheme.sageGreen,
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.alertRose),
                            );
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('حفظ جدول ساعات العمل', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReportReviewModal(Map<String, dynamic> report) {
    final notesController = TextEditingController(text: report['doctor_review_notes_encrypted'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('مراجعة التقرير الأولي (${report['patient_name'] ?? 'مريض'})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ملخص المساعد الذكي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.primaryTealDark)),
                      const SizedBox(height: 4),
                      Text(report['summary_ar_encrypted'] ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('ملاحظات وتقييم الطبيب السريري:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'اكتب التشخيص المهني وتوصيات الخطة العلاجية...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.slateMuted)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      try {
                        await ApiService.patch('/ai/reports/${report['id']}/review/', {
                          'doctor_notes': notesController.text.trim(),
                        });
                        nav.pop();
                        _fetchDoctorData();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('تم حفظ مراجعة التقرير بنجاح.'), backgroundColor: AppTheme.sageGreen),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.alertRose),
                        );
                      } finally {
                        setModalState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('اعتماد وحفظ المراجعة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAppointmentStatus(String apptId, String newStatus) async {
    try {
      final res = await ApiService.patch('/appointments/$apptId/status/', {
        'status': newStatus,
        'cancellation_reason': newStatus == 'CANCELLED' ? 'Cancelled by Doctor' : '',
      });

      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'CONFIRMED' ? 'تم قبول وتأكيد الموعد بنجاح.' : 'تم إلغاء الموعد.'),
            backgroundColor: newStatus == 'CONFIRMED' ? AppTheme.sageGreen : AppTheme.alertRose,
          ),
        );
        _fetchDoctorData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final doctorName = auth.user?['first_name'] ?? 'دكتور';
    final isVerified = _doctorProfile?['is_verified'] == true;
    final highRiskReports = _reports.where((r) => r['preliminary_risk_level'] == 'HIGH' || r['safety_warning_triggered'] == true).toList();

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchDoctorData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Doctor Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (isVerified ? AppTheme.sageGreen : AppTheme.oceanAzure).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isVerified ? Icons.verified_user_outlined : Icons.pending_outlined,
                                  color: isVerified ? AppTheme.sageGreen : AppTheme.oceanAzure,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'د. $doctorName',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isVerified ? '✓ طبيب معتمد ومصرح' : 'حساب قيد الاعتماد والمراجعة',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isVerified ? AppTheme.sageGreen : AppTheme.oceanAzure,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ConversationsListScreen()),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: AppTheme.oceanAzure.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.chat_outlined, size: 18, color: AppTheme.oceanAzure),
                                ),
                              ),
                              const SizedBox(width: 8),
                              NotificationBellButton(onOpened: _fetchDoctorData),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _fetchDoctorData,
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
                      const SizedBox(height: 18),

                      // If UNVERIFIED -> Show Credentialing Gate
                      if (!isVerified)
                        _buildVerificationGate()
                      else ...[
                        // Emergency Crisis Alert Banner (If Any Patient in High Risk / Suicide Ideation)
                        if (highRiskReports.isNotEmpty) ...[
                          _buildEmergencyCrisisBanner(highRiskReports),
                          const SizedBox(height: 16),
                        ],

                        // Segmented Tab Selector for Clean Navigation
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.slateLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _buildSegmentTab(0, 'المواعيد (${_appointments.length})', Icons.calendar_month),
                              _buildSegmentTab(1, 'التقارير السريرية (${_reports.length})', Icons.psychology_outlined),
                              _buildSegmentTab(2, 'الجدول والملف', Icons.access_time),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Render Selected Tab Content
                        if (_selectedDoctorTab == 0) _buildAppointmentsTab(),
                        if (_selectedDoctorTab == 1) _buildReportsTab(),
                        if (_selectedDoctorTab == 2) _buildScheduleAndProfileTab(),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmergencyCrisisBanner(List<dynamic> urgentReports) {
    final firstRep = urgentReports.first as Map<String, dynamic>;
    final pName = firstRep['patient_name'] ?? 'مريض مسجل';
    final pEmail = (firstRep['patient_email'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.alertRose.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.alertRose.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.alertRose.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency_rounded, color: AppTheme.alertRose, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚨 تنبيه طوارئ سريرية حرجة (${urgentReports.length} حالات في خطر مرتفع)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.alertRose),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تم رصد إشارات خطر إيذاء نفس أو رغبة بالانتحار للمريض: $pName ${pEmail.isNotEmpty ? "($pEmail)" : ""}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.slateNavy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRose,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() => _selectedDoctorTab = 1);
                },
                icon: const Icon(Icons.psychology_outlined, size: 16),
                label: const Text('الانتقال للتقارير السريرية 👁️', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.alertRose,
                  side: BorderSide(color: AppTheme.alertRose.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openReportReviewModal(firstRep),
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('مراجعة فورية للحالة', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, String label, IconData icon) {
    final isSelected = _selectedDoctorTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDoctorTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppTheme.primaryTeal : AppTheme.slateMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryTealDark : AppTheme.slateMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: APPOINTMENTS ---
  Widget _buildAppointmentsTab() {
    if (_appointments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(Icons.event_available, size: 40, color: AppTheme.primaryTeal.withOpacity(0.4)),
              const SizedBox(height: 12),
              const Text('لا توجد مواعيد مسجلة حالياً.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final pendingList = _appointments.where((a) => a['status'] == 'PENDING').toList();
    final confirmedList = _appointments.where((a) => a['status'] == 'CONFIRMED').toList();
    final completedList = _appointments.where((a) => a['status'] == 'COMPLETED').toList();
    final cancelledList = _appointments.where((a) => a['status'] == 'CANCELLED').toList();
    final patientCancelledList = cancelledList.where((a) => a['is_cancelled_by_patient'] == true).toList();

    List<dynamic> filteredList;
    if (_appointmentStatusFilter == 'PENDING') {
      filteredList = pendingList;
    } else if (_appointmentStatusFilter == 'CONFIRMED') {
      filteredList = confirmedList;
    } else if (_appointmentStatusFilter == 'COMPLETED') {
      filteredList = completedList;
    } else if (_appointmentStatusFilter == 'CANCELLED') {
      filteredList = cancelledList;
    } else {
      filteredList = _appointments;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Patient Cancellation Notification Alert Banner (If Any)
        if (patientCancelledList.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.alertRose.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.alertRose.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined, color: AppTheme.alertRose, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إشعار إلغاء: قام مريض بإلغاء موعد (${patientCancelledList.length} مواعيد ملغية من قِبل المرضى)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.alertRose),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المريض: ${patientCancelledList.first['patient_name'] ?? 'مريض'} - السبب: ${patientCancelledList.first['cancellation_reason'] ?? 'تم الإلغاء بواسطة المريض'}',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.slateNavy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2. Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildApptFilterChip('ALL', 'الكل (${_appointments.length})'),
              const SizedBox(width: 6),
              _buildApptFilterChip('PENDING', '⏳ قيد الموافقة (${pendingList.length})', isHighlight: pendingList.isNotEmpty),
              const SizedBox(width: 6),
              _buildApptFilterChip('CONFIRMED', '📅 المؤكدة (${confirmedList.length})'),
              const SizedBox(width: 6),
              _buildApptFilterChip('COMPLETED', '✅ المكتملة (${completedList.length})'),
              const SizedBox(width: 6),
              _buildApptFilterChip('CANCELLED', '🚫 الملغية (${cancelledList.length})'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Appointments List
        if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('لا توجد مواعيد في هذا التصنيف حالياً.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12.5)),
            ),
          )
        else
          ...filteredList.map((app) {
            final status = app['status'];
            final isConfirmed = status == 'CONFIRMED';
            final isPending = status == 'PENDING';
            final isCancelled = status == 'CANCELLED';
            final isCompleted = status == 'COMPLETED';
            final riskLevel = app['patient_risk_level'] ?? 'LOW';
            final bool isHighRisk = riskLevel == 'HIGH';
            final bool isModRisk = riskLevel == 'MODERATE';
            final bool isPatientCancelled = app['is_cancelled_by_patient'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Patient & Badges
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline, color: AppTheme.primaryTeal, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app['patient_name'] ?? 'مريض مسجل',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slateNavy),
                              ),
                              if (app['patient_email'] != null)
                                Text(
                                  app['patient_email'],
                                  style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                                ),
                            ],
                          ),
                        ),
                        // Patient Risk Situation Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: (isHighRisk
                                    ? AppTheme.alertRose
                                    : isModRisk
                                        ? AppTheme.oceanAzure
                                        : AppTheme.sageGreen)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isHighRisk
                                ? '🔴 خطورة مرتفعة'
                                : isModRisk
                                    ? '🟡 خطورة متوسطة'
                                    : '🟢 حالة مستقرة',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isHighRisk
                                  ? AppTheme.alertRose
                                  : isModRisk
                                      ? AppTheme.oceanAzure
                                      : AppTheme.sageGreen,
                            ),
                          ),
                        ),
                        // Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isConfirmed
                                    ? AppTheme.sageGreen
                                    : isPending
                                        ? AppTheme.oceanAzure
                                        : isCompleted
                                            ? AppTheme.primaryTeal
                                            : AppTheme.alertRose)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isConfirmed
                                ? '✓ مؤكد'
                                : isPending
                                    ? 'قيد الموافقة'
                                    : isCompleted
                                        ? 'مكتمل'
                                        : 'ملغي',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isConfirmed
                                  ? AppTheme.sageGreen
                                  : isPending
                                      ? AppTheme.oceanAzure
                                      : isCompleted
                                          ? AppTheme.primaryTeal
                                          : AppTheme.alertRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),

                    // Date & Time
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.primaryTeal),
                        const SizedBox(width: 6),
                        Text(
                          'التاريخ: ${app['appointment_date']}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.access_time, size: 14, color: AppTheme.primaryTeal),
                        const SizedBox(width: 6),
                        Text(
                          'الوقت: ${(app['start_time'] as String).substring(0, 5)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.slateNavy),
                        ),
                      ],
                    ),

                    // Patient Notes if any
                    if (app['patient_notes'] != null && (app['patient_notes'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.slateLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 13, color: AppTheme.slateMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'ملاحظات المريض: ${app['patient_notes']}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.slateNavy),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Cancellation Details if Cancelled
                    if (isCancelled) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRose.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.alertRose.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel_outlined, size: 14, color: AppTheme.alertRose),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isPatientCancelled
                                    ? '⚠️ أُلغي من قِبل المريض: ${app['cancellation_reason'] ?? 'بدون سبب معلن'}'
                                    : 'أُلغي من قِبل الطبيب/الإدارة: ${app['cancellation_reason'] ?? 'تم الإلغاء'}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.alertRose),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action Buttons
                    if (isPending) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.alertRose,
                              side: BorderSide(color: AppTheme.alertRose.withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _updateAppointmentStatus(app['id'], 'CANCELLED'),
                            child: const Text('رفض الموعد', style: TextStyle(fontSize: 11.5)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.sageGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _updateAppointmentStatus(app['id'], 'CONFIRMED'),
                            child: const Text('قبول وتأكيد الموعد', style: TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                    ],
                    if (isConfirmed || isCompleted) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline, size: 14),
                            label: const Text('محادثة المريض', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    otherProfileId: app['patient']?.toString() ?? app['patient_id']?.toString(),
                                    otherUserName: app['patient_name'] ?? 'المريض',
                                    otherUserRole: 'مريض',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildApptFilterChip(String filterKey, String label, {bool isHighlight = false}) {
    final isSelected = _appointmentStatusFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isHighlight ? AppTheme.oceanAzure : AppTheme.slateNavy),
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal,
      backgroundColor: isHighlight ? AppTheme.oceanAzure.withOpacity(0.12) : AppTheme.slateLight,
      onSelected: (selected) {
        if (selected) setState(() => _appointmentStatusFilter = filterKey);
      },
    );
  }

  // --- TAB 2: CLINICAL REPORTS & PSYCHOLOGICAL ASSESSMENTS (PHQ-9, GAD-7, AraBERT) ---
  Widget _buildReportsTab() {
    if (_reports.isEmpty && _assessments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(Icons.psychology_outlined, size: 40, color: AppTheme.oceanAzure.withOpacity(0.4)),
              const SizedBox(height: 12),
              const Text('لا توجد تقارير سريرية أو مقاييس مسجلة حالياً.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // Group both AI Reports and Scale Assessments (PHQ-9, GAD-7) by Patient Key (Email / ID / Name)
    final Map<String, Map<String, dynamic>> patientGroups = {};

    String getPatientKey(dynamic item) {
      if (item is! Map) return 'unknown';
      final email = (item['patient_email'] as String?)?.trim().toLowerCase();
      if (email != null && email.isNotEmpty) return email;
      final id = item['patient_id']?.toString() ?? item['patient']?.toString();
      if (id != null && id.isNotEmpty) return id;
      return (item['patient_name'] as String?)?.trim() ?? 'unknown';
    }

    // 1. Process AI Reports
    for (final rep in _reports) {
      final pKey = getPatientKey(rep);
      final pName = rep['patient_name'] ?? 'مريض مسجل';
      final pEmail = rep['patient_email'];

      if (!patientGroups.containsKey(pKey)) {
        patientGroups[pKey] = {
          'patient_key': pKey,
          'patient_name': pName,
          'patient_email': pEmail,
          'reports': <dynamic>[],
          'assessments': <dynamic>[],
          'highest_risk': rep['preliminary_risk_level'] ?? 'LOW',
          'latest_date': rep['created_at'] ?? '',
        };
      }

      final group = patientGroups[pKey]!;
      (group['reports'] as List<dynamic>).add(rep);

      final curRisk = rep['preliminary_risk_level'] ?? 'LOW';
      if (curRisk == 'HIGH') {
        group['highest_risk'] = 'HIGH';
      } else if (curRisk == 'MODERATE' && group['highest_risk'] != 'HIGH') {
        group['highest_risk'] = 'MODERATE';
      }
    }

    // 2. Process Psychological Assessments (PHQ-9 & GAD-7)
    for (final ass in _assessments) {
      final pKey = getPatientKey(ass);
      final pName = ass['patient_name'] ?? 'مريض مسجل';
      final pEmail = ass['patient_email'];

      if (!patientGroups.containsKey(pKey)) {
        patientGroups[pKey] = {
          'patient_key': pKey,
          'patient_name': pName,
          'patient_email': pEmail,
          'reports': <dynamic>[],
          'assessments': <dynamic>[],
          'highest_risk': 'LOW',
          'latest_date': ass['created_at'] ?? '',
        };
      }

      final group = patientGroups[pKey]!;
      (group['assessments'] as List<dynamic>).add(ass);

      // Check severity level
      final sev = ass['severity_level'] ?? '';
      if (sev == 'SEVERE' || sev == 'MODERATELY_SEVERE') {
        group['highest_risk'] = 'HIGH';
      } else if (sev == 'MODERATE' && group['highest_risk'] != 'HIGH') {
        group['highest_risk'] = 'MODERATE';
      }
    }

    // Sort all entries in each patient group by date (newest first)
    patientGroups.forEach((key, group) {
      (group['reports'] as List<dynamic>).sort((a, b) {
        final da = a['created_at'] ?? '';
        final db = b['created_at'] ?? '';
        return db.compareTo(da);
      });
      (group['assessments'] as List<dynamic>).sort((a, b) {
        final da = a['created_at'] ?? '';
        final db = b['created_at'] ?? '';
        return db.compareTo(da);
      });

      String latestD = '';
      if ((group['reports'] as List).isNotEmpty) {
        latestD = (group['reports'] as List).first['created_at'] ?? '';
      }
      if ((group['assessments'] as List).isNotEmpty) {
        final assD = (group['assessments'] as List).first['created_at'] ?? '';
        if (assD.compareTo(latestD) > 0) latestD = assD;
      }
      group['latest_date'] = latestD;
    });

    final patientList = patientGroups.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header Info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_shared_outlined, color: AppTheme.primaryTeal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'سجلات المرضى والمقاييس السريرية (${patientList.length} مرضى مسجلين)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.primaryTealDark),
                ),
              ),
              const Text('مرتب حسب المريض', style: TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Grouped Patient Cards
        ...patientList.map((group) {
          final pName = group['patient_name'] as String;
          final reports = group['reports'] as List<dynamic>;
          final assessments = group['assessments'] as List<dynamic>;
          final totalTests = reports.length + assessments.length;
          final highestRisk = group['highest_risk'] as String;
          final latestDate = (group['latest_date'] as String).split('T').first;
          final bool isHigh = highestRisk == 'HIGH';
          final bool isMod = highestRisk == 'MODERATE';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: () => _openPatientReportsHistoryModal(group),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: AppTheme.primaryTeal, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.slateNavy),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.history, size: 13, color: AppTheme.slateMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'آخر تقييم: $latestDate',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isHigh
                                    ? AppTheme.alertRose
                                    : isMod
                                        ? AppTheme.oceanAzure
                                        : AppTheme.sageGreen)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isHigh
                                ? '🔴 خطورة مرتفعة'
                                : isMod
                                    ? '🟡 خطورة متوسطة'
                                    : '🟢 حالة مستقرة',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isHigh
                                  ? AppTheme.alertRose
                                  : isMod
                                      ? AppTheme.oceanAzure
                                      : AppTheme.sageGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.slateLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '📊 $totalTests فحوصات (${reports.length} ذكاء اصطناعي + ${assessments.length} مقاييس)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text(
                              'عرض السجل السريري الشامل',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primaryTeal),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- MODAL: PATIENT CHRONOLOGICAL REPORTS & ASSESSMENTS TIMELINE ---
  void _openPatientReportsHistoryModal(Map<String, dynamic> patientGroup) {
    final pName = patientGroup['patient_name'] as String;
    final reports = (patientGroup['reports'] as List<dynamic>?) ?? [];
    final assessments = (patientGroup['assessments'] as List<dynamic>?) ?? [];
    String subFilter = 'ALL'; // 'ALL', 'AI', 'PHQ9', 'GAD7'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Combine and sort both lists
          final List<Map<String, dynamic>> combinedItems = [];
          for (final r in reports) {
            combinedItems.add({'type': 'AI_REPORT', 'date': r['created_at'] ?? '', 'data': r});
          }
          for (final a in assessments) {
            final code = a['assessment_code'] ?? 'SCALE';
            combinedItems.add({'type': code, 'date': a['created_at'] ?? '', 'data': a});
          }

          combinedItems.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

          final filteredItems = combinedItems.where((item) {
            if (subFilter == 'AI') return item['type'] == 'AI_REPORT';
            if (subFilter == 'PHQ9') return item['type'] == 'PHQ-9';
            if (subFilter == 'GAD7') return item['type'] == 'GAD-7';
            return true;
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.96,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Modal Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_edu, color: AppTheme.primaryTeal, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'السجل الإكلينيكي الشامل: $pName',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slateNavy),
                                  ),
                                  Text(
                                    'إجمالي الفحوصات: ${combinedItems.length} (المقابلات الذكية ومقاييس PHQ-9 و GAD-7)',
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppTheme.slateMuted),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Sub-filter tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: Text('الكل (${combinedItems.length})', style: TextStyle(fontSize: 11, color: subFilter == 'ALL' ? Colors.white : AppTheme.slateNavy)),
                                selected: subFilter == 'ALL',
                                selectedColor: AppTheme.primaryTeal,
                                onSelected: (s) => setModalState(() => subFilter = 'ALL'),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: Text('المقابلات الذكية (${reports.length})', style: TextStyle(fontSize: 11, color: subFilter == 'AI' ? Colors.white : AppTheme.slateNavy)),
                                selected: subFilter == 'AI',
                                selectedColor: AppTheme.primaryTeal,
                                onSelected: (s) => setModalState(() => subFilter = 'AI'),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: Text('مقياس الاكتئاب PHQ-9 (${assessments.where((a) => a['assessment_code'] == 'PHQ-9').length})', style: TextStyle(fontSize: 11, color: subFilter == 'PHQ9' ? Colors.white : AppTheme.slateNavy)),
                                selected: subFilter == 'PHQ9',
                                selectedColor: AppTheme.primaryTeal,
                                onSelected: (s) => setModalState(() => subFilter = 'PHQ9'),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: Text('مقياس القلق GAD-7 (${assessments.where((a) => a['assessment_code'] == 'GAD-7').length})', style: TextStyle(fontSize: 11, color: subFilter == 'GAD7' ? Colors.white : AppTheme.slateNavy)),
                                selected: subFilter == 'GAD7',
                                selectedColor: AppTheme.primaryTeal,
                                onSelected: (s) => setModalState(() => subFilter = 'GAD7'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chronological List of Entries
                  Expanded(
                    child: filteredItems.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('لا توجد عناصر مسجلة في هذا القسم.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 13)),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final isAi = item['type'] == 'AI_REPORT';
                              final rawDate = item['date'] as String;
                              final formattedDate = rawDate.contains('T')
                                  ? rawDate.split('T').first + ' (' + rawDate.split('T').last.substring(0, 5) + ')'
                                  : rawDate;

                              if (isAi) {
                                final rep = item['data'] as Map<String, dynamic>;
                                final isReviewed = rep['is_reviewed_by_doctor'] == true;
                                final riskLevel = rep['preliminary_risk_level'] ?? 'LOW';
                                final bool isHigh = riskLevel == 'HIGH';
                                final bool isMod = riskLevel == 'MODERATE';

                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.grey.withOpacity(0.18)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.oceanAzure.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.psychology, size: 16, color: AppTheme.oceanAzure),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'تقرير التقييم الإكلينيكي الذكي',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slateNavy),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (isHigh ? AppTheme.alertRose : isMod ? AppTheme.oceanAzure : AppTheme.sageGreen).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isHigh ? '🔴 خطورة مرتفعة' : isMod ? '🟡 خطورة متوسطة' : '🟢 حالة مستقرة',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isHigh ? AppTheme.alertRose : isMod ? AppTheme.oceanAzure : AppTheme.sageGreen,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('التاريخ: $formattedDate', style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                                        const Divider(height: 16),
                                        Text(
                                          rep['summary_ar_encrypted'] ?? '',
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.slateNavy),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (isReviewed ? AppTheme.sageGreen : AppTheme.oceanAzure).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isReviewed ? '✓ تم التقييم والاعتماد' : '⏳ قيد المراجعة',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isReviewed ? AppTheme.sageGreen : AppTheme.oceanAzure,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryTeal,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _openReportReviewModal(rep);
                                              },
                                              icon: const Icon(Icons.rate_review_outlined, size: 14),
                                              label: Text(isReviewed ? 'تعديل الملاحظات' : 'مراجعة وكتابة التقييم', style: const TextStyle(fontSize: 11.5)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                // Quantitative Scale: PHQ-9 (9 questions) or GAD-7 (7 questions)
                                final ass = item['data'] as Map<String, dynamic>;
                                final code = ass['assessment_code'] ?? 'SCALE';
                                final title = ass['assessment_title_ar'] ?? code;
                                final score = ass['total_score'] ?? 0;
                                final maxScore = code == 'PHQ-9' ? 27 : 21;
                                final sevDisplay = ass['severity_level_display'] ?? ass['severity_level'] ?? 'MILD';
                                final interp = ass['interpretation_ar'] ?? ass['interpretation_en'] ?? '';
                                final answers = (ass['answers'] as List<dynamic>?) ?? [];
                                final bool isPhq = code == 'PHQ-9';

                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: (isPhq ? AppTheme.oceanAzure : AppTheme.primaryTeal).withOpacity(0.3)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: (isPhq ? AppTheme.oceanAzure : AppTheme.primaryTeal).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(
                                                    isPhq ? Icons.assignment_outlined : Icons.health_and_safety_outlined,
                                                    size: 16,
                                                    color: isPhq ? AppTheme.oceanAzure : AppTheme.primaryTeal,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  title,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slateNavy),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.oceanAzure.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'الدرجة: $score / $maxScore',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.oceanAzure),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('التاريخ: $formattedDate', style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                                        const Divider(height: 16),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.slateLight,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'التصنيف السريري: $sevDisplay',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (interp.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            interp,
                                            style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.slateNavy),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => _openAssessmentAnswersModal(ass),
                                            icon: const Icon(Icons.list_alt, size: 14),
                                            label: Text(
                                              'عرض إجابات الأسئلة (${answers.isNotEmpty ? answers.length : (isPhq ? 9 : 7)} أسئلة)',
                                              style: const TextStyle(fontSize: 11.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MODAL: SHOW INDIVIDUAL QUESTION & ANSWER BREAKDOWN FOR PHQ-9 / GAD-7 ---
  void _openAssessmentAnswersModal(Map<String, dynamic> assessment) {
    final title = assessment['assessment_title_ar'] ?? assessment['assessment_code'] ?? 'المقياس السريري';
    final code = assessment['assessment_code'] ?? 'SCALE';
    final score = assessment['total_score'] ?? 0;
    final maxScore = code == 'PHQ-9' ? 27 : 21;
    final answers = (assessment['answers'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.checklist_rtl, color: AppTheme.primaryTeal, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تفاصيل إجابات $title',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.oceanAzure.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('النتيجة الإجمالية للمقياس:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateNavy)),
                    Text('$score من أصل $maxScore', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.oceanAzure)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (answers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('تم تسجيل النتيجة الإجمالية للمقياس بنجاح.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: answers.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, idx) {
                      final ans = answers[idx];
                      final qText = ans['question_text_ar'] ?? 'السؤال ${idx + 1}';
                      final optLabel = ans['option_label_ar'] ?? 'الإجابة المختارة';
                      final ansScore = ans['score'] ?? 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${idx + 1}. $qText',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('• الإجابة: $optLabel', style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryTealDark)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.slateLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('+$ansScore نقاط', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.slateMuted)),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: SCHEDULE & PROFILE ---
  Widget _buildScheduleAndProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Availability Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.access_time_filled, color: AppTheme.primaryTeal, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'أوقات العمل الأسبوعية',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slateNavy),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        side: const BorderSide(color: AppTheme.primaryTeal, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openScheduleManagerModal,
                      icon: const Icon(Icons.tune, size: 13),
                      label: const Text('تعديل', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const Divider(height: 16),
                if (_availabilities.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.oceanAzure.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'لم تقم بتحديد ساعات العمل بعد. اضغط على "تعديل" لتحديد الأيام والأوقات.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.slateNavy),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _availabilities.map((av) {
                      final dayDisplay = av['day_display'] ?? 'يوم عمل';
                      final startTime = (av['start_time'] as String).substring(0, 5);
                      final endTime = (av['end_time'] as String).substring(0, 5);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                        ),
                        child: Text(
                          '$dayDisplay ($startTime - $endTime)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Verified Profile Details Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_outlined, color: AppTheme.primaryTeal, size: 18),
                    SizedBox(width: 8),
                    Text('البيانات المهنية والترخيص', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ],
                ),
                const Divider(height: 16),
                _buildDetailRow('التخصص الدقيق:', _doctorProfile?['specialty_display'] ?? _doctorProfile?['specialty'] ?? '-'),
                const SizedBox(height: 6),
                _buildDetailRow('رقم الترخيص:', _doctorProfile?['license_number'] ?? '-'),
                const SizedBox(height: 6),
                _buildDetailRow('سنوات الخبرة:', '${_doctorProfile?['years_of_experience'] ?? 0} سنوات'),
                const SizedBox(height: 6),
                _buildDetailRow('البريد الإلكتروني:', _doctorProfile?['email'] ?? '-'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // --- UNVERIFIED DOCTOR GATE ---
  Widget _buildVerificationGate() {
    final hasPendingQual = (_doctorProfile?['qualifications'] as List? ?? []).isNotEmpty;
    final hasLicense = (_doctorProfile?['license_number'] ?? '').toString().isNotEmpty;
    final isUnderReview = hasPendingQual || hasLicense;
    final rejectionReason = (_doctorProfile?['rejection_reason'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rejectionReason.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.alertRose.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.alertRose.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cancel_outlined, color: AppTheme.alertRose, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ملاحظات إدارة المنصة على طلب الاعتماد السابق:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.alertRose),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rejectionReason,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateNavy, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Calm Security Notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.oceanAzure.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.oceanAzure.withOpacity(0.25)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppTheme.oceanAzure, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حسابك قيد الاعتماد والمراجعة المهنية',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slateNavy),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'وفقاً لمعايير الخصوصية السريرية، يتم تفعيل استقبال المواعيد بعد مراجعة الترخيص من قِبل إدارة المنصة.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.slateNavy, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Credentialing Form Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_information_outlined, color: AppTheme.primaryTeal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isUnderReview ? 'تحديث وتعديل وثائق الترخيص' : 'إكمال وتوثيق بيانات الترخيص الطبي',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('أدخل بياناتك المهنية وارفق وثيقة الترخيص لاعتماد حسابك', style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted)),
                const Divider(height: 20),

                // Specialty
                const Text('التخصص السريري الدقيق *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedSpecialty,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.psychology_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _specialties.map((s) => DropdownMenuItem(
                    value: s['value'],
                    child: Text(s['label']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedSpecialty = val!),
                ),
                const SizedBox(height: 12),

                // License Number
                const Text('رقم الترخيص المهني / تصنيف الهيئة *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 4),
                TextField(
                  controller: _licenseController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: SCFHS-892143',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Years of Experience
                const Text('سنوات الخبرة السريرية *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 4),
                TextField(
                  controller: _yearsExpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'مثال: 5',
                    prefixIcon: Icon(Icons.work_history_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Degree & Institution
                const Text('المؤهل الطبي والجامعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 4),
                TextField(
                  controller: _degreeController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: ماجستير علم النفس الإكلينيكي',
                    prefixIcon: Icon(Icons.school_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Bio
                const Text('نبذة مهنية عنك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 4),
                TextField(
                  controller: _bioController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'اكتب نبذة عن منهجك العلاجي وخبراتك...',
                  ),
                ),
                const SizedBox(height: 16),

                // File Upload Box
                const Text('وثيقة الترخيص الطبي (PDF / صورة) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                if (_attachedDocumentName == null)
                  InkWell(
                    onTap: _openDocumentPickerModal,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_outlined, color: AppTheme.primaryTeal, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'اضغط لاختيار ملف (PDF أو صورة)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTealDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.sageGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.sageGreen.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _attachedDocumentName!.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                          color: _attachedDocumentName!.toLowerCase().endsWith('.pdf') ? AppTheme.alertRose : AppTheme.primaryTeal,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _attachedDocumentName!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slateNavy),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.change_circle_outlined, color: AppTheme.primaryTeal, size: 20),
                          tooltip: 'تغيير',
                          onPressed: _openDocumentPickerModal,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.alertRose, size: 20),
                          tooltip: 'حذف',
                          onPressed: () => setState(() {
                            _attachedDocumentName = null;
                            _selectedFilePath = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),

                // Submit Button
                ElevatedButton.icon(
                  onPressed: _isSubmittingCredentials ? null : _submitDoctorCredentials,
                  icon: _isSubmittingCredentials
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('إرسال وثائق الاعتماد إلى المشرف', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
          ),
        ),
      ],
    );
  }
}
