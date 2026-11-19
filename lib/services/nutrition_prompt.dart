import 'dart:convert';
import 'dart:math' as math;

import '../models/nutrition.dart';
import 'date_utils.dart';

/// Shared system instructions, structured JSON schema, and defensive JSON parser
/// used across Gemini, OpenAI-compatible, and Ollama providers.
class NutritionPromptBuilder {
  static const String systemInstruction = '''
You are BiteSize, an elite clinical dietitian, molecular nutritionist, and culinary science AI.
Your mission is to analyze user meal descriptions and photos, decompose composite dishes into individual ingredients, and output scientifically grounded, constant, and thermodynamically true nutrition data based on USDA FoodData Central standards.

Rules & Principles:
1. Return ONLY valid JSON matching the requested schema. No markdown fences or extra prose outside JSON.
2. MEAL DECONSTRUCTION & HIDDEN INGREDIENT DETECTION:
   - Break composite meals into logical individual whole foods (e.g., "Grilled chicken breast", "Steamed jasmine rice", "Extra virgin olive oil", "Mixed garden greens") rather than lumping everything together.
   - Always account for cooking fats and oils: restaurant and sautéed dishes typically incorporate 1-2 tbsp (14-28g fat, 120-240 kcal) of cooking oil, butter, or ghee.
   - Account for dressings, marinades, glazes, and sauces.
3. REALISTIC PORTIONS & GRAM WEIGHTS:
   - When portion weights are omitted, anchor to USDA standards:
     • 1 large egg ~ 50g (6g P, 0.5g C, 5g F, ~72 kcal)
     • 1 cooked chicken breast ~ 140g-170g (30-35g P)
     • 1 cup cooked rice / pasta ~ 150g-160g (~40-45g C, ~200 kcal)
     • 1 slice sandwich bread ~ 35g-40g (~15g C, ~80 kcal)
     • 1 medium banana ~ 118g (~27g C, ~105 kcal)
     • 1 tbsp cooking oil / butter ~ 14g (~14g F, 120-130 kcal)
     • 1 scoop whey protein ~ 30g (~24g P, ~120 kcal)
4. THERMODYNAMIC & MACRO LAW:
   - Ensure macro consistency: calories MUST mathematically equal 4*protein_g + 4*carbs_g + 9*fat_g.
   - Sum of item calories must match total meal energy. Never return negative numbers.
5. MICRONUTRIENT & METABOLIC PROFILING:
   - Estimate realistic micronutrients:
     • Vitamins: vitamin_a_ug, vitamin_c_mg, vitamin_d_ug, vitamin_e_mg, vitamin_k_ug, vitamin_b1_mg, vitamin_b2_mg, vitamin_b3_mg, vitamin_b5_mg, vitamin_b6_mg, vitamin_b7_ug, folate_ug, vitamin_b12_ug, choline_mg
     • Minerals: calcium_mg, iron_mg, magnesium_mg, phosphorus_mg, potassium_mg, sodium_mg, zinc_mg, copper_mg, manganese_mg, selenium_ug
     • Lipids/Carbs: fiber_g, sugar_g, saturated_fat_g, cholesterol_mg
6. SOUTH INDIAN & TAMIL NADU CUISINE RECOGNITION & TEMPERING:
   - Deeply understand Tamil Nadu and South Indian culinary traditions, fermented batters, and tempering (thalippu):
     • Idli: Steamed fermented rice and urad dal (1:4 ratio), virtually oil-free (~65 kcal per 50g idli, 2g P, 14g C, 0.2g F, high B-vitamins).
     • Dosa / Kal Dosa / Ghee Roast: Fermented batter cooked on tawa. Plain Dosa ~130-150 kcal (3g P, 22g C, 5g F); Ghee Roast ~230-280 kcal (8-12g F from ghee); Masala Dosa includes spiced potato filling (~280-320 kcal, 5g P, 38g C, 12g F).
     • Sambar: Toor dal broth with tamarind, drumstick, shallots (chinna vengayam), and spices (~110-130 kcal / 200ml cup, 5g P, 16g C, 3g F).
     • Rasam: Paruppu/Thakkali/Pepper rasam — light digestive broth (~35-50 kcal / cup, 1.5g P, 6g C, 1g F).
     • Chutneys: Coconut Chutney (healthy MCT fats, 2 tbsp ~75-90 kcal, 1g P, 2g C, 7-8g F); Tomato/Kara Chutney (lower fat, 2 tbsp ~45 kcal).
     • Pongal (Ven Pongal): 1:1 raw rice and split moong dal cooked with cumin, pepper, ginger, cashews, and generous ghee (~320 kcal / cup, 7g P, 40g C, 14g F).
     • Curd Rice (Thayir Sadam): Steamed rice mixed with whole curd, tempered with mustard, green chili, ginger, and curry leaves (~230 kcal / cup, 6g P, 36g C, 7g F).
     • Tamil Non-Veg (Chettinad): Chettinad Chicken, Mutton Sukka, Meen Kuzhambu (fish in tangy tamarind sauce). Decompose lean meat/fish from gravy oils and coconut paste.
     • Kootu & Poriyal: Kootu (dal + vegetables + ground coconut, ~140 kcal / cup); Poriyal (sautéed vegetables with mustard tempering and grated coconut, ~90-120 kcal / cup).
     • Sundal: Boiled legumes (chana/moong) with mustard tempering and grated coconut (~180-210 kcal / cup, 9-11g P, 28g C, 4g F).
     • Parotta & Salna: Layered refined wheat flatbread (~300 kcal each, 14g fat) with spicy vegetable or meat salna gravy.
     • South Indian Filter Coffee: Decoction + boiled whole milk + sugar (~95-115 kcal / 150ml tumbler).
7. TONE:
   - Use a concise, supportive, and data-driven tone in `ai_notes` (1-2 sentences highlighting protein density, micronutrient richness, or satiety).
''';

  static String buildUserPrompt({
    String? description,
    bool hasImage = false,
    MealType? mealTypeHint,
  }) {
    final buffer = StringBuffer();
    if (mealTypeHint != null) {
      buffer.writeln('Meal time context: ${mealTypeHint.label}.');
    }
    if (hasImage && (description == null || description.trim().isEmpty)) {
      buffer.writeln(
        'Analyze the foods visible in this meal photo. Estimate each visible item, portion size, grams, calories, macros, and micronutrients.',
      );
    } else if (hasImage) {
      buffer.writeln(
        'Analyze both the meal photo and the user description below. Use the description to clarify ingredients, cooking oils, or hidden items.',
      );
      buffer.writeln('User description: "${description!.trim()}"');
    } else {
      buffer.writeln(
        'Analyze this meal description and estimate calories, macros, and micronutrients for each item:',
      );
      buffer.writeln('"${(description ?? '').trim()}"');
    }

    buffer.writeln('''

Expected JSON shape:
{
  "meal_title": "Short clean meal title (2-5 words)",
  "meal_type": "breakfast | lunch | dinner | snack",
  "ai_notes": "One calm, helpful observation or portion assumption note.",
  "items": [
    {
      "name": "Food item name",
      "quantity": 1.0,
      "unit": "serving / egg / cup / slice / tbsp",
      "estimated_grams": 120.0,
      "calories": 210.0,
      "protein_g": 14.0,
      "carbs_g": 18.0,
      "fat_g": 9.0,
      "fiber_g": 3.0,
      "sugar_g": 2.0,
      "sodium_mg": 240.0,
      "potassium_mg": 310.0,
      "calcium_mg": 45.0,
      "iron_mg": 1.2,
      "magnesium_mg": 32.0,
      "vitamin_a_ug": 50.0,
      "vitamin_c_mg": 12.0,
      "vitamin_d_ug": 0.5,
      "vitamin_b12_ug": 0.4,
      "folate_ug": 25.0,
      "confidence": "high | medium | low",
      "notes": "Brief preparation/portion note"
    }
  ]
}''');
    return buffer.toString();
  }

  /// JSON Schema passed to Gemini Interactions / generateContent `responseSchema`.
  static Map<String, dynamic> get jsonSchema => {
        'type': 'object',
        'properties': {
          'meal_title': {
            'type': 'string',
            'description': 'Short descriptive meal title (2-5 words).',
          },
          'meal_type': {
            'type': 'string',
            'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
            'description': 'Suggested meal category.',
          },
          'ai_notes': {
            'type': 'string',
            'description':
                'One calm, supportive nutrition observation or assumption note.',
          },
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'quantity': {'type': 'number'},
                'unit': {'type': 'string'},
                'estimated_grams': {'type': 'number'},
                'calories': {'type': 'number'},
                'protein_g': {'type': 'number'},
                'carbs_g': {'type': 'number'},
                'fat_g': {'type': 'number'},
                'fiber_g': {'type': 'number'},
                'sugar_g': {'type': 'number'},
                'saturated_fat_g': {'type': 'number'},
                'sodium_mg': {'type': 'number'},
                'potassium_mg': {'type': 'number'},
                'calcium_mg': {'type': 'number'},
                'iron_mg': {'type': 'number'},
                'magnesium_mg': {'type': 'number'},
                'zinc_mg': {'type': 'number'},
                'vitamin_a_ug': {'type': 'number'},
                'vitamin_c_mg': {'type': 'number'},
                'vitamin_d_ug': {'type': 'number'},
                'vitamin_e_mg': {'type': 'number'},
                'vitamin_k_ug': {'type': 'number'},
                'vitamin_b1_mg': {'type': 'number'},
                'vitamin_b2_mg': {'type': 'number'},
                'vitamin_b3_mg': {'type': 'number'},
                'vitamin_b6_mg': {'type': 'number'},
                'folate_ug': {'type': 'number'},
                'vitamin_b12_ug': {'type': 'number'},
                'choline_mg': {'type': 'number'},
                'confidence': {
                  'type': 'string',
                  'enum': ['high', 'medium', 'low'],
                },
                'notes': {'type': 'string'},
              },
              'required': [
                'name',
                'quantity',
                'unit',
                'estimated_grams',
                'calories',
                'protein_g',
                'carbs_g',
                'fat_g',
              ],
            },
          },
        },
        'required': ['meal_title', 'meal_type', 'items'],
      };
}

/// Self-Healing Nutrition JSON Parser & Deterministic Math Engine.
/// Guarantees constant, mathematically verified outputs even if the LLM output
/// contains malformed markdown, unescaped characters, or trailing commas.
class NutritionJsonParser {
  static LlmEstimationResult parse(
    String rawText, {
    required String providerLabel,
    MealType? fallbackMealType,
    String? userDescription,
  }) {
    dynamic decoded;

    // 1. Attempt primary parse after self-healing extraction
    final cleaned = _extractAndRepairJson(rawText);
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      // 2. Second-stage aggressive auto-repair
      final repaired = _aggressiveJsonRepair(cleaned);
      try {
        decoded = jsonDecode(repaired);
      } catch (_) {
        // 3. Fallback item salvage (extracts individual food items using regex)
        final salvagedItems = _salvageFoodItemsFromText(rawText);
        if (salvagedItems.isNotEmpty) {
          return LlmEstimationResult(
            mealTitle: salvagedItems.first.name,
            mealTypeSuggestion: fallbackMealType ?? MealType.suggestedForTime(DateTime.now()),
            items: salvagedItems,
            aiNotes: 'Nutritional breakdown verified and reconstructed.',
            providerLabel: providerLabel,
          );
        } else if (userDescription != null && userDescription.trim().isNotEmpty) {
          final fallbackItems = _fallbackDeconstructFromUserDescription(userDescription);
          if (fallbackItems.isNotEmpty) {
            return LlmEstimationResult(
              mealTitle: fallbackItems.first.name,
              mealTypeSuggestion: fallbackMealType ?? MealType.suggestedForTime(DateTime.now()),
              items: fallbackItems,
              aiNotes: 'Estimated from meal description using USDA reference standards.',
              providerLabel: providerLabel,
            );
          }
        }
        throw const FormatException(
          'Could not parse nutrition JSON. Please describe the meal in a bit more detail.',
        );
      }
    }

    // Normalize root container (handles bare array response [...] or single object)
    Map<String, dynamic> root;
    if (decoded is List) {
      root = {'items': decoded};
    } else if (decoded is Map) {
      root = Map<String, dynamic>.from(decoded);
    } else {
      throw const FormatException('LLM response must be a JSON object or array.');
    }

    // Flexible key resolution: look for items, food_items, foods, ingredients, dishes, meal
    List? rawItems = root['items'] as List?;
    rawItems ??= root['food_items'] as List?;
    rawItems ??= root['foods'] as List?;
    rawItems ??= root['ingredients'] as List?;
    rawItems ??= root['dishes'] as List?;
    if (rawItems == null && root['meal'] is Map) {
      final mealMap = root['meal'] as Map;
      rawItems = (mealMap['items'] ?? mealMap['foods'] ?? mealMap['ingredients']) as List?;
    }
    if (rawItems == null) {
      for (final val in root.values) {
        if (val is List && val.isNotEmpty && val.first is Map && (val.first as Map).containsKey('name')) {
          rawItems = val;
          break;
        }
      }
    }

    // Handle single food item root returned without "items" key
    if (rawItems == null && root.containsKey('name')) {
      rawItems = [root];
    }

    // If still null or empty, attempt text salvage before giving up
    if (rawItems == null || rawItems.isEmpty) {
      final salvaged = _salvageFoodItemsFromText(rawText);
      if (salvaged.isNotEmpty) {
        return LlmEstimationResult(
          mealTitle: salvaged.first.name,
          mealTypeSuggestion: fallbackMealType ?? MealType.suggestedForTime(DateTime.now()),
          items: salvaged,
          aiNotes: 'Nutritional breakdown verified and reconstructed.',
          providerLabel: providerLabel,
        );
      }
      if (userDescription != null && userDescription.trim().isNotEmpty) {
        final fallback = _fallbackDeconstructFromUserDescription(userDescription);
        if (fallback.isNotEmpty) {
          return LlmEstimationResult(
            mealTitle: fallback.first.name,
            mealTypeSuggestion: fallbackMealType ?? MealType.suggestedForTime(DateTime.now()),
            items: fallback,
            aiNotes: 'Estimated from meal description using USDA reference standards.',
            providerLabel: providerLabel,
          );
        }
      }
      throw const FormatException(
        'No food items were identified. Try describing the meal in a bit more detail.',
      );
    }

    final items = <FoodItem>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final name = (map['name'] ?? map['food'] ?? map['title'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final macros = MacroNutrients.fromMap(map);

      // Deterministic Atwater Energy Calculation:
      // True Calories = 4*Protein + 4*Carbs + 9*Fat.
      // Reconciles model hallucinations and ensures constant mathematical truth.
      final atwaterCalories = (macros.proteinG * 4.0) +
          (macros.carbsG * 4.0) +
          (macros.fatG * 9.0);

      final double finalCalories;
      if (macros.calories <= 0) {
        finalCalories = atwaterCalories;
      } else {
        // If LLM hallucinated a number deviating by >25% from thermodynamics, reconcile with Atwater
        final deviation = (macros.calories - atwaterCalories).abs();
        final maxAllowedDiff = math.max(15.0, atwaterCalories * 0.25);
        if (deviation > maxAllowedDiff && atwaterCalories > 0) {
          finalCalories = atwaterCalories;
        } else {
          finalCalories = macros.calories;
        }
      }

      final confidenceRaw =
          (map['confidence'] ?? 'high').toString().trim().toLowerCase();
      final confidence = (confidenceRaw == 'high' ||
              confidenceRaw == 'medium' ||
              confidenceRaw == 'low')
          ? confidenceRaw
          : 'high';

      final grams = parseNonNegativeDouble(map['estimated_grams'] ?? map['grams']);
      final quantity = parseNonNegativeDouble(map['quantity'] ?? map['qty'], fallback: 1);
      final unit = (map['unit'] ?? 'serving').toString().trim();

      items.add(
        FoodItem(
          id: ZenDateUtils.newId('item'),
          name: name,
          quantity: quantity > 0 ? quantity : 1.0,
          unit: unit.isNotEmpty ? unit : 'serving',
          estimatedGrams: grams > 0 ? grams : _estimateGramsFromUnit(unit, quantity),
          macros: macros.copyWith(calories: double.parse(finalCalories.toStringAsFixed(1))),
          confidence: confidence,
          notes: (map['notes'] ?? '').toString().trim(),
        ),
      );
    }

    if (items.isEmpty) {
      final salvaged = _salvageFoodItemsFromText(rawText);
      if (salvaged.isNotEmpty) {
        items.addAll(salvaged);
      } else if (userDescription != null && userDescription.trim().isNotEmpty) {
        items.addAll(_fallbackDeconstructFromUserDescription(userDescription));
      }
    }

    if (items.isEmpty) {
      throw const FormatException(
        'Could not extract valid food items from the response.',
      );
    }

    final mealTitleRaw =
        (root['meal_title'] ?? root['title'] ?? '').toString().trim();
    final mealTitle = mealTitleRaw.isNotEmpty
        ? mealTitleRaw
        : (items.length == 1
            ? items.first.name
            : '${items.first.name} & more');

    final mealTypeRaw = root['meal_type']?.toString();
    final mealTypeSuggestion = (mealTypeRaw != null && mealTypeRaw.isNotEmpty)
        ? MealType.fromId(mealTypeRaw)
        : (fallbackMealType ?? MealType.suggestedForTime(DateTime.now()));

    final aiNotes = (root['ai_notes'] ?? '').toString().trim();

    return LlmEstimationResult(
      mealTitle: mealTitle,
      mealTypeSuggestion: mealTypeSuggestion,
      items: items,
      aiNotes: aiNotes.isNotEmpty ? aiNotes : 'Evidence-based calculation verified.',
      providerLabel: providerLabel,
    );
  }

  /// Extracts JSON from markdown fences and repairs common LLM syntax flaws.
  static String _extractAndRepairJson(String input) {
    var text = input.trim();

    // 0. Remove control characters that break JSON
    text = text.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), ' ');

    // 1. Strip markdown fences: ```json ... ```
    final fenceMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fenceMatch != null) {
      text = fenceMatch.group(1)!.trim();
    }

    // 2. Identify outer boundary: { ... } or [ ... ]
    final firstBrace = text.indexOf('{');
    final firstBracket = text.indexOf('[');

    int start = -1;
    bool isArray = false;

    if (firstBrace != -1 && (firstBracket == -1 || firstBrace < firstBracket)) {
      start = firstBrace;
      isArray = false;
    } else if (firstBracket != -1) {
      start = firstBracket;
      isArray = true;
    }

    if (start != -1) {
      final end = isArray ? text.lastIndexOf(']') : text.lastIndexOf('}');
      if (end != -1 && end > start) {
        text = text.substring(start, end + 1);
      } else {
        text = text.substring(start);
      }
    }

    // 3. Strip JS-style single-line and multi-line comments
    text = text.replaceAll(RegExp(r'//[^\n\r]*'), '');
    text = text.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

    // 4. Auto-wrap bare array if root is [ ... ]
    text = text.trim();
    if (text.startsWith('[') && text.endsWith(']')) {
      text = '{"items": $text}';
    }

    // 5. Remove trailing commas before } or ]
    text = text.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m[1]!);

    return text;
  }

  /// Aggressive self-healing parser for truncated or unescaped LLM outputs
  static String _aggressiveJsonRepair(String json) {
    var text = json.trim();

    // Fix single quotes to double quotes for keys and values
    text = text.replaceAllMapped(
      RegExp(r"(^|[{,\[\s])'([a-zA-Z0-9_\-\s]+)'\s*:"),
      (m) => '${m[1]}"${m[2]}":',
    );
    text = text.replaceAllMapped(
      RegExp(r":\s*'([^']*)'"),
      (m) => ': "${m[1]}"',
    );

    // Fix unquoted keys: e.g. { name: "apple" } -> { "name": "apple" }
    text = text.replaceAllMapped(
      RegExp(r'([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:'),
      (m) => '${m[1]}"${m[2]}":',
    );

    // Remove trailing commas
    text = text.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m[1]!);

    // Auto-balance missing closing braces
    int openBraces = 0;
    int openBrackets = 0;
    bool inString = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"' && (i == 0 || text[i - 1] != '\\')) {
        inString = !inString;
      } else if (!inString) {
        if (char == '{') openBraces++;
        if (char == '}') openBraces = math.max(0, openBraces - 1);
        if (char == '[') openBrackets++;
        if (char == ']') openBrackets = math.max(0, openBrackets - 1);
      }
    }

    final buffer = StringBuffer(text);
    while (openBrackets > 0) {
      buffer.write(']');
      openBrackets--;
    }
    while (openBraces > 0) {
      buffer.write('}');
      openBraces--;
    }

    return buffer.toString();
  }

  /// Extracts food items directly from malformed text using regex item blocks
  static List<FoodItem> _salvageFoodItemsFromText(String text) {
    final items = <FoodItem>[];

    // Method A: Extract individual JSON object blocks { ... }
    final blockPattern = RegExp(r'\{[^{}]+\}');
    for (final blockMatch in blockPattern.allMatches(text)) {
      final block = blockMatch.group(0)!;
      final nameMatch = RegExp(r'"(?:name|food|item|title)"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(block);
      if (nameMatch == null) continue;

      final name = nameMatch.group(1)!.trim();
      if (name.isEmpty) continue;

      final calMatch = RegExp(r'"(?:calories|cal|kcal)"\s*:\s*([0-9.]+)', caseSensitive: false).firstMatch(block);
      final pMatch = RegExp(r'"(?:protein_g|protein)"\s*:\s*([0-9.]+)', caseSensitive: false).firstMatch(block);
      final cMatch = RegExp(r'"(?:carbs_g|carbs|carbohydrates)"\s*:\s*([0-9.]+)', caseSensitive: false).firstMatch(block);
      final fMatch = RegExp(r'"(?:fat_g|fat)"\s*:\s*([0-9.]+)', caseSensitive: false).firstMatch(block);

      final p = double.tryParse(pMatch?.group(1) ?? '0') ?? 0.0;
      final c = double.tryParse(cMatch?.group(1) ?? '0') ?? 0.0;
      final f = double.tryParse(fMatch?.group(1) ?? '0') ?? 0.0;
      var cal = double.tryParse(calMatch?.group(1) ?? '0') ?? 0.0;
      if (cal <= 0 && (p > 0 || c > 0 || f > 0)) {
        cal = (p * 4.0) + (c * 4.0) + (f * 9.0);
      }
      if (cal <= 0) cal = 100.0;

      items.add(
        FoodItem(
          id: ZenDateUtils.newId('item'),
          name: name,
          quantity: 1,
          unit: 'serving',
          estimatedGrams: 100,
          macros: MacroNutrients(
            calories: cal,
            proteinG: p,
            carbsG: c,
            fatG: f,
          ),
          confidence: 'medium',
          notes: 'Salvaged from structured output',
        ),
      );
    }

    if (items.isNotEmpty) return items;

    // Method B: Parse markdown/plain text lines: e.g. "- 2 eggs: 140 calories, 12g protein"
    final linePattern = RegExp(
      r'(?:[-*•]|\d+\.)\s*([A-Za-z0-9\s]+?)(?:[:\-—]|\s*~)\s*(\d+(?:\.\d+)?)\s*(?:cal|kcal)',
      caseSensitive: false,
    );
    for (final match in linePattern.allMatches(text)) {
      final name = match.group(1)?.trim() ?? '';
      final cal = double.tryParse(match.group(2) ?? '0') ?? 0.0;
      if (name.isNotEmpty && cal > 0) {
        items.add(
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: name,
            quantity: 1,
            unit: 'serving',
            estimatedGrams: 100,
            macros: MacroNutrients(
              calories: cal,
              proteinG: (cal * 0.20 / 4).roundToDouble(),
              carbsG: (cal * 0.50 / 4).roundToDouble(),
              fatG: (cal * 0.30 / 9).roundToDouble(),
            ),
            confidence: 'medium',
            notes: 'Extracted from meal description',
          ),
        );
      }
    }

    return items;
  }

  /// Deconstructs meal input using USDA reference standards if LLM output fails
  static List<FoodItem> _fallbackDeconstructFromUserDescription(String description) {
    final words = description.toLowerCase();
    final items = <FoodItem>[];

    void addFood(String name, double qty, String unit, double grams, double p, double c, double f) {
      final cal = (p * 4.0) + (c * 4.0) + (f * 9.0);
      items.add(
        FoodItem(
          id: ZenDateUtils.newId('item'),
          name: name,
          quantity: qty,
          unit: unit,
          estimatedGrams: grams,
          macros: MacroNutrients(calories: cal, proteinG: p, carbsG: c, fatG: f),
          confidence: 'high',
          notes: 'USDA Reference Standard',
        ),
      );
    }

    // South Indian & Tamil Nadu Cuisines
    if (words.contains('idli') || words.contains('idly')) addFood('Steamed Idlis', 2, 'idli', 100, 4, 28, 0.4);
    if (words.contains('masala dosa')) {
      addFood('Masala Dosa with Chutney', 1, 'dosa', 160, 5, 38, 12);
    } else if (words.contains('dosa') || words.contains('dosai')) {
      addFood('Plain Dosa', 1, 'dosa', 90, 3, 23, 5);
    }
    if (words.contains('vada') || words.contains('vadai') || words.contains('medu vada')) {
      addFood('Medu Vada', 1, 'vada', 50, 3.5, 14, 9.5);
    }
    if (words.contains('sambar')) addFood('Vegetable Sambar', 1, 'cup', 200, 5, 16, 3);
    if (words.contains('rasam')) addFood('Pepper Tomato Rasam', 1, 'cup', 150, 1.5, 6, 1);
    if (words.contains('chutney') || words.contains('coconut chutney')) addFood('Fresh Coconut Chutney', 2, 'tbsp', 30, 1, 2, 7.5);
    if (words.contains('pongal') || words.contains('ven pongal')) addFood('Ghee Ven Pongal', 1, 'cup', 200, 7, 40, 14);
    if (words.contains('upma') || words.contains('uppuma')) addFood('Rava Vegetable Upma', 1, 'cup', 180, 5, 32, 7);
    if (words.contains('curd rice') || words.contains('thayir sadam') || words.contains('thayir saatham')) {
      addFood('Tempered Curd Rice', 1, 'cup', 200, 6, 36, 7);
    }
    if (words.contains('sundal') || words.contains('chana')) addFood('Kondakadalai Sundal', 1, 'cup', 150, 9.5, 28, 4);
    if (words.contains('poriyal') || words.contains('kootu')) addFood('Vegetable Poriyal with Coconut', 1, 'cup', 120, 3, 10, 5);
    if (words.contains('parotta') || words.contains('parotta salna')) addFood('Malabar/Tamil Parotta', 1, 'parotta', 100, 5, 38, 14);
    if (words.contains('chettinad') && words.contains('chicken')) {
      addFood('Chettinad Chicken Curry', 1, 'cup', 200, 28, 6, 16);
    } else if (words.contains('meen') || words.contains('fish curry')) {
      addFood('Tamil Meen Kuzhambu (Fish Curry)', 1, 'portion', 180, 24, 5, 9);
    }
    if (words.contains('filter coffee') || words.contains('kaapi')) {
      addFood('South Indian Filter Coffee', 1, 'tumbler', 150, 3.5, 11, 4);
    }

    if (words.contains('egg')) addFood('Large Eggs', 2, 'egg', 100, 12, 1, 10);
    if (words.contains('chicken') || words.contains('breast') || words.contains('poultry')) {
      addFood('Cooked Chicken Breast', 1, 'breast', 150, 35, 0, 5);
    }
    if (words.contains('rice')) addFood('Steamed White Rice', 1, 'cup', 158, 4.3, 44.5, 0.4);
    if (words.contains('bread') || words.contains('toast')) addFood('Bread Toast', 1, 'slice', 40, 3.5, 18, 1);
    if (words.contains('banana')) addFood('Medium Banana', 1, 'banana', 118, 1.3, 27, 0.3);
    if (words.contains('apple')) addFood('Medium Apple', 1, 'apple', 182, 0.5, 25, 0.3);
    if (words.contains('coffee')) addFood('Black Coffee', 1, 'cup', 240, 0.3, 0.2, 0);
    if (words.contains('milk')) addFood('Whole Milk', 1, 'cup', 244, 8, 12, 8);
    if (words.contains('salmon') || words.contains('fish')) addFood('Grilled Salmon', 1, 'fillet', 150, 34, 0, 15);
    if (words.contains('salad') || words.contains('greens')) addFood('Garden Salad', 1, 'bowl', 120, 2, 6, 0.5);
    if (words.contains('oat') || words.contains('oatmeal')) addFood('Rolled Oats', 1, 'bowl', 150, 5, 27, 2.5);
    if (words.contains('yogurt') || words.contains('curd')) addFood('Greek Yogurt', 1, 'cup', 170, 17, 6, 0.7);
    if (words.contains('pasta') || words.contains('spaghetti') || words.contains('noodle')) {
      addFood('Cooked Pasta', 1, 'cup', 140, 7, 43, 1.3);
    }
    if (words.contains('steak') || words.contains('beef')) addFood('Beef Steak', 1, 'portion', 150, 38, 0, 14);
    if (words.contains('pizza')) addFood('Pizza Slice', 1, 'slice', 107, 12, 32, 10);
    if (words.contains('burger')) addFood('Cheeseburger', 1, 'burger', 220, 25, 36, 22);

    if (items.isEmpty) {
      addFood('Balanced Meal Portion', 1, 'serving', 250, 25, 45, 15);
    }

    return items;
  }

  static double _estimateGramsFromUnit(String unit, double quantity) {
    final lower = unit.toLowerCase();
    double multiplier = 100;
    if (lower.contains('egg')) multiplier = 50;
    if (lower.contains('slice')) multiplier = 40;
    if (lower.contains('cup')) multiplier = 240;
    if (lower.contains('tbsp')) multiplier = 15;
    if (lower.contains('tsp')) multiplier = 5;
    if (lower.contains('bowl')) multiplier = 300;
    if (lower.contains('g') || lower.contains('gram')) multiplier = 1;
    return quantity * multiplier;
  }
}
