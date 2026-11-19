import 'package:flutter/material.dart';

/// Frequency options for recurring habit tracking.
enum HabitFrequency {
  daily,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case HabitFrequency.daily:
        return 'Daily';
      case HabitFrequency.weekly:
        return 'Weekly';
      case HabitFrequency.monthly:
        return 'Monthly';
    }
  }

  static HabitFrequency fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'weekly':
        return HabitFrequency.weekly;
      case 'monthly':
        return HabitFrequency.monthly;
      case 'daily':
      default:
        return HabitFrequency.daily;
    }
  }
}

/// Category grouping for habits.
enum HabitCategory {
  health,
  fitness,
  nutrition,
  mindset,
  custom;

  String get label {
    switch (this) {
      case HabitCategory.health:
        return 'Health & Body';
      case HabitCategory.fitness:
        return 'Fitness & Movement';
      case HabitCategory.nutrition:
        return 'Nutrition & Diet';
      case HabitCategory.mindset:
        return 'Mindset & Rest';
      case HabitCategory.custom:
        return 'Custom';
    }
  }

  Color get color {
    switch (this) {
      case HabitCategory.health:
        return const Color(0xFF00D2B4); // Cyan / Emerald
      case HabitCategory.fitness:
        return const Color(0xFFFF6B4A); // Coral / Orange
      case HabitCategory.nutrition:
        return const Color(0xFF4ADE80); // Fresh Green
      case HabitCategory.mindset:
        return const Color(0xFFA78BFA); // Violet / Purple
      case HabitCategory.custom:
        return const Color(0xFFFBBF24); // Amber / Gold
    }
  }

  static HabitCategory fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'health':
        return HabitCategory.health;
      case 'fitness':
        return HabitCategory.fitness;
      case 'nutrition':
        return HabitCategory.nutrition;
      case 'mindset':
        return HabitCategory.mindset;
      case 'custom':
      default:
        return HabitCategory.custom;
    }
  }
}

/// Scheduled time reminder for a habit.
class HabitReminder {
  const HabitReminder({
    required this.isEnabled,
    required this.hour,
    required this.minute,
  });

  final bool isEnabled;
  final int hour;
  final int minute;

  String get timeFormatted {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Map<String, dynamic> toMap() => {
        'isEnabled': isEnabled,
        'hour': hour,
        'minute': minute,
      };

  factory HabitReminder.fromMap(Map<String, dynamic> map) {
    return HabitReminder(
      isEnabled: map['isEnabled'] as bool? ?? false,
      hour: map['hour'] as int? ?? 8,
      minute: map['minute'] as int? ?? 0,
    );
  }
}

/// A recurring or custom habit tracked by the user.
class HabitItem {
  HabitItem({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '🔥',
    this.category = HabitCategory.custom,
    this.frequency = HabitFrequency.daily,
    this.targetDaysPerWeek = 7,
    this.targetDaysPerMonth = 20,
    this.reminder,
    DateTime? createdAt,
    this.isArchived = false,
    Set<String>? completedDates,
  })  : createdAt = createdAt ?? DateTime.now(),
        completedDates = completedDates ?? <String>{};

  final String id;
  final String title;
  final String description;
  final String emoji;
  final HabitCategory category;
  final HabitFrequency frequency;
  final int targetDaysPerWeek; // e.g. 3, 5, or 7 days
  final int targetDaysPerMonth; // e.g. 15 or 20 days
  final HabitReminder? reminder;
  final DateTime createdAt;
  final bool isArchived;
  final Set<String> completedDates; // Format: 'yyyy-MM-dd'

  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool isCompletedOn(DateTime date) {
    return completedDates.contains(dateKey(date));
  }

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  /// Calculates current consecutive completed streak days.
  int get currentStreak {
    if (completedDates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var checkDate = today;

    // If today is not completed yet, check if yesterday was completed to keep streak alive
    if (!isCompletedOn(today)) {
      checkDate = today.subtract(const Duration(days: 1));
      if (!isCompletedOn(checkDate)) return 0;
    }

    int streak = 0;
    while (isCompletedOn(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Calculates all-time highest completed streak.
  int get bestStreak {
    if (completedDates.isEmpty) return 0;

    final sortedDates = completedDates.map((k) {
      final parts = k.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      return DateTime(2000);
    }).toList()
      ..sort();

    int maxStreak = 1;
    int currStreak = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      if (diff == 1) {
        currStreak++;
        if (currStreak > maxStreak) maxStreak = currStreak;
      } else if (diff > 1) {
        currStreak = 1;
      }
    }
    return maxStreak;
  }

  /// Counts completions in the 7 days of the specified week.
  int completionsInWeek(DateTime date) {
    // Find Monday of this week
    final monday = date.subtract(Duration(days: date.weekday - 1));
    int count = 0;
    for (int i = 0; i < 7; i++) {
      if (isCompletedOn(monday.add(Duration(days: i)))) {
        count++;
      }
    }
    return count;
  }

  /// Counts completions in the specified calendar month.
  int completionsInMonth(DateTime date) {
    int count = 0;
    for (final key in completedDates) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y == date.year && m == date.month) {
          count++;
        }
      }
    }
    return count;
  }

  HabitItem copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    HabitCategory? category,
    HabitFrequency? frequency,
    int? targetDaysPerWeek,
    int? targetDaysPerMonth,
    HabitReminder? reminder,
    DateTime? createdAt,
    bool? isArchived,
    Set<String>? completedDates,
  }) {
    return HabitItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      targetDaysPerMonth: targetDaysPerMonth ?? this.targetDaysPerMonth,
      reminder: reminder ?? this.reminder,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      completedDates: completedDates ?? Set<String>.from(this.completedDates),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'category': category.name,
        'frequency': frequency.name,
        'targetDaysPerWeek': targetDaysPerWeek,
        'targetDaysPerMonth': targetDaysPerMonth,
        'reminder': reminder?.toMap(),
        'createdAt': createdAt.toIso8601String(),
        'isArchived': isArchived,
        'completedDates': completedDates.toList(),
      };

  factory HabitItem.fromMap(Map<String, dynamic> map) {
    return HabitItem(
      id: map['id'] as String? ?? 'habit_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Daily Habit',
      description: map['description'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '🔥',
      category: HabitCategory.fromString(map['category'] as String?),
      frequency: HabitFrequency.fromString(map['frequency'] as String?),
      targetDaysPerWeek: map['targetDaysPerWeek'] as int? ?? 7,
      targetDaysPerMonth: map['targetDaysPerMonth'] as int? ?? 20,
      reminder: map['reminder'] != null
          ? HabitReminder.fromMap(map['reminder'] as Map<String, dynamic>)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isArchived: map['isArchived'] as bool? ?? false,
      completedDates: (map['completedDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{},
    );
  }
}

/// A motivating, time-bound challenge that users can join to build strong habits.
class HabitChallenge {
  HabitChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.badgeEmoji,
    required this.durationDays,
    required this.category,
    this.isJoined = false,
    this.startDate,
    Set<String>? completedDates,
    this.rewardPoints = 500,
  }) : completedDates = completedDates ?? <String>{};

  final String id;
  final String title;
  final String description;
  final String badgeEmoji;
  final int durationDays;
  final HabitCategory category;
  final bool isJoined;
  final DateTime? startDate;
  final Set<String> completedDates;
  final int rewardPoints;

  int get daysCompleted => completedDates.length;

  double get progress => durationDays > 0 ? (daysCompleted / durationDays).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => daysCompleted >= durationDays;

  bool isCompletedOn(DateTime date) {
    return completedDates.contains(HabitItem.dateKey(date));
  }

  HabitChallenge copyWith({
    String? id,
    String? title,
    String? description,
    String? badgeEmoji,
    int? durationDays,
    HabitCategory? category,
    bool? isJoined,
    DateTime? startDate,
    Set<String>? completedDates,
    int? rewardPoints,
  }) {
    return HabitChallenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      badgeEmoji: badgeEmoji ?? this.badgeEmoji,
      durationDays: durationDays ?? this.durationDays,
      category: category ?? this.category,
      isJoined: isJoined ?? this.isJoined,
      startDate: startDate ?? this.startDate,
      completedDates: completedDates ?? Set<String>.from(this.completedDates),
      rewardPoints: rewardPoints ?? this.rewardPoints,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'badgeEmoji': badgeEmoji,
        'durationDays': durationDays,
        'category': category.name,
        'isJoined': isJoined,
        'startDate': startDate?.toIso8601String(),
        'completedDates': completedDates.toList(),
        'rewardPoints': rewardPoints,
      };

  factory HabitChallenge.fromMap(Map<String, dynamic> map) {
    return HabitChallenge(
      id: map['id'] as String? ?? 'challenge_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Challenge',
      description: map['description'] as String? ?? '',
      badgeEmoji: map['badgeEmoji'] as String? ?? '🏆',
      durationDays: map['durationDays'] as int? ?? 7,
      category: HabitCategory.fromString(map['category'] as String?),
      isJoined: map['isJoined'] as bool? ?? false,
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate'] as String)
          : null,
      completedDates: (map['completedDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{},
      rewardPoints: map['rewardPoints'] as int? ?? 500,
    );
  }
}
