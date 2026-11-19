import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';

/// Weekly compliance report generator formatted for clinical consultations,
/// personal trainers, or registered dietitians.
class DietitianReportSheet extends StatelessWidget {
  const DietitianReportSheet({super.key, required this.appState});

  final AppState appState;

  String _generateReportText() {
    final today = ZenDateUtils.dateOnly(DateTime.now());
    final trailing7 = ZenDateUtils.trailingDates(today, 7);

    var loggedDays = 0;
    var sumCal = 0.0;
    var sumProtein = 0.0;
    var sumCarbs = 0.0;
    var sumFat = 0.0;
    var sumFiber = 0.0;

    for (final day in trailing7) {
      final s = appState.recentSummaries[ZenDateUtils.toDateKey(day)];
      if (s != null && s.mealCount > 0) {
        loggedDays++;
        sumCal += s.calories;
        sumProtein += s.proteinG;
        sumCarbs += s.carbsG;
        sumFat += s.fatG;
        sumFiber += s.fiberG;
      }
    }

    final divisor = loggedDays == 0 ? 1 : loggedDays;
    final avgCal = (sumCal / divisor).round();
    final avgProtein = (sumProtein / divisor).round();
    final avgCarbs = (sumCarbs / divisor).round();
    final avgFat = (sumFat / divisor).round();
    final avgFiber = (sumFiber / divisor).round();

    final targetCal = appState.goals.calorieTarget;
    final complianceRate = ((loggedDays / 7) * 100).round();

    final latestWt = appState.latestWeight?.weightKg;
    final targetWt = appState.goals.targetWeightKg;

    final profile = appState.profile;

    return '''
========================================
BITESIZE NUTRITION & CLINICAL SUMMARY
Generated: ${DateTime.now().toLocal().toString().split('.')[0]}
Tracking Period: Last 7 Days
========================================

PATIENT / CLIENT METRICS:
- Biological Sex: ${profile.sexLabel}
- Age: ${profile.age} years
- Height: ${profile.heightCm.toStringAsFixed(0)} cm
- Weight: ${latestWt != null ? '${latestWt.toStringAsFixed(1)} kg' : 'Not recorded'} (Goal: ${targetWt.toStringAsFixed(1)} kg)
- Asian-Specific BMI: ${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})
- Waist-to-Height Ratio: ${profile.waistToHeightRatio.toStringAsFixed(2)}

7-DAY ADHERENCE & COMPLIANCE:
- Logging Compliance: $loggedDays / 7 Days ($complianceRate%)
- Current Logging Streak: ${appState.currentStreakDays} days

ENERGY & MACRONUTRIENT BALANCE (7-Day Averages):
- Daily Energy Intake: $avgCal kcal / day
- Daily Energy Target: $targetCal kcal / day
- Variance: ${(avgCal - targetCal) > 0 ? '+$avgCal' : '${avgCal - targetCal}'} kcal/day
- Dietary Protein: ${avgProtein}g / day (Target: ${appState.goals.proteinTargetG}g)
- Dietary Carbohydrates: ${avgCarbs}g / day (Target: ${appState.goals.carbsTargetG}g)
- Dietary Fats: ${avgFat}g / day (Target: ${appState.goals.fatTargetG}g)
- Dietary Fiber: ${avgFiber}g / day (Target: ${appState.goals.fiberTargetG}g)

HYDRATION & METABOLIC STATUS:
- Today's Water: ${appState.totalWaterMlForDay} ml (Goal: ${appState.goals.waterTargetMl} ml)
- Fasting Protocol: ${appState.fasting.protocol.label} (${appState.fasting.isActive ? 'Active' : 'Inactive'})
- Calorie Banking: ${appState.calorieBank.enabled ? 'Enabled (${appState.calorieBank.bankDailyKcal} kcal/weekday banked)' : 'Disabled'}

========================================
Summary compiled securely on device by BiteSize AI.
========================================
''';
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final today = ZenDateUtils.dateOnly(DateTime.now());
    final trailing7 = ZenDateUtils.trailingDates(today, 7);

    var loggedDays = 0;
    var sumCal = 0.0;
    var sumProtein = 0.0;
    var sumFiber = 0.0;

    for (final day in trailing7) {
      final s = appState.recentSummaries[ZenDateUtils.toDateKey(day)];
      if (s != null && s.mealCount > 0) {
        loggedDays++;
        sumCal += s.calories;
        sumProtein += s.proteinG;
        sumFiber += s.fiberG;
      }
    }

    final divisor = loggedDays == 0 ? 1 : loggedDays;
    final avgCal = (sumCal / divisor).round();
    final avgProtein = (sumProtein / divisor).round();
    final avgFiber = (sumFiber / divisor).round();
    final complianceRate = ((loggedDays / 7) * 100).round();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: zen.borderSoft),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: zen.inkMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: zen.sageSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assignment_turned_in_rounded, color: zen.sage, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dietitian & Doctor Clinical Report',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      '7-Day clinical nutrition and metabolic compliance',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: zen.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metric Cards Row
          Row(
            children: [
              Expanded(
                child: _ReportStatCard(
                  label: 'Compliance',
                  value: '$complianceRate%',
                  subtitle: '$loggedDays of 7 days',
                  accent: zen.sage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReportStatCard(
                  label: 'Avg Energy',
                  value: '$avgCal',
                  subtitle: 'Target: ${appState.goals.calorieTarget}',
                  accent: zen.carbs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReportStatCard(
                  label: 'Avg Protein',
                  value: '${avgProtein}g',
                  subtitle: 'Fiber: ${avgFiber}g',
                  accent: zen.protein,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: zen.borderSoft),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _generateReportText(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generateReportText()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Clinical summary copied to clipboard! Ready to share.'),
                ),
              );
            },
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copy Clinical Report to Clipboard'),
          ),
        ],
      ),
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  const _ReportStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: accent,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the Dietitian Report sheet.
Future<void> showDietitianReportSheet(BuildContext context, {required AppState appState}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DietitianReportSheet(appState: appState),
  );
}

