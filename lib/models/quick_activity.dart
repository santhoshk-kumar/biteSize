import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../services/date_utils.dart';
import 'exercise_entry.dart';

/// Quick-tap preset workout or activity for instantaneous 1-tap logging.
@immutable
class QuickActivityPreset {
  const QuickActivityPreset({
    required this.id,
    required this.title,
    required this.type,
    required this.durationMinutes,
    this.distanceKm,
    this.steps,
    this.intensity = ExerciseIntensity.moderate,
    this.gymCategory,
    this.isCustom = false,
  });

  final String id;
  final String title;
  final ExerciseType type;
  final int durationMinutes;
  final double? distanceKm;
  final int? steps;
  final ExerciseIntensity intensity;
  final String? gymCategory;
  final bool isCustom;

  /// Calculates dynamic burn calibrated scientifically to the user's weight.
  double calculateBurn(double userWeightKg, {double? userHeightCm}) {
    return ExerciseCalculator.calculateBurn(
      type: type,
      durationMinutes: durationMinutes,
      userWeightKg: userWeightKg,
      intensity: intensity,
      distanceKm: distanceKm,
      userHeightCm: userHeightCm,
    );
  }

  /// Converts this preset into a logged [ExerciseEntry].
  ExerciseEntry toEntry({
    required String dateKey,
    required double userWeightKg,
    double? userHeightCm,
    DateTime? loggedAt,
  }) {
    final burn = calculateBurn(userWeightKg, userHeightCm: userHeightCm);
    final calculatedSteps = steps ??
        (distanceKm != null
            ? ExerciseCalculator.stepsFromKm(distanceKm!, userHeightCm: userHeightCm)
            : null);

    return ExerciseEntry(
      id: ZenDateUtils.newId('ex'),
      dateKey: dateKey,
      loggedAt: loggedAt ?? DateTime.now(),
      type: type,
      title: title,
      durationMinutes: durationMinutes,
      caloriesBurned: burn,
      distanceKm: distanceKm,
      steps: calculatedSteps,
      intensity: intensity,
      gymCategory: gymCategory,
    );
  }

  /// Creates a quick preset from an existing logged workout.
  factory QuickActivityPreset.fromEntry(ExerciseEntry entry) {
    return QuickActivityPreset(
      id: 'qa_custom_${DateTime.now().millisecondsSinceEpoch}',
      title: entry.title,
      type: entry.type,
      durationMinutes: entry.durationMinutes,
      distanceKm: entry.distanceKm,
      steps: entry.steps,
      intensity: entry.intensity,
      gymCategory: entry.gymCategory,
      isCustom: true,
    );
  }

  QuickActivityPreset copyWith({
    String? id,
    String? title,
    ExerciseType? type,
    int? durationMinutes,
    double? distanceKm,
    int? steps,
    ExerciseIntensity? intensity,
    String? gymCategory,
    bool? isCustom,
  }) {
    return QuickActivityPreset(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      steps: steps ?? this.steps,
      intensity: intensity ?? this.intensity,
      gymCategory: gymCategory ?? this.gymCategory,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'durationMinutes': durationMinutes,
        'distanceKm': distanceKm,
        'steps': steps,
        'intensity': intensity.name,
        'gymCategory': gymCategory,
        'isCustom': isCustom,
      };

  factory QuickActivityPreset.fromJson(Map<String, dynamic> json) {
    final typeName = (json['type'] ?? 'walking').toString();
    final parsedType = ExerciseType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => ExerciseType.walking,
    );
    final intensityName = (json['intensity'] ?? 'moderate').toString();
    final parsedIntensity = ExerciseIntensity.values.firstWhere(
      (e) => e.name == intensityName,
      orElse: () => ExerciseIntensity.moderate,
    );

    return QuickActivityPreset(
      id: json['id'] as String? ?? 'qa_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Workout',
      type: parsedType,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      steps: (json['steps'] as num?)?.toInt(),
      intensity: parsedIntensity,
      gymCategory: json['gymCategory']?.toString(),
      isCustom: json['isCustom'] as bool? ?? true,
    );
  }

  static String encodeList(List<QuickActivityPreset> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  static List<QuickActivityPreset> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(QuickActivityPreset.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Popular default presets calibrated scientifically with MET standards.
  static const List<QuickActivityPreset> defaultPresets = [
    QuickActivityPreset(
      id: 'qa_walk_30m',
      title: '30m Walk',
      type: ExerciseType.walking,
      durationMinutes: 30,
      distanceKm: 2.5,
    ),
    QuickActivityPreset(
      id: 'qa_run_5k',
      title: '5km Run',
      type: ExerciseType.running,
      durationMinutes: 30,
      distanceKm: 5.0,
      intensity: ExerciseIntensity.vigorous,
    ),
    QuickActivityPreset(
      id: 'qa_cycling_30m',
      title: '30m Cycling',
      type: ExerciseType.cycling,
      durationMinutes: 30,
      distanceKm: 10.0,
    ),
    QuickActivityPreset(
      id: 'qa_gym_workout',
      title: '45m Gym Workout',
      type: ExerciseType.gym,
      durationMinutes: 45,
      gymCategory: 'Full Body',
    ),
    QuickActivityPreset(
      id: 'qa_jump_rope_15m',
      title: '15m Jump Rope',
      type: ExerciseType.jumpRope,
      durationMinutes: 15,
      intensity: ExerciseIntensity.vigorous,
    ),
  ];
}
