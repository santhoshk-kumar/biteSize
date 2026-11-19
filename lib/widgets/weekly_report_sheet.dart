import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/weekly_metabolic_report.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'shareable_infographic_sheet.dart';

/// Opens the full interactive Weekly Metabolic Report & Fat Loss Rate Predictor modal.
Future<void> showWeeklyReportSheet(
  BuildContext context, {
  required AppState appState,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => WeeklyReportSheet(appState: appState),
  );
}

/// Comprehensive bottom sheet presenting deep MacroFactor & Whoop style metabolic analysis:
/// - Thermodynamic energy balance & net weekly caloric deficit.
/// - Adipose fat loss rate predictor ($7,700\text{ kcal/kg}$).
/// - Real scale weight vs true fat tissue distinction.
/// - 4 Metabolic pillars (Deficit, Muscle preservation, Fasting/Autophagy, Hydration/Fiber).
/// - 1-tap clipboard report export.
class WeeklyReportSheet extends StatefulWidget {
  const WeeklyReportSheet({super.key, required this.appState});

  final AppState appState;

  @override
  State<WeeklyReportSheet> createState() => _WeeklyReportSheetState();
}

class _WeeklyReportSheetState extends State<WeeklyReportSheet> {
  int _selectedWeekIndex = 0; // 0 = Current 7 Days, 1 = Previous 7 Days

  void _copyToClipboard(WeeklyMetabolicReport report, bool useKg) {
    final text = report.toShareableText(useKg: useKg);
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metabolic report copied to clipboard! Ready to share.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final useKg = widget.appState.prefs.useKg;
    final report = _selectedWeekIndex == 0
        ? widget.appState.currentWeeklyReport
        : widget.appState.previousWeeklyReport;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: zen.inkMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.insights_rounded, color: zen.sage, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Metabolic Report',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                IconButton(
                  tooltip: 'Share Infographic Card',
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  onPressed: () => showShareInfographicSheet(
                    context,
                    appState: widget.appState,
                    initialMode: InfographicMode.weekly,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Week Selector (Current vs Prior 7 Days)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _TabPill(
                      label: 'Current 7 Days',
                      isSelected: _selectedWeekIndex == 0,
                      onTap: () => setState(() => _selectedWeekIndex = 0),
                    ),
                  ),
                  Expanded(
                    child: _TabPill(
                      label: 'Prior 7 Days',
                      isSelected: _selectedWeekIndex == 1,
                      onTap: () => setState(() => _selectedWeekIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 16),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // 1. Overall Metabolic Adherence Medallion
                _ScoreMedallionCard(report: report),

                const SizedBox(height: 16),

                // 2. Fat Loss Rate Predictor Dial
                _FatLossPredictorCard(report: report, useKg: useKg),

                const SizedBox(height: 16),

                // 3. 7-Day Intake vs Maintenance Mini Chart
                _IntakeTrendBarCard(report: report),

                const SizedBox(height: 16),

                // 4. Four Core Metabolic Pillars
                _MetabolicPillarsSection(report: report),

                const SizedBox(height: 16),

                // 5. Scientific Observations & Coaching Verdict
                _TakeawayInsightsCard(report: report),

                const SizedBox(height: 24),

                // 6. Action Button: Copy Report
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: zen.sage,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => showShareInfographicSheet(
                          context,
                          appState: widget.appState,
                          initialMode: InfographicMode.weekly,
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text(
                          'Share Infographic Card HD',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _copyToClipboard(report, useKg),
                        icon: const Icon(Icons.content_copy_rounded, size: 18),
                        label: const Text(
                          'Copy Full Report to Clipboard',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? zen.inkPrimary : zen.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreMedallionCard extends StatelessWidget {
  const _ScoreMedallionCard({required this.report});

  final WeeklyMetabolicReport report;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradeColor.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Circular Score Ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: (score / 100.0).clamp(0.0, 1.0),
                  strokeWidth: 7,
                  backgroundColor: Theme.of(context).cardColor,
                  valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    report.letterGrade,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: gradeColor,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: zen.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.gradeTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: gradeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Metabolic Consistency Score',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.daysLogged == 0
                      ? 'No meals logged in this period'
                      : 'Logged ${report.daysLogged} of ${report.totalDays} days with balanced macronutrient pacing',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: zen.inkMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FatLossPredictorCard extends StatelessWidget {
  const _FatLossPredictorCard({
    required this.report,
    required this.useKg,
  });

  final WeeklyMetabolicReport report;
  final bool useKg;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final isDeficit = report.isDeficit;
    final netDeficit = report.netWeeklyEnergyBalance.round();

    final fatLossRate = useKg
        ? '${isDeficit ? "-" : "+"}${report.predictedFatLossKg.abs().toStringAsFixed(2)} kg'
        : '${isDeficit ? "-" : "+"}${report.predictedFatLossLb.abs().toStringAsFixed(2)} lbs';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zen.inkMuted.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isDeficit ? zen.sage : zen.carbs).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDeficit ? Icons.local_fire_department_rounded : Icons.trending_up_rounded,
                  color: isDeficit ? zen.sage : zen.carbs,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Fat Loss Rate Predictor',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '7,700 kcal / kg',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: zen.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Predicted Fat Loss Big Stat
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDeficit ? 'PREDICTED FAT LOSS' : 'PREDICTED SURPLUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: isDeficit ? zen.sage : zen.carbs,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fatLossRate,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDeficit ? zen.sage : zen.carbs,
                            ),
                      ),
                      Text(
                        'pure adipose tissue / wk',
                        style: TextStyle(fontSize: 11, color: zen.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Net Energy Balance
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NET 7-DAY BALANCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: zen.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${netDeficit.abs()} kcal',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        isDeficit ? 'net caloric deficit' : 'net caloric surplus',
                        style: TextStyle(fontSize: 11, color: zen.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Scale vs Fat Explanation Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: zen.inkMuted.withOpacity(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: zen.sage),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.scaleVsFatExplanation,
                    style: TextStyle(
                      fontSize: 12,
                      color: zen.inkMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeTrendBarCard extends StatelessWidget {
  const _IntakeTrendBarCard({required this.report});

  final WeeklyMetabolicReport report;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final points = report.dailyDataPoints;
    final target = report.dailyCalorieTarget;
    final maxCal = points.isEmpty
        ? 2500.0
        : points.map((p) => p.caloriesConsumed).fold(target.toDouble() * 1.25, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zen.inkMuted.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-Day Caloric Distribution',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'Goal: $target kcal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: zen.sage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((p) {
                final heightFactor = (p.caloriesConsumed / maxCal).clamp(0.04, 1.0);
                final isWithin = (p.caloriesConsumed - target).abs() <= target * 0.15;
                final isOver = p.caloriesConsumed > target * 1.15;

                Color barColor;
                if (!p.hasLogs) {
                  barColor = Theme.of(context).cardColor;
                } else if (isWithin) {
                  barColor = zen.sage;
                } else if (isOver) {
                  barColor = zen.carbs;
                } else {
                  barColor = const Color(0xFF38BDF8); // Under
                }

                final dayLabel = _dayLabel(p.date.weekday);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (p.hasLogs)
                          Text(
                            p.caloriesConsumed.round().toString(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: zen.inkMuted,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: p.hasLogs ? zen.inkPrimary : zen.inkMuted.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(int weekday) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return (weekday >= 1 && weekday <= 7) ? days[weekday - 1] : '';
  }
}

class _MetabolicPillarsSection extends StatelessWidget {
  const _MetabolicPillarsSection({required this.report});

  final WeeklyMetabolicReport report;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    final proteinRatio = report.proteinTargetG > 0
        ? (report.averageProteinG / report.proteinTargetG)
        : 1.0;
    final waterRatio = report.waterTargetMl > 0
        ? (report.averageWaterMl / report.waterTargetMl)
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metabolic Pillars',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Pillar 1: Protein & Muscle
            Expanded(
              child: _PillarCard(
                icon: Icons.fitness_center_rounded,
                accent: zen.protein,
                title: 'Protein Pacing',
                value: '${report.averageProteinG.round()}g / day',
                subtitle: '${(proteinRatio * 100).round()}% of ${report.proteinTargetG}g target',
                progress: proteinRatio.clamp(0.0, 1.0),
              ),
            ),
            const SizedBox(width: 10),
            // Pillar 2: Fasting & Ketosis
            Expanded(
              child: _PillarCard(
                icon: Icons.timer_outlined,
                accent: const Color(0xFFA855F7), // Amethyst
                title: 'Fasting Depth',
                value: '${report.fastingHoursTotal.round()}h fasted',
                subtitle: '${report.ketosisHoursTotal.round()}h in ketosis',
                progress: (report.fastingHoursTotal / 40.0).clamp(0.0, 1.0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Pillar 3: Hydration
            Expanded(
              child: _PillarCard(
                icon: Icons.water_drop_rounded,
                accent: const Color(0xFF38BDF8), // Ice blue
                title: 'Hydration',
                value: '${report.averageWaterMl.round()} ml / day',
                subtitle: '${(waterRatio * 100).round()}% of target',
                progress: waterRatio.clamp(0.0, 1.0),
              ),
            ),
            const SizedBox(width: 10),
            // Pillar 4: Dietary Fiber
            Expanded(
              child: _PillarCard(
                icon: Icons.grass_rounded,
                accent: zen.fiber,
                title: 'Dietary Fiber',
                value: '${report.averageFiberG.round()}g / day',
                subtitle: '${((report.averageFiberG / (report.fiberTargetG > 0 ? report.fiberTargetG : 28)) * 100).round()}% of ${report.fiberTargetG}g',
                progress: (report.averageFiberG / (report.fiberTargetG > 0 ? report.fiberTargetG : 28)).clamp(0.0, 1.0),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String value;
  final String subtitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zen.inkMuted.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: zen.inkPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: zen.inkMuted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).cardColor,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeawayInsightsCard extends StatelessWidget {
  const _TakeawayInsightsCard({required this.report});

  final WeeklyMetabolicReport report;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: zen.sage.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: zen.sage, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Coach Verdict & Observations',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: zen.sage,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"${report.verdictHeadline}"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
          ),
          if (report.keyInsights.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...report.keyInsights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: zen.sage,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        insight,
                        style: TextStyle(
                          fontSize: 12,
                          color: zen.inkMuted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
