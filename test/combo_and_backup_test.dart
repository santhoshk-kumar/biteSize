import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/calorie_bank.dart';
import 'package:zen_calorie/models/dietary_preferences.dart';
import 'package:zen_calorie/models/fasting_model.dart';
import 'package:zen_calorie/models/health_log.dart';
import 'package:zen_calorie/models/notification_settings.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/models/quick_bite.dart';
import 'package:zen_calorie/models/saved_combo.dart';
import 'package:zen_calorie/models/user_profile.dart';
import 'package:zen_calorie/services/backup_service.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dietary Preferences Tests', () {
    test('DietType labels, descriptions, and lookup are accurate', () {
      expect(DietType.balanced.label, 'Balanced / Omnivore');
      expect(DietType.southIndian.label, 'South Indian Traditional');
      expect(DietType.southIndian.description, contains('sambar'));
      expect(DietType.fromId('southIndian'), DietType.southIndian);
      expect(DietType.fromId('unknown'), DietType.balanced);
    });

    test('DietaryPreferences prompt directive correctly includes avoidances and notes', () {
      const prefs = DietaryPreferences(
        dietType: DietType.southIndian,
        allergies: ['Gluten-Free', 'Nut-Free', 'Low-Oil'],
        customNote: 'Prefer homemade Tamil Nadu style with curd and rasam',
      );

      final directive = prefs.promptDirective;
      expect(directive, contains('USER DIETARY PROFILE:'));
      expect(directive, contains('South Indian Traditional'));
      expect(directive, contains('Gluten-Free, Nut-Free, Low-Oil'));
      expect(directive, contains('Prefer homemade Tamil Nadu style with curd and rasam'));
    });

    test('DietaryPreferences serialization toMap and fromMap roundtrip', () {
      const original = DietaryPreferences(
        dietType: DietType.vegan,
        allergies: ['Dairy-Free', 'Egg-Free'],
        customNote: 'Strictly plant-based',
      );

      final map = original.toMap();
      final restored = DietaryPreferences.fromMap(map);
      expect(restored.dietType, DietType.vegan);
      expect(restored.allergies, ['Dairy-Free', 'Egg-Free']);
      expect(restored.customNote, 'Strictly plant-based');
    });
  });

  group('Saved Meal Combo Tests', () {
    test('Calculates aggregated macros from multiple food items', () {
      const combo = SavedMealCombo(
        id: 'combo_1',
        name: 'South Indian Thali',
        icon: '🍱',
        mealType: MealType.lunch,
        items: [
          FoodItem(
            id: 'item_1',
            name: 'Brown Rice',
            quantity: 1,
            unit: '1 cup',
            estimatedGrams: 150,
            macros: MacroNutrients(calories: 180, carbsG: 38, proteinG: 4, fatG: 1.5),
            confidence: 'high',
          ),
          FoodItem(
            id: 'item_2',
            name: 'Sambar',
            quantity: 1,
            unit: '1 bowl',
            estimatedGrams: 150,
            macros: MacroNutrients(calories: 120, carbsG: 18, proteinG: 6, fatG: 3),
            confidence: 'high',
          ),
          FoodItem(
            id: 'item_3',
            name: 'Curd / Yogurt',
            quantity: 1,
            unit: '1 cup',
            estimatedGrams: 100,
            macros: MacroNutrients(calories: 70, carbsG: 5, proteinG: 4, fatG: 4),
            confidence: 'high',
          ),
        ],
      );

      final totals = combo.totalMacros;
      expect(totals.calories, 370);
      expect(totals.carbsG, 61);
      expect(totals.proteinG, 14);
      expect(totals.fatG, 8.5);
    });

    test('Converts SavedMealCombo to MealEntry and back from MealEntry', () {
      const combo = SavedMealCombo(
        id: 'combo_fit',
        name: 'Post-Workout Fuel',
        icon: '💪',
        mealType: MealType.breakfast,
        items: [
          FoodItem(
            id: 'it_1',
            name: 'Oats with Whey',
            quantity: 1,
            unit: '1 bowl',
            estimatedGrams: 200,
            macros: MacroNutrients(calories: 320, proteinG: 30, carbsG: 40, fatG: 5),
            confidence: 'high',
          ),
        ],
      );

      final meal = combo.toMealEntry(dateKey: '2026-11-14');
      expect(meal.title, 'Post-Workout Fuel');
      expect(meal.dateKey, '2026-11-14');
      expect(meal.mealType, MealType.breakfast);
      expect(meal.items.length, 1);
      expect(meal.items.first.name, 'Oats with Whey');

      // Round-trip back from MealEntry
      final recreated = SavedMealCombo.fromMealEntry(meal, customName: 'Saved Post-Workout');
      expect(recreated.name, 'Saved Post-Workout');
      expect(recreated.items.length, 1);
      expect(recreated.totalMacros.calories, 320);
    });

    test('SavedMealCombo JSON serialization and round-trip', () {
      const combo = SavedMealCombo(
        id: 'combo_json',
        name: 'Quick Salad',
        icon: '🥗',
        mealType: MealType.dinner,
        items: [
          FoodItem(
            id: 'it_veg',
            name: 'Greek Salad',
            quantity: 1,
            unit: 'bowl',
            estimatedGrams: 250,
            macros: MacroNutrients(calories: 160, proteinG: 5, carbsG: 10, fatG: 12),
            confidence: 'high',
          ),
        ],
      );

      final jsonMap = combo.toJson();
      final fromJson = SavedMealCombo.fromJson(jsonMap);
      expect(fromJson.id, 'combo_json');
      expect(fromJson.name, 'Quick Salad');
      expect(fromJson.icon, '🥗');
      expect(fromJson.mealType, MealType.dinner);
      expect(fromJson.items.length, 1);
      expect(fromJson.items.first.name, 'Greek Salad');
    });
  });

  group('Fasting 4-Stage Metabolic Model Tests', () {
    test('Calculates timeUntilNextStage and nextStageName accurately', () {
      final now = DateTime.now();
      // Fast started 2 hours ago (inside Digestion stage 0-4h)
      final state = FastingState(
        isActive: true,
        startTime: now.subtract(const Duration(hours: 2)),
        protocol: FastingProtocol.sixteenEight,
      );

      expect(state.currentStage.name, 'Digestion & Anabolic');
      expect(state.nextStageName, 'Glycogen Depletion');
      expect(state.timeUntilNextStage?.inHours, 2);

      // Fast started 10 hours ago (inside Glycogen Depletion 4-12h)
      final state10h = FastingState(
        isActive: true,
        startTime: now.subtract(const Duration(hours: 10)),
        protocol: FastingProtocol.sixteenEight,
      );
      expect(state10h.currentStage.name, 'Glycogen Depletion');
      expect(state10h.nextStageName, 'Fat Burning & Ketosis');
    });

    test('Accumulates fasting history statistics across sessions', () {
      const initial = FastingState(
        isActive: false,
        totalFastsCompleted: 5,
        totalHoursFasted: 82.5,
        longestFastHours: 18.0,
      );

      final updated = initial.copyWith(
        totalFastsCompleted: 6,
        totalHoursFasted: 98.5,
        longestFastHours: 18.0,
      );

      expect(updated.totalFastsCompleted, 6);
      expect(updated.totalHoursFasted, 98.5);
      expect(updated.longestFastHours, 18.0);

      final map = updated.toMap();
      final restored = FastingState.fromMap(map);
      expect(restored.totalFastsCompleted, 6);
      expect(restored.totalHoursFasted, 98.5);
      expect(restored.longestFastHours, 18.0);
    });

    test('allStages returns 4 detailed metabolic phases with physiological benefits', () {
      expect(FastingStage.allStages.length, 4);
      expect(FastingStage.allStages[0].name, 'Digestion & Anabolic');
      expect(FastingStage.allStages[1].name, 'Glycogen Depletion');
      expect(FastingStage.allStages[2].name, 'Fat Burning & Ketosis');
      expect(FastingStage.allStages[3].name, 'Autophagy & Deep Repair');
    });
  });

  group('Notification Settings Tests', () {
    test('Default notification settings have all core alerts enabled', () {
      const notifs = NotificationSettings();
      expect(notifs.enabled, true);
      expect(notifs.breakfastReminder, true);
      expect(notifs.fastingStageTransitionAlert, true);
      expect(notifs.fastingTargetReachedAlert, true);
      expect(notifs.hydrationReminder, true);
      expect(notifs.hydrationIntervalHours, 2);
      expect(notifs.weekendBankingAlert, true);
      expect(notifs.streakProtection, true);
    });

    test('NotificationSettings serialization and roundtrip', () {
      const original = NotificationSettings(
        enabled: true,
        fastingStageTransitionAlert: false,
        hydrationIntervalHours: 1,
        weekendBankingAlert: true,
      );

      final map = original.toMap();
      final restored = NotificationSettings.fromMap(map);
      expect(restored.enabled, true);
      expect(restored.fastingStageTransitionAlert, false);
      expect(restored.hydrationIntervalHours, 1);
      expect(restored.weekendBankingAlert, true);
    });
  });

  group('BackupService Full JSON Export and Import Tests', () {
    test('Exports and imports complete application snapshot', () async {
      final db = DatabaseService();
      final settingsRepo = SettingsRepository();

      final backupService = BackupService(
        database: db,
        settingsRepo: settingsRepo,
      );

      const profile = UserProfile(
        isMale: true,
        weightKg: 75.0,
        heightCm: 178.0,
        age: 28,
        neckCm: 39.0,
        waistCm: 82.0,
        hipCm: 95.0,
        isConfigured: true,
      );

      const dietary = DietaryPreferences(
        dietType: DietType.southIndian,
        allergies: ['Gluten-Free'],
        customNote: 'High protein vegetarian',
      );

      const goals = DailyGoals(
        calorieTarget: 2100,
        proteinTargetG: 140,
        carbsTargetG: 220,
        fatTargetG: 65,
        fiberTargetG: 35,
        targetWeightKg: 70.0,
      );

      const notifs = NotificationSettings(
        hydrationIntervalHours: 3,
      );

      const banking = CalorieBankSettings(
        enabled: true,
        bankDailyKcal: 120,
      );

      const fasting = FastingState(
        totalFastsCompleted: 12,
        totalHoursFasted: 195.0,
        longestFastHours: 20.0,
      );

      final customQuickBites = <QuickBitePreset>[
        const QuickBitePreset(
          id: 'qb_1',
          name: 'Filter Coffee',
          portion: '1 cup',
          estimatedGrams: 150,
          macros: MacroNutrients(calories: 65, proteinG: 2, carbsG: 6, fatG: 3),
          icon: '☕',
          mealType: MealType.snack,
          isCustom: true,
        ),
      ];

      final savedCombos = <SavedMealCombo>[
        const SavedMealCombo(
          id: 'cb_1',
          name: 'Classic Breakfast',
          icon: '🍳',
          mealType: MealType.breakfast,
          items: [
            FoodItem(
              id: 'it_egg',
              name: 'Eggs & Toast',
              quantity: 1,
              unit: 'plate',
              estimatedGrams: 180,
              macros: MacroNutrients(calories: 280, proteinG: 18, carbsG: 22, fatG: 12),
              confidence: 'high',
            ),
          ],
        ),
      ];

      final jsonString = await backupService.exportBackupJson(
        profile: profile,
        dietary: dietary,
        goals: goals,
        notifications: notifs,
        calorieBank: banking,
        fasting: fasting,
        customQuickBites: customQuickBites,
        savedCombos: savedCombos,
      );

      expect(jsonString, isNotEmpty);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['version'], '2.0.0');
      expect(decoded['profile']['weightKg'], 75.0);
      expect(decoded['dietary']['dietType'], 'southIndian');
      expect(decoded['goals']['calorieTarget'], 2100);
      expect(decoded['calorieBank']['bankDailyKcal'], 120);
      expect(decoded['fasting']['totalFastsCompleted'], 12);
      expect((decoded['customQuickBites'] as List).length, 1);
      expect((decoded['savedCombos'] as List).length, 1);

      // Verify importing the exported backup succeeds
      final importedMeals = await backupService.importBackupJson(jsonString);
      expect(importedMeals, isA<int>());
    });

    test('exportMealsCsv exports RFC 4180 compliant header', () async {
      final db = DatabaseService();
      final settingsRepo = SettingsRepository();

      final backupService = BackupService(
        database: db,
        settingsRepo: settingsRepo,
      );

      final csv = await backupService.exportMealsCsv();
      expect(csv, contains('Date,Time,Meal Type,Title,Calories (kcal)'));
    });
  });
}
