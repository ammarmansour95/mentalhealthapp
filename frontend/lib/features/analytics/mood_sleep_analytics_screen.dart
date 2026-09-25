import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/services/api_service.dart';

class MoodSleepAnalyticsScreen extends StatefulWidget {
  const MoodSleepAnalyticsScreen({super.key});

  @override
  State<MoodSleepAnalyticsScreen> createState() => _MoodSleepAnalyticsScreenState();
}

class _MoodSleepAnalyticsScreenState extends State<MoodSleepAnalyticsScreen> {
  bool _isLoading = true;
  List<dynamic> _records = [];
  double _avgMood = 0.0;
  double _avgSleep = 0.0;
  int _totalCount = 0;

  // Check-in form state
  int _currentMood = 7;
  double _currentSleep = 7.5;
  int _anxietyLevel = 1;
  final _notesController = TextEditingController();
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _fetchProgressData();
  }

  Future<void> _fetchProgressData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/treatment/progress/');
      if (res['success'] == true) {
        setState(() {
          _records = res['results'] ?? [];
          _avgMood = num.tryParse(res['avg_mood']?.toString() ?? '0')?.toDouble() ?? 0.0;
          _avgSleep = num.tryParse(res['avg_sleep']?.toString() ?? '0')?.toDouble() ?? 0.0;
          _totalCount = num.tryParse(res['count']?.toString() ?? '0')?.toInt() ?? 0;
        });
      }
    } catch (e) {
      // Handled
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitDailyLog() async {
    setState(() => _isLogging = true);
    try {
      final res = await ApiService.post('/treatment/progress/log/', {
        'mood_score': _currentMood,
        'sleep_hours': _currentSleep,
        'anxiety_level': _anxietyLevel,
        'notes': _notesController.text.trim(),
      });

      if (res['success'] == true && mounted) {
        _notesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل حالتك اليومية بنجاح وتحديث المنحنيات البيانية.'),
            backgroundColor: AppTheme.sageGreen,
          ),
        );
        _fetchProgressData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التسجيل: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  String _getMoodEmoji(dynamic moodVal) {
    final mood = num.tryParse(moodVal?.toString() ?? '5')?.toInt() ?? 5;
    if (mood <= 2) return '😢';
    if (mood <= 4) return '🌧️';
    if (mood <= 6) return '😐';
    if (mood <= 8) return '😊';
    return '🌿';
  }

  String _getMoodLabel(dynamic moodVal) {
    final mood = num.tryParse(moodVal?.toString() ?? '5')?.toInt() ?? 5;
    if (mood <= 2) return 'منخفض';
    if (mood <= 4) return 'متراجع';
    if (mood <= 6) return 'مستقر / هادئ';
    if (mood <= 8) return 'جيد وإيجابي';
    return 'ممتاز ومرتاح';
  }

  String _getAnxietyLabel(int level) {
    switch (level) {
      case 2:
        return 'معتدل';
      case 3:
        return 'مرتفع';
      case 1:
      default:
        return 'منخفض';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchProgressData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تحليلات المزاج والنوم',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'متابعة استقرارك النفسي ونمط نومك اليومي',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Metrics Overview Cards (Green-to-Blue Spectrum)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricBox(
                              'متوسط المزاج',
                              _avgMood > 0 ? '$_avgMood / 10' : '-',
                              _getMoodEmoji(_avgMood.round()),
                              AppTheme.primaryTeal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricBox(
                              'متوسط النوم',
                              _avgSleep > 0 ? '$_avgSleep س' : '-',
                              '🌙',
                              AppTheme.oceanAzure,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricBox(
                              'أيام التسجيل',
                              '$_totalCount',
                              '📅',
                              AppTheme.sageGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fix 9: Daily Check-In Logger placed ABOVE charts so first-time users can log immediately
                      _buildCheckInCard(),
                      const SizedBox(height: 18),

                      // Mood Line Chart
                      _buildMoodLineChart(),
                      const SizedBox(height: 18),

                      // Sleep Hours Bar Chart
                      _buildSleepBarChart(),
                      const SizedBox(height: 20),

                      // Past Check-In History
                      const Text('سجل اليوميات والملاحظات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slateNavy)),
                      const SizedBox(height: 10),
                      if (_records.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('لا توجد تسجيلات سابقة حتى الآن. سجّل حالتك اليومية أعلاه!', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12.5))),
                          ),
                        )
                      else
                        ..._records.map((rec) {
                          final moodVal = num.tryParse(rec['mood_score']?.toString() ?? '5')?.toInt() ?? 5;
                          final sleepVal = num.tryParse(rec['sleep_hours']?.toString() ?? '7')?.toDouble() ?? 7.0;
                          final logDateStr = rec['log_date']?.toString() ?? rec['created_at']?.toString().substring(0, 10) ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                                child: Text(_getMoodEmoji(moodVal), style: const TextStyle(fontSize: 18)),
                              ),
                              title: Text(
                                'المزاج: $moodVal/10 (${_getMoodLabel(moodVal)}) • النوم: $sleepVal ساعات',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text('التاريخ: $logDateStr', style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
                                  if (rec['notes_encrypted'] != null && rec['notes_encrypted'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('ملاحظة: ${rec['notes_encrypted']}', style: const TextStyle(fontSize: 11.5, color: AppTheme.slateNavy)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, String iconOrEmoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(iconOrEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted)),
        ],
      ),
    );
  }

  Widget _buildMoodLineChart() {
    final chronological = _records.reversed.toList();
    final spots = <FlSpot>[];
    for (int i = 0; i < chronological.length; i++) {
      final mood = num.tryParse(chronological[i]['mood_score']?.toString() ?? '5')?.toDouble() ?? 5.0;
      spots.add(FlSpot(i.toDouble(), mood));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.primaryTeal, size: 20),
                SizedBox(width: 8),
                Text('منحنى تطور المزاج اليومي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('مؤشر من 1 (منخفض جداً) إلى 10 (ممتاز ومرتاح)', style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted)),
            const SizedBox(height: 16),
            if (spots.isEmpty)
              const SizedBox(
                height: 140,
                child: Center(child: Text('لا توجد بيانات كافية لرسم المنحنى بعد', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12))),
              )
            else
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 2,
                      getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (val, _) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < chronological.length) {
                              final fullDate = chronological[idx]['log_date']?.toString() ?? chronological[idx]['created_at']?.toString() ?? '';
                              final dateStr = fullDate.length >= 10 ? fullDate.substring(5, 10) : fullDate;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(dateStr, style: const TextStyle(fontSize: 9.5, color: AppTheme.slateMuted)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 2,
                          reservedSize: 22,
                          getTitlesWidget: (val, _) => Text('${val.toInt()}', style: const TextStyle(fontSize: 9.5, color: AppTheme.slateMuted)),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 10,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppTheme.primaryTeal,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primaryTeal.withOpacity(0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepBarChart() {
    final chronological = _records.reversed.toList();
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < chronological.length; i++) {
      final sleep = num.tryParse(chronological[i]['sleep_hours']?.toString() ?? '7.0')?.toDouble() ?? 7.0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: sleep,
              color: sleep >= 7.0 ? AppTheme.sageGreen : AppTheme.oceanAzure,
              width: 12,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bedtime_outlined, color: AppTheme.oceanAzure, size: 20),
                SizedBox(width: 8),
                Text('ساعات النوم اليومية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('النطاق الصحي المثالي للنوم: 7 - 9 ساعات يومياً', style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted)),
            const SizedBox(height: 16),
            if (barGroups.isEmpty)
              const SizedBox(
                height: 140,
                child: Center(child: Text('لا توجد بيانات نوم مسجلة بعد', style: TextStyle(color: AppTheme.slateMuted, fontSize: 12))),
              )
            else
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 2,
                      getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (val, _) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < chronological.length) {
                              final fullDate = chronological[idx]['log_date']?.toString() ?? chronological[idx]['created_at']?.toString() ?? '';
                              final dateStr = fullDate.length >= 10 ? fullDate.substring(5, 10) : fullDate;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(dateStr, style: const TextStyle(fontSize: 9.5, color: AppTheme.slateMuted)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 2,
                          reservedSize: 24,
                          getTitlesWidget: (val, _) => Text('${val.toInt()} س', style: const TextStyle(fontSize: 9.5, color: AppTheme.slateMuted)),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    maxY: 12,
                    barGroups: barGroups,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note, color: AppTheme.primaryTeal, size: 22),
                SizedBox(width: 8),
                Text('تسجيل الحالة اليومية الجديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 20),

            // Mood Header & Quick Emoji Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تقييم المزاج العام:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_getMoodEmoji(_currentMood)} $_currentMood / 10 (${_getMoodLabel(_currentMood)})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildQuickMoodChip(2, '😢', 'منخفض'),
                const SizedBox(width: 6),
                _buildQuickMoodChip(4, '🌧️', 'متراجع'),
                const SizedBox(width: 6),
                _buildQuickMoodChip(6, '😐', 'مستقر'),
                const SizedBox(width: 6),
                _buildQuickMoodChip(8, '😊', 'جيد'),
                const SizedBox(width: 6),
                _buildQuickMoodChip(10, '🌿', 'ممتاز'),
              ],
            ),
            const SizedBox(height: 6),
            Slider(
              value: _currentMood.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppTheme.primaryTeal,
              onChanged: (val) => setState(() => _currentMood = val.round()),
            ),
            const SizedBox(height: 10),

            // Sleep Duration Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ساعات النوم الليلة الماضية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.oceanAzure.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_currentSleep ساعة',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.oceanAzure, fontSize: 12),
                  ),
                ),
              ],
            ),
            Slider(
              value: _currentSleep,
              min: 3.0,
              max: 12.0,
              divisions: 18,
              activeColor: AppTheme.oceanAzure,
              onChanged: (val) => setState(() => _currentSleep = double.parse(val.toStringAsFixed(1))),
            ),
            const SizedBox(height: 10),

            // General Anxiety Level Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('مستوى القلق والتوتر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_anxietyLevel == 3 ? AppTheme.alertRose : (_anxietyLevel == 2 ? const Color(0xFFF59E0B) : AppTheme.sageGreen)).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getAnxietyLabel(_anxietyLevel),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _anxietyLevel == 3 ? AppTheme.alertRose : (_anxietyLevel == 2 ? const Color(0xFFD97706) : AppTheme.sageGreen),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildAnxietyChip(1, 'منخفض / هادئ', AppTheme.sageGreen),
                const SizedBox(width: 8),
                _buildAnxietyChip(2, 'معتدل / متوسط', const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildAnxietyChip(3, 'مرتفع / متوتر', AppTheme.alertRose),
              ],
            ),
            const SizedBox(height: 14),

            // Journal notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات يومية أو أحداث أثرت على مزاجك (اختياري)',
                hintText: 'مثال: شعرت بالراحة بعد ممارسة رياضة المشي والتأمل...',
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isLogging ? null : _submitDailyLog,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isLogging
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('حفظ وتسجيل الحالة اليومية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMoodChip(int targetScore, String emoji, String label) {
    final isSelected = (_currentMood - targetScore).abs() <= 1;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentMood = targetScore),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryTeal.withOpacity(0.12) : AppTheme.slateNavy.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryTeal : AppTheme.slateLight,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryTealDark : AppTheme.slateMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnxietyChip(int level, String label, Color color) {
    final isSelected = _anxietyLevel == level;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _anxietyLevel = level),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : AppTheme.slateNavy.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppTheme.slateLight,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppTheme.slateNavy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
