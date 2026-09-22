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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.slateNavy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تقرير التقييم السريري الذكي 🌿',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'تحليل وتلخيص شامل للمؤشرات السريرية المبدئية',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Risk Badge Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: riskColor.withOpacity(0.25), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shield_outlined, color: riskColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مستوى الخطورة والحاجة للرعاية:',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            riskDisplay,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: riskColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isReviewed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.sageGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('✓ تمت مراجعة الطبيب', style: TextStyle(fontSize: 10.5, color: AppTheme.sageGreen, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Extracted Clinical Indicators
              const Text(
                'المؤشرات والأعراض السريرية المرصودة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
              ),
              const SizedBox(height: 8),
              if (indicators.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: indicators.map((ind) {
                    return Chip(
                      avatar: const Icon(Icons.check_circle_outline, size: 15, color: AppTheme.primaryTeal),
                      backgroundColor: AppTheme.primaryTeal.withOpacity(0.06),
                      side: BorderSide(color: AppTheme.primaryTeal.withOpacity(0.18)),
                      label: Text(
                        ind['label_ar'] ?? ind['category'],
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                      ),
                    );
                  }).toList(),
                )
              else
                const Text('أعراض عامة ومؤشرات أولية خفيفة بدون دلالات حادة.', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12)),
              const SizedBox(height: 20),

              // Clinical Narrative Summary Card (Cleaned without tensor metadata)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notes, color: AppTheme.primaryTeal, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الملخص السريري الأولي',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Text(
                        cleanSummaryAr.isNotEmpty ? cleanSummaryAr : rawSummaryAr,
                        style: const TextStyle(fontSize: 13, height: 1.6, color: AppTheme.slateNavy),
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
                          Icon(Icons.medical_services_outlined, color: AppTheme.primaryTeal, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'التخصص الطبي المقترح لمتابعة حالتك',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        specialtyDisplay,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                      ),
                      if (reasonAr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(reasonAr, style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted, height: 1.35)),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
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
                        label: const Text('حجز موعد مع أخصائي في هذا المجال', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
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
                            : 'تنويه سريري: هذا التقرير الأولي مُولّد بواسطة تقنيات الذكاء الاصطناعي كأداة استرشادية للمساعدة في الفرز والتوجيه ولا يُعد بديلاً عن الفحص الطبي المباشر.',
                        style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted, height: 1.45),
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
