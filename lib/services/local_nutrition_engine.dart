import 'dart:math' as math;

import '../models/nutrition.dart';
import 'local_food_database.dart';

/// Natural language parser and offline calculator that matches everyday food logs
/// against the local food database with zero network delay (0 ms).
class LocalNutritionEngine {
  static const Map<String, double> _wordNumbers = {
    'a': 1.0,
    'an': 1.0,
    'one': 1.0,
    'two': 2.0,
    'three': 3.0,
    'four': 4.0,
    'five': 5.0,
    'six': 6.0,
    'seven': 7.0,
    'eight': 8.0,
    'nine': 9.0,
    'ten': 10.0,
    'half': 0.5,
    'quarter': 0.25,
  };

  /// Attempts to parse a multi-item or single-item meal query completely offline.
  /// Returns `null` if the user's text contains items not recognized in the local DB,
  /// signaling that the query should fall through to the cloud LLM.
  static LlmEstimationResult? tryParseMeal(
    String description, {
    MealType? mealTypeHint,
  }) {
    final raw = description.trim();
    if (raw.isEmpty) return null;

    // Split query by common natural delimiters: "and", "+", ",", "with", "&", "\n"
    final delimiters = RegExp(r'\b(?:and|with|\+|,|&|\n)\b', caseSensitive: false);
    final segments = raw
        .split(delimiters)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.isEmpty) return null;

    final parsedItems = <FoodItem>[];
    MealType? inferredMealType = mealTypeHint;

    for (final seg in segments) {
      final parsed = _parseSingleSegment(seg);
      if (parsed == null) {
        // Unrecognized segment -> fall back to cloud AI
        return null;
      }
      parsedItems.add(parsed.item);
      inferredMealType ??= parsed.suggestedMealType;
    }

    if (parsedItems.isEmpty) return null;

    // Generate clean meal title
    final title = parsedItems.length == 1
        ? parsedItems.first.name
        : parsedItems.map((e) => e.name).take(3).join(' & ');

    final effectiveMealType = inferredMealType ?? MealType.suggestedForTime(DateTime.now());

    return LlmEstimationResult(
      mealTitle: title,
      mealTypeSuggestion: effectiveMealType,
      items: parsedItems,
      providerLabel: '⚡ Local Offline Engine (0 ms)',
      aiNotes: 'Calculated instantly on-device using BiteSize Local Food Database.',
    );
  }

  static ({FoodItem item, MealType suggestedMealType})? _parseSingleSegment(String segment) {
    var text = segment.trim().toLowerCase();
    if (text.isEmpty) return null;

    double? rawAmount;
    String? explicitUnit;

    const unitRegexStr =
        r'(?:ml|mls|milliliters?|l|liters?|litres?|g|gm|gms|grams?|kg|kgs|kilos?|kilograms?|oz|ounces?|cups?|glass(?:es)?|tumblers?|bowls?|plates?|slices?|scoops?|tbsp|tablespoons?|tsp|teaspoons?|pieces?|pcs|nos?\.?|servings?|handfuls?)';

    // 1a. Check for leading digits + optional unit (e.g. "100ml of...", "100 ml...", "2.5 cups...", "2 eggs...")
    final leadingNumUnitMatch = RegExp(
      '^(\\d+(?:\\.\\d+)?|\\d+\\/\\d+)\\s*($unitRegexStr)?\\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (leadingNumUnitMatch != null) {
      final numStr = leadingNumUnitMatch.group(1)!;
      if (numStr.contains('/')) {
        final parts = numStr.split('/');
        final num = double.tryParse(parts[0]) ?? 1.0;
        final den = double.tryParse(parts[1]) ?? 1.0;
        rawAmount = den != 0 ? num / den : 1.0;
      } else {
        rawAmount = double.tryParse(numStr) ?? 1.0;
      }
      explicitUnit = leadingNumUnitMatch.group(2);
      text = text.substring(leadingNumUnitMatch.end).trim();
    } else {
      // 1b. Check for leading word numbers (e.g. "two cups of...", "half cup of...")
      final wordNumMatch = RegExp(
        '^(a|an|one|two|three|four|five|six|seven|eight|nine|ten|half|quarter)\\s+($unitRegexStr)?\\b',
        caseSensitive: false,
      ).firstMatch(text);

      if (wordNumMatch != null) {
        final word = wordNumMatch.group(1)!.toLowerCase();
        rawAmount = _wordNumbers[word] ?? 1.0;
        explicitUnit = wordNumMatch.group(2);
        text = text.substring(wordNumMatch.end).trim();
      } else {
        // 1c. Check for trailing quantity & unit (e.g. "milk tea 100ml", "white rice 200g", "boiled egg 2")
        final trailingMatch = RegExp(
          '^(.*?)\\s+(\\d+(?:\\.\\d+)?|\\d+\\/\\d+)\\s*($unitRegexStr)?\$',
          caseSensitive: false,
        ).firstMatch(text);

        if (trailingMatch != null) {
          final foodPart = trailingMatch.group(1)!.trim();
          final numStr = trailingMatch.group(2)!;
          if (numStr.contains('/')) {
            final parts = numStr.split('/');
            final num = double.tryParse(parts[0]) ?? 1.0;
            final den = double.tryParse(parts[1]) ?? 1.0;
            rawAmount = den != 0 ? num / den : 1.0;
          } else {
            rawAmount = double.tryParse(numStr) ?? 1.0;
          }
          explicitUnit = trailingMatch.group(3);
          text = foodPart;
        }
      }
    }

    // 2. Strip filler words like "of", "approx", "about"
    text = text.replaceFirst(RegExp(r'^(?:of\s+|approx\.?\s+|about\s+)', caseSensitive: false), '').trim();
    text = text.replaceAll(RegExp(r'\s*(?:pieces|piece|pcs|nos|no\.?)$', caseSensitive: false), '').trim();

    // 3. Search local food database
    final food = LocalFoodDatabase.findMatch(text);
    if (food == null) return null;

    final amt = rawAmount ?? 1.0;
    final u = explicitUnit?.toLowerCase();

    double effectiveMultiplier = 1.0;
    double? customQuantity;
    String? customUnit;
    double? customGrams;

    if (u != null) {
      if (u == 'ml' || u == 'mls' || u.startsWith('millilit')) {
        // Milliliters (standard beverages/liquids ~1g/ml)
        final grams = amt;
        effectiveMultiplier = grams / (food.gramsPerUnit > 0 ? food.gramsPerUnit : 100.0);
        customQuantity = amt;
        customUnit = 'ml';
        customGrams = grams;
      } else if (u == 'l' || u.startsWith('liter') || u.startsWith('litre')) {
        // Liters (1L = 1000ml)
        final grams = amt * 1000.0;
        effectiveMultiplier = grams / (food.gramsPerUnit > 0 ? food.gramsPerUnit : 100.0);
        customQuantity = amt * 1000.0;
        customUnit = 'ml';
        customGrams = grams;
      } else if (u == 'g' || u == 'gm' || u == 'gms' || u.startsWith('gram')) {
        // Grams
        final grams = amt;
        effectiveMultiplier = grams / (food.gramsPerUnit > 0 ? food.gramsPerUnit : 100.0);
        customQuantity = amt;
        customUnit = 'g';
        customGrams = grams;
      } else if (u == 'kg' || u == 'kgs' || u.startsWith('kilo')) {
        // Kilograms (1kg = 1000g)
        final grams = amt * 1000.0;
        effectiveMultiplier = grams / (food.gramsPerUnit > 0 ? food.gramsPerUnit : 100.0);
        customQuantity = amt * 1000.0;
        customUnit = 'g';
        customGrams = grams;
      } else if (u == 'oz' || u.startsWith('ounce')) {
        // Ounces (1 oz = 28.35g)
        final grams = amt * 28.35;
        effectiveMultiplier = grams / (food.gramsPerUnit > 0 ? food.gramsPerUnit : 100.0);
        customQuantity = amt;
        customUnit = 'oz';
        customGrams = grams;
      } else if (u == 'tbsp' || u.startsWith('tablespoon')) {
        // Tablespoon (~15g/ml)
        final grams = amt * 15.0;
        effectiveMultiplier = grams / (food.gramsPerUnit > 0 ? food.gramsPerUnit : 15.0);
        customQuantity = amt;
        customUnit = 'tbsp';
        customGrams = grams;
      } else if (u == 'tsp' || u.startsWith('teaspoon')) {
        // Teaspoon (~5g/ml)
        final grams = amt * 5.0;
        effectiveMultiplier = grams / (food.gramsPerUnit > 0 ? food.gramsPerUnit : 5.0);
        customQuantity = amt;
        customUnit = 'tsp';
        customGrams = grams;
      } else {
        // Standard portion units: cups, glasses, slices, scoops, plates, bowls
        effectiveMultiplier = amt;
        customQuantity = amt;
        customUnit = u == 'glasses'
            ? 'glass'
            : (u.endsWith('s') && !u.endsWith('ss') ? u.substring(0, u.length - 1) : u);
        customGrams = food.gramsPerUnit * amt;
      }
    } else {
      // Default item units (e.g. "2 boiled eggs", "3 idlis", "1 banana")
      effectiveMultiplier = amt;
      customQuantity = food.defaultQuantity * amt;
      customUnit = food.defaultUnit;
      customGrams = food.gramsPerUnit * amt;
    }

    final item = food.toFoodItem(
      multiplier: math.max(0.01, effectiveMultiplier),
      customQuantity: customQuantity,
      customUnit: customUnit,
      customGrams: customGrams,
    );

    return (item: item, suggestedMealType: food.suggestedMealType);
  }
}
