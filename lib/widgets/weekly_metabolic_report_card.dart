import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'weekly_report_sheet.dart';

/// Summary card featured on the Trends / Insights screen that previews the user's
/// weekly thermodynamic net caloric deficit, predicted fat loss rate, and consistency grade.
class WeeklyMetabolicReportCard extends StatelessWidget {
  const WeeklyMetabolicReportCard({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final useKg = appState.prefs.useKg;
    final report = appState.currentWeeklyReport;

    final score = report.adherenceScore;
    Color gradeColor;
    if (score >= 90) {
      gradeColor = const Color(0xFF10B981); // Emerald
    } else if (score >= 80) {
      gradeColor = const Color(0xFF38BDF8); // Cyan
    } else if (score >= 70) {
      gradeColor = const Color(0xFFFBBF24); // Amber
    } else {
      gradeColor = const Color(0xFFFB7185); // Coral
    }

    final isDeficit = report.isDeficit;
    final fatLossRate = useKg
        ? '${isDeficit ? "-" : "+"}${report.predictedFatLossKg.abs().toStringAsFixed(2)} kg'
        : '${isDeficit ? "-" : "+"}${report.predictedFatLossLb.abs().toStringAsFixed(2)} lbs';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: gradeColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title, Date Range & Grade Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.insights_rounded, color: gradeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Metabolic Report',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        report.dateRangeFormatted,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: zen.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${report.letterGrade} • ${report.adherenceScore}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: gradeColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Highlight Box: Predicted Fat Loss & Deficit
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREDICTED FAT LOSS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDeficit ? zen.sage : zen.carbs,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          report.daysLogged == 0 ? '—' : fatLossRate,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDeficit ? zen.sage : zen.carbs,
                              ),
                        ),
                        Text(
                          '7-day adipose rate',
                          style: TextStyle(fontSize: 11, color: zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: zen.inkMuted.withValues(alpha: 0.15),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NET ENERGY BALANCE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: zen.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          report.daysLogged == 0
                              ? '—'
                              : '${report.netWeeklyEnergyBalance.round().abs()} kcal',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          isDeficit ? 'net deficit' : 'net surplus',
                          style: TextStyle(fontSize: 11, color: zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Quick Pill Metrics
            Row(
              children: [
                Expanded(
                  child: _MiniPill(
                    icon: Icons.restaurant_rounded,
                    label: report.daysLogged == 0 ? 'No logs' : '${report.averageDailyCalories.round()} kcal/d',
                    color: zen.carbs,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniPill(
                    icon: Icons.fitness_center_rounded,
                    label: report.daysLogged == 0 ? 'Protein —' : '${report.averageProteinG.round()}g protein',
                    color: zen.protein,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniPill(
                    icon: Icons.timer_outlined,
                    label: '${report.fastingHoursTotal.round()}h fasted',
                    color: const Color(0xFFA855F7),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Button to View Breakdown
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: zen.sage.withValues(alpha: 0.5)),
                ),
                onPressed: () => showWeeklyReportSheet(context, appState: appState),
                icon: Icon(Icons.analytics_outlined, size: 18, color: zen.sage),
                label: Text(
                  'View Full Metabolic Breakdown →',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: zen.sage,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: zen.inkMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
