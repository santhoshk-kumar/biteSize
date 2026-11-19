/// Flexible Dieting & Weekend Calorie Banking configuration.
/// Allows saving calories on weekdays (Mon-Fri) to enjoy a larger calorie budget on weekends (Sat-Sun)
/// while maintaining the exact same weekly caloric deficit and fat loss pace.
class CalorieBankSettings {
  const CalorieBankSettings({
    this.enabled = false,
    this.bankDailyKcal = 150, // 50 to 300 kcal saved per weekday
  });

  final bool enabled;
  final int bankDailyKcal;

  /// Total calories saved Monday through Friday (5 days).
  int get totalBankedKcal => enabled ? (bankDailyKcal * 5) : 0;

  /// Extra calories added to Saturday and Sunday daily budget (totalBanked / 2).
  int get weekendBonusPerDay => enabled ? (totalBankedKcal ~/ 2) : 0;

  /// Computes the adjusted daily target for a given date.
  int adjustedTarget({
    required int baseTarget,
    required DateTime date,
  }) {
    if (!enabled || baseTarget <= 0) return baseTarget;

    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    if (isWeekend) {
      return baseTarget + weekendBonusPerDay;
    } else {
      final safeTarget = baseTarget - bankDailyKcal;
      return safeTarget >= 1200 ? safeTarget : 1200;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'bankDailyKcal': bankDailyKcal,
    };
  }

  factory CalorieBankSettings.fromMap(Map<String, dynamic> map) {
    return CalorieBankSettings(
      enabled: (map['enabled'] as bool?) ?? false,
      bankDailyKcal: (map['bankDailyKcal'] as num?)?.toInt() ?? 150,
    );
  }

  CalorieBankSettings copyWith({
    bool? enabled,
    int? bankDailyKcal,
  }) {
    return CalorieBankSettings(
      enabled: enabled ?? this.enabled,
      bankDailyKcal: bankDailyKcal ?? this.bankDailyKcal,
    );
  }
}

