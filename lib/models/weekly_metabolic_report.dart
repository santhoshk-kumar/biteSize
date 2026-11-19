import 'dart:math' as math;

import '../models/fasting_model.dart';
import '../models/health_log.dart';
import '../models/user_profile.dart';
import '../services/date_utils.dart';

/// Single daily breakdown row within the weekly metabolic report.
class DailyMetabolicDataPoint {
  const DailyMetabolicDataPoint({
    required this.date,
    required this.dateKey,
    required this.caloriesConsumed,
    required this.calorieTarget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.waterMl,
    required this.hasLogs,
  });

  final DateTime date;
  final String dateKey;
  final double caloriesConsumed;
  final int calorieTarget;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final int waterMl;
  final bool hasLogs;

  double get netBalance => caloriesConsumed - calorieTarget;
}

/// Comprehensive Weekly Metabolic Report & Fat Loss Rate Predictor.
///
/// Implements dynamic energy balance modeling inspired by MacroFactor and Whoop:
/// - $1\text{ kg adipose fat tissue} \approx 7,700\text{ kcal}$ ($1\text{ lb} \approx 3,500\text{ kcal}$).
/// - Real caloric deficit vs predicted rate of adipose tissue loss.
/// - Adherence scoring across 4 metabolic pillars (Calorie pacing, Protein sufficiency, Fasting, Hydration).
/// - Contrast between scale weight fluctuations and true predicted fat loss.
class WeeklyMetabolicReport {
  const WeeklyMetabolicReport({
    required this.startDate,
    required this.endDate,
    required this.daysLogged,
    required this.totalDays,
    required this.dailyDataPoints,
    required this.totalCaloriesConsumed,
    required this.averageDailyCalories,
    required this.dailyCalorieTarget,
    required this.estimatedDailyTdee,
    required this.netWeeklyEnergyBalance,
    required this.predictedFatLossKg,
    required this.predictedFatLossLb,
    this.startWeightKg,
    this.endWeightKg,
    this.actualWeightDeltaKg,
    required this.scaleVsFatExplanation,
    required this.averageProteinG,
    required this.proteinTargetG,
    required this.averageCarbsG,
    required this.carbsTargetG,
    required this.averageFatG,
    required this.fatTargetG,
    required this.averageFiberG,
    required this.fiberTargetG,
    required this.averageWaterMl,
    required this.waterTargetMl,
    required this.fastingHoursTotal,
    required this.ketosisHoursTotal,
    required this.autophagyHoursTotal,
    required this.adherenceScore,
    required this.letterGrade,
    required this.gradeTitle,
    required this.verdictHeadline,
    required this.keyInsights,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int daysLogged;
  final int totalDays;
  final List<DailyMetabolicDataPoint> dailyDataPoints;

  // Calorie & Energy Balance
  final double totalCaloriesConsumed;
  final double averageDailyCalories;
  final int dailyCalorieTarget;
  final double estimatedDailyTdee;

  /// Net caloric balance over logged days:
  /// Positive value indicates a net caloric deficit (intake < maintenance).
  /// Negative value indicates a net caloric surplus (intake > maintenance).
  final double netWeeklyEnergyBalance;

  /// Predicted adipose tissue lost in kilograms over the period (7,700 kcal / kg).
  /// Positive = fat lost; negative = fat gained.
  final double predictedFatLossKg;

  /// Predicted adipose tissue lost in pounds over the period (3,500 kcal / lb).
  final double predictedFatLossLb;

  // Weight Tracking Comparison
  final double? startWeightKg;
  final double? endWeightKg;
  final double? actualWeightDeltaKg;
  final String scaleVsFatExplanation;

  // Macronutrients & Fiber
  final double averageProteinG;
  final int proteinTargetG;
  final double averageCarbsG;
  final int carbsTargetG;
  final double averageFatG;
  final int fatTargetG;
  final double averageFiberG;
  final int fiberTargetG;

  // Hydration
  final double averageWaterMl;
  final int waterTargetMl;

  // Intermittent Fasting
  final double fastingHoursTotal;
  final double ketosisHoursTotal;
  final double autophagyHoursTotal;

  // Adherence & Scoring (0 - 100)
  final int adherenceScore;
  final String letterGrade;
  final String gradeTitle;

  // Insights & Scientific Takeaways
  final String verdictHeadline;
  final List<String> keyInsights;

  bool get isDeficit => netWeeklyEnergyBalance >= 0;

  /// Formatted date range string (e.g. "Nov 8 – Nov 14, 2026").
  String get dateRangeFormatted {
    final startStr = '${_monthName(startDate.month)} ${startDate.day}';
    final endStr = '${_monthName(endDate.month)} ${endDate.day}, ${endDate.year}';
    return '$startStr – $endStr';
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  /// Calculates a full WeeklyMetabolicReport from app state data.
  factory WeeklyMetabolicReport.compute({
    required List<DateTime> dates,
    required Map<String, DailyCalorieSummary> summaries,
    required DailyGoals goals,
    required UserProfile profile,
    required List<WeightEntry> weightHistory,
    required FastingState fasting,
  }) {
    final totalDays = dates.length;
    if (totalDays == 0) {
      final now = DateTime.now();
      return WeeklyMetabolicReport._empty(now, now, goals);
    }

    final startDate = dates.first;
    final endDate = dates.last;

    var daysLogged = 0;
    var sumCal = 0.0;
    var sumProtein = 0.0;
    var sumCarbs = 0.0;
    var sumFat = 0.0;
    var sumFiber = 0.0;
    var sumWater = 0;

    final dataPoints = <DailyMetabolicDataPoint>[];

    for (final day in dates) {
      final key = ZenDateUtils.toDateKey(day);
      final s = summaries[key];
      final hasLogs = s != null && s.mealCount > 0;

      if (hasLogs) {
        daysLogged++;
        sumCal += s.calories;
        sumProtein += s.proteinG;
        sumCarbs += s.carbsG;
        sumFat += s.fatG;
        sumFiber += s.fiberG;
        sumWater += s.waterMl;
      }

      dataPoints.add(
        DailyMetabolicDataPoint(
          date: day,
          dateKey: key,
          caloriesConsumed: s?.calories ?? 0.0,
          calorieTarget: goals.calorieTarget,
          proteinG: s?.proteinG ?? 0.0,
          carbsG: s?.carbsG ?? 0.0,
          fatG: s?.fatG ?? 0.0,
          fiberG: s?.fiberG ?? 0.0,
          waterMl: s?.waterMl ?? 0,
          hasLogs: hasLogs,
        ),
      );
    }

    final divisor = daysLogged == 0 ? 1 : daysLogged;
    final avgCal = sumCal / divisor;
    final avgProtein = sumProtein / divisor;
    final avgCarbs = sumCarbs / divisor;
    final avgFat = sumFat / divisor;
    final avgFiber = sumFiber / divisor;
    final avgWater = (sumWater / divisor).toDouble();

    // 1. Maintenance TDEE estimation (Mifflin-St Jeor formula with 1.375 activity multiplier)
    double estimatedTdee;
    if (profile.heightCm > 0 && profile.weightKg > 0 && profile.age > 0) {
      final bmr = profile.isMale
          ? (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * profile.age) + 5
          : (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * profile.age) - 161;
      estimatedTdee = bmr * 1.375;
    } else {
      // Fallback: assume user's calorie target was set based on a typical 300-500 kcal deficit
      estimatedTdee = (goals.calorieTarget * 1.20).clamp(1600.0, 3600.0);
    }

    // 2. Net Energy Balance & Predicted Fat Loss Rate
    // Net Deficit = (Daily Maintenance TDEE * daysLogged) - totalCaloriesConsumed
    final activeDays = daysLogged > 0 ? daysLogged : 7;
    final totalMaintenanceForPeriod = estimatedTdee * activeDays;
    final netEnergyBalance = totalMaintenanceForPeriod - sumCal;

    // 1 kg pure body fat tissue = 7,700 kcal (3,500 kcal / lb)
    final predictedFatLossKg = netEnergyBalance / 7700.0;
    final predictedFatLossLb = predictedFatLossKg * 2.20462;

    // 3. Weight Tracking Comparison
    double? startWt;
    double? endWt;
    double? actualDelta;

    if (weightHistory.isNotEmpty) {
      final relevantWeights = weightHistory.where((w) {
        final d = ZenDateUtils.fromDateKey(w.dateKey);
        return d.isAfter(startDate.subtract(const Duration(days: 2))) &&
            d.isBefore(endDate.add(const Duration(days: 2)));
      }).toList();

      if (relevantWeights.isNotEmpty) {
        // sorted by date ascending
        relevantWeights.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
        startWt = relevantWeights.first.weightKg;
        endWt = relevantWeights.last.weightKg;
        if (relevantWeights.length >= 2) {
          actualDelta = endWt - startWt;
        }
      }
    }

    String scaleExplanation;
    if (actualDelta == null) {
      scaleExplanation = 'Log weight 2+ times per week to compare true fat loss with scale fluid changes.';
    } else {
      final diffKg = (actualDelta.abs() - predictedFatLossKg.abs()).abs();
      if (diffKg < 0.3) {
        scaleExplanation = 'High correlation: Scale movement matches thermodynamic energy expenditure closely.';
      } else if (actualDelta < -predictedFatLossKg) {
        scaleExplanation = 'Scale dropped faster than fat loss rate — reflects glycogen depletion & natural water shed.';
      } else {
        scaleExplanation = 'Scale showed transient retention (sodium, hydration, or muscle inflammation) despite steady fat deficit.';
      }
    }

    // 4. Fasting & Metabolic Hours
    // Fasting hours for this week estimated from fasting state & completions
    final fastingHours = math.min(
      fasting.totalHoursFasted,
      (fasting.totalFastsCompleted * fasting.protocol.fastHours.toDouble()).clamp(0.0, 168.0),
    );
    // Stages: >12h is Ketosis/Lipolysis, >18h is Deep Autophagy
    final ketosisHours = math.max(
      0.0,
      fastingHours - (fasting.totalFastsCompleted * 12.0),
    );
    final autophagyHours = math.max(
      0.0,
      fastingHours - (fasting.totalFastsCompleted * 18.0),
    );

    // 5. MacroFactor / Whoop Adherence Scoring (0 - 100)
    var score = 0;
    final proteinRatio = goals.proteinTargetG > 0 ? (avgProtein / goals.proteinTargetG) : 1.0;
    final waterRatio = goals.waterTargetMl > 0 ? (avgWater / goals.waterTargetMl) : 1.0;
    final fiberRatio = goals.fiberTargetG > 0 ? (avgFiber / goals.fiberTargetG) : 1.0;

    if (daysLogged > 0) {
      // A. Calorie Adherence (up to 40 pts)
      final calRatio = (avgCal / goals.calorieTarget).clamp(0.0, 2.0);
      final calVariance = (calRatio - 1.0).abs();
      if (calVariance <= 0.08) {
        score += 40; // Within 8% of target
      } else if (calVariance <= 0.15) {
        score += 32; // Within 15%
      } else if (calVariance <= 0.25) {
        score += 22; // Within 25%
      } else {
        score += 10;
      }

      // B. Protein Sufficiency (up to 25 pts)
      if (proteinRatio >= 0.90) {
        score += 25;
      } else if (proteinRatio >= 0.75) {
        score += 18;
      } else if (proteinRatio >= 0.60) {
        score += 12;
      } else {
        score += 5;
      }

      // C. Logging Consistency (up to 20 pts)
      final logPoints = ((daysLogged / totalDays) * 20).round();
      score += logPoints;

      // D. Hydration & Fiber Balance (up to 15 pts)
      if (waterRatio >= 0.80) {
        score += 10;
      } else if (waterRatio >= 0.50) {
        score += 5;
      }

      if (fiberRatio >= 0.80) {
        score += 5;
      } else if (fiberRatio >= 0.50) {
        score += 3;
      }
    }

    score = score.clamp(0, 100);

    // Determine Letter Grade
    String grade;
    String gradeTitle;
    if (score >= 90) {
      grade = 'A+';
      gradeTitle = 'Elite Adherence';
    } else if (score >= 80) {
      grade = 'A';
      gradeTitle = 'Strong Progress';
    } else if (score >= 70) {
      grade = 'B';
      gradeTitle = 'Solid Foundation';
    } else if (score >= 60) {
      grade = 'C';
      gradeTitle = 'Inconsistent Pacing';
    } else {
      grade = 'D';
      gradeTitle = 'Needs Recalibration';
    }

    // 6. Actionable Takeaways & Scientific Insights
    final keyInsights = <String>[];
    String verdictHeadline;

    if (daysLogged == 0) {
      verdictHeadline = 'No meals logged this week yet. Log your first meal to calculate fat loss rate.';
      keyInsights.add('Logging daily meals allows the metabolic engine to model your real net caloric expenditure.');
      keyInsights.add('Consistent tracking is 3x more predictive of long-term body composition than diet type.');
    } else if (predictedFatLossKg > 0.15) {
      verdictHeadline = 'Optimal Fat Burning Zone: Projected fat reduction of ${predictedFatLossKg.toStringAsFixed(2)} kg this week.';
      keyInsights.add('Your weekly net deficit of ${netEnergyBalance.round()} kcal fuels cellular lipolysis without slowing basal metabolic rate.');
      if (proteinRatio >= 0.85) {
        keyInsights.add('High protein intake (${avgProtein.round()}g / day) successfully shields lean muscle tissue from catabolism.');
      } else {
        keyInsights.add('Increase daily protein closer to ${goals.proteinTargetG}g to ensure lean muscle mass is preserved.');
      }
      if (fastingHours > 10) {
        keyInsights.add('${fastingHours.round()}h fasted across the week accelerated ketone production and cellular autophagy.');
      }
      if (waterRatio < 0.75) {
        keyInsights.add('Fluid intake was ${avgWater.round()} ml/day — boosting water to ${goals.waterTargetMl} ml aids metabolic waste clearance.');
      }
    } else if (predictedFatLossKg < -0.15) {
      verdictHeadline = 'Caloric Surplus Detected: Averaging ${(avgCal - estimatedTdee).round()} kcal above maintenance.';
      keyInsights.add('Energy surplus supports muscle hypertrophy or recovery. If aiming for fat loss, trim daily intake by 300–500 kcal.');
      keyInsights.add('Review evening snacks or liquid calories to regain caloric equilibrium.');
    } else {
      verdictHeadline = 'Energy Neutrality: Intake matches estimated maintenance TDEE within ±100 kcal.';
      keyInsights.add('Perfect metabolic maintenance rhythm. Body fat percentage and weight will remain highly stable.');
      keyInsights.add('To enter a steady fat loss phase, create a gentle 350 kcal/day deficit.');
    }

    return WeeklyMetabolicReport(
      startDate: startDate,
      endDate: endDate,
      daysLogged: daysLogged,
      totalDays: totalDays,
      dailyDataPoints: dataPoints,
      totalCaloriesConsumed: sumCal,
      averageDailyCalories: avgCal,
      dailyCalorieTarget: goals.calorieTarget,
      estimatedDailyTdee: estimatedTdee,
      netWeeklyEnergyBalance: netEnergyBalance,
      predictedFatLossKg: predictedFatLossKg,
      predictedFatLossLb: predictedFatLossLb,
      startWeightKg: startWt,
      endWeightKg: endWt,
      actualWeightDeltaKg: actualDelta,
      scaleVsFatExplanation: scaleExplanation,
      averageProteinG: avgProtein,
      proteinTargetG: goals.proteinTargetG,
      averageCarbsG: avgCarbs,
      carbsTargetG: goals.carbsTargetG,
      averageFatG: avgFat,
      fatTargetG: goals.fatTargetG,
      averageFiberG: avgFiber,
      fiberTargetG: goals.fiberTargetG,
      averageWaterMl: avgWater,
      waterTargetMl: goals.waterTargetMl,
      fastingHoursTotal: fastingHours,
      ketosisHoursTotal: ketosisHours,
      autophagyHoursTotal: autophagyHours,
      adherenceScore: score,
      letterGrade: grade,
      gradeTitle: gradeTitle,
      verdictHeadline: verdictHeadline,
      keyInsights: keyInsights,
    );
  }

  static WeeklyMetabolicReport _empty(DateTime start, DateTime end, DailyGoals goals) {
    return WeeklyMetabolicReport(
      startDate: start,
      endDate: end,
      daysLogged: 0,
      totalDays: 7,
      dailyDataPoints: const [],
      totalCaloriesConsumed: 0.0,
      averageDailyCalories: 0.0,
      dailyCalorieTarget: goals.calorieTarget,
      estimatedDailyTdee: goals.calorieTarget * 1.15,
      netWeeklyEnergyBalance: 0.0,
      predictedFatLossKg: 0.0,
      predictedFatLossLb: 0.0,
      scaleVsFatExplanation: 'Log meals and weigh-ins to activate the predictive metabolic model.',
      averageProteinG: 0.0,
      proteinTargetG: goals.proteinTargetG,
      averageCarbsG: 0.0,
      carbsTargetG: goals.carbsTargetG,
      averageFatG: 0.0,
      fatTargetG: goals.fatTargetG,
      averageFiberG: 0.0,
      fiberTargetG: goals.fiberTargetG,
      averageWaterMl: 0.0,
      waterTargetMl: goals.waterTargetMl,
      fastingHoursTotal: 0.0,
      ketosisHoursTotal: 0.0,
      autophagyHoursTotal: 0.0,
      adherenceScore: 0,
      letterGrade: '—',
      gradeTitle: 'No Data',
      verdictHeadline: 'No tracking data available for this week.',
      keyInsights: const [
        'Log your meals to unlock full metabolic predictions, net deficit modeling, and fat loss forecasting.',
      ],
    );
  }

  /// Formatted text output suitable for 1-tap clipboard copying or sharing.
  String toShareableText({required bool useKg}) {
    final fatLossStr = useKg
        ? '${predictedFatLossKg >= 0 ? "-" : "+"}${predictedFatLossKg.abs().toStringAsFixed(2)} kg fat'
        : '${predictedFatLossLb >= 0 ? "-" : "+"}${predictedFatLossLb.abs().toStringAsFixed(2)} lb fat';

    final buffer = StringBuffer();
    buffer.writeln('🧬 BITESIZE WEEKLY METABOLIC REPORT');
    buffer.writeln('📅 Period: $dateRangeFormatted');
    buffer.writeln('🎯 Score: $adherenceScore/100 ($letterGrade • $gradeTitle)');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔥 ENERGY & FAT LOSS PREDICTOR:');
    buffer.writeln('• Avg Intake: ${averageDailyCalories.round()} kcal / day (Goal: $dailyCalorieTarget kcal)');
    buffer.writeln('• Estimated TDEE: ${estimatedDailyTdee.round()} kcal / day');
    buffer.writeln('• Net 7-Day Deficit: ${netWeeklyEnergyBalance.round()} kcal');
    buffer.writeln('• Predicted Fat Loss Rate: $fatLossStr / week');
    if (actualWeightDeltaKg != null) {
      final actualStr = useKg
          ? '${actualWeightDeltaKg! >= 0 ? "+" : ""}${actualWeightDeltaKg!.toStringAsFixed(1)} kg'
          : '${actualWeightDeltaKg! >= 0 ? "+" : ""}${(actualWeightDeltaKg! * 2.20462).toStringAsFixed(1)} lbs';
      buffer.writeln('• Actual Scale Delta: $actualStr');
      buffer.writeln('• Note: $scaleVsFatExplanation');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🥩 MACRONUTRIENTS & MICROS:');
    buffer.writeln('• Protein: ${averageProteinG.round()}g / ${proteinTargetG}g (${((averageProteinG / (proteinTargetG > 0 ? proteinTargetG : 1)) * 100).round()}%)');
    buffer.writeln('• Carbs: ${averageCarbsG.round()}g | Fat: ${averageFatG.round()}g');
    buffer.writeln('• Fiber: ${averageFiberG.round()}g / ${fiberTargetG}g');
    buffer.writeln('• Hydration: ${averageWaterMl.round()} ml / $waterTargetMl ml');
    if (fastingHoursTotal > 0) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('⏳ FASTING & CELLULAR RENEWAL:');
      buffer.writeln('• Total Fasted: ${fastingHoursTotal.toStringAsFixed(1)}h');
      buffer.writeln('• Lipolysis & Ketosis: ${ketosisHoursTotal.toStringAsFixed(1)}h');
      buffer.writeln('• Deep Autophagy: ${autophagyHoursTotal.toStringAsFixed(1)}h');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💡 METABOLIC TAKEAWAY:');
    buffer.writeln('"$verdictHeadline"');
    for (final insight in keyInsights) {
      buffer.writeln('• $insight');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Tracked with BiteSize — Smart Calorie & Metabolism Counter');
    return buffer.toString();
  }
}
