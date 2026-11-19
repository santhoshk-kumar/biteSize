import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zen_calorie/models/llm_config.dart';
import 'package:zen_calorie/services/local_food_database.dart';
import 'package:zen_calorie/services/local_nutrition_engine.dart';
import 'package:zen_calorie/services/meal_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Local Food Database & Offline Nutrition Engine Tests', () {
    test('LocalFoodDatabase finds staples by name and aliases', () {
      final egg = LocalFoodDatabase.findMatch('boiled egg');
      expect(egg, isNotNull);
      expect(egg!.name, 'Boiled Egg');
      expect(egg.caloriesPerUnit, 74);
      expect(egg.proteinPerUnit, 6.3);

      final idli = LocalFoodDatabase.findMatch('idlis');
      expect(idli, isNotNull);
      expect(idli!.name, 'Idli');
      expect(idli.caloriesPerUnit, 65);

      final sambar = LocalFoodDatabase.findMatch('sambar');
      expect(sambar, isNotNull);
      expect(sambar!.name, 'Sambar');

      final banana = LocalFoodDatabase.findMatch('banana');
      expect(banana, isNotNull);
      expect(banana!.name, 'Banana');
      expect(banana.caloriesPerUnit, 105);

      final roti = LocalFoodDatabase.findMatch('chapati');
      expect(roti, isNotNull);
      expect(roti!.name, 'Whole Wheat Roti / Chapati');

      final unknown = LocalFoodDatabase.findMatch('extraterrestrial stew');
      expect(unknown, isNull);
    });

    test('LocalNutritionEngine parses single-item meal with number multiplier', () {
      final result = LocalNutritionEngine.tryParseMeal('2 boiled eggs');
      expect(result, isNotNull);
      expect(result!.items.length, 1);

      final item = result.items.first;
      expect(item.name, 'Boiled Egg');
      expect(item.quantity, 2.0);
      expect(item.estimatedGrams, 100.0);
      expect(item.macros.calories, 148.0);
      expect(item.macros.proteinG, 12.6);
      expect(result.providerLabel.contains('Offline Engine'), true);
    });

    test('LocalNutritionEngine parses multi-item meal (2 boiled eggs and 1 banana)', () {
      final result = LocalNutritionEngine.tryParseMeal('2 boiled eggs and 1 banana');
      expect(result, isNotNull);
      expect(result!.items.length, 2);

      final eggs = result.items[0];
      final banana = result.items[1];

      expect(eggs.name, 'Boiled Egg');
      expect(eggs.quantity, 2.0);

      expect(banana.name, 'Banana');
      expect(banana.quantity, 1.0);

      // Aggregated total
      final totalCalories = result.totalMacros.calories;
      expect(totalCalories, 148.0 + 105.0); // 253.0 kcal
      expect(result.mealTitle.contains('Boiled Egg'), true);
      expect(result.mealTitle.contains('Banana'), true);
      expect(result.providerLabel, '⚡ Local Offline Engine (0 ms)');
    });

    test('LocalNutritionEngine parses South Indian combo (3 idlis with sambar and coconut chutney)', () {
      final result = LocalNutritionEngine.tryParseMeal('3 idlis with 1 cup sambar and coconut chutney');
      expect(result, isNotNull);
      expect(result!.items.length, 3);

      final idlis = result.items[0];
      final sambar = result.items[1];
      final chutney = result.items[2];

      expect(idlis.name, 'Idli');
      expect(idlis.quantity, 3.0);
      expect(idlis.macros.calories, 195.0); // 65 * 3

      expect(sambar.name, 'Sambar');
      expect(sambar.quantity, 1.0);

      expect(chutney.name, 'Coconut Chutney');
      expect(chutney.quantity, 1.0);

      expect(result.totalMacros.calories > 350, true);
      expect(result.totalMacros.proteinG > 12, true);
    });

    test('LocalNutritionEngine correctly parses metric volume and mass units (100ml milk tea)', () {
      // 100ml of milk tea (1 cup is 150ml ~ 86 kcal => 100ml is ~57.3 kcal, NOT 100 cups!)
      final res1 = LocalNutritionEngine.tryParseMeal('100ml of milk tea');
      expect(res1, isNotNull);
      expect(res1!.items.length, 1);
      final tea1 = res1.items.first;
      expect(tea1.name, 'Indian Masala Chai / Milk Tea');
      expect(tea1.quantity, 100.0);
      expect(tea1.unit, 'ml');
      expect(tea1.estimatedGrams, 100.0);
      expect(tea1.macros.calories, closeTo(57.3, 1.0)); // 86 * (100 / 150)
      expect(tea1.macros.calories < 100, true);

      // 100 ml milk tea (with space)
      final res2 = LocalNutritionEngine.tryParseMeal('100 ml milk tea');
      expect(res2, isNotNull);
      expect(res2!.items.first.quantity, 100.0);
      expect(res2.items.first.unit, 'ml');
      expect(res2.totalMacros.calories, closeTo(57.3, 1.0));

      // Trailing unit: milk tea 100ml
      final res3 = LocalNutritionEngine.tryParseMeal('milk tea 100ml');
      expect(res3, isNotNull);
      expect(res3!.items.first.quantity, 100.0);
      expect(res3.items.first.unit, 'ml');
      expect(res3.totalMacros.calories, closeTo(57.3, 1.0));

      // Grams: 200g cooked white rice (1 cup = 158g ~ 205 kcal => 200g ~ 259 kcal)
      final res4 = LocalNutritionEngine.tryParseMeal('200g cooked white rice');
      expect(res4, isNotNull);
      final rice = res4!.items.first;
      expect(rice.quantity, 200.0);
      expect(rice.unit, 'g');
      expect(rice.estimatedGrams, 200.0);
      expect(rice.macros.calories, closeTo(259.5, 2.0));

      // 1 glass of milk tea (standard serving)
      final res5 = LocalNutritionEngine.tryParseMeal('1 glass of milk tea');
      expect(res5, isNotNull);
      expect(res5!.items.first.quantity, 1.0);
      expect(res5.items.first.unit, 'glass');
      expect(res5.items.first.macros.calories, 86.0);
    });

    test('LocalNutritionEngine parses rotis and dal (2 rotis with dal tadka)', () {
      final result = LocalNutritionEngine.tryParseMeal('2 rotis with dal tadka');
      expect(result, isNotNull);
      expect(result!.items.length, 2);

      expect(result.items[0].name, 'Whole Wheat Roti / Chapati');
      expect(result.items[0].quantity, 2.0);
      expect(result.items[1].name, 'Dal Tadka / Yellow Dal');
      expect(result.items[1].quantity, 1.0);

      expect(result.totalMacros.calories, 208.0 + 155.0);
    });

    test('LocalNutritionEngine returns null on unknown/complex recipes so cloud LLM takes over', () {
      final result = LocalNutritionEngine.tryParseMeal('authentic wood-smoked barbecue brisket with chimichurri');
      expect(result, isNull);
    });

    test('LocalFoodDatabase provides comprehensive vitamins and minerals for staples', () {
      final egg = LocalFoodDatabase.findMatch('boiled egg')!.toFoodItem(multiplier: 2.0);
      expect(egg.macros.vitaminAUg, 150.0); // 75 * 2
      expect(egg.macros.vitaminDUg, 2.2); // 1.1 * 2
      expect(egg.macros.vitaminB12Ug, 1.1); // 0.55 * 2
      expect(egg.macros.cholineMg, 294.0); // 147 * 2
      expect(egg.macros.seleniumUg, 30.8); // 15.4 * 2
      expect(egg.macros.calciumMg, 50.0); // 25 * 2

      final sambar = LocalFoodDatabase.findMatch('sambar')!.toFoodItem();
      expect(sambar.macros.vitaminCMg, 14.5);
      expect(sambar.macros.vitaminAUg, 55.0);
      expect(sambar.macros.folateUg, 38.0);
      expect(sambar.macros.magnesiumMg, 32.0);

      final idli = LocalFoodDatabase.findMatch('idli')!.toFoodItem(multiplier: 3.0);
      expect(idli.macros.vitaminB1Mg, closeTo(0.24, 0.01)); // 0.08 * 3
      expect(idli.macros.folateUg, 54.0); // 18 * 3

      final banana = LocalFoodDatabase.findMatch('banana')!.toFoodItem();
      expect(banana.macros.potassiumMg, 422.0);
      expect(banana.macros.vitaminCMg, 10.3);
      expect(banana.macros.vitaminB6Mg, 0.43);

      final keerai = LocalFoodDatabase.findMatch('keerai poriyal')!.toFoodItem();
      expect(keerai.macros.vitaminAUg, 480.0);
      expect(keerai.macros.vitaminKUg, 190.0);
      expect(keerai.macros.vitaminCMg, 28.0);
      expect(keerai.macros.calciumMg, 125.0);
    });

    test('LocalFoodDatabase covers expanded South Indian dishes, biryanis, curries, and fitness foods', () {
      // Biryani & Rice
      final biryani = LocalFoodDatabase.findMatch('chicken biryani');
      expect(biryani, isNotNull);
      expect(biryani!.name, 'Chicken Biryani');
      expect(biryani.caloriesPerUnit, 540);
      expect(biryani.proteinPerUnit, 28.5);

      final lemonRice = LocalFoodDatabase.findMatch('lemon rice');
      expect(lemonRice, isNotNull);
      expect(lemonRice!.name.contains('Lemon Rice'), true);

      final bisiBele = LocalFoodDatabase.findMatch('bisi bele bath');
      expect(bisiBele, isNotNull);
      expect(bisiBele!.caloriesPerUnit, 265);

      // Poriyals & Sides
      final cabbage = LocalFoodDatabase.findMatch('cabbage poriyal');
      expect(cabbage, isNotNull);
      expect(cabbage!.name.contains('Cabbage'), true);

      final beans = LocalFoodDatabase.findMatch('beans poriyal');
      expect(beans, isNotNull);
      expect(beans!.name.contains('Green Beans'), true);

      final avial = LocalFoodDatabase.findMatch('avial');
      expect(avial, isNotNull);
      expect(avial!.proteinPerUnit, 3.8);

      final potatoRoast = LocalFoodDatabase.findMatch('potato roast');
      expect(potatoRoast, isNotNull);
      expect(potatoRoast!.caloriesPerUnit, 210);

      // Non-Veg
      final chicken65 = LocalFoodDatabase.findMatch('chicken 65');
      expect(chicken65, isNotNull);
      expect(chicken65!.proteinPerUnit, 26.0);

      final fishCurry = LocalFoodDatabase.findMatch('meen kuzhambu');
      expect(fishCurry, isNotNull);
      expect(fishCurry!.name.contains('Fish Curry'), true);

      // Beverages & Chutneys
      final tenderCoconut = LocalFoodDatabase.findMatch('elaneer');
      expect(tenderCoconut, isNotNull);
      expect(tenderCoconut!.potassiumMgPerUnit, 600);

      final buttermilk = LocalFoodDatabase.findMatch('spiced buttermilk');
      expect(buttermilk, isNotNull);
      expect(buttermilk!.caloriesPerUnit, 45);

      final peanutChutney = LocalFoodDatabase.findMatch('peanut chutney');
      expect(peanutChutney, isNotNull);
      expect(peanutChutney!.proteinPerUnit, 3.8);

      // Curries & Breads
      final pbm = LocalFoodDatabase.findMatch('paneer butter masala');
      expect(pbm, isNotNull);
      expect(pbm!.caloriesPerUnit, 340);

      final palak = LocalFoodDatabase.findMatch('palak paneer');
      expect(palak, isNotNull);
      expect(palak!.vitaminAUgPerUnit, 520);

      final chole = LocalFoodDatabase.findMatch('chana masala');
      expect(chole, isNotNull);
      expect(chole!.fiberPerUnit, 8.2);

      final alooParatha = LocalFoodDatabase.findMatch('aloo paratha');
      expect(alooParatha, isNotNull);
      expect(alooParatha!.caloriesPerUnit, 260);

      // Fitness Staples
      final pb = LocalFoodDatabase.findMatch('peanut butter');
      expect(pb, isNotNull);
      expect(pb!.proteinPerUnit, 8.0);

      final greekYogurt = LocalFoodDatabase.findMatch('greek yogurt');
      expect(greekYogurt, isNotNull);
      expect(greekYogurt!.proteinPerUnit, 17.0);

      final avocado = LocalFoodDatabase.findMatch('avocado');
      expect(avocado, isNotNull);
      expect(avocado!.fatPerUnit, 14.7);

      final sweetPotato = LocalFoodDatabase.findMatch('sweet potato');
      expect(sweetPotato, isNotNull);
      expect(sweetPotato!.vitaminAUgPerUnit, 1150);

      final makhana = LocalFoodDatabase.findMatch('roasted makhana');
      expect(makhana, isNotNull);
      expect(makhana!.caloriesPerUnit, 110);
    });

    test('LocalNutritionEngine parses complex realistic Indian meal query', () {
      final result = LocalNutritionEngine.tryParseMeal('1 plate chicken biryani and 1 glass spiced buttermilk');
      expect(result, isNotNull);
      expect(result!.items.length, 2);
      expect(result.items[0].name, 'Chicken Biryani');
      expect(result.items[1].name, 'Spiced Buttermilk / Neer Mor (Zero Oil)');
      expect(result.totalMacros.calories, 540 + 45); // 585 kcal
      expect(result.totalMacros.proteinG, closeTo(31.7, 0.5));
      expect(result.providerLabel, '⚡ Local Offline Engine (0 ms)');
    });

    test('LocalNutritionEngine aggregates vitamins across multi-item meals', () {
      final result = LocalNutritionEngine.tryParseMeal('2 boiled eggs and 1 banana')!;
      final total = result.totalMacros;
      // Eggs (150 ug) + Banana (4 ug)
      expect(total.vitaminAUg, 154.0);
      // Eggs (0 mg) + Banana (10.3 mg)
      expect(total.vitaminCMg, 10.3);
      // Eggs (2.2 ug) + Banana (0 ug)
      expect(total.vitaminDUg, 2.2);
      // Eggs (1.1 ug) + Banana (0 ug)
      expect(total.vitaminB12Ug, 1.1);
      // Banana potassium (422) + Eggs potassium (126)
      expect(total.potassiumMg, 548.0);
    });

    test('MealCacheService stores and retrieves recent meal queries in 0 ms', () async {
      final cache = MealCacheService();

      expect(await cache.get('2 boiled eggs and 1 banana'), isNull);

      final meal = LocalNutritionEngine.tryParseMeal('2 boiled eggs and 1 banana')!;
      await cache.put('2 boiled eggs and 1 banana', meal);

      final cached = await cache.get('2 boiled eggs and 1 banana');
      expect(cached, isNotNull);
      expect(cached!.items.length, 2);
      expect(cached.mealTitle, meal.mealTitle);
      expect(cached.providerLabel, '⚡ Cached (0 ms)');
    });

    test('LlmSettings supports Groq provider and Gemini 2.0 Flash-Lite default', () {
      expect(LlmSettings.defaultGeminiModel, 'gemini-2.0-flash-lite');
      expect(LlmSettings.defaultGroqModel, 'llama-3.3-70b-versatile');
      expect(LlmSettings.defaultGroqBaseUrl, 'https://api.groq.com/openai/v1');

      const settings = LlmSettings();
      final groqSettings = settings.copyWith(provider: LlmProviderType.groq);
      expect(groqSettings.provider, LlmProviderType.groq);
      expect(groqSettings.activeModel, 'llama-3.3-70b-versatile');
    });
  });
}
