import 'package:flutter_test/flutter_test.dart';
import 'package:zen_calorie/models/health_log.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/date_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseService Schema & Persistence Verification', () {
    test('foodItemDbColumns contains every key exported by FoodItem.toDbMap', () {
      const sampleItem = FoodItem(
        id: 'test_item_1',
        name: 'Avocado Toast with Egg',
        quantity: 1,
        unit: 'slice',
        estimatedGrams: 120,
        confidence: 'high',
        notes: 'Rich in monounsaturated fats',
        macros: MacroNutrients(
          calories: 220,
          proteinG: 8,
          carbsG: 18,
          fatG: 14,
          fiberG: 5,
          sugarG: 1.5,
          saturatedFatG: 2.5,
          cholesterolMg: 185,
          sodiumMg: 210,
          potassiumMg: 350,
          calciumMg: 35,
          ironMg: 1.4,
          magnesiumMg: 28,
          phosphorusMg: 110,
          zincMg: 0.9,
          copperMg: 0.12,
          manganeseMg: 0.3,
          seleniumUg: 15.2,
          vitaminAUg: 90,
          vitaminCMg: 6.5,
          vitaminDUg: 1.1,
          vitaminEMg: 2.1,
          vitaminKUg: 14.2,
          vitaminB1Mg: 0.1,
          vitaminB2Mg: 0.2,
          vitaminB3Mg: 1.8,
          vitaminB5Mg: 0.9,
          vitaminB6Mg: 0.25,
          vitaminB7Ug: 9.5,
          folateUg: 65,
          vitaminB12Ug: 0.6,
          cholineMg: 125,
        ),
      );

      final dbMap = sampleItem.toDbMap(mealId: 'meal_1', sortOrder: 0);

      for (final key in dbMap.keys) {
        expect(
          DatabaseService.foodItemDbColumns.contains(key),
          isTrue,
          reason: 'Key "$key" in FoodItem.toDbMap() MUST exist in DatabaseService.foodItemDbColumns',
        );
      }
    });

    test('upsertMeal, getMealsForDate, and deleteMeal work reliably', () async {
      final service = DatabaseService();
      final now = DateTime.now();
      final dateKey = ZenDateUtils.toDateKey(now);

      final meal = MealEntry(
        id: 'persisted_meal_1',
        dateKey: dateKey,
        loggedAt: now,
        mealType: MealType.breakfast,
        title: 'Masala Dosa & Sambar',
        rawInput: '1 crispy masala dosa with potato masala and vegetable sambar',
        providerUsed: 'Gemini 2.5 Flash',
        aiNotes: 'Rich in B vitamins and complex carbs.',
        items: const [
          FoodItem(
            id: 'dosa_item_1',
            name: 'Masala Dosa',
            quantity: 1,
            unit: 'piece',
            estimatedGrams: 180,
            confidence: 'high',
            macros: MacroNutrients(
              calories: 320,
              proteinG: 6,
              carbsG: 45,
              fatG: 12,
              fiberG: 3.5,
              saturatedFatG: 3.0,
              cholesterolMg: 10,
              sodiumMg: 450,
              potassiumMg: 220,
              vitaminCMg: 8.5,
              magnesiumMg: 35,
              ironMg: 1.8,
            ),
          ),
        ],
      );

      // Save meal
      await service.upsertMeal(meal);

      // Fetch meal
      final loaded = await service.getMealsForDate(dateKey);
      expect(loaded.isNotEmpty, isTrue);
      final found = loaded.firstWhere((m) => m.id == 'persisted_meal_1');
      expect(found.title, 'Masala Dosa & Sambar');
      expect(found.items.length, 1);
      expect(found.items.first.macros.calories, 320);
      expect(found.items.first.macros.saturatedFatG, 3.0);
      expect(found.items.first.macros.magnesiumMg, 35);

      // Daily summaries
      final summaries = await service.getDailySummaries([now]);
      expect(summaries[dateKey], isNotNull);
      expect(summaries[dateKey]!.mealCount, 1);
      expect(summaries[dateKey]!.calories, 320);

      // Delete meal
      await service.deleteMeal('persisted_meal_1');
      final afterDelete = await service.getMealsForDate(dateKey);
      expect(afterDelete.any((m) => m.id == 'persisted_meal_1'), isFalse);
    });

    test('water and weight logs operate smoothly', () async {
      final service = DatabaseService();
      final now = DateTime.now();
      final dateKey = ZenDateUtils.toDateKey(now);

      final water = WaterEntry(
        id: 'water_test_1',
        dateKey: dateKey,
        loggedAt: now,
        amountMl: 350,
      );
      await service.insertWater(water);

      final waterList = await service.getWaterForDate(dateKey);
      expect(waterList.any((w) => w.id == 'water_test_1'), isTrue);

      final weight = WeightEntry(
        id: 'weight_test_1',
        dateKey: dateKey,
        loggedAt: now,
        weightKg: 72.4,
        note: 'Morning weigh-in',
      );
      await service.insertWeight(weight);

      final weightList = await service.getWeightHistory();
      expect(weightList.any((w) => w.id == 'weight_test_1'), isTrue);

      await service.deleteWater('water_test_1');
      await service.deleteWeight('weight_test_1');
    });
  });
}
