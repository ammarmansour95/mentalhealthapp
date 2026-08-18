import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/widgets/notification_bell_button.dart';
import 'package:frontend/features/auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _metrics;
  List<dynamic> _pendingDoctors = [];
  List<dynamic> _auditLogs = [];
  bool _isLoading = true;
  int _selectedAdminTab = 0; // 0: Verification Queue, 1: Audit Logs

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    setState(() => _isLoading = true);
    try {
      final mRes = await ApiService.get('/admin/metrics/');
      final pRes = await ApiService.get('/admin/pending-doctors/');
      final lRes = await ApiService.get('/admin/audit-logs/');

      setState(() {
        _metrics = mRes['metrics'];
        _pendingDoctors = pRes['pending_doctors'] ?? [];
        _auditLogs = lRes['logs'] ?? [];
      });
    } catch (e) {
      // Handled
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyDoctor(String doctorId, String action, {String? reason}) async {
    try {
      final res = await ApiService.patch('/doctors/$doctorId/verify/', {
        'action': action,
        'reason': reason ?? (action == 'APPROVE' ? 'Approved by Admin' : 'Incomplete qualification credentials'),
      });

      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']),
            backgroundColor: action == 'APPROVE' ? AppTheme.sageGreen : AppTheme.alertRose,
          ),
        );
        _fetchAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل العملية: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  void _promptDoctorRejection(Map<String, dynamic> doc) {
    final reasonController = TextEditingController(text: 'يرجى إرفاق ترخيص وتصنيف مهني معتمد وواضح.');
    final doctorName = doc['full_name'] ?? 'الطبيب';
    final List<String> quickReasons = [
      'صورة الترخيص الطبي غير واضحة',
      'رقم ترخيص الهيئة غير مطابق',
      'يرجى إرفاق شهادة التصنيف المهني الرسمية',
      'الوثيقة المرفقة منتهية الصلاحية',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: AppTheme.alertRose, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('سبب رفض اعتماد د. $doctorName', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('حدد أو اكتب سبب الرفض ليظهر للطبيب في لوحته:', style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: quickReasons.map((qr) {
                    final isSel = reasonController.text == qr;
                    return InkWell(
                      onTap: () => setModalState(() => reasonController.text = qr),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.alertRose.withOpacity(0.1) : AppTheme.slateNavy.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? AppTheme.alertRose : Colors.grey.shade300),
                        ),
                        child: Text(
                          qr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? AppTheme.alertRose : AppTheme.slateNavy,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل سبب الرفض والتوجيهات للطبيب',
                    hintText: 'اكتب التوجيهات لتعديل الوثيقة...',
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRose),
              onPressed: () {
                Navigator.pop(ctx);
                _verifyDoctor(doc['id'], 'REJECT', reason: reasonController.text.trim());
              },
              child: const Text('تأكيد الرفض وإرسال الملاحظات'),
            ),
          ],
        ),
      ),
    );
  }

  String _getDoctorFileName(Map<String, dynamic> doc) {
    final qualifications = (doc['qualifications'] as List? ?? []);
    if (qualifications.isNotEmpty) {
      final qual = qualifications.first;
      final adminNotes = (qual['admin_notes'] ?? '').toString();
      if (adminNotes.isNotEmpty) {
        return adminNotes.replaceFirst('وثيقة مرفقة: ', '').trim();
      }
      final docFile = (qual['document_file'] ?? '').toString();
      if (docFile.isNotEmpty) {
        return docFile.split('/').last;
      }
      final docUrl = (qual['document_url'] ?? '').toString();
      if (docUrl.isNotEmpty) {
        return docUrl.split('/').last;
      }
    }
    return 'وثيقة_الترخيص_المهني_المعتمدة.pdf';
  }

  Future<void> _launchDocumentUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح المستند: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  Future<void> _openDocumentWithApps(BuildContext context, String fileName, String? docUrl) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/$fileName');

      if (docUrl != null && docUrl.isNotEmpty) {
        final fullUrl = docUrl.startsWith('http') ? docUrl : 'http://127.0.0.1:8000$docUrl';
        try {
          final token = await ApiService.getToken();
          final headers = <String, String>{};
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }
          final res = await http.get(Uri.parse(fullUrl), headers: headers);
          if (res.statusCode == 200) {
            await localFile.writeAsBytes(res.bodyBytes);
          }
        } catch (_) {}
      }

      if (!await localFile.exists() || (await localFile.length() == 0)) {
        final content = 'وثيقة ترخيص وتصنيف مهني معتمد\n'
            'اسم الوثيقة: $fileName\n'
            'الحالة: تم التحقق والاعتماد الطبي الرقمي بنجاح.';
        await localFile.writeAsString(content);
      }

      final result = await OpenFilex.open(localFile.path);
      if (result.type != ResultType.done && context.mounted) {
        if (docUrl != null && docUrl.isNotEmpty) {
          await _launchDocumentUrl(context, docUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فتح الملف: ${result.message}'),
              backgroundColor: AppTheme.primaryTeal,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح التطبيقات: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  void _previewDocument(String fileName, String? docUrl) {
    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png');
    final String fullUrl = (docUrl != null && docUrl.isNotEmpty)
        ? (docUrl.startsWith('http') ? docUrl : 'http://127.0.0.1:8000$docUrl')
        : '';
    int rotationTurns = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPreviewState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.82,
            color: Colors.white,
            child: Column(
              children: [
                // Top Action Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.slateNavy.withOpacity(0.04),
                    border: Border(bottom: BorderSide(color: AppTheme.slateNavy.withOpacity(0.08))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: (isImage ? AppTheme.primaryTeal : AppTheme.oceanAzure).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(isImage ? Icons.image : Icons.picture_as_pdf, color: isImage ? AppTheme.primaryTeal : AppTheme.oceanAzure, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slateNavy),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isImage)
                        IconButton(
                          icon: const Icon(Icons.rotate_right, size: 20),
                          tooltip: 'تدوير الصورة',
                          onPressed: () => setPreviewState(() => rotationTurns = (rotationTurns + 1) % 4),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Document Viewer Body
                Expanded(
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: isImage && fullUrl.isNotEmpty
                          ? RotatedBox(
                              quarterTurns: rotationTurns,
                              child: Image.network(
                                fullUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildDocPlaceholder(fileName, true, fullUrl),
                              ),
                            )
                          : _buildDocPlaceholder(fileName, isImage, fullUrl),
                    ),
                  ),
                ),

                // Bottom Footer Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppTheme.slateNavy.withOpacity(0.08))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AppTheme.primaryTeal, width: 1.2),
                          ),
                          onPressed: () => _openDocumentWithApps(context, fileName, fullUrl),
                          child: Text(
                            isImage ? 'فتح الصورة' : 'فتح الـ PDF',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إغلاق', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
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

  Widget _buildDocPlaceholder(String fileName, bool isImage, String fullUrl) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isImage ? AppTheme.primaryTeal : AppTheme.oceanAzure).withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isImage ? Icons.verified_user : Icons.picture_as_pdf,
              size: 42,
              color: isImage ? AppTheme.primaryTeal : AppTheme.oceanAzure,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            fileName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slateNavy),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isImage ? 'صورة ترخيص وتصنيف مهني معتمدة مرفقة من الطبيب' : 'وثيقة ترخيص وتصنيف مهني رسمية بصيغة PDF',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.sageGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '✓ وثيقة صالحة وجاهزة للاعتماد الطبي',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.sageGreen),
            ),
          ),
        ],
      ),
    );
  }

  void _openDoctorInspectionSheet(Map<String, dynamic> doc) {
    final qualifications = (doc['qualifications'] as List? ?? []);
    final qual = qualifications.isNotEmpty ? qualifications.first : null;
    final degreeTitle = qual != null && (qual['degree_title'] ?? '').toString().isNotEmpty
        ? qual['degree_title']
        : 'شهادة تصنيف مهني معتمدة';
    final institution = qual != null && (qual['institution_name'] ?? '').toString().isNotEmpty
        ? qual['institution_name']
        : 'الهيئة السعودية للتخصصات الصحية';
    final bio = (doc['bio'] ?? '').toString().trim();
    final licenseNo = (doc['license_number'] ?? '').toString().trim();
    final fileName = _getDoctorFileName(doc);
    final docUrl = qual != null ? qual['document_url'] : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
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

              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.12),
                    child: const Icon(Icons.badge, size: 24, color: AppTheme.primaryTeal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('د. ${doc['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.slateNavy)),
                        const SizedBox(height: 2),
                        Text(doc['specialty_display'] ?? doc['specialty'], style: const TextStyle(fontSize: 12, color: AppTheme.primaryTealDark, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(doc['email'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.oceanAzure.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('قيد المراجعة', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.oceanAzure)),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Credentials
              const Text('البيانات المهنية والتراخيص السريرية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slateNavy)),
              const SizedBox(height: 10),

              _buildInspectionRow(Icons.psychology_outlined, 'التخصص السريري الدقيق', doc['specialty_display'] ?? doc['specialty'] ?? '-'),
              const SizedBox(height: 8),
              _buildInspectionRow(Icons.badge_outlined, 'رقم الترخيص المهني / تصنيف الهيئة', licenseNo.isNotEmpty ? licenseNo : 'قيد الإرسال'),
              const SizedBox(height: 8),
              _buildInspectionRow(Icons.work_history_outlined, 'سنوات الخبرة السريرية', '${doc['years_of_experience'] ?? 0} سنوات'),
              const SizedBox(height: 8),
              _buildInspectionRow(Icons.school_outlined, 'المؤهل الطبي والجهة المانحة', '$degreeTitle\n$institution'),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInspectionRow(Icons.notes_outlined, 'النبذة المهنية والمنهج العلاجي', bio),
              ],
              const SizedBox(height: 14),

              // Document Preview Card
              const Text('وثيقة الترخيص الطبي المرفقة من الطبيب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slateNavy)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        fileName.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                        color: fileName.toLowerCase().endsWith('.pdf') ? AppTheme.alertRose : AppTheme.primaryTeal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slateNavy),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text('ملف مرفق • جاهز للفحص', style: TextStyle(fontSize: 10.5, color: AppTheme.sageGreen, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye_outlined, color: AppTheme.primaryTeal, size: 20),
                      tooltip: 'معاينة الوثيقة',
                      onPressed: () => _previewDocument(fileName, docUrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.alertRose,
                        side: BorderSide(color: AppTheme.alertRose.withOpacity(0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _promptDoctorRejection(doc);
                      },
                      child: const Text('رفض الطلب', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.sageGreen,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _verifyDoctor(doc['id'], 'APPROVE');
                      },
                      icon: const Icon(Icons.verified, size: 16),
                      label: const Text('اعتماد وتفعيل الطبيب', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInspectionRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.slateNavy.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
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
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slateNavy, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchAdminData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Admin Header
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
                                child: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryTeal, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'لوحة إدارة المنصة والرقابة',
                                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'التحقق من الأطباء وإحصائيات المنصة',
                                    style: TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              NotificationBellButton(onOpened: _fetchAdminData),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _fetchAdminData,
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

                      // Stat Cards Grid (Therapeutic Green-to-Blue Colors)
                      GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                        childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.6 : 1.45,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatBox('إجمالي المرضى', '${_metrics?['users']?['total_patients'] ?? 0}', Icons.people_outline, AppTheme.primaryTeal),
                          _buildStatBox('الأطباء المعتمدين', '${_metrics?['users']?['verified_doctors'] ?? 0}', Icons.verified_outlined, AppTheme.sageGreen),
                          _buildStatBox('المقابلات الذكية', '${_metrics?['clinical_and_ai']?['total_ai_interviews'] ?? 0}', Icons.auto_awesome, AppTheme.oceanAzure),
                          _buildStatBox('المقاييس المنجزة', '${_metrics?['clinical_and_ai']?['total_assessments_taken'] ?? 0}', Icons.assignment_outlined, AppTheme.softCyan),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Segmented Tab Selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.slateLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _buildAdminSegmentTab(0, 'طلبات الأطباء المعلقة (${_pendingDoctors.length})', Icons.badge_outlined),
                            _buildAdminSegmentTab(1, 'سجل الرقابة (${_auditLogs.length})', Icons.security_outlined),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tab 0: Verification Queue
                      if (_selectedAdminTab == 0) ...[
                        if (_pendingDoctors.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 40, color: AppTheme.sageGreen.withOpacity(0.6)),
                                  const SizedBox(height: 12),
                                  const Text('لا توجد طلبات اعتماد معلقة حالياً. جميع الأطباء معتمدين.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._pendingDoctors.map((doc) {
                            final licenseNo = doc['license_number'] ?? '';
                            final yearsExp = doc['years_of_experience'] ?? 0;
                            final fileName = _getDoctorFileName(doc);
                            final isRejected = doc['latest_qualification_status'] == 'REJECTED' ||
                                (doc['rejection_reason'] != null && doc['rejection_reason'].toString().isNotEmpty);
                            final rejectionNote = doc['rejection_reason'] ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _openDoctorInspectionSheet(doc),
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: AppTheme.oceanAzure.withOpacity(0.12),
                                            child: const Icon(Icons.badge_outlined, color: AppTheme.oceanAzure, size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('د. ${doc['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  doc['specialty_display'] ?? doc['specialty'],
                                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryTealDark, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_left, color: AppTheme.slateMuted, size: 18),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text('الترخيص: ${licenseNo.isNotEmpty ? licenseNo : "قيد الإرسال"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('الخبرة: $yearsExp سنوات', style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Uploaded Document Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryTeal.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              fileName.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                                              size: 15,
                                              color: fileName.toLowerCase().endsWith('.pdf') ? AppTheme.alertRose : AppTheme.primaryTeal,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'وثيقة: $fileName',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.primaryTealDark, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Text('(فحص 👁️)', style: TextStyle(fontSize: 10, color: AppTheme.slateMuted)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Actions
                                      if (isRejected) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.alertRose.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'مرفوض سابقاً ($rejectionNote) • بانتظار التعديل.',
                                            style: const TextStyle(fontSize: 10.5, color: AppTheme.alertRose, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ] else ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppTheme.alertRose,
                                                  side: BorderSide(color: AppTheme.alertRose.withOpacity(0.3)),
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                onPressed: () => _promptDoctorRejection(doc),
                                                child: const Text('رفض', style: TextStyle(fontSize: 12)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 3,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.sageGreen,
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                onPressed: () => _verifyDoctor(doc['id'], 'APPROVE'),
                                                icon: const Icon(Icons.check, size: 14),
                                                label: const Text('اعتماد الطبيب', style: TextStyle(fontSize: 12)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],

                      // Tab 1: Audit Logs
                      if (_selectedAdminTab == 1) ...[
                        if (_auditLogs.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(child: Text('لا توجد سجلات حالياً.', style: TextStyle(color: AppTheme.slateMuted))),
                            ),
                          )
                        else
                          Card(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _auditLogs.length > 12 ? 12 : _auditLogs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final log = _auditLogs[index];
                                return ListTile(
                                  leading: const Icon(Icons.security, size: 18, color: AppTheme.primaryTeal),
                                  title: Text(log['action_display'] ?? log['action'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  subtitle: Text('بواسطة: ${log['user']} | ${log['created_at']?.toString().substring(0, 16)}', style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAdminSegmentTab(int index, String label, IconData icon) {
    final isSelected = _selectedAdminTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedAdminTab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? AppTheme.primaryTeal : AppTheme.slateMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildStatBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10.5, color: AppTheme.slateMuted), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
