import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/notification_settings.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/models/quick_bite.dart';
import 'package:zen_calorie/services/date_utils.dart';
import 'package:zen_calorie/services/settings_repository.dart';

void main() {
  group('BiteSize Features Test', () {
    test('ZenDateUtils.dynamicGreeting returns contextual string', () {
      final today = DateTime.now();
      final greeting = ZenDateUtils.dynamicGreeting(today);
      expect(greeting.isNotEmpty, true);

      final yesterday = today.subtract(const Duration(days: 1));
      final yGreeting = ZenDateUtils.dynamicGreeting(yesterday, now: today);
      expect(yGreeting.contains('Yesterday'), true);

      final tomorrow = today.add(const Duration(days: 1));
      final tGreeting = ZenDateUtils.dynamicGreeting(tomorrow, now: today);
      expect(tGreeting.contains('Tomorrow'), true);
    });

    test('ZenDateUtils.formatHourMinute formats 12h time properly', () {
      expect(ZenDateUtils.formatHourMinute(8, 30), '8:30 AM');
      expect(ZenDateUtils.formatHourMinute(13, 0), '1:00 PM');
      expect(ZenDateUtils.formatHourMinute(19, 45), '7:45 PM');
      expect(ZenDateUtils.formatHourMinute(0, 15), '12:15 AM');
      expect(ZenDateUtils.formatHourMinute(12, 0), '12:00 PM');
    });

    test('NotificationSettings defaults and serialization', () {
      const settings = NotificationSettings();
      expect(settings.enabled, true);
      expect(settings.breakfastHour, 8);
      expect(settings.breakfastMinute, 30);
      expect(settings.lunchHour, 13);
      expect(settings.dinnerHour, 19);
      expect(settings.underCalorieAlert, true);
      expect(settings.overCalorieAlert, true);

      final map = settings.toMap();
      final parsed = NotificationSettings.fromMap(map);
      expect(parsed.enabled, true);
      expect(parsed.lunchHour, 13);
    });

    test('QuickBitePreset defaults provide valid non-zero nutrients', () {
      expect(QuickBitePreset.defaultPresets.isNotEmpty, true);
      for (final p in QuickBitePreset.defaultPresets) {
        expect(p.name.isNotEmpty, true);
        expect(p.macros.calories > 0, true);
        expect(p.macros.proteinG >= 0, true);
      }
    });

    test('QuickBitePreset custom serialization toJson and fromJson preserves data', () {
      const custom = QuickBitePreset(
        id: 'qb_custom_123',
        name: "Amma's Rasam Rice",
        icon: '🍲',
        portion: '1 bowl',
        estimatedGrams: 220,
        macros: MacroNutrients(
          calories: 260,
          proteinG: 6.5,
          carbsG: 48,
          fatG: 5.2,
          fiberG: 3.8,
        ),
        mealType: MealType.lunch,
        isCustom: true,
      );

      final json = custom.toJson();
      expect(json['id'], 'qb_custom_123');
      expect(json['name'], "Amma's Rasam Rice");
      expect(json['icon'], '🍲');
      expect(json['isCustom'], true);
      expect(json['mealType'], 'lunch');

      final reconstructed = QuickBitePreset.fromJson(json);
      expect(reconstructed.id, custom.id);
      expect(reconstructed.name, custom.name);
      expect(reconstructed.icon, custom.icon);
      expect(reconstructed.portion, custom.portion);
      expect(reconstructed.estimatedGrams, 220.0);
      expect(reconstructed.macros.calories, 260.0);
      expect(reconstructed.macros.proteinG, 6.5);
      expect(reconstructed.mealType, MealType.lunch);
      expect(reconstructed.isCustom, true);
    });

    test('QuickBitePreset.fromMealEntry builds valid custom quick bite', () {
      final meal = MealEntry(
        id: 'meal_test_1',
        dateKey: '2026-11-13',
        loggedAt: DateTime.now(),
        mealType: MealType.breakfast,
        title: '3 Idli + Filter Coffee',
        rawInput: '3 idlis with sambar and coffee',
        items: const [
          FoodItem(
            id: 'item_1',
            name: 'Idli',
            quantity: 3,
            unit: 'piece',
            estimatedGrams: 150,
            macros: MacroNutrients(calories: 195, proteinG: 6, carbsG: 39, fatG: 1),
          ),
          FoodItem(
            id: 'item_2',
            name: 'Filter Coffee',
            quantity: 1,
            unit: 'tumbler',
            estimatedGrams: 150,
            macros: MacroNutrients(calories: 105, proteinG: 3.5, carbsG: 12, fatG: 4),
          ),
        ],
      );

      final preset = QuickBitePreset.fromMealEntry(meal, icon: '🥞');
      expect(preset.name, '3 Idli + Filter Coffee');
      expect(preset.icon, '🥞');
      expect(preset.mealType, MealType.breakfast);
      expect(preset.isCustom, true);
      expect(preset.macros.calories, 300.0);
      expect(preset.macros.proteinG, 9.5);
      expect(preset.estimatedGrams, 300.0);
    });

    test('SettingsRepository persists and restores custom quick bites', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository();

      final initial = await repo.loadCustomQuickBites();
      expect(initial.isEmpty, true);

      const bite = QuickBitePreset(
        id: 'qb_custom_999',
        name: 'Whey + Peanut Butter',
        icon: '🥤',
        portion: '1 shaker',
        estimatedGrams: 350,
        macros: MacroNutrients(calories: 320, proteinG: 32, carbsG: 12, fatG: 14),
        mealType: MealType.snack,
        isCustom: true,
      );

      await repo.saveCustomQuickBites([bite]);

      final loaded = await repo.loadCustomQuickBites();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'qb_custom_999');
      expect(loaded.first.name, 'Whey + Peanut Butter');
      expect(loaded.first.macros.proteinG, 32.0);
    });
  });
}


