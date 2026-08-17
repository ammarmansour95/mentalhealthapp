import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/auth/login_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  Map<String, dynamic>? _doctorProfile;
  List<dynamic> _appointments = [];
  List<dynamic> _reports = [];
  List<dynamic> _availabilities = [];
  bool _isLoading = true;
  bool _isSubmittingCredentials = false;
  int _selectedDoctorTab = 0; // 0: Appointments, 1: AI Reports, 2: Schedule & Profile

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
          final appRes = await ApiService.get('/appointments/');
          final repRes = await ApiService.get('/ai/reports/');
          final availRes = await ApiService.get('/doctors/availability/');
          _appointments = appRes['results'] ?? [];
          _reports = repRes['results'] ?? [];
          _availabilities = availRes['availabilities'] ?? [];
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
                      const Text('ملخص الذكاء الاصطناعي (AraBART):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.primaryTealDark)),
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
              const Text('لا توجد مواعيد محجوزة حالياً.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _appointments.map((app) {
        final status = app['status'];
        final isConfirmed = status == 'CONFIRMED';
        final isPending = status == 'PENDING';

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
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_outline, color: AppTheme.primaryTeal, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'المريض: ${app['patient_name'] ?? 'مريض مسجل'}',
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
                        isConfirmed
                            ? '✓ مؤكد'
                            : isPending
                                ? 'قيد الموافقة'
                                : 'ملغي',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isConfirmed
                              ? AppTheme.sageGreen
                              : isPending
                                  ? AppTheme.oceanAzure
                                  : AppTheme.alertRose,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('التاريخ: ${app['appointment_date']} | الوقت: ${app['start_time']}', style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                if (isPending) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.alertRose,
                          side: BorderSide(color: AppTheme.alertRose.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _updateAppointmentStatus(app['id'], 'CANCELLED'),
                        child: const Text('رفض', style: TextStyle(fontSize: 11.5)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.sageGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _updateAppointmentStatus(app['id'], 'CONFIRMED'),
                        child: const Text('قبول وتأكيد', style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- TAB 2: AI REPORTS ---
  Widget _buildReportsTab() {
    if (_reports.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(Icons.psychology_outlined, size: 40, color: AppTheme.oceanAzure.withOpacity(0.4)),
              const SizedBox(height: 12),
              const Text('لا توجد تقارير سريرية جديدة حالياً.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _reports.map((rep) {
        final isReviewed = rep['is_reviewed_by_doctor'] == true;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.oceanAzure.withOpacity(0.12),
                      child: const Icon(Icons.psychology, color: AppTheme.oceanAzure, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المريض: ${rep['patient_name'] ?? 'مريض'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          Text('مستوى الخطورة: ${rep['preliminary_risk_level_display'] ?? rep['preliminary_risk_level']}', style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isReviewed ? AppTheme.sageGreen : AppTheme.oceanAzure).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isReviewed ? '✓ تمت المراجعة' : 'قيد المراجعة',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isReviewed ? AppTheme.sageGreen : AppTheme.oceanAzure,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Text(
                  rep['summary_ar_encrypted'] ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.slateNavy),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openReportReviewModal(rep),
                    icon: const Icon(Icons.rate_review_outlined, size: 15),
                    label: Text(isReviewed ? 'تعديل التقييم' : 'مراجعة وكتابة التقييم', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
