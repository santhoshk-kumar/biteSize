import 'package:flutter/material.dart';

/// User configuration for daily meal reminders, fasting alerts, and calorie budget alerts.
@immutable
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    // Meals
    this.breakfastReminder = true,
    this.breakfastHour = 8,
    this.breakfastMinute = 30,
    this.lunchReminder = true,
    this.lunchHour = 13,
    this.lunchMinute = 0,
    this.dinnerReminder = true,
    this.dinnerHour = 19,
    this.dinnerMinute = 30,
    // Fasting
    this.fastingTargetReachedAlert = true,
    this.fastingStageTransitionAlert = true,
    this.fastingWindowClosingAlert = true,
    this.fastingOngoingNotification = true,
    // Hydration
    this.hydrationReminder = true,
    this.hydrationIntervalHours = 2,
    // Budget & Debrief
    this.underCalorieAlert = true,
    this.overCalorieAlert = true,
    this.streakProtection = true,
    this.weekendBankingAlert = true,
    this.eveningDebriefReminder = true,
    this.eveningDebriefHour = 20,
    this.eveningDebriefMinute = 30,
    // Activity & Movement
    this.activityReminder = true,
    this.activityReminderHour = 17,
    this.activityReminderMinute = 30,
  });

  /// Master notification switch
  final bool enabled;

  // Meal Reminders
  final bool breakfastReminder;
  final int breakfastHour;
  final int breakfastMinute;

  final bool lunchReminder;
  final int lunchHour;
  final int lunchMinute;

  final bool dinnerReminder;
  final int dinnerHour;
  final int dinnerMinute;

  // Intermittent Fasting Alerts
  final bool fastingTargetReachedAlert;
  final bool fastingStageTransitionAlert;
  final bool fastingWindowClosingAlert;
  final bool fastingOngoingNotification;

  // Hydration Alerts
  final bool hydrationReminder;
  final int hydrationIntervalHours;

  // Nutrition & Pacing Alerts
  final bool underCalorieAlert;
  final bool overCalorieAlert;
  final bool streakProtection;
  final bool weekendBankingAlert;
  final bool eveningDebriefReminder;
  final int eveningDebriefHour;
  final int eveningDebriefMinute;

  // Activity & Movement Alerts
  final bool activityReminder;
  final int activityReminderHour;
  final int activityReminderMinute;

  TimeOfDay get breakfastTime =>
      TimeOfDay(hour: breakfastHour, minute: breakfastMinute);
  TimeOfDay get lunchTime => TimeOfDay(hour: lunchHour, minute: lunchMinute);
  TimeOfDay get dinnerTime => TimeOfDay(hour: dinnerHour, minute: dinnerMinute);
  TimeOfDay get eveningDebriefTime =>
      TimeOfDay(hour: eveningDebriefHour, minute: eveningDebriefMinute);
  TimeOfDay get activityReminderTime =>
      TimeOfDay(hour: activityReminderHour, minute: activityReminderMinute);

  NotificationSettings copyWith({
    bool? enabled,
    bool? breakfastReminder,
    int? breakfastHour,
    int? breakfastMinute,
    bool? lunchReminder,
    int? lunchHour,
    int? lunchMinute,
    bool? dinnerReminder,
    int? dinnerHour,
    int? dinnerMinute,
    bool? fastingTargetReachedAlert,
    bool? fastingStageTransitionAlert,
    bool? fastingWindowClosingAlert,
    bool? fastingOngoingNotification,
    bool? hydrationReminder,
    int? hydrationIntervalHours,
    bool? underCalorieAlert,
    bool? overCalorieAlert,
    bool? streakProtection,
    bool? weekendBankingAlert,
    bool? eveningDebriefReminder,
    int? eveningDebriefHour,
    int? eveningDebriefMinute,
    bool? activityReminder,
    int? activityReminderHour,
    int? activityReminderMinute,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      breakfastReminder: breakfastReminder ?? this.breakfastReminder,
      breakfastHour: breakfastHour ?? this.breakfastHour,
      breakfastMinute: breakfastMinute ?? this.breakfastMinute,
      lunchReminder: lunchReminder ?? this.lunchReminder,
      lunchHour: lunchHour ?? this.lunchHour,
      lunchMinute: lunchMinute ?? this.lunchMinute,
      dinnerReminder: dinnerReminder ?? this.dinnerReminder,
      dinnerHour: dinnerHour ?? this.dinnerHour,
      dinnerMinute: dinnerMinute ?? this.dinnerMinute,
      fastingTargetReachedAlert:
          fastingTargetReachedAlert ?? this.fastingTargetReachedAlert,
      fastingStageTransitionAlert:
          fastingStageTransitionAlert ?? this.fastingStageTransitionAlert,
      fastingWindowClosingAlert:
          fastingWindowClosingAlert ?? this.fastingWindowClosingAlert,
      fastingOngoingNotification:
          fastingOngoingNotification ?? this.fastingOngoingNotification,
      hydrationReminder: hydrationReminder ?? this.hydrationReminder,
      hydrationIntervalHours:
          hydrationIntervalHours ?? this.hydrationIntervalHours,
      underCalorieAlert: underCalorieAlert ?? this.underCalorieAlert,
      overCalorieAlert: overCalorieAlert ?? this.overCalorieAlert,
      streakProtection: streakProtection ?? this.streakProtection,
      weekendBankingAlert: weekendBankingAlert ?? this.weekendBankingAlert,
      eveningDebriefReminder:
          eveningDebriefReminder ?? this.eveningDebriefReminder,
      eveningDebriefHour: eveningDebriefHour ?? this.eveningDebriefHour,
      eveningDebriefMinute:
          eveningDebriefMinute ?? this.eveningDebriefMinute,
      activityReminder: activityReminder ?? this.activityReminder,
      activityReminderHour: activityReminderHour ?? this.activityReminderHour,
      activityReminderMinute:
          activityReminderMinute ?? this.activityReminderMinute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'breakfastReminder': breakfastReminder,
      'breakfastHour': breakfastHour,
      'breakfastMinute': breakfastMinute,
      'lunchReminder': lunchReminder,
      'lunchHour': lunchHour,
      'lunchMinute': lunchMinute,
      'dinnerReminder': dinnerReminder,
      'dinnerHour': dinnerHour,
      'dinnerMinute': dinnerMinute,
      'fastingTargetReachedAlert': fastingTargetReachedAlert,
      'fastingStageTransitionAlert': fastingStageTransitionAlert,
      'fastingWindowClosingAlert': fastingWindowClosingAlert,
      'fastingOngoingNotification': fastingOngoingNotification,
      'hydrationReminder': hydrationReminder,
      'hydrationIntervalHours': hydrationIntervalHours,
      'underCalorieAlert': underCalorieAlert,
      'overCalorieAlert': overCalorieAlert,
      'streakProtection': streakProtection,
      'weekendBankingAlert': weekendBankingAlert,
      'eveningDebriefReminder': eveningDebriefReminder,
      'eveningDebriefHour': eveningDebriefHour,
      'eveningDebriefMinute': eveningDebriefMinute,
      'activityReminder': activityReminder,
      'activityReminderHour': activityReminderHour,
      'activityReminderMinute': activityReminderMinute,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationSettings();
    return NotificationSettings(
      enabled: map['enabled'] as bool? ?? true,
      breakfastReminder: map['breakfastReminder'] as bool? ?? true,
      breakfastHour: (map['breakfastHour'] as num?)?.toInt() ?? 8,
      breakfastMinute: (map['breakfastMinute'] as num?)?.toInt() ?? 30,
      lunchReminder: map['lunchReminder'] as bool? ?? true,
      lunchHour: (map['lunchHour'] as num?)?.toInt() ?? 13,
      lunchMinute: (map['lunchMinute'] as num?)?.toInt() ?? 0,
      dinnerReminder: map['dinnerReminder'] as bool? ?? true,
      dinnerHour: (map['dinnerHour'] as num?)?.toInt() ?? 19,
      dinnerMinute: (map['dinnerMinute'] as num?)?.toInt() ?? 30,
      fastingTargetReachedAlert:
          map['fastingTargetReachedAlert'] as bool? ?? true,
      fastingStageTransitionAlert:
          map['fastingStageTransitionAlert'] as bool? ?? true,
      fastingWindowClosingAlert:
          map['fastingWindowClosingAlert'] as bool? ?? true,
      fastingOngoingNotification:
          map['fastingOngoingNotification'] as bool? ?? true,
      hydrationReminder: map['hydrationReminder'] as bool? ?? true,
      hydrationIntervalHours:
          (map['hydrationIntervalHours'] as num?)?.toInt() ?? 2,
      underCalorieAlert: map['underCalorieAlert'] as bool? ?? true,
      overCalorieAlert: map['overCalorieAlert'] as bool? ?? true,
      streakProtection: map['streakProtection'] as bool? ?? true,
      weekendBankingAlert: map['weekendBankingAlert'] as bool? ?? true,
      eveningDebriefReminder: map['eveningDebriefReminder'] as bool? ?? true,
      eveningDebriefHour: (map['eveningDebriefHour'] as num?)?.toInt() ?? 20,
      eveningDebriefMinute: (map['eveningDebriefMinute'] as num?)?.toInt() ?? 30,
      activityReminder: map['activityReminder'] as bool? ?? true,
      activityReminderHour: (map['activityReminderHour'] as num?)?.toInt() ?? 17,
      activityReminderMinute: (map['activityReminderMinute'] as num?)?.toInt() ?? 30,
    );
  }
}
