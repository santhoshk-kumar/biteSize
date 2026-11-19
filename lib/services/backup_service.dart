import 'dart:convert';
import '../models/calorie_bank.dart';
import '../models/dietary_preferences.dart';
import '../models/fasting_model.dart';
import '../models/health_log.dart';
import '../models/notification_settings.dart';
import '../models/nutrition.dart';
import '../models/quick_bite.dart';
import '../models/saved_combo.dart';
import '../models/user_profile.dart';
import 'database_service.dart';
import 'date_utils.dart';
import 'settings_repository.dart';

/// Service responsible for full data export/import (JSON backup & restore) and CSV generation.
class BackupService {
  const BackupService({
    required DatabaseService database,
    required SettingsRepository settingsRepo,
  })  : _db = database,
        _settingsRepo = settingsRepo;

  final DatabaseService _db;
  final SettingsRepository _settingsRepo;

  /// Compiles all application tables, preferences, and logs into a single structured JSON string.
  Future<String> exportBackupJson({
    required UserProfile profile,
    required DietaryPreferences dietary,
    required DailyGoals goals,
    required NotificationSettings notifications,
    required CalorieBankSettings calorieBank,
    required FastingState fasting,
    required List<QuickBitePreset> customQuickBites,
    required List<SavedMealCombo> savedCombos,
  }) async {
    // 1. Fetch all meals covering trailing 365 days
    final now = DateTime.now();
    final allDates = ZenDateUtils.trailingDates(now, 365);
    final allMeals = <MealEntry>[];
    for (final d in allDates) {
      final key = ZenDateUtils.toDateKey(d);
      final dayMeals = await _db.getMealsForDate(key);
      allMeals.addAll(dayMeals);
    }

    // 2. Fetch all water logs
    final allWater = <WaterEntry>[];
    for (final d in allDates) {
      final key = ZenDateUtils.toDateKey(d);
      final dayWater = await _db.getWaterForDate(key);
      allWater.addAll(dayWater);
    }

    // 3. Fetch all weight history
    final weightHistory = await _db.getWeightHistory();

    final backupPayload = {
      'app': 'BiteSize',
      'version': '2.0.0',
      'exportedAt': now.toIso8601String(),
      'profile': profile.toMap(),
      'dietary': dietary.toMap(),
      'goals': {
        'calorieTarget': goals.calorieTarget,
        'proteinTargetG': goals.proteinTargetG,
        'carbsTargetG': goals.carbsTargetG,
        'fatTargetG': goals.fatTargetG,
        'fiberTargetG': goals.fiberTargetG,
        'waterTargetMl': goals.waterTargetMl,
        'targetWeightKg': goals.targetWeightKg,
      },
      'notifications': notifications.toMap(),
      'calorieBank': calorieBank.toMap(),
      'fasting': fasting.toMap(),
      'customQuickBites': customQuickBites.map((e) => e.toJson()).toList(),
      'savedCombos': savedCombos.map((e) => e.toJson()).toList(),
      'meals': allMeals.map((m) => m.toMap()).toList(),
      'water': allWater.map((w) => w.toMap()).toList(),
      'weightHistory': weightHistory.map((wt) => wt.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(backupPayload);
  }

  /// Restores application data from a raw JSON backup string.
  /// Returns count of restored meals.
  Future<int> importBackupJson(String rawJson) async {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file: root must be a JSON object.');
    }

    // 1. Restore Profile
    if (decoded['profile'] is Map<String, dynamic>) {
      final profile = UserProfile.fromMap(decoded['profile'] as Map<String, dynamic>);
      await _settingsRepo.saveUserProfile(profile);
    }

    // 2. Restore Goals
    if (decoded['goals'] is Map<String, dynamic>) {
      final gMap = decoded['goals'] as Map<String, dynamic>;
      final goals = DailyGoals(
        calorieTarget: (gMap['calorieTarget'] as num?)?.toInt() ?? 2000,
        proteinTargetG: (gMap['proteinTargetG'] as num?)?.toInt() ?? 130,
        carbsTargetG: (gMap['carbsTargetG'] as num?)?.toInt() ?? 220,
        fatTargetG: (gMap['fatTargetG'] as num?)?.toInt() ?? 67,
        fiberTargetG: (gMap['fiberTargetG'] as num?)?.toInt() ?? 28,
        waterTargetMl: (gMap['waterTargetMl'] as num?)?.toInt() ?? 2500,
        targetWeightKg: (gMap['targetWeightKg'] as num?)?.toDouble() ?? 68.0,
      );
      await _settingsRepo.saveGoals(goals);
    }

    // 3. Restore Notifications
    if (decoded['notifications'] is Map<String, dynamic>) {
      final n = NotificationSettings.fromMap(decoded['notifications'] as Map<String, dynamic>);
      await _settingsRepo.saveNotificationSettings(n);
    }

    // 4. Restore Calorie Banking
    if (decoded['calorieBank'] is Map<String, dynamic>) {
      final b = CalorieBankSettings.fromMap(decoded['calorieBank'] as Map<String, dynamic>);
      await _settingsRepo.saveCalorieBankSettings(b);
    }

    // 5. Restore Fasting
    if (decoded['fasting'] is Map<String, dynamic>) {
      final f = FastingState.fromMap(decoded['fasting'] as Map<String, dynamic>);
      await _settingsRepo.saveFastingState(f);
    }

    // 6. Restore Custom Quick Bites
    if (decoded['customQuickBites'] is List<dynamic>) {
      final list = (decoded['customQuickBites'] as List<dynamic>)
          .map((e) => QuickBitePreset.fromJson(e as Map<String, dynamic>))
          .toList();
      await _settingsRepo.saveCustomQuickBites(list);
    }

    // 7. Restore Database Meals
    var restoredMealsCount = 0;
    if (decoded['meals'] is List<dynamic>) {
      for (final rawMeal in decoded['meals'] as List<dynamic>) {
        if (rawMeal is Map<String, dynamic>) {
          final meal = MealEntry.fromMap(rawMeal);
          await _db.upsertMeal(meal);
          restoredMealsCount++;
        }
      }
    }

    // 8. Restore Water
    if (decoded['water'] is List<dynamic>) {
      for (final rawWater in decoded['water'] as List<dynamic>) {
        if (rawWater is Map<String, dynamic>) {
          final water = WaterEntry.fromMap(rawWater);
          await _db.insertWater(water);
        }
      }
    }

    // 9. Restore Weight
    if (decoded['weightHistory'] is List<dynamic>) {
      for (final rawWeight in decoded['weightHistory'] as List<dynamic>) {
        if (rawWeight is Map<String, dynamic>) {
          final wt = WeightEntry.fromMap(rawWeight);
          await _db.insertWeight(wt);
        }
      }
    }

    return restoredMealsCount;
  }

  /// Exports all logged meals into standard CSV format for spreadsheets.
  Future<String> exportMealsCsv() async {
    final now = DateTime.now();
    final trailing = ZenDateUtils.trailingDates(now, 90);
    final allMeals = <MealEntry>[];

    for (final day in trailing) {
      final dayMeals = await _db.getMealsForDate(ZenDateUtils.toDateKey(day));
      allMeals.addAll(dayMeals);
    }

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln(
        'Date,Time,Meal Type,Title,Calories (kcal),Protein (g),Carbs (g),Fat (g),Fiber (g),Food Items');

    for (final meal in allMeals) {
      final dateStr = ZenDateUtils.toDateKey(meal.loggedAt);
      final timeStr = ZenDateUtils.formatTime(meal.loggedAt);
      final mealType = meal.mealType.label;
      final title = _escapeCsv(meal.title);
      final cals = meal.totalMacros.calories.round();
      final protein = meal.totalMacros.proteinG.toStringAsFixed(1);
      final carbs = meal.totalMacros.carbsG.toStringAsFixed(1);
      final fat = meal.totalMacros.fatG.toStringAsFixed(1);
      final fiber = meal.totalMacros.fiberG.toStringAsFixed(1);

      final itemNames = meal.items
          .map((i) => '${i.name} (${i.quantity} ${i.unit})')
          .join('; ');
      final escapedItems = _escapeCsv(itemNames);

      buffer.writeln(
          '$dateStr,$timeStr,$mealType,$title,$cals,$protein,$carbs,$fat,$fiber,$escapedItems');
    }

    return buffer.toString();
  }

  String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}

