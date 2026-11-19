import 'dart:math' as math;

import 'gps_route.dart';

/// Types of physical movement and fitness tracked in Zen Calorie.
enum ExerciseType {
  walking,
  running,
  jumpRope,
  gym,
  cycling,
  custom;

  String get displayName {
    switch (this) {
      case ExerciseType.walking:
        return 'Walking';
      case ExerciseType.running:
        return 'Running';
      case ExerciseType.jumpRope:
        return 'Jump Rope';
      case ExerciseType.gym:
        return 'Gym Workout';
      case ExerciseType.cycling:
        return 'Cycling';
      case ExerciseType.custom:
        return 'Activity';
    }
  }

  String get emoji {
    switch (this) {
      case ExerciseType.walking:
        return '🚶';
      case ExerciseType.running:
        return '🏃';
      case ExerciseType.jumpRope:
        return '🪢';
      case ExerciseType.gym:
        return '🏋️';
      case ExerciseType.cycling:
        return '🚴';
      case ExerciseType.custom:
        return '⚡';
    }
  }

  /// Default base MET (Metabolic Equivalent of Task) per Compendium of Physical Activities.
  double get baseMet {
    switch (this) {
      case ExerciseType.walking:
        return 3.8; // Moderate walking (~4.8 km/h)
      case ExerciseType.running:
        return 9.8; // Moderate running (~9.7 km/h / 6:12 min/km)
      case ExerciseType.jumpRope:
        return 11.8; // Standard skipping (100-120 skips/min)
      case ExerciseType.gym:
        return 5.5; // Resistance & strength training
      case ExerciseType.cycling:
        return 7.5; // Moderate cycling (~19-22 km/h)
      case ExerciseType.custom:
        return 5.0;
    }
  }
}

/// Workout perceived exertion & intensity tier.
enum ExerciseIntensity {
  light,
  moderate,
  vigorous,
  extreme;

  String get label {
    switch (this) {
      case ExerciseIntensity.light:
        return 'Light';
      case ExerciseIntensity.moderate:
        return 'Moderate';
      case ExerciseIntensity.vigorous:
        return 'Vigorous';
      case ExerciseIntensity.extreme:
        return 'Maximum';
    }
  }

  double get metMultiplier {
    switch (this) {
      case ExerciseIntensity.light:
        return 0.85;
      case ExerciseIntensity.moderate:
        return 1.0;
      case ExerciseIntensity.vigorous:
        return 1.25;
      case ExerciseIntensity.extreme:
        return 1.45;
    }
  }
}

/// A logged workout or physical movement session.
class ExerciseEntry {
  const ExerciseEntry({
    required this.id,
    required this.dateKey,
    required this.loggedAt,
    required this.type,
    required this.title,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.distanceKm,
    this.steps,
    this.intensity = ExerciseIntensity.moderate,
    this.gymCategory,
    this.notes = '',
    this.routePointsJson,
  });

  final String id;
  final String dateKey;
  final DateTime loggedAt;
  final ExerciseType type;
  final String title;
  final int durationMinutes;
  final double caloriesBurned;
  final double? distanceKm;
  final int? steps;
  final ExerciseIntensity intensity;
  final String? gymCategory;
  final String notes;

  /// Serialized JSON list of [GpsPoint] objects captured during headless GPS tracking.
  final String? routePointsJson;

  /// Deserialized route points.
  List<GpsPoint> get routePoints => GpsPoint.listFromJson(routePointsJson);

  /// True if this entry has recorded GPS route breadcrumbs.
  bool get hasRoute =>
      routePointsJson != null &&
      routePointsJson!.trim().isNotEmpty &&
      routePoints.isNotEmpty;

  /// Average pace in minutes per kilometer (for running/walking with distance).
  String? get formattedPace {
    if (distanceKm == null || distanceKm! <= 0 || durationMinutes <= 0) {
      return null;
    }
    final paceMinPerKm = durationMinutes / distanceKm!;
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Average speed in km/h.
  double? get speedKmh {
    if (distanceKm == null || distanceKm! <= 0 || durationMinutes <= 0) {
      return null;
    }
    return distanceKm! / (durationMinutes / 60.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateKey': dateKey,
      'loggedAt': loggedAt.millisecondsSinceEpoch,
      'type': type.name,
      'title': title,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'distanceKm': distanceKm,
      'steps': steps,
      'intensity': intensity.name,
      'gymCategory': gymCategory,
      'notes': notes,
      'routePointsJson': routePointsJson,
    };
  }

  factory ExerciseEntry.fromMap(Map<String, dynamic> map) {
    final typeName = (map['type'] ?? map['exercise_type'] ?? 'walking').toString();
    final parsedType = ExerciseType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => ExerciseType.custom,
    );

    final intensityName = (map['intensity'] ?? 'moderate').toString();
    final parsedIntensity = ExerciseIntensity.values.firstWhere(
      (e) => e.name == intensityName,
      orElse: () => ExerciseIntensity.moderate,
    );

    return ExerciseEntry(
      id: (map['id'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? map['date_key'] ?? '').toString(),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['loggedAt'] ?? map['logged_at'] as num?)?.toInt() ?? 0,
      ),
      type: parsedType,
      title: (map['title'] ?? parsedType.displayName).toString(),
      durationMinutes: ((map['durationMinutes'] ?? map['duration_minutes']) as num?)?.toInt() ?? 0,
      caloriesBurned: ((map['caloriesBurned'] ?? map['calories_burned']) as num?)?.toDouble() ?? 0.0,
      distanceKm: ((map['distanceKm'] ?? map['distance_km']) as num?)?.toDouble(),
      steps: ((map['steps'] as num?)?.toInt()),
      intensity: parsedIntensity,
      gymCategory: map['gymCategory']?.toString() ?? map['gym_category']?.toString(),
      notes: (map['notes'] ?? '').toString(),
      routePointsJson: map['routePointsJson']?.toString() ??
          map['route_points_json']?.toString(),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'date_key': dateKey,
      'logged_at': loggedAt.millisecondsSinceEpoch,
      'exercise_type': type.name,
      'title': title,
      'duration_minutes': durationMinutes,
      'calories_burned': caloriesBurned,
      'distance_km': distanceKm,
      'steps': steps,
      'intensity': intensity.name,
      'gym_category': gymCategory,
      'notes': notes,
      'route_points_json': routePointsJson,
    };
  }

  factory ExerciseEntry.fromDbMap(Map<String, dynamic> map) {
    return ExerciseEntry.fromMap(map);
  }

  ExerciseEntry copyWith({
    String? id,
    String? dateKey,
    DateTime? loggedAt,
    ExerciseType? type,
    String? title,
    int? durationMinutes,
    double? caloriesBurned,
    double? distanceKm,
    int? steps,
    ExerciseIntensity? intensity,
    String? gymCategory,
    String? notes,
    String? routePointsJson,
  }) {
    return ExerciseEntry(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      loggedAt: loggedAt ?? this.loggedAt,
      type: type ?? this.type,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distanceKm: distanceKm ?? this.distanceKm,
      steps: steps ?? this.steps,
      intensity: intensity ?? this.intensity,
      gymCategory: gymCategory ?? this.gymCategory,
      notes: notes ?? this.notes,
      routePointsJson: routePointsJson ?? this.routePointsJson,
    );
  }
}

/// Scientific physical activity energy expenditure calculator
/// based on the 2024 Compendium of Physical Activities and kinematic human locomotion models.
class ExerciseCalculator {
  /// Default average step count per 1.0 km of human walking (~0.76m step length).
  static const double stepsPerKm = 1315.0;

  /// Dynamic steps per km based on biomechanical stride length (0.414 * height).
  static double stepsPerKmForHeight(double? userHeightCm) {
    if (userHeightCm != null && userHeightCm >= 100 && userHeightCm <= 240) {
      final strideM = (userHeightCm * 0.414) / 100.0;
      return 1000.0 / strideM;
    }
    return stepsPerKm;
  }

  /// Estimate steps from distance in km, calibrated to user height if configured.
  static int stepsFromKm(double km, {double? userHeightCm}) =>
      (km * stepsPerKmForHeight(userHeightCm)).round();

  /// Estimate distance in km from step count, calibrated to user height if configured.
  static double kmFromSteps(int steps, {double? userHeightCm}) =>
      (steps / stepsPerKmForHeight(userHeightCm));

  /// Calculate scientific active calorie burn using:
  /// Calories = MET * Weight(kg) * (Duration(mins) / 60)
  static double calculateBurn({
    required ExerciseType type,
    required int durationMinutes,
    required double userWeightKg,
    ExerciseIntensity intensity = ExerciseIntensity.moderate,
    double? distanceKm,
    double? userHeightCm,
  }) {
    if (durationMinutes <= 0 || userWeightKg <= 0) return 0.0;

    double effectiveMet = type.baseMet * intensity.metMultiplier;

    // Kinematic speed-adjusted MET for running and walking if distance is provided
    if (distanceKm != null && distanceKm > 0 && durationMinutes > 0) {
      final speedKmh = distanceKm / (durationMinutes / 60.0);
      if (type == ExerciseType.running) {
        if (speedKmh <= 8.0) {
          effectiveMet = 8.0;
        } else if (speedKmh <= 9.7) {
          effectiveMet = 9.8;
        } else if (speedKmh <= 11.3) {
          effectiveMet = 11.0;
        } else if (speedKmh <= 13.0) {
          effectiveMet = 12.5;
        } else {
          effectiveMet = 14.5; // > 13 km/h fast pacing
        }
        effectiveMet *= intensity.metMultiplier;
      } else if (type == ExerciseType.walking) {
        if (speedKmh <= 4.0) {
          effectiveMet = 3.0; // Slow stroll
        } else if (speedKmh <= 5.2) {
          effectiveMet = 3.8; // Moderate walk
        } else if (speedKmh <= 6.5) {
          effectiveMet = 4.8; // Brisk fitness walk
        } else {
          effectiveMet = 6.0; // Power walk / uphill
        }
        effectiveMet *= intensity.metMultiplier;
      } else if (type == ExerciseType.cycling) {
        if (speedKmh <= 15.0) {
          effectiveMet = 5.5; // Leisurely cycling
        } else if (speedKmh <= 19.0) {
          effectiveMet = 6.8;
        } else if (speedKmh <= 22.5) {
          effectiveMet = 8.0; // Moderate effort
        } else if (speedKmh <= 26.0) {
          effectiveMet = 10.0; // Fast / vigorous
        } else {
          effectiveMet = 12.0; // Racing / intense
        }
        effectiveMet *= intensity.metMultiplier;
      }
    }

    final hours = durationMinutes / 60.0;
    final burn = effectiveMet * userWeightKg * hours;
    return math.max(0.0, (burn * 10).round() / 10.0);
  }

  /// Format pace as M:SS /km.
  static String formatPace(int durationMinutes, double distanceKm) {
    if (distanceKm <= 0 || durationMinutes <= 0) return '-- /km';
    final paceMinPerKm = durationMinutes / distanceKm;
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Natural language heuristic parser for workouts and activities.
  /// Works 100% offline with zero dependencies and sub-millisecond execution.
  /// Backward compatible helper returning primary segment or single parsed exercise.
  static ExerciseParseResult parseNaturalLanguage(
    String text, {
    double? userWeightKg,
    double? userHeightCm,
  }) {
    final compound = parseCompoundNaturalLanguage(
      text,
      userWeightKg: userWeightKg,
      userHeightCm: userHeightCm,
    );
    return compound.primarySegment;
  }

  /// Compound natural language parser capable of splitting multi-activity descriptions
  /// (e.g. "5km run and 20 min jump rope" or "45 min gym push then 15 min walk")
  /// into distinct, scientifically calibrated workout segments.
  static CompoundExerciseParseResult parseCompoundNaturalLanguage(
    String text, {
    double? userWeightKg,
    double? userHeightCm,
  }) {
    final raw = text.trim();
    if (raw.isEmpty) {
      return const CompoundExerciseParseResult(
        segments: [],
        totalDurationMinutes: 0,
        totalCaloriesBurned: 0.0,
      );
    }

    final rawSegments = _splitCompoundActivities(raw);

    final segments = <ExerciseParseResult>[];
    for (final segText in rawSegments) {
      final parsed = _parseSingleSegment(
        segText,
        userWeightKg: userWeightKg,
        userHeightCm: userHeightCm,
      );
      segments.add(parsed);
    }

    if (segments.isEmpty) {
      final single = _parseSingleSegment(
        raw,
        userWeightKg: userWeightKg,
        userHeightCm: userHeightCm,
      );
      segments.add(single);
    }

    int totalDuration = 0;
    double totalCalories = 0.0;
    double? totalDistance;
    int? totalSteps;

    for (final s in segments) {
      totalDuration += s.durationMinutes;
      totalCalories += s.caloriesBurned ?? 0.0;
      if (s.distanceKm != null && s.distanceKm! > 0) {
        totalDistance = (totalDistance ?? 0.0) + s.distanceKm!;
      }
      if (s.steps != null && s.steps! > 0) {
        totalSteps = (totalSteps ?? 0) + s.steps!;
      }
    }

    final compositeTitle = segments.length > 1
        ? segments.map((s) => s.title).join(' + ')
        : (segments.isNotEmpty ? segments.first.title : 'Workout');

    return CompoundExerciseParseResult(
      segments: segments,
      totalDurationMinutes: totalDuration,
      totalCaloriesBurned: (totalCalories * 10).round() / 10.0,
      totalDistanceKm: totalDistance != null ? (totalDistance * 10).round() / 10.0 : null,
      totalSteps: totalSteps,
      compositeTitle: compositeTitle,
      notes: raw,
    );
  }

  /// Splits text into compound activity segments only when distinct activities
  /// or multi-modal workout metrics are explicitly present.
  static List<String> _splitCompoundActivities(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return [];

    // 1. Explicit sequential words always split
    final sequentialRegex = RegExp(
      r'\s+(?:then|followed\s+by|after\s+that)\s+|;\s*',
      caseSensitive: false,
    );
    if (sequentialRegex.hasMatch(raw)) {
      return raw.split(sequentialRegex).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }

    // 2. Conjunctions: " and ", " + ", " & ", or ", "
    final conjunctionRegex = RegExp(r'\s+(?:and|\+|&)\s+|(?<!\d),\s*', caseSensitive: false);
    final candidateParts = raw.split(conjunctionRegex).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (candidateParts.length <= 1) return [raw];

    // Check if at least two parts have distinct exercise types or both have explicit metrics
    bool isLegitSplit = false;
    for (int i = 0; i < candidateParts.length - 1; i++) {
      final typeA = _detectType(candidateParts[i]);
      final typeB = _detectType(candidateParts[i + 1]);
      final hasMetricsA = _hasMetrics(candidateParts[i]);
      final hasMetricsB = _hasMetrics(candidateParts[i + 1]);

      // If types are different and at least one is a known exercise or has metrics
      if (typeA != typeB && (hasMetricsA || hasMetricsB || (typeA != ExerciseType.custom && typeB != ExerciseType.custom))) {
        isLegitSplit = true;
        break;
      }
      // If same type but both have explicit independent duration/distance numbers
      if (hasMetricsA && hasMetricsB) {
        isLegitSplit = true;
        break;
      }
    }

    return isLegitSplit ? candidateParts : [raw];
  }

  static ExerciseType _detectType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('run') ||
        lower.contains('ran') ||
        lower.contains('jog') ||
        lower.contains('sprint') ||
        lower.contains('marathon')) {
      return ExerciseType.running;
    } else if (lower.contains('rope') ||
        lower.contains('skip') ||
        lower.contains('skipping') ||
        lower.contains('skipped')) {
      return ExerciseType.jumpRope;
    } else if (lower.contains('gym') ||
        lower.contains('lift') ||
        lower.contains('weight') ||
        lower.contains('bench') ||
        lower.contains('chest') ||
        lower.contains('squat') ||
        lower.contains('push') ||
        lower.contains('pull') ||
        lower.contains('leg') ||
        lower.contains('shoulder') ||
        lower.contains('bicep') ||
        lower.contains('tricep') ||
        lower.contains('dumbbell') ||
        lower.contains('barbell') ||
        lower.contains('deadlift') ||
        lower.contains('strength')) {
      return ExerciseType.gym;
    } else if (lower.contains('cycle') ||
        lower.contains('cycling') ||
        lower.contains('cycled') ||
        lower.contains('bike') ||
        lower.contains('biking') ||
        lower.contains('biked') ||
        lower.contains('spin')) {
      return ExerciseType.cycling;
    } else if (lower.contains('walk') ||
        lower.contains('walked') ||
        lower.contains('stroll') ||
        lower.contains('hike') ||
        lower.contains('treadmill')) {
      return ExerciseType.walking;
    }
    return ExerciseType.custom;
  }

  static bool _hasMetrics(String text) {
    final lower = text.toLowerCase();
    final hasDuration = RegExp(r'\d+\s*(?:hr|hrs|hour|hours|m|min|mins|minute|minutes)\b').hasMatch(lower);
    final hasDistance = RegExp(r'\d+(?:\.\d+)?\s*(?:km|k|kilometer|kilometers|mi|mile|miles)\b').hasMatch(lower);
    return hasDuration || hasDistance;
  }

  /// Parses an isolated single activity phrase (e.g. "5km run" or "20 min jump rope").
  static ExerciseParseResult _parseSingleSegment(
    String text, {
    double? userWeightKg,
    double? userHeightCm,
  }) {
    final lower = text.toLowerCase().trim();

    // 1. Detect Exercise Type
    ExerciseType type = ExerciseType.walking;
    if (lower.contains('run') ||
        lower.contains('ran') ||
        lower.contains('jog') ||
        lower.contains('sprint') ||
        lower.contains('marathon')) {
      type = ExerciseType.running;
    } else if (lower.contains('rope') ||
        lower.contains('skip') ||
        lower.contains('skipping') ||
        lower.contains('skipped')) {
      type = ExerciseType.jumpRope;
    } else if (lower.contains('gym') ||
        lower.contains('lift') ||
        lower.contains('weight') ||
        lower.contains('bench') ||
        lower.contains('chest') ||
        lower.contains('squat') ||
        lower.contains('push') ||
        lower.contains('pull') ||
        lower.contains('leg') ||
        lower.contains('shoulder') ||
        lower.contains('bicep') ||
        lower.contains('tricep') ||
        lower.contains('dumbbell') ||
        lower.contains('barbell') ||
        lower.contains('deadlift') ||
        lower.contains('strength')) {
      type = ExerciseType.gym;
    } else if (lower.contains('cycle') ||
        lower.contains('cycling') ||
        lower.contains('cycled') ||
        lower.contains('bike') ||
        lower.contains('biking') ||
        lower.contains('biked') ||
        lower.contains('spin')) {
      type = ExerciseType.cycling;
    } else if (lower.contains('walk') ||
        lower.contains('walked') ||
        lower.contains('stroll') ||
        lower.contains('hike') ||
        lower.contains('treadmill')) {
      type = ExerciseType.walking;
    } else {
      type = ExerciseType.custom;
    }

    // 2. Detect Distance (e.g. 5km, 3.2 miles)
    double? distanceKm;
    if (type == ExerciseType.running ||
        type == ExerciseType.walking ||
        type == ExerciseType.cycling ||
        type == ExerciseType.custom) {
      final kmMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:km|k|kilometer|kilometers)\b').firstMatch(lower);
      if (kmMatch != null) {
        distanceKm = double.tryParse(kmMatch.group(1) ?? '');
      } else {
        final miMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:mi|mile|miles)\b').firstMatch(lower);
        if (miMatch != null) {
          final mi = double.tryParse(miMatch.group(1) ?? '');
          if (mi != null) distanceKm = (mi * 1.60934 * 10).round() / 10.0;
        }
      }
    }

    // 3. Detect Duration (minutes or hours)
    int? explicitDuration;
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hr|hrs|hour|hours)\b').firstMatch(lower);
    if (hourMatch != null) {
      final hours = double.tryParse(hourMatch.group(1) ?? '1') ?? 1.0;
      explicitDuration = (hours * 60).round();
    } else {
      final minMatch = RegExp(r'(\d+)\s*(?:m|min|mins|minute|minutes)\b').firstMatch(lower);
      if (minMatch != null) {
        explicitDuration = int.tryParse(minMatch.group(1) ?? '30');
      }
    }

    // Kinematic pace inference when distance is supplied without explicit duration
    int durationMinutes = explicitDuration ?? 30;
    if (explicitDuration == null && distanceKm != null && distanceKm > 0) {
      if (type == ExerciseType.running) {
        // Average recreational running pace ~6:00 min/km (10 km/h)
        durationMinutes = (distanceKm * 6.0).round().clamp(5, 300);
      } else if (type == ExerciseType.walking) {
        // Average brisk walking pace ~12:00 min/km (5 km/h)
        durationMinutes = (distanceKm * 12.0).round().clamp(5, 300);
      } else if (type == ExerciseType.cycling) {
        // Average road cycling pace ~3:00 min/km (20 km/h)
        durationMinutes = (distanceKm * 3.0).round().clamp(5, 300);
      }
    }

    // 4. Detect Intensity
    ExerciseIntensity intensity = ExerciseIntensity.moderate;
    if (lower.contains('brisk') ||
        lower.contains('fast') ||
        lower.contains('intense') ||
        lower.contains('heavy') ||
        lower.contains('vigorous') ||
        lower.contains('hard')) {
      intensity = ExerciseIntensity.vigorous;
    } else if (lower.contains('max') || lower.contains('extreme') || lower.contains('hiit')) {
      intensity = ExerciseIntensity.extreme;
    } else if (lower.contains('light') ||
        lower.contains('easy') ||
        lower.contains('gentle') ||
        lower.contains('slow') ||
        lower.contains('casual')) {
      intensity = ExerciseIntensity.light;
    }

    // 5. Detect Gym Category Split
    String? gymCategory;
    if (type == ExerciseType.gym) {
      if (lower.contains('push') || lower.contains('chest') || lower.contains('tricep')) {
        gymCategory = 'Push';
      } else if (lower.contains('pull') || lower.contains('back') || lower.contains('bicep')) {
        gymCategory = 'Pull';
      } else if (lower.contains('leg') || lower.contains('squat') || lower.contains('quad')) {
        gymCategory = 'Legs';
      } else if (lower.contains('upper')) {
        gymCategory = 'Upper Body';
      } else if (lower.contains('lower')) {
        gymCategory = 'Lower Body';
      } else if (lower.contains('core') || lower.contains('ab')) {
        gymCategory = 'Core & Abs';
      } else if (lower.contains('hiit') || lower.contains('circuit')) {
        gymCategory = 'Circuit / HIIT';
      } else {
        gymCategory = 'Full Body';
      }
    }

    // 6. Generate Title
    String title = type.displayName;
    if (type == ExerciseType.gym && gymCategory != null) {
      title = '$gymCategory Workout';
    } else if (type == ExerciseType.running && distanceKm != null) {
      title = '${distanceKm.toStringAsFixed(1)}km Run';
    } else if (type == ExerciseType.walking && distanceKm != null) {
      title = '${distanceKm.toStringAsFixed(1)}km Walk';
    } else if (type == ExerciseType.jumpRope) {
      title = explicitDuration != null ? '${explicitDuration}m Jump Rope' : 'Jump Rope Session';
    } else if (type == ExerciseType.cycling && distanceKm != null) {
      title = '${distanceKm.toStringAsFixed(1)}km Cycling';
    }

    int? steps;
    if (distanceKm != null && distanceKm > 0 && (type == ExerciseType.walking || type == ExerciseType.running)) {
      steps = stepsFromKm(distanceKm, userHeightCm: userHeightCm);
    } else if (type == ExerciseType.jumpRope) {
      steps = durationMinutes * 115;
    }

    // 7. Calculate calibrated active calorie burn
    final effectiveWeight = (userWeightKg != null && userWeightKg > 20) ? userWeightKg : 70.0;
    final calories = calculateBurn(
      type: type,
      durationMinutes: durationMinutes,
      userWeightKg: effectiveWeight,
      intensity: intensity,
      distanceKm: distanceKm,
      userHeightCm: userHeightCm,
    );

    return ExerciseParseResult(
      type: type,
      title: title,
      durationMinutes: durationMinutes,
      distanceKm: distanceKm,
      steps: steps,
      intensity: intensity,
      gymCategory: gymCategory,
      caloriesBurned: calories,
      notes: text.trim(),
    );
  }
}

/// Result of parsing an individual exercise segment from natural language.
class ExerciseParseResult {
  const ExerciseParseResult({
    required this.type,
    required this.title,
    required this.durationMinutes,
    this.distanceKm,
    this.steps,
    this.intensity = ExerciseIntensity.moderate,
    this.gymCategory,
    this.caloriesBurned,
    this.notes = '',
  });

  final ExerciseType type;
  final String title;
  final int durationMinutes;
  final double? distanceKm;
  final int? steps;
  final ExerciseIntensity intensity;
  final String? gymCategory;
  final double? caloriesBurned;
  final String notes;
}

/// Compound result containing multiple distinct exercise segments
/// (e.g., "5km run and 20 min jump rope" -> 2 segments).
class CompoundExerciseParseResult {
  const CompoundExerciseParseResult({
    required this.segments,
    required this.totalDurationMinutes,
    required this.totalCaloriesBurned,
    this.totalDistanceKm,
    this.totalSteps,
    this.compositeTitle = '',
    this.notes = '',
  });

  final List<ExerciseParseResult> segments;
  final int totalDurationMinutes;
  final double totalCaloriesBurned;
  final double? totalDistanceKm;
  final int? totalSteps;
  final String compositeTitle;
  final String notes;

  bool get isCompound => segments.length > 1;

  ExerciseParseResult get primarySegment => segments.isNotEmpty
      ? segments.first
      : const ExerciseParseResult(
          type: ExerciseType.custom,
          title: 'Activity',
          durationMinutes: 30,
        );
}
