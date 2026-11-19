import 'dart:convert';
import 'dart:math' as math;

import '../state/app_state.dart';

/// Single physical movement or exercise component identified in user's day.
class ActivityItem {
  const ActivityItem({
    required this.name,
    required this.volumeOrDuration,
    required this.estimatedBurnKcal,
    required this.metScore,
  });

  final String name;
  final String volumeOrDuration;
  final double estimatedBurnKcal;
  final double metScore;

  Map<String, dynamic> toJson() => {
        'name': name,
        'volume': volumeOrDuration,
        'calories': estimatedBurnKcal,
        'met': metScore,
      };

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      name: json['name'] as String? ?? 'Activity',
      volumeOrDuration: (json['volume'] ?? json['duration'] ?? '').toString(),
      estimatedBurnKcal: (json['calories'] as num?)?.toDouble() ?? 100.0,
      metScore: (json['met'] as num?)?.toDouble() ?? 3.5,
    );
  }
}

/// Comprehensive metabolic profile derived from natural language daily activity.
class AiMetabolicProfile {
  const AiMetabolicProfile({
    required this.activityFactor,
    required this.dailyActiveCalories,
    required this.category,
    required this.neatSummary,
    required this.activities,
    required this.coachingAdvice,
    this.usedAi = false,
  });

  final double activityFactor; // e.g. 1.48
  final double dailyActiveCalories; // e.g. 480 kcal
  final String category; // e.g. "Moderately Active"
  final String neatSummary;
  final List<ActivityItem> activities;
  final String coachingAdvice;
  final bool usedAi;
}

/// Intelligent metabolic profiler utilizing LLM reasoning with a deterministic MET fallback.
class MetabolicAnalyzer {
  static const String _systemPrompt = '''
You are an expert clinical exercise physiologist and metabolic scientist.
The user provides their natural language daily routine and physical activities (e.g. "walk 5km every morning, desk job 8 hours, 15 min rope skip in evening").
Given the user's weight in kg and Basal Metabolic Rate (BMR):
1. Deconstruct all physical movements, occupational NEAT (Non-Exercise Activity Thermogenesis), and purposeful exercises.
2. Estimate the Metabolic Equivalent of Task (MET score) and calorie burn for each activity:
   Calories = MET * Weight(kg) * Duration(hours).
3. Compute the accurate Physical Activity Level (PAL / Activity Factor) between 1.20 and 2.20.
4. Provide structured, actionable metabolic coaching advice tailored to their daily balance.

Return strictly valid JSON with this format:
{
  "activity_factor": 1.48,
  "active_calories": 520,
  "category": "Moderately Active with Aerobic & Plyometric Bursts",
  "neat_summary": "Sedentary desk work offset by high-value morning locomotion and evening jump rope.",
  "activities": [
    {
      "name": "Morning Walk",
      "volume": "5 km (~50 mins)",
      "calories": 240,
      "met": 3.8
    },
    {
      "name": "Rope Skipping",
      "volume": "15 mins",
      "calories": 165,
      "met": 10.0
    },
    {
      "name": "Desk Job / Sedentary Work",
      "volume": "8 hours",
      "calories": 115,
      "met": 1.3
    }
  ],
  "advice": "Your morning walk primes aerobic fitness while rope skipping provides bone-density and lymphatic stimulus. Take 2-minute hourly standing breaks during your desk job to prevent glucose spikes."
}
''';

  /// Analyzes natural language daily activity using the active LLM or local MET heuristics.
  static Future<AiMetabolicProfile> analyzeDailyActivity({
    required String description,
    required double weightKg,
    required double bmr,
    AppState? appState,
  }) async {
    final cleanDesc = description.trim();
    if (cleanDesc.isEmpty) {
      return _buildSedentaryProfile(weightKg, bmr);
    }

    if (appState != null && appState.isActiveProviderConfigured) {
      try {
        final userPrompt = '''
User Stats:
- Weight: ${weightKg.toStringAsFixed(1)} kg
- BMR: ${bmr.round()} kcal/day

Daily Activity & Routine Description:
"$cleanDesc"
''';

        final rawReply = await appState.generateText(
          systemPrompt: _systemPrompt,
          userPrompt: userPrompt,
        );

        final parsed = _tryParseJsonProfile(rawReply);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // Fall back gracefully to local exercise science heuristics
      }
    }

    return _heuristicMetabolicAnalysis(cleanDesc, weightKg, bmr);
  }

  static AiMetabolicProfile _buildSedentaryProfile(double weightKg, double bmr) {
    return const AiMetabolicProfile(
      activityFactor: 1.20,
      dailyActiveCalories: 0,
      category: 'Sedentary Baseline',
      neatSummary: 'Minimal structured movement recorded.',
      activities: [
        ActivityItem(
          name: 'Baseline Daily Living',
          volumeOrDuration: '24 hours',
          estimatedBurnKcal: 0,
          metScore: 1.2,
        ),
      ],
      coachingAdvice:
          'Add a brisk 20-30 minute walk or short mobility breaks to elevate metabolic rate and cardiovascular health.',
      usedAi: false,
    );
  }

  /// Parses JSON response from LLM with regex block recovery.
  static AiMetabolicProfile? _tryParseJsonProfile(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'```(?:json)?\s*'), '').replaceAll('```', '').trim();
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) return null;

    cleaned = cleaned.substring(firstBrace, lastBrace + 1);

    try {
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final factor = double.tryParse((decoded['activity_factor'] ?? decoded['pal'] ?? decoded['factor'] ?? '1.35').toString()) ?? 1.35;
      final activeCal = double.tryParse((decoded['active_calories'] ?? decoded['calories'] ?? decoded['total_active_calories'] ?? '300').toString()) ?? 300.0;
      final category = (decoded['category'] ?? decoded['activity_level'] ?? 'Custom Activity Profile').toString();
      final neatSummary = (decoded['neat_summary'] ?? decoded['summary'] ?? 'Mixed daily movement pattern.').toString();
      final advice = (decoded['advice'] ?? decoded['coaching_advice'] ?? decoded['recommendation'] ?? 'Maintain consistent hydration and daily movement.').toString();

      final activitiesList = <ActivityItem>[];
      if (decoded['activities'] is List) {
        for (final act in decoded['activities'] as List) {
          if (act is Map<String, dynamic>) {
            activitiesList.add(ActivityItem.fromJson(act));
          } else if (act is Map) {
            activitiesList.add(ActivityItem.fromJson(Map<String, dynamic>.from(act)));
          }
        }
      }

      return AiMetabolicProfile(
        activityFactor: factor.clamp(1.15, 2.30),
        dailyActiveCalories: activeCal.clamp(0, 3000),
        category: category,
        neatSummary: neatSummary,
        activities: activitiesList.isNotEmpty
            ? activitiesList
            : [
                ActivityItem(
                  name: 'Daily Active Movement',
                  volumeOrDuration: 'Various',
                  estimatedBurnKcal: activeCal,
                  metScore: 3.5,
                ),
              ],
        coachingAdvice: advice,
        usedAi: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Deterministic Compendium of Physical Activities (MET) rule engine for instant offline analysis.
  static AiMetabolicProfile _heuristicMetabolicAnalysis(
    String desc,
    double weightKg,
    double bmr,
  ) {
    final lower = desc.toLowerCase();
    final activities = <ActivityItem>[];
    double totalActiveBurn = 0.0;

    // 1. Walking / Steps
    final walkMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:km|k|kilometer|mile)s?\s*(?:walk|walked|walking)?').firstMatch(lower);
    final hasWalk = lower.contains('walk') || walkMatch != null;
    if (hasWalk) {
      double km = 3.5;
      if (walkMatch != null) {
        km = double.tryParse(walkMatch.group(1) ?? '3.5') ?? 3.5;
      }
      final durationHours = km / 5.0; // 5 km/h average brisk pace
      final burn = 3.8 * weightKg * durationHours;
      totalActiveBurn += burn;
      activities.add(ActivityItem(
        name: 'Brisk Walking',
        volumeOrDuration: '${km.toStringAsFixed(1)} km (~${(durationHours * 60).round()} mins)',
        estimatedBurnKcal: burn,
        metScore: 3.8,
      ));
    }

    // 2. Rope Skipping / Jump Rope
    final skipMatch = RegExp(r'(\d+)\s*(?:mins?|minutes?)\s*(?:of\s*)?(?:rope\s*skip|skipping|jump\s*rope)').firstMatch(lower) ??
        RegExp(r'(?:rope\s*skip|skipping|jump\s*rope)\s*(?:for\s*)?(\d+)\s*(?:mins?|minutes?)').firstMatch(lower);
    if (lower.contains('skip') || lower.contains('rope') || skipMatch != null) {
      final mins = skipMatch != null ? (double.tryParse(skipMatch.group(1) ?? '15') ?? 15.0) : 15.0;
      final durationHours = mins / 60.0;
      final burn = 10.0 * weightKg * durationHours;
      totalActiveBurn += burn;
      activities.add(ActivityItem(
        name: 'Rope Skipping / Jump Rope',
        volumeOrDuration: '${mins.round()} mins',
        estimatedBurnKcal: burn,
        metScore: 10.0,
      ));
    }

    // 3. Gym / Strength Training / Weightlifting
    if (lower.contains('gym') || lower.contains('weight') || lower.contains('lift') || lower.contains('workout') || lower.contains('strength')) {
      const mins = 45.0;
      const durationHours = mins / 60.0;
      final burn = 5.0 * weightKg * durationHours;
      totalActiveBurn += burn;
      activities.add(ActivityItem(
        name: 'Resistance & Weight Training',
        volumeOrDuration: '45 mins session',
        estimatedBurnKcal: burn,
        metScore: 5.0,
      ));
    }

    // 4. Running / Jogging
    if (lower.contains('run') || lower.contains('jog')) {
      const mins = 30.0;
      const durationHours = mins / 60.0;
      final burn = 8.5 * weightKg * durationHours;
      totalActiveBurn += burn;
      activities.add(ActivityItem(
        name: 'Running / Jogging',
        volumeOrDuration: '30 mins (steady state)',
        estimatedBurnKcal: burn,
        metScore: 8.5,
      ));
    }

    // 5. Cycling / Biking
    if (lower.contains('cycl') || lower.contains('bike')) {
      const mins = 35.0;
      const durationHours = mins / 60.0;
      final burn = 6.0 * weightKg * durationHours;
      totalActiveBurn += burn;
      activities.add(ActivityItem(
        name: 'Cycling / Biking',
        volumeOrDuration: '35 mins moderate pace',
        estimatedBurnKcal: burn,
        metScore: 6.0,
      ));
    }

    // 6. Yoga / Stretching / Mobility
    if (lower.contains('yoga') || lower.contains('stretch') || lower.contains('pilates')) {
      const mins = 30.0;
      const durationHours = mins / 60.0;
      final burn = 2.5 * weightKg * durationHours;
      totalActiveBurn += burn;
      activities.add(ActivityItem(
        name: 'Yoga & Active Mobility',
        volumeOrDuration: '30 mins',
        estimatedBurnKcal: burn,
        metScore: 2.5,
      ));
    }

    // 7. Occupational Desk Job vs Standing
    final isDeskJob = lower.contains('desk') || lower.contains('sit') || lower.contains('office') || lower.contains('computer');
    final isStanding = lower.contains('stand') || lower.contains('retail') || lower.contains('teach') || lower.contains('housework');

    String neatDesc = 'Standard moderate daily routine.';
    if (isDeskJob) {
      neatDesc = 'Sedentary occupational sitting (8+ hours). Regular breaks recommended.';
      activities.add(const ActivityItem(
        name: 'Sedentary Desk Work',
        volumeOrDuration: '7-8 hours sitting',
        estimatedBurnKcal: 85,
        metScore: 1.3,
      ));
      totalActiveBurn += 85;
    } else if (isStanding) {
      neatDesc = 'Active standing and occupational locomotion.';
      final burn = 2.2 * weightKg * 4.0;
      totalActiveBurn += burn;
      activities.add(ActivityItem(
        name: 'Standing & Occupational NEAT',
        volumeOrDuration: '4-6 hours on feet',
        estimatedBurnKcal: burn,
        metScore: 2.2,
      ));
    }

    // Compute activity factor from active calories relative to BMR
    final safeBmr = bmr > 500 ? bmr : 1600.0;
    final derivedFactor = (1.20 + (totalActiveBurn / safeBmr)).clamp(1.20, 2.10);

    String category = 'Lightly Active';
    if (derivedFactor >= 1.70) {
      category = 'Very Active Athletic Routine';
    } else if (derivedFactor >= 1.45) {
      category = 'Moderately Active Day';
    } else if (derivedFactor < 1.25) {
      category = 'Predominantly Sedentary';
    }

    return AiMetabolicProfile(
      activityFactor: (derivedFactor * 100).round() / 100.0,
      dailyActiveCalories: totalActiveBurn.roundToDouble(),
      category: category,
      neatSummary: neatDesc,
      activities: activities.isNotEmpty
          ? activities
          : [
              ActivityItem(
                name: 'Daily Functional Movement',
                volumeOrDuration: 'Estimated routine',
                estimatedBurnKcal: math.max(120.0, totalActiveBurn),
                metScore: 2.8,
              ),
            ],
      coachingAdvice: isDeskJob
          ? 'Great movement habits! Set a vibrating reminder to stand and stretch for 90 seconds every hour to keep insulin sensitivity peaked during desk work.'
          : 'Solid overall energy output. Prioritize post-workout electrolytes and consistent sleep to support muscular recovery.',
      usedAi: false,
    );
  }

  /// AI-powered body composition & South Asian metabolic diagnosis.
  static Future<String> generateBodyCompositionDiagnosis({
    required double bmi,
    required double bodyFatPct,
    required double weightKg,
    required double heightCm,
    required bool isMale,
    required String activityDescription,
    AppState? appState,
  }) async {
    final gender = isMale ? 'Male' : 'Female';
    final userStats = '''
- Height: ${heightCm.toStringAsFixed(1)} cm
- Weight: ${weightKg.toStringAsFixed(1)} kg
- Gender: $gender
- BMI: ${bmi.toStringAsFixed(1)} (Asian WHO Standard: Healthy 18.5 - 22.9, Overweight >= 23.0, Obese >= 27.5)
- Body Fat: ${bodyFatPct.toStringAsFixed(1)}% (US Navy formula)
- Lifestyle / Daily Activity: "$activityDescription"
''';

    if (appState != null && appState.isActiveProviderConfigured) {
      try {
        const sysPrompt = '''
You are a senior metabolic physician specializing in South Asian / Indian cardiometabolic health and body composition.
Analyze the user's BMI, Body Fat %, and physical activities.
Address the "South Asian Phenotype" (tendency toward normal or borderline BMI but elevated visceral/abdominal fat and low skeletal muscle mass).
Provide:
1. Primary Body Composition Diagnosis (e.g. "Lean Athletic", "Metabolically Healthy", "Normal-Weight Central Adiposity / Sarcopenic", "Excess Adiposity").
2. Visceral & Cardiometabolic Risk Analysis.
3. Tailored South Indian Nutrition & Training Protocol (e.g., protein targets, green gram sundal/lentil additions, resistance training frequency).
Keep the tone encouraging, scientific, direct, and concise (under 250 words). Avoid generic disclaimers.
''';
        final reply = await appState.generateText(
          systemPrompt: sysPrompt,
          userPrompt: userStats,
        );
        if (reply.trim().isNotEmpty) return reply.trim();
      } catch (_) {}
    }

    // High quality offline clinical rule-based diagnosis
    final isSkinnyFat = bmi < 23.0 && bodyFatPct > (isMale ? 21.0 : 31.0);
    final isOverweightAsian = bmi >= 23.0;

    if (isSkinnyFat) {
      return '### AI Clinical Diagnosis: Normal-Weight Central Adiposity\n\n'
          'Your BMI (${bmi.toStringAsFixed(1)}) appears within the standard range, but your body fat (${bodyFatPct.toStringAsFixed(1)}%) reveals a classic South Asian body composition pattern: low skeletal muscle mass accompanied by disproportionate visceral fat storage.\n\n'
          '**Recommended Protocol:**\n'
          '• **Avoid Aggressive Calorie Cutting**: Slashing calories further will cannibalize your remaining lean mass.\n'
          '• **Strength Training**: Lift weights or do progressive calisthenics 3–4 days/week to stimulate muscle protein synthesis.\n'
          '• **Dietary Shift**: Target 1.4–1.6g of protein per kg body weight (~${(weightKg * 1.5).round()}g). Add chana sundal, boiled eggs, or sprouted moong dhal to your traditional South Indian meals.';
    }

    if (isOverweightAsian) {
      return '### AI Clinical Diagnosis: Elevated Cardiometabolic Adiposity\n\n'
          'Under WHO & ICMR Asian cutoffs (Overweight ≥ 23.0, Obese ≥ 27.5), your BMI of ${bmi.toStringAsFixed(1)} indicates increased visceral adiposity risk.\n\n'
          '**Recommended Protocol:**\n'
          '• **Target Calorie Deficit**: Create a measured 400–500 kcal daily deficit to burn approximately 0.5 kg of body fat per week.\n'
          '• **Activity Boost**: Your daily routine provides a great foundation—layer on an extra 15 minutes of zone-2 aerobic movement.\n'
          '• **Tamil Nadu Food Strategy**: Sambar and Rasam are low-energy-density superfoods. Keep sambar high and control oil/ghee additions on dosas and roasts.';
    }

    return '### AI Clinical Diagnosis: Optimal Metabolic Symmetry\n\n'
        'Your BMI (${bmi.toStringAsFixed(1)}) and body fat percentage (${bodyFatPct.toStringAsFixed(1)}%) fall cleanly within the healthy Asian metabolic window. Your active daily movement supports healthy insulin sensitivity and mitochondrial density.\n\n'
        '**Maintenance Strategy:**\n'
        '• Maintain your current caloric equilibrium.\n'
        '• Prioritize micronutrient density from diverse greens (*keerai*), legumes, and adequate hydration.';
  }

  /// Generates a personalized AI Fat Loss Roadmap and macro advice.
  static Future<String> generateFatLossPlan({
    required double currentWeightKg,
    required double targetWeightKg,
    required double weeklyLossRateKg,
    required double bmr,
    required double tdee,
    required double dailyCalorieBudget,
    required String macroSplitType,
    required int proteinGrams,
    required int carbsGrams,
    required int fatGrams,
    required bool isMale,
    AppState? appState,
  }) async {
    final fatToLose = math.max(0.0, currentWeightKg - targetWeightKg);
    final weeks = weeklyLossRateKg > 0 ? (fatToLose / weeklyLossRateKg).ceil() : 0;

    if (appState != null && appState.isActiveProviderConfigured) {
      try {
        const sysPrompt = '''
You are a world-class metabolic fat-loss coach and sports nutritionist.
Provide a clear, realistic, and inspiring fat loss strategy tailored to the user's specific targets.
Structure your answer in 3 concise markdown sections:
1. **Feasibility & Timeline**: Review their weekly rate and estimated completion weeks. Note whether the pace is gentle, optimal, or aggressive.
2. **Nutrition & Macro Strategy**: Explain why the calorie budget and macro split support preserving lean muscle while maximizing fat oxidation.
3. **Daily Action Blueprint**: Give 2 practical habits (e.g. daily step target, meal timing, protein distribution) to guarantee adherence.
Keep the tone scientific, encouraging, direct, and under 220 words. Avoid generic boilerplate.
''';
        final userPrompt = '''
User Stats & Fat Loss Plan:
- Sex: ${isMale ? 'Male' : 'Female'}
- Current Weight: ${currentWeightKg.toStringAsFixed(1)} kg
- Target Weight: ${targetWeightKg.toStringAsFixed(1)} kg (${fatToLose.toStringAsFixed(1)} kg fat loss required)
- Desired Weekly Rate: ${weeklyLossRateKg.toStringAsFixed(2)} kg/week (Estimated $weeks weeks)
- Maintenance TDEE: ${tdee.round()} kcal | BMR: ${bmr.round()} kcal
- Planned Daily Calorie Target: ${dailyCalorieBudget.round()} kcal
- Macro Plan ($macroSplitType): ${proteinGrams}g Protein, ${carbsGrams}g Carbs, ${fatGrams}g Fat
''';
        final reply = await appState.generateText(
          systemPrompt: sysPrompt,
          userPrompt: userPrompt,
        );
        if (reply.trim().isNotEmpty) return reply.trim();
      } catch (e) {
        // Fall back gracefully to offline clinical plan
      }
    }

    final deficit = (tdee - dailyCalorieBudget).round();
    return '### AI Fat Loss Strategy Blueprint\n\n'
        '• **Pacing & Timeline:** Aiming to shed ${fatToLose.toStringAsFixed(1)} kg at ${weeklyLossRateKg.toStringAsFixed(2)} kg/week puts you at your goal in approximately **$weeks weeks**.\n'
        '• **Metabolic Deficit:** A measured daily deficit of ~$deficit kcal (${dailyCalorieBudget.round()} kcal budget) creates consistent fat oxidation without triggering severe metabolic slowdown.\n'
        '• **Muscle Preservation:** Your target of ${proteinGrams}g protein per day is vital to protect metabolically active lean tissue while burning fat.';
  }
}
