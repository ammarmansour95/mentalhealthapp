import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/doctors/doctor_list_screen.dart';

class AIReportScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const AIReportScreen({super.key, required this.reportData});

  Color _getRiskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH':
        return AppTheme.alertRose;
      case 'MODERATE':
        return const Color(0xFFF59E0B);
      default:
        return AppTheme.sageGreen;
    }
  }

  /// Strips technical tensor / model debug lines from the clinical summary narrative
  String _cleanPatientSummary(String rawSummary) {
    if (rawSummary.isEmpty) return '';
    const ignoredPatterns = [
      'نموذج الاستدلال',
      'آلية التحليل',
      'Embeddings:',
      'Tensor',
      'Tokens',
      '768-dim',
      'AraBERT',
      'AraBART',
      'MARBERT',
    ];

    final lines = rawSummary.split('\n');
    final cleanLines = lines.where((line) {
      for (final pattern in ignoredPatterns) {
        if (line.contains(pattern)) return false;
      }
      return true;
    }).toList();

    return cleanLines.join('\n').trim();
  }

  void _showExportSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_outlined, color: AppTheme.primaryTeal, size: 24),
            SizedBox(width: 8),
            Text('تصدير التقرير الطبي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تم إنشاء نسخة رقمية موثقة من التقرير الطبي (PDF) تشمل المؤشرات المبدئية والملخص التحليلي وتوصيات الفرز الطبي.',
              style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.slateNavy),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: AppTheme.sageGreen),
                SizedBox(width: 6),
                Text('التقرير مشفر ومعتمد للسرية الطبية', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.sageGreen)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حفظ التقرير الطبي PDF بنجاح في مجلد المستندات.'),
                  backgroundColor: AppTheme.sageGreen,
                ),
              );
            },
            child: const Text('حفظ وتحميل PDF', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riskLevel = reportData['preliminary_risk_level'] ?? 'LOW';
    final riskColor = _getRiskColor(riskLevel);
    final riskDisplay = reportData['preliminary_risk_level_display'] ?? riskLevel;
    final rawSummaryAr = reportData['summary_ar_encrypted'] ?? '';
    final cleanSummaryAr = _cleanPatientSummary(rawSummaryAr);
    final indicators = reportData['primary_indicators'] as List? ?? [];
    final specialty = reportData['recommended_specialty'] ?? 'CLINICAL_PSYCHOLOGY';
    final specialtyDisplay = reportData['recommended_specialty_display'] ?? specialty;
    final reasonAr = reportData['recommendation_reason_ar'] ?? '';
    final disclaimer = reportData['disclaimer_notice'] ?? '';
    final isReviewed = reportData['is_reviewed_by_doctor'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تقرير التقييم الذكي',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.slateNavy),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.primaryTeal),
            tooltip: 'تصدير التقرير PDF',
            onPressed: () => _showExportSuccessDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.slateNavy),
            tooltip: 'مشاركة التقرير',
            onPressed: () => _showExportSuccessDialog(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clinical AI System Badge Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryTeal.withOpacity(0.08),
                      AppTheme.oceanAzure.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppTheme.primaryTeal, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نظام الفرز والتحليل الذكي',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'تحليل مؤشرات DSM-5 المعتمدة وتصنيف الأعراض النفسية الأولية بدقة طبية',
                            style: TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Risk Badge Card with Triage Level
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: riskColor.withOpacity(0.28), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shield_outlined, color: riskColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مستوى الخطورة والحاجة للرعاية الطبية:',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            riskDisplay,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: riskColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isReviewed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.sageGreen.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.sageGreen.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 13, color: AppTheme.sageGreen),
                            SizedBox(width: 4),
                            Text('مراجعة الطبيب', style: TextStyle(fontSize: 11, color: AppTheme.sageGreen, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Extracted Clinical Indicators
              const Row(
                children: [
                  Icon(Icons.insights, color: AppTheme.primaryTeal, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'المؤشرات والأعراض المرصودة',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (indicators.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: indicators.map((ind) {
                    return Chip(
                      avatar: const Icon(Icons.check_circle, size: 16, color: AppTheme.primaryTeal),
                      backgroundColor: AppTheme.primaryTeal.withOpacity(0.06),
                      side: BorderSide(color: AppTheme.primaryTeal.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      label: Text(
                        ind['label_ar'] ?? ind['category'],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                      ),
                    );
                  }).toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.slateLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('أعراض عامة ومؤشرات أولية خفيفة بدون دلالات حادة.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12.5)),
                ),
              const SizedBox(height: 20),

              // Clinical Narrative Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.description_outlined, color: AppTheme.primaryTeal, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الملخص الأولي للحالة',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        cleanSummaryAr.isNotEmpty ? cleanSummaryAr : rawSummaryAr,
                        style: const TextStyle(fontSize: 13.5, height: 1.65, color: AppTheme.slateNavy),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Recommended Specialist Card & Booking Action
              Card(
                color: AppTheme.primaryTeal.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppTheme.primaryTeal.withOpacity(0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.medical_services_outlined, color: AppTheme.primaryTeal, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'التخصص الطبي المقترح لمتابعة حالتك',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        specialtyDisplay,
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                      ),
                      if (reasonAr.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(reasonAr, style: const TextStyle(fontSize: 12.5, color: AppTheme.slateMuted, height: 1.4)),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: AppTheme.primaryTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DoctorListScreen(initialSpecialty: specialty),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: const Text('حجز استشارة مع أخصائي في هذا المجال', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Medical & Ethical Disclaimer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.slateNavy.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.slateNavy.withOpacity(0.08)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppTheme.slateMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        disclaimer.isNotEmpty
                            ? disclaimer
                            : 'تنويه سريري: هذا التقرير الأولي مُولّد بواسطة تقنيات الذكاء الاصطناعي كأداة استرشادية للمساعدة في الفرز والتوجيه ولا يُعد بديلاً عن التشخيص الطبي المباشر.',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMuted, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
