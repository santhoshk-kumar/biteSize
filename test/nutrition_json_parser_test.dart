import 'package:flutter_test/flutter_test.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/services/nutrition_prompt.dart';

void main() {
  group('NutritionJsonParser', () {
    test('parses valid structured nutrition JSON with micronutrients', () {
      const raw = '''
      {
        "meal_title": "Oatmeal & Eggs",
        "meal_type": "breakfast",
        "ai_notes": "Balanced protein and soluble fiber.",
        "items": [
          {
            "name": "Rolled oats",
            "quantity": 1,
            "unit": "bowl",
            "estimated_grams": 200,
            "calories": 160,
            "protein_g": 6,
            "carbs_g": 27,
            "fat_g": 3,
            "fiber_g": 4,
            "sugar_g": 1,
            "sodium_mg": 10,
            "potassium_mg": 150,
            "vitamin_c_mg": 0,
            "calcium_mg": 25,
            "iron_mg": 1.6,
            "vitamin_d_ug": 0,
            "confidence": "high",
            "notes": "Cooked in water"
          }
        ]
      }
      ''';

      final result = NutritionJsonParser.parse(
        raw,
        providerLabel: 'Gemini (gemini-3.8-flash)',
      );

      expect(result.mealTitle, 'Oatmeal & Eggs');
      expect(result.mealTypeSuggestion, MealType.breakfast);
      expect(result.items.length, 1);
      final item = result.items.first;
      expect(item.name, 'Rolled oats');
      expect(item.macros.calories, 160);
      expect(item.macros.fiberG, 4);
      expect(item.macros.ironMg, 1.6);
      expect(item.confidence, 'high');
    });

    test('strips markdown code fences and parses stringified numbers', () {
      const raw = '''
      Here is the breakdown:
      ```json
      {
        "meal_title": "Berry Smoothie",
        "meal_type": "snack",
        "items": [
          {
            "name": "Mixed berry smoothie",
            "quantity": "1 cup",
            "unit": "cup",
            "estimated_grams": "240g",
            "calories": "210 kcal",
            "protein_g": "8.5 g",
            "carbs_g": 35,
            "fat_g": 3.5
          }
        ]
      }
      ```
      ''';

      final result = NutritionJsonParser.parse(
        raw,
        providerLabel: 'Ollama',
      );
      expect(result.items.first.macros.calories, 210);
      expect(result.items.first.macros.proteinG, 8.5);
      expect(result.items.first.estimatedGrams, 240);
    });

    test('computes fallback calories from macros if calories is 0', () {
      const raw = '''
      {
        "meal_title": "Egg Whites",
        "meal_type": "breakfast",
        "items": [
          {
            "name": "Egg whites",
            "quantity": 3,
            "unit": "whites",
            "estimated_grams": 100,
            "calories": 0,
            "protein_g": 11,
            "carbs_g": 1,
            "fat_g": 0
          }
        ]
      }
      ''';

      final result = NutritionJsonParser.parse(raw, providerLabel: 'Test');
      expect(result.items.first.macros.calories, 48);
    });

    test('throws FormatException when items list is empty', () {
      const raw = '{"meal_title": "Empty", "meal_type": "snack", "items": []}';
      expect(
        () => NutritionJsonParser.parse(raw, providerLabel: 'Test'),
        throwsFormatException,
      );
    });

    test('recovers from bare JSON array root and trailing commas', () {
      const raw = '''
      [
        {
          "name": "Greek Yogurt",
          "quantity": 1,
          "unit": "cup",
          "estimated_grams": 200,
          "calories": 130,
          "protein_g": 15,
          "carbs_g": 6,
          "fat_g": 4,
        },
      ]
      ''';

      final result = NutritionJsonParser.parse(raw, providerLabel: 'Gemini Engine');
      expect(result.items.length, 1);
      expect(result.items.first.name, 'Greek Yogurt');
      expect(result.items.first.macros.proteinG, 15);
      expect(result.items.first.macros.calories, 130);
    });

    test('resolves alternative keys like food_items and ingredients', () {
      const raw = '''
      {
        "meal_title": "Chicken & Rice",
        "food_items": [
          { "name": "Grilled Chicken", "protein_g": 30, "carbs_g": 0, "fat_g": 5, "calories": 165 },
          { "name": "Jasmine Rice", "protein_g": 4, "carbs_g": 45, "fat_g": 1, "calories": 205 }
        ]
      }
      ''';
      final result = NutritionJsonParser.parse(raw, providerLabel: 'Test');
      expect(result.items.length, 2);
      expect(result.items[0].name, 'Grilled Chicken');
      expect(result.items[1].name, 'Jasmine Rice');
    });

    test('repairs unquoted keys and single-quoted JSON', () {
      const raw = "{'meal_title': 'Avocado Toast', 'items': [{'name': 'Toast', 'calories': 90, 'protein_g': 3, 'carbs_g': 16, 'fat_g': 1}]}";
      final result = NutritionJsonParser.parse(raw, providerLabel: 'Test');
      expect(result.items.length, 1);
      expect(result.items.first.name, 'Toast');
    });

    test('recovers from prose text using userDescription fallback', () {
      const invalidProse = "I am an AI and cannot format this right now.";
      final result = NutritionJsonParser.parse(
        invalidProse,
        providerLabel: 'Test',
        userDescription: '2 eggs and toast with coffee',
      );
      expect(result.items.isNotEmpty, true);
      expect(result.items.any((i) => i.name.contains('Egg')), true);
    });
  });

  group('FoodItem scaling and MealEntry totals', () {
    test('scales portion quantities and nutrients cleanly', () {
      const item = FoodItem(
        id: 'i1',
        name: 'Chicken breast',
        quantity: 1,
        unit: 'fillet',
        estimatedGrams: 150,
        macros: MacroNutrients(
          calories: 240,
          proteinG: 45,
          carbsG: 0,
          fatG: 5,
          sodiumMg: 120,
        ),
      );

      final scaled = item.scaleBy(1.5);
      expect(scaled.quantity, 1.5);
      expect(scaled.estimatedGrams, 225);
      expect(scaled.macros.calories, 360);
      expect(scaled.macros.proteinG, 67.5);
      expect(scaled.macros.sodiumMg, 180);
    });

    test('aggregates MealEntry totalMacros across items', () {
      final meal = MealEntry(
        id: 'm1',
        dateKey: '2026-11-11',
        loggedAt: DateTime(2026, 11, 11, 12),
        mealType: MealType.lunch,
        title: 'Lunch',
        rawInput: 'rice and salmon',
        items: const [
          FoodItem(
            id: '1',
            name: 'Salmon',
            quantity: 1,
            unit: 'fillet',
            estimatedGrams: 140,
            macros: MacroNutrients(calories: 290, proteinG: 29, fatG: 18),
          ),
          FoodItem(
            id: '2',
            name: 'Rice',
            quantity: 1,
            unit: 'cup',
            estimatedGrams: 180,
            macros: MacroNutrients(calories: 210, proteinG: 4, carbsG: 45),
          ),
        ],
      );

      expect(meal.totalMacros.calories, 500);
      expect(meal.totalMacros.proteinG, 33);
      expect(meal.totalMacros.carbsG, 45);
      expect(meal.totalMacros.fatG, 18);
    });

    test('parses full vitamins and minerals spectrum and computes DVs', () {
      const raw = '''
      {
        "meal_title": "Nutrient Power Bowl",
        "meal_type": "lunch",
        "items": [
          {
            "name": "Superfood salad",
            "quantity": 1,
            "unit": "bowl",
            "estimated_grams": 300,
            "calories": 350,
            "protein_g": 18,
            "carbs_g": 40,
            "fat_g": 14,
            "fiber_g": 8,
            "sugar_g": 4,
            "vitamin_a_ug": 450,
            "vitamin_c_mg": 45,
            "vitamin_d_ug": 5,
            "vitamin_e_mg": 7.5,
            "vitamin_k_ug": 60,
            "vitamin_b1_mg": 0.6,
            "vitamin_b2_mg": 0.65,
            "vitamin_b3_mg": 8,
            "vitamin_b6_mg": 0.85,
            "folate_ug": 200,
            "vitamin_b12_ug": 1.2,
            "calcium_mg": 650,
            "iron_mg": 9,
            "magnesium_mg": 210,
            "potassium_mg": 2350,
            "zinc_mg": 5.5
          }
        ]
      }
      ''';

      final res = NutritionJsonParser.parse(raw, providerLabel: 'Test');
      final macros = res.items.first.macros;

      expect(macros.vitaminAUg, 450);
      expect(macros.vitaminCMg, 45);
      expect(macros.magnesiumMg, 210);
      expect(macros.zincMg, 5.5);

      final vitC = macros.vitamins.firstWhere((v) => v.name == 'Vitamin C');
      expect(vitC.amount, 45);
      expect(vitC.percentageOfDv, 50.0); // 45mg of 90mg = 50%

      final mg = macros.minerals.firstWhere((m) => m.name == 'Magnesium');
      expect(mg.amount, 210);
      expect(mg.percentageOfDv, 50.0); // 210mg of 420mg = 50%
    });
  });
}
