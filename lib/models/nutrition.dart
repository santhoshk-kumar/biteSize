/// Comprehensive nutritional values for a food item or aggregated meal/day,
/// including all major vitamins, minerals, and lipid/carbohydrate fractions.
class MacroNutrients {
  const MacroNutrients({
    // Core Macronutrients
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.fiberG = 0,
    this.sugarG = 0,
    this.saturatedFatG = 0,
    this.cholesterolMg = 0,

    // Minerals
    this.sodiumMg = 0,
    this.potassiumMg = 0,
    this.calciumMg = 0,
    this.ironMg = 0,
    this.magnesiumMg = 0,
    this.phosphorusMg = 0,
    this.zincMg = 0,
    this.copperMg = 0,
    this.manganeseMg = 0,
    this.seleniumUg = 0,

    // Vitamins
    this.vitaminAUg = 0,
    this.vitaminCMg = 0,
    this.vitaminDUg = 0,
    this.vitaminEMg = 0,
    this.vitaminKUg = 0,
    this.vitaminB1Mg = 0,
    this.vitaminB2Mg = 0,
    this.vitaminB3Mg = 0,
    this.vitaminB5Mg = 0,
    this.vitaminB6Mg = 0,
    this.vitaminB7Ug = 0,
    this.folateUg = 0,
    this.vitaminB12Ug = 0,
    this.cholineMg = 0,
  });

  static const MacroNutrients zero = MacroNutrients();

  // Core Macronutrients
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double saturatedFatG;
  final double cholesterolMg;

  // Minerals
  final double sodiumMg;
  final double potassiumMg;
  final double calciumMg;
  final double ironMg;
  final double magnesiumMg;
  final double phosphorusMg;
  final double zincMg;
  final double copperMg;
  final double manganeseMg;
  final double seleniumUg;

  // Vitamins
  final double vitaminAUg;
  final double vitaminCMg;
  final double vitaminDUg;
  final double vitaminEMg;
  final double vitaminKUg;
  final double vitaminB1Mg;
  final double vitaminB2Mg;
  final double vitaminB3Mg;
  final double vitaminB5Mg;
  final double vitaminB6Mg;
  final double vitaminB7Ug;
  final double folateUg;
  final double vitaminB12Ug;
  final double cholineMg;

  MacroNutrients operator +(MacroNutrients other) {
    return MacroNutrients(
      calories: calories + other.calories,
      proteinG: proteinG + other.proteinG,
      carbsG: carbsG + other.carbsG,
      fatG: fatG + other.fatG,
      fiberG: fiberG + other.fiberG,
      sugarG: sugarG + other.sugarG,
      saturatedFatG: saturatedFatG + other.saturatedFatG,
      cholesterolMg: cholesterolMg + other.cholesterolMg,

      sodiumMg: sodiumMg + other.sodiumMg,
      potassiumMg: potassiumMg + other.potassiumMg,
      calciumMg: calciumMg + other.calciumMg,
      ironMg: ironMg + other.ironMg,
      magnesiumMg: magnesiumMg + other.magnesiumMg,
      phosphorusMg: phosphorusMg + other.phosphorusMg,
      zincMg: zincMg + other.zincMg,
      copperMg: copperMg + other.copperMg,
      manganeseMg: manganeseMg + other.manganeseMg,
      seleniumUg: seleniumUg + other.seleniumUg,

      vitaminAUg: vitaminAUg + other.vitaminAUg,
      vitaminCMg: vitaminCMg + other.vitaminCMg,
      vitaminDUg: vitaminDUg + other.vitaminDUg,
      vitaminEMg: vitaminEMg + other.vitaminEMg,
      vitaminKUg: vitaminKUg + other.vitaminKUg,
      vitaminB1Mg: vitaminB1Mg + other.vitaminB1Mg,
      vitaminB2Mg: vitaminB2Mg + other.vitaminB2Mg,
      vitaminB3Mg: vitaminB3Mg + other.vitaminB3Mg,
      vitaminB5Mg: vitaminB5Mg + other.vitaminB5Mg,
      vitaminB6Mg: vitaminB6Mg + other.vitaminB6Mg,
      vitaminB7Ug: vitaminB7Ug + other.vitaminB7Ug,
      folateUg: folateUg + other.folateUg,
      vitaminB12Ug: vitaminB12Ug + other.vitaminB12Ug,
      cholineMg: cholineMg + other.cholineMg,
    );
  }

  /// Scales every macro and micronutrient by [factor], clamped at 0.
  MacroNutrients scale(double factor) {
    final safe = factor < 0 ? 0.0 : factor;
    return MacroNutrients(
      calories: _round1(calories * safe),
      proteinG: _round1(proteinG * safe),
      carbsG: _round1(carbsG * safe),
      fatG: _round1(fatG * safe),
      fiberG: _round1(fiberG * safe),
      sugarG: _round1(sugarG * safe),
      saturatedFatG: _round1(saturatedFatG * safe),
      cholesterolMg: _round1(cholesterolMg * safe),

      sodiumMg: _round1(sodiumMg * safe),
      potassiumMg: _round1(potassiumMg * safe),
      calciumMg: _round1(calciumMg * safe),
      ironMg: _round1(ironMg * safe),
      magnesiumMg: _round1(magnesiumMg * safe),
      phosphorusMg: _round1(phosphorusMg * safe),
      zincMg: _round1(zincMg * safe),
      copperMg: _round1(copperMg * safe),
      manganeseMg: _round1(manganeseMg * safe),
      seleniumUg: _round1(seleniumUg * safe),

      vitaminAUg: _round1(vitaminAUg * safe),
      vitaminCMg: _round1(vitaminCMg * safe),
      vitaminDUg: _round1(vitaminDUg * safe),
      vitaminEMg: _round1(vitaminEMg * safe),
      vitaminKUg: _round1(vitaminKUg * safe),
      vitaminB1Mg: _round1(vitaminB1Mg * safe),
      vitaminB2Mg: _round1(vitaminB2Mg * safe),
      vitaminB3Mg: _round1(vitaminB3Mg * safe),
      vitaminB5Mg: _round1(vitaminB5Mg * safe),
      vitaminB6Mg: _round1(vitaminB6Mg * safe),
      vitaminB7Ug: _round1(vitaminB7Ug * safe),
      folateUg: _round1(folateUg * safe),
      vitaminB12Ug: _round1(vitaminB12Ug * safe),
      cholineMg: _round1(cholineMg * safe),
    );
  }

  MacroNutrients copyWith({
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    double? sugarG,
    double? saturatedFatG,
    double? cholesterolMg,
    double? sodiumMg,
    double? potassiumMg,
    double? calciumMg,
    double? ironMg,
    double? magnesiumMg,
    double? phosphorusMg,
    double? zincMg,
    double? copperMg,
    double? manganeseMg,
    double? seleniumUg,
    double? vitaminAUg,
    double? vitaminCMg,
    double? vitaminDUg,
    double? vitaminEMg,
    double? vitaminKUg,
    double? vitaminB1Mg,
    double? vitaminB2Mg,
    double? vitaminB3Mg,
    double? vitaminB5Mg,
    double? vitaminB6Mg,
    double? vitaminB7Ug,
    double? folateUg,
    double? vitaminB12Ug,
    double? cholineMg,
  }) {
    return MacroNutrients(
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      sugarG: sugarG ?? this.sugarG,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      cholesterolMg: cholesterolMg ?? this.cholesterolMg,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      potassiumMg: potassiumMg ?? this.potassiumMg,
      calciumMg: calciumMg ?? this.calciumMg,
      ironMg: ironMg ?? this.ironMg,
      magnesiumMg: magnesiumMg ?? this.magnesiumMg,
      phosphorusMg: phosphorusMg ?? this.phosphorusMg,
      zincMg: zincMg ?? this.zincMg,
      copperMg: copperMg ?? this.copperMg,
      manganeseMg: manganeseMg ?? this.manganeseMg,
      seleniumUg: seleniumUg ?? this.seleniumUg,
      vitaminAUg: vitaminAUg ?? this.vitaminAUg,
      vitaminCMg: vitaminCMg ?? this.vitaminCMg,
      vitaminDUg: vitaminDUg ?? this.vitaminDUg,
      vitaminEMg: vitaminEMg ?? this.vitaminEMg,
      vitaminKUg: vitaminKUg ?? this.vitaminKUg,
      vitaminB1Mg: vitaminB1Mg ?? this.vitaminB1Mg,
      vitaminB2Mg: vitaminB2Mg ?? this.vitaminB2Mg,
      vitaminB3Mg: vitaminB3Mg ?? this.vitaminB3Mg,
      vitaminB5Mg: vitaminB5Mg ?? this.vitaminB5Mg,
      vitaminB6Mg: vitaminB6Mg ?? this.vitaminB6Mg,
      vitaminB7Ug: vitaminB7Ug ?? this.vitaminB7Ug,
      folateUg: folateUg ?? this.folateUg,
      vitaminB12Ug: vitaminB12Ug ?? this.vitaminB12Ug,
      cholineMg: cholineMg ?? this.cholineMg,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'sugar_g': sugarG,
      'saturated_fat_g': saturatedFatG,
      'cholesterol_mg': cholesterolMg,
      'sodium_mg': sodiumMg,
      'potassium_mg': potassiumMg,
      'calcium_mg': calciumMg,
      'iron_mg': ironMg,
      'magnesium_mg': magnesiumMg,
      'phosphorus_mg': phosphorusMg,
      'zinc_mg': zincMg,
      'copper_mg': copperMg,
      'manganese_mg': manganeseMg,
      'selenium_ug': seleniumUg,
      'vitamin_a_ug': vitaminAUg,
      'vitamin_c_mg': vitaminCMg,
      'vitamin_d_ug': vitaminDUg,
      'vitamin_e_mg': vitaminEMg,
      'vitamin_k_ug': vitaminKUg,
      'vitamin_b1_mg': vitaminB1Mg,
      'vitamin_b2_mg': vitaminB2Mg,
      'vitamin_b3_mg': vitaminB3Mg,
      'vitamin_b5_mg': vitaminB5Mg,
      'vitamin_b6_mg': vitaminB6Mg,
      'vitamin_b7_ug': vitaminB7Ug,
      'folate_ug': folateUg,
      'vitamin_b12_ug': vitaminB12Ug,
      'choline_mg': cholineMg,
    };
  }

  factory MacroNutrients.fromMap(Map<String, dynamic> map) {
    return MacroNutrients(
      calories: parseNonNegativeDouble(map['calories']),
      proteinG: parseNonNegativeDouble(map['protein_g'] ?? map['proteinG']),
      carbsG: parseNonNegativeDouble(map['carbs_g'] ?? map['carbsG']),
      fatG: parseNonNegativeDouble(map['fat_g'] ?? map['fatG']),
      fiberG: parseNonNegativeDouble(map['fiber_g'] ?? map['fiberG']),
      sugarG: parseNonNegativeDouble(map['sugar_g'] ?? map['sugarG']),
      saturatedFatG: parseNonNegativeDouble(map['saturated_fat_g'] ?? map['saturatedFatG']),
      cholesterolMg: parseNonNegativeDouble(map['cholesterol_mg'] ?? map['cholesterolMg']),
      sodiumMg: parseNonNegativeDouble(map['sodium_mg'] ?? map['sodiumMg']),
      potassiumMg: parseNonNegativeDouble(map['potassium_mg'] ?? map['potassiumMg']),
      calciumMg: parseNonNegativeDouble(map['calcium_mg'] ?? map['calciumMg']),
      ironMg: parseNonNegativeDouble(map['iron_mg'] ?? map['ironMg']),
      magnesiumMg: parseNonNegativeDouble(map['magnesium_mg'] ?? map['magnesiumMg']),
      phosphorusMg: parseNonNegativeDouble(map['phosphorus_mg'] ?? map['phosphorusMg']),
      zincMg: parseNonNegativeDouble(map['zinc_mg'] ?? map['zincMg']),
      copperMg: parseNonNegativeDouble(map['copper_mg'] ?? map['copperMg']),
      manganeseMg: parseNonNegativeDouble(map['manganese_mg'] ?? map['manganeseMg']),
      seleniumUg: parseNonNegativeDouble(map['selenium_ug'] ?? map['seleniumUg']),
      vitaminAUg: parseNonNegativeDouble(map['vitamin_a_ug'] ?? map['vitaminAUg']),
      vitaminCMg: parseNonNegativeDouble(map['vitamin_c_mg'] ?? map['vitaminCMg']),
      vitaminDUg: parseNonNegativeDouble(map['vitamin_d_ug'] ?? map['vitaminDUg']),
      vitaminEMg: parseNonNegativeDouble(map['vitamin_e_mg'] ?? map['vitaminEMg']),
      vitaminKUg: parseNonNegativeDouble(map['vitamin_k_ug'] ?? map['vitaminKUg']),
      vitaminB1Mg: parseNonNegativeDouble(map['vitamin_b1_mg'] ?? map['vitaminB1Mg']),
      vitaminB2Mg: parseNonNegativeDouble(map['vitamin_b2_mg'] ?? map['vitaminB2Mg']),
      vitaminB3Mg: parseNonNegativeDouble(map['vitamin_b3_mg'] ?? map['vitaminB3Mg']),
      vitaminB5Mg: parseNonNegativeDouble(map['vitamin_b5_mg'] ?? map['vitaminB5Mg']),
      vitaminB6Mg: parseNonNegativeDouble(map['vitamin_b6_mg'] ?? map['vitaminB6Mg']),
      vitaminB7Ug: parseNonNegativeDouble(map['vitamin_b7_ug'] ?? map['vitaminB7Ug']),
      folateUg: parseNonNegativeDouble(map['folate_ug'] ?? map['folateUg']),
      vitaminB12Ug: parseNonNegativeDouble(map['vitamin_b12_ug'] ?? map['vitaminB12Ug']),
      cholineMg: parseNonNegativeDouble(map['choline_mg'] ?? map['cholineMg']),
    );
  }

  /// Categorized breakdown of all vitamins with official FDA Daily Values (DV).
  List<NutrientDetail> get vitamins => [
        NutrientDetail(name: 'Vitamin A', amount: vitaminAUg, unit: 'µg RAE', dailyValue: 900),
        NutrientDetail(name: 'Vitamin C', amount: vitaminCMg, unit: 'mg', dailyValue: 90),
        NutrientDetail(name: 'Vitamin D', amount: vitaminDUg, unit: 'µg', dailyValue: 20),
        NutrientDetail(name: 'Vitamin E', amount: vitaminEMg, unit: 'mg', dailyValue: 15),
        NutrientDetail(name: 'Vitamin K', amount: vitaminKUg, unit: 'µg', dailyValue: 120),
        NutrientDetail(name: 'Thiamin (B1)', amount: vitaminB1Mg, unit: 'mg', dailyValue: 1.2),
        NutrientDetail(name: 'Riboflavin (B2)', amount: vitaminB2Mg, unit: 'mg', dailyValue: 1.3),
        NutrientDetail(name: 'Niacin (B3)', amount: vitaminB3Mg, unit: 'mg', dailyValue: 16),
        NutrientDetail(name: 'Pantothenic Acid (B5)', amount: vitaminB5Mg, unit: 'mg', dailyValue: 5),
        NutrientDetail(name: 'Vitamin B6', amount: vitaminB6Mg, unit: 'mg', dailyValue: 1.7),
        NutrientDetail(name: 'Biotin (B7)', amount: vitaminB7Ug, unit: 'µg', dailyValue: 30),
        NutrientDetail(name: 'Folate (B9)', amount: folateUg, unit: 'µg DFE', dailyValue: 400),
        NutrientDetail(name: 'Vitamin B12', amount: vitaminB12Ug, unit: 'µg', dailyValue: 2.4),
        NutrientDetail(name: 'Choline', amount: cholineMg, unit: 'mg', dailyValue: 550),
      ];

  /// Categorized breakdown of all essential minerals with official FDA Daily Values (DV).
  List<NutrientDetail> get minerals => [
        NutrientDetail(name: 'Calcium', amount: calciumMg, unit: 'mg', dailyValue: 1300),
        NutrientDetail(name: 'Iron', amount: ironMg, unit: 'mg', dailyValue: 18),
        NutrientDetail(name: 'Magnesium', amount: magnesiumMg, unit: 'mg', dailyValue: 420),
        NutrientDetail(name: 'Phosphorus', amount: phosphorusMg, unit: 'mg', dailyValue: 1250),
        NutrientDetail(name: 'Potassium', amount: potassiumMg, unit: 'mg', dailyValue: 4700),
        NutrientDetail(name: 'Sodium', amount: sodiumMg, unit: 'mg', dailyValue: 2300, isLimit: true),
        NutrientDetail(name: 'Zinc', amount: zincMg, unit: 'mg', dailyValue: 11),
        NutrientDetail(name: 'Copper', amount: copperMg, unit: 'mg', dailyValue: 0.9),
        NutrientDetail(name: 'Manganese', amount: manganeseMg, unit: 'mg', dailyValue: 2.3),
        NutrientDetail(name: 'Selenium', amount: seleniumUg, unit: 'µg', dailyValue: 55),
      ];

  /// Lipid and carbohydrate fractions.
  List<NutrientDetail> get lipidsAndCarbs => [
        NutrientDetail(name: 'Dietary Fiber', amount: fiberG, unit: 'g', dailyValue: 28),
        NutrientDetail(name: 'Total Sugar', amount: sugarG, unit: 'g', dailyValue: 50, isLimit: true),
        NutrientDetail(name: 'Saturated Fat', amount: saturatedFatG, unit: 'g', dailyValue: 20, isLimit: true),
        NutrientDetail(name: 'Cholesterol', amount: cholesterolMg, unit: 'mg', dailyValue: 300, isLimit: true),
      ];
}

/// A specific nutrient with unit and percentage of Daily Value (% DV).
class NutrientDetail {
  const NutrientDetail({
    required this.name,
    required this.amount,
    required this.unit,
    required this.dailyValue,
    this.isLimit = false,
  });

  final String name;
  final double amount;
  final String unit;
  final double dailyValue;
  final bool isLimit;

  double get percentageOfDv => dailyValue > 0 ? (amount / dailyValue) * 100 : 0.0;
}

/// Time-of-day meal category.
enum MealType {
  breakfast('breakfast', 'Breakfast'),
  lunch('lunch', 'Lunch'),
  dinner('dinner', 'Dinner'),
  snack('snack', 'Snack');

  const MealType(this.id, this.label);

  final String id;
  final String label;

  static MealType fromId(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final type in MealType.values) {
      if (type.id == normalized) return type;
    }
    return MealType.snack;
  }

  static MealType suggestedForTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 17 && hour < 22) return MealType.dinner;
    return MealType.snack;
  }
}

/// An individual food component within a meal.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.estimatedGrams,
    required this.macros,
    this.confidence = 'medium',
    this.notes = '',
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final double estimatedGrams;
  final MacroNutrients macros;
  final String confidence;
  final String notes;

  /// Returns a scaled copy of this item (portion multiplier).
  FoodItem scaleBy(double factor) {
    final safe = factor < 0 ? 0.0 : factor;
    return copyWith(
      quantity: _round2(quantity * safe),
      estimatedGrams: _round1(estimatedGrams * safe),
      macros: macros.scale(safe),
    );
  }

  String get formattedPortion {
    final qtyText =
        quantity == quantity.roundToDouble()
            ? quantity.toInt().toString()
            : quantity.toStringAsFixed(1);
    final gramsText =
        estimatedGrams > 0 ? ' (${estimatedGrams.round()}g)' : '';
    if (unit.trim().isEmpty) return '$qtyText$gramsText';
    return '$qtyText ${unit.trim()}$gramsText';
  }

  FoodItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    double? estimatedGrams,
    MacroNutrients? macros,
    String? confidence,
    String? notes,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedGrams: estimatedGrams ?? this.estimatedGrams,
      macros: macros ?? this.macros,
      confidence: confidence ?? this.confidence,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'estimatedGrams': estimatedGrams,
      'confidence': confidence,
      'notes': notes,
      'macros': macros.toMap(),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Food item').toString(),
      quantity: parseNonNegativeDouble(map['quantity'], fallback: 1),
      unit: (map['unit'] ?? 'serving').toString(),
      estimatedGrams: parseNonNegativeDouble(map['estimatedGrams'] ?? map['estimated_grams']),
      macros: map['macros'] is Map<String, dynamic>
          ? MacroNutrients.fromMap(map['macros'] as Map<String, dynamic>)
          : MacroNutrients.fromMap(map),
      confidence: (map['confidence'] ?? 'medium').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toDbMap({required String mealId, required int sortOrder}) {
    return {
      'id': id,
      'meal_id': mealId,
      'sort_order': sortOrder,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'estimated_grams': estimatedGrams,
      'confidence': confidence,
      'notes': notes,
      ...macros.toMap(),
    };
  }

  factory FoodItem.fromDbMap(Map<String, dynamic> map) {
    return FoodItem(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Food item').toString(),
      quantity: parseNonNegativeDouble(map['quantity'], fallback: 1),
      unit: (map['unit'] ?? 'serving').toString(),
      estimatedGrams: parseNonNegativeDouble(map['estimated_grams']),
      macros: MacroNutrients.fromMap(map),
      confidence: (map['confidence'] ?? 'medium').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

/// A saved meal entry in the daily food log.
class MealEntry {
  const MealEntry({
    required this.id,
    required this.dateKey,
    required this.loggedAt,
    required this.mealType,
    required this.title,
    required this.rawInput,
    required this.items,
    this.imagePath,
    this.providerUsed = '',
    this.aiNotes = '',
  });

  final String id;
  final String dateKey;
  final DateTime loggedAt;
  final MealType mealType;
  final String title;
  final String rawInput;
  final List<FoodItem> items;
  final String? imagePath;
  final String providerUsed;
  final String aiNotes;

  MacroNutrients get totalMacros {
    var total = MacroNutrients.zero;
    for (final item in items) {
      total = total + item.macros;
    }
    return total;
  }

  MealEntry copyWith({
    String? id,
    String? dateKey,
    DateTime? loggedAt,
    MealType? mealType,
    String? title,
    String? rawInput,
    List<FoodItem>? items,
    String? imagePath,
    String? providerUsed,
    String? aiNotes,
  }) {
    return MealEntry(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      loggedAt: loggedAt ?? this.loggedAt,
      mealType: mealType ?? this.mealType,
      title: title ?? this.title,
      rawInput: rawInput ?? this.rawInput,
      items: items ?? this.items,
      imagePath: imagePath ?? this.imagePath,
      providerUsed: providerUsed ?? this.providerUsed,
      aiNotes: aiNotes ?? this.aiNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateKey': dateKey,
      'loggedAt': loggedAt.millisecondsSinceEpoch,
      'mealType': mealType.name,
      'title': title,
      'rawInput': rawInput,
      'imagePath': imagePath,
      'providerUsed': providerUsed,
      'aiNotes': aiNotes,
      'items': items.map((it) => it.toMap()).toList(),
    };
  }

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return MealEntry(
      id: (map['id'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? map['date_key'] ?? '').toString(),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['loggedAt'] ?? map['logged_at'] as num?)?.toInt() ?? 0,
      ),
      mealType: MealType.fromId(map['mealType']?.toString() ?? map['meal_type']?.toString()),
      title: (map['title'] ?? 'Meal').toString(),
      rawInput: (map['rawInput'] ?? map['raw_input'] ?? '').toString(),
      imagePath: map['imagePath'] as String? ?? map['image_path'] as String?,
      providerUsed: (map['providerUsed'] ?? map['provider_used'] ?? '').toString(),
      aiNotes: (map['aiNotes'] ?? map['ai_notes'] ?? '').toString(),
      items: rawItems
          .map((e) => FoodItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'date_key': dateKey,
      'logged_at': loggedAt.millisecondsSinceEpoch,
      'meal_type': mealType.id,
      'title': title,
      'raw_input': rawInput,
      'image_path': imagePath,
      'provider_used': providerUsed,
      'ai_notes': aiNotes,
    };
  }

  factory MealEntry.fromDbMap(
    Map<String, dynamic> map,
    List<FoodItem> items,
  ) {
    return MealEntry(
      id: (map['id'] ?? '').toString(),
      dateKey: (map['date_key'] ?? '').toString(),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['logged_at'] as num?)?.toInt() ?? 0,
      ),
      mealType: MealType.fromId(map['meal_type']?.toString()),
      title: (map['title'] ?? 'Meal').toString(),
      rawInput: (map['raw_input'] ?? '').toString(),
      items: items,
      imagePath: map['image_path'] as String?,
      providerUsed: (map['provider_used'] ?? '').toString(),
      aiNotes: (map['ai_notes'] ?? '').toString(),
    );
  }
}

/// Output package returned by an LLM estimation call.
class LlmEstimationResult {
  const LlmEstimationResult({
    required this.mealTitle,
    required this.mealTypeSuggestion,
    required this.items,
    required this.providerLabel,
    this.aiNotes = '',
  });

  final String mealTitle;
  final MealType mealTypeSuggestion;
  final List<FoodItem> items;
  final String providerLabel;
  final String aiNotes;

  MacroNutrients get totalMacros {
    var total = MacroNutrients.zero;
    for (final item in items) {
      total = total + item.macros;
    }
    return total;
  }
}

double _round1(double val) => (val * 10).roundToDouble() / 10;
double _round2(double val) => (val * 100).roundToDouble() / 100;

double parseNonNegativeDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) {
    final v = value.toDouble();
    return v < 0 ? 0.0 : v;
  }
  if (value is String) {
    final clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = double.tryParse(clean);
    if (parsed == null || parsed < 0) return fallback;
    return parsed;
  }
  return fallback;
}
