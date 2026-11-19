import 'package:flutter/material.dart';

import 'achievement.dart';

/// Achievement or habit milestone badge.
class HabitBadge {
  const HabitBadge({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isUnlocked,
    this.currentStreak = 0,
    this.targetStreak = 3,
    this.achievement,
  });

  factory HabitBadge.fromAchievement(Achievement a) {
    return HabitBadge(
      id: a.id,
      title: a.title,
      subtitle: a.subtitle,
      icon: a.icon,
      accentColor: a.accentColor,
      isUnlocked: a.isUnlocked,
      currentStreak: a.currentValue.toInt(),
      targetStreak: a.targetValue.toInt(),
      achievement: a,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isUnlocked;
  final int currentStreak;
  final int targetStreak;
  final Achievement? achievement;

  double get progress => targetStreak > 0 ? (currentStreak / targetStreak).clamp(0.0, 1.0) : 0.0;
}
