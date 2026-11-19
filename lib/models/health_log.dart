/// A single hydration log entry.
class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.dateKey,
    required this.loggedAt,
    required this.amountMl,
  });

  final String id;
  final String dateKey;
  final DateTime loggedAt;
  final int amountMl;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateKey': dateKey,
      'loggedAt': loggedAt.millisecondsSinceEpoch,
      'amountMl': amountMl,
    };
  }

  factory WaterEntry.fromMap(Map<String, dynamic> map) {
    return WaterEntry(
      id: (map['id'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? map['date_key'] ?? '').toString(),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['loggedAt'] ?? map['logged_at'] as num?)?.toInt() ?? 0,
      ),
      amountMl: ((map['amountMl'] ?? map['amount_ml']) as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'date_key': dateKey,
      'logged_at': loggedAt.millisecondsSinceEpoch,
      'amount_ml': amountMl,
    };
  }

  factory WaterEntry.fromDbMap(Map<String, dynamic> map) {
    return WaterEntry(
      id: (map['id'] ?? '').toString(),
      dateKey: (map['date_key'] ?? '').toString(),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['logged_at'] as num?)?.toInt() ?? 0,
      ),
      amountMl: (map['amount_ml'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A body weight measurement entry stored in kilograms.
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.dateKey,
    required this.loggedAt,
    required this.weightKg,
    this.note = '',
  });

  final String id;
  final String dateKey;
  final DateTime loggedAt;
  final double weightKg;
  final String note;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateKey': dateKey,
      'loggedAt': loggedAt.millisecondsSinceEpoch,
      'weightKg': weightKg,
      'note': note,
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: (map['id'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? map['date_key'] ?? '').toString(),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['loggedAt'] ?? map['logged_at'] as num?)?.toInt() ?? 0,
      ),
      weightKg: ((map['weightKg'] ?? map['weight_kg']) as num?)?.toDouble() ?? 0,
      note: (map['note'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'date_key': dateKey,
      'logged_at': loggedAt.millisecondsSinceEpoch,
      'weight_kg': weightKg,
      'note': note,
    };
  }

  factory WeightEntry.fromDbMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: (map['id'] ?? '').toString(),
      dateKey: (map['date_key'] ?? '').toString(),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['logged_at'] as num?)?.toInt() ?? 0,
      ),
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 0,
      note: (map['note'] ?? '').toString(),
    );
  }
}

/// User's daily nutritional and wellness targets.
class DailyGoals {
  const DailyGoals({
    this.calorieTarget = 2000,
    this.proteinTargetG = 130,
    this.carbsTargetG = 220,
    this.fatTargetG = 67,
    this.fiberTargetG = 28,
    this.waterTargetMl = 2500,
    this.targetWeightKg = 68.0,
  });

  final int calorieTarget;
  final int proteinTargetG;
  final int carbsTargetG;
  final int fatTargetG;
  final int fiberTargetG;
  final int waterTargetMl;
  final double targetWeightKg;

  /// Generates balanced default macro targets (26% protein / 44% carbs / 30% fat)
  /// from a calorie target.
  static DailyGoals balancedForCalories(
    int calories, {
    int waterTargetMl = 2500,
    double targetWeightKg = 68.0,
  }) {
    final safeCal = calories.clamp(1000, 6000);
    return DailyGoals(
      calorieTarget: safeCal,
      proteinTargetG: ((safeCal * 0.26) / 4).round(),
      carbsTargetG: ((safeCal * 0.44) / 4).round(),
      fatTargetG: ((safeCal * 0.30) / 9).round(),
      fiberTargetG: ((safeCal / 1000) * 14).round().clamp(18, 55),
      waterTargetMl: waterTargetMl,
      targetWeightKg: targetWeightKg,
    );
  }

  DailyGoals copyWith({
    int? calorieTarget,
    int? proteinTargetG,
    int? carbsTargetG,
    int? fatTargetG,
    int? fiberTargetG,
    int? waterTargetMl,
    double? targetWeightKg,
  }) {
    return DailyGoals(
      calorieTarget: calorieTarget ?? this.calorieTarget,
      proteinTargetG: proteinTargetG ?? this.proteinTargetG,
      carbsTargetG: carbsTargetG ?? this.carbsTargetG,
      fatTargetG: fatTargetG ?? this.fatTargetG,
      fiberTargetG: fiberTargetG ?? this.fiberTargetG,
      waterTargetMl: waterTargetMl ?? this.waterTargetMl,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    );
  }
}

/// Lightweight per-day calorie summary for week strips and trend charts.
class DailyCalorieSummary {
  const DailyCalorieSummary({
    required this.dateKey,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sugarG,
    required this.sodiumMg,
    required this.waterMl,
    required this.mealCount,
  });

  final String dateKey;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
  final int waterMl;
  final int mealCount;
}
