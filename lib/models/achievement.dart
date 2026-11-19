import 'package:flutter/material.dart';

/// Categories for organizing user achievements.
enum AchievementCategory {
  streaks,
  nutrition,
  fasting,
  hydration,
  body,
  activity,
  mastery,
}

/// Prestige tiers representing milestone difficulty.
enum AchievementTier {
  bronze,
  silver,
  gold,
  emerald,
}

/// Comprehensive gamified achievement and trophy model for BiteSize.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.tier,
    required this.icon,
    required this.accentColor,
    required this.isUnlocked,
    required this.currentValue,
    required this.targetValue,
    this.unit = '',
    this.unlockedDate,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final IconData icon;
  final Color accentColor;
  final bool isUnlocked;
  final double currentValue;
  final double targetValue;
  final String unit;
  final String? unlockedDate;

  /// Progress fraction clamped between 0.0 and 1.0.
  double get progress {
    if (targetValue <= 0) return isUnlocked ? 1.0 : 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  /// Percentage formatted string (e.g. "100%" or "42%").
  String get progressPercentage => '${(progress * 100).round()}%';

  /// Human-readable progress fraction (e.g. "3 / 7 days" or "1 / 1").
  String get progressFraction {
    final curFormatted = currentValue % 1 == 0 ? currentValue.toInt().toString() : currentValue.toStringAsFixed(1);
    final tarFormatted = targetValue % 1 == 0 ? targetValue.toInt().toString() : targetValue.toStringAsFixed(1);
    final unitSuffix = unit.isNotEmpty ? ' $unit' : '';
    return '$curFormatted / $tarFormatted$unitSuffix';
  }

  /// Tier label for display in badges and headers.
  String get tierLabel {
    switch (tier) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.emerald:
        return 'Emerald';
    }
  }

  /// Color representing the tier prestige level.
  Color get tierColor {
    switch (tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFFC0C0C0);
      case AchievementTier.gold:
        return const Color(0xFFFFD700);
      case AchievementTier.emerald:
        return const Color(0xFF10B981);
    }
  }

  /// Human-readable category title.
  String get categoryLabel {
    switch (category) {
      case AchievementCategory.streaks:
        return 'Habits & Streaks';
      case AchievementCategory.nutrition:
        return 'Macro Mastery';
      case AchievementCategory.fasting:
        return 'Intermittent Fasting';
      case AchievementCategory.hydration:
        return 'Hydration';
      case AchievementCategory.body:
        return 'Body Transformation';
      case AchievementCategory.activity:
        return 'Movement & Fitness';
      case AchievementCategory.mastery:
        return 'App Exploration';
    }
  }

  /// Category icon for tabs and headers.
  IconData get categoryIcon {
    switch (category) {
      case AchievementCategory.streaks:
        return Icons.local_fire_department_rounded;
      case AchievementCategory.nutrition:
        return Icons.restaurant_menu_rounded;
      case AchievementCategory.fasting:
        return Icons.timer_outlined;
      case AchievementCategory.hydration:
        return Icons.water_drop_rounded;
      case AchievementCategory.body:
        return Icons.monitor_weight_outlined;
      case AchievementCategory.activity:
        return Icons.directions_run_rounded;
      case AchievementCategory.mastery:
        return Icons.auto_awesome_rounded;
    }
  }
}
