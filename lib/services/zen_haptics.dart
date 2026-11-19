import 'package:flutter/services.dart';

/// Semantic, tactile haptic feedback system for BiteSize.
/// Provides consistent micro-interactions and celebratory sensory patterns.
class ZenHaptics {
  const ZenHaptics._();

  /// Crisp selection click: for calendar day scrub, tab switches, and dropdowns.
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Light tap impact: for food item checks, chips, and small toggle switches.
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium tactile pulse: for adding water (+250ml), logging a meal, starting a fast.
  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact: for completing a fast, unlocking an achievement, or reaching a goal.
  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Celebratory rhythmic pulse sequence: fires on calorie/protein/water target hit.
  static Future<void> celebrationSequence() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Success tactile feedback when an item or workout is logged.
  static Future<void> success() async => medium();

  /// Error or warning double-tap vibration: for over-budget or validation alert.
  static Future<void> warning() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
