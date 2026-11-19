import 'package:flutter/foundation.dart';
import 'nutrition.dart';

/// Preset popular snack or meal component for instantaneous 1-tap logging.
@immutable
class QuickBitePreset {
  const QuickBitePreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.portion,
    required this.estimatedGrams,
    required this.macros,
    required this.mealType,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String icon;
  final String portion;
  final double estimatedGrams;
  final MacroNutrients macros;
  final MealType mealType;
  final bool isCustom;

  QuickBitePreset copyWith({
    String? id,
    String? name,
    String? icon,
    String? portion,
    double? estimatedGrams,
    MacroNutrients? macros,
    MealType? mealType,
    bool? isCustom,
  }) {
    return QuickBitePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      portion: portion ?? this.portion,
      estimatedGrams: estimatedGrams ?? this.estimatedGrams,
      macros: macros ?? this.macros,
      mealType: mealType ?? this.mealType,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'portion': portion,
        'estimatedGrams': estimatedGrams,
        'macros': macros.toMap(),
        'mealType': mealType.id,
        'isCustom': isCustom,
      };

  factory QuickBitePreset.fromJson(Map<String, dynamic> json) {
    return QuickBitePreset(
      id: json['id'] as String? ?? 'qb_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Custom Bite',
      icon: json['icon'] as String? ?? '🍽️',
      portion: json['portion'] as String? ?? '1 serving',
      estimatedGrams: (json['estimatedGrams'] as num?)?.toDouble() ?? 100.0,
      macros: json['macros'] is Map<String, dynamic>
          ? MacroNutrients.fromMap(json['macros'] as Map<String, dynamic>)
          : MacroNutrients(calories: (json['calories'] as num?)?.toDouble() ?? 100),
      mealType: MealType.fromId(json['mealType'] as String?),
      isCustom: json['isCustom'] as bool? ?? true,
    );
  }

  /// Creates a custom quick bite from an existing logged meal.
  factory QuickBitePreset.fromMealEntry(MealEntry meal, {String? icon}) {
    final totalGrams = meal.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.estimatedGrams > 0 ? item.estimatedGrams : 100.0),
    );
    final defaultIcon = switch (meal.mealType) {
      MealType.breakfast => '🥞',
      MealType.lunch => '🍛',
      MealType.dinner => '🍲',
      MealType.snack => '🥪',
    };

    return QuickBitePreset(
      id: 'qb_custom_${DateTime.now().millisecondsSinceEpoch}',
      name: meal.title.isNotEmpty ? meal.title : 'My Saved Meal',
      icon: icon ?? defaultIcon,
      portion: meal.items.length > 1 ? '${meal.items.length} items' : '1 meal',
      estimatedGrams: totalGrams > 0 ? totalGrams : 250.0,
      macros: meal.totalMacros,
      mealType: meal.mealType,
      isCustom: true,
    );
  }

  static const List<QuickBitePreset> defaultPresets = [
    QuickBitePreset(
      id: 'qb_idli_sambar',
      name: '2 Idli + Sambar',
      icon: '🥞',
      portion: '2 idlis + 1 cup sambar',
      estimatedGrams: 300,
      macros: MacroNutrients(
        calories: 220,
        proteinG: 8.5,
        carbsG: 42,
        fatG: 3.5,
        fiberG: 4.8,
        calciumMg: 45,
        ironMg: 2.1,
      ),
      mealType: MealType.breakfast,
    ),
    QuickBitePreset(
      id: 'qb_masala_dosa',
      name: 'Masala Dosa',
      icon: '🫓',
      portion: '1 dosa + chutney',
      estimatedGrams: 200,
      macros: MacroNutrients(
        calories: 285,
        proteinG: 6,
        carbsG: 39,
        fatG: 12,
        fiberG: 3.5,
        potassiumMg: 240,
      ),
      mealType: MealType.breakfast,
    ),
    QuickBitePreset(
      id: 'qb_sundal',
      name: 'Chana Sundal',
      icon: '🧆',
      portion: '1 cup boiled (150g)',
      estimatedGrams: 150,
      macros: MacroNutrients(
        calories: 195,
        proteinG: 10.5,
        carbsG: 28,
        fatG: 4.5,
        fiberG: 7.2,
        ironMg: 2.8,
      ),
      mealType: MealType.snack,
    ),
    QuickBitePreset(
      id: 'qb_curd_rice',
      name: 'Curd Rice',
      icon: '🍚',
      portion: '1 bowl (200g)',
      estimatedGrams: 200,
      macros: MacroNutrients(
        calories: 235,
        proteinG: 6.5,
        carbsG: 36,
        fatG: 7,
        calciumMg: 150,
        sodiumMg: 180,
      ),
      mealType: MealType.lunch,
    ),
    QuickBitePreset(
      id: 'qb_filter_coffee',
      name: 'Filter Coffee',
      icon: '☕',
      portion: '1 tumbler (150ml)',
      estimatedGrams: 150,
      macros: MacroNutrients(
        calories: 105,
        proteinG: 3.8,
        carbsG: 11.5,
        fatG: 4.2,
        calciumMg: 120,
      ),
      mealType: MealType.snack,
    ),
    QuickBitePreset(
      id: 'qb_whey',
      name: 'Whey Protein',
      icon: '🥤',
      portion: '1 scoop (30g)',
      estimatedGrams: 30,
      macros: MacroNutrients(
        calories: 120,
        proteinG: 24,
        carbsG: 2,
        fatG: 1.5,
        calciumMg: 140,
        sodiumMg: 150,
      ),
      mealType: MealType.snack,
    ),
    QuickBitePreset(
      id: 'qb_eggs',
      name: '2 Boiled Eggs',
      icon: '🥚',
      portion: '2 large eggs',
      estimatedGrams: 100,
      macros: MacroNutrients(
        calories: 143,
        proteinG: 12.6,
        carbsG: 0.7,
        fatG: 9.5,
        vitaminDUg: 2.2,
        vitaminB12Ug: 1.1,
        ironMg: 1.8,
        cholineMg: 294,
      ),
      mealType: MealType.breakfast,
    ),
    QuickBitePreset(
      id: 'qb_banana',
      name: 'Banana',
      icon: '🍌',
      portion: '1 medium (118g)',
      estimatedGrams: 118,
      macros: MacroNutrients(
        calories: 105,
        proteinG: 1.3,
        carbsG: 27,
        fatG: 0.3,
        fiberG: 3.1,
        sugarG: 14.4,
        potassiumMg: 422,
        vitaminCMg: 10.3,
        vitaminB6Mg: 0.4,
      ),
      mealType: MealType.snack,
    ),
    QuickBitePreset(
      id: 'qb_oat_latte',
      name: 'Iced Oat Latte',
      icon: '☕',
      portion: '1 medium cup',
      estimatedGrams: 350,
      macros: MacroNutrients(
        calories: 130,
        proteinG: 3,
        carbsG: 19,
        fatG: 5,
        fiberG: 1.5,
        calciumMg: 280,
      ),
      mealType: MealType.snack,
    ),
    QuickBitePreset(
      id: 'qb_greek_yogurt',
      name: 'Greek Yogurt',
      icon: '🥣',
      portion: '3/4 cup (170g)',
      estimatedGrams: 170,
      macros: MacroNutrients(
        calories: 100,
        proteinG: 17,
        carbsG: 6,
        fatG: 0.7,
        calciumMg: 187,
        vitaminB12Ug: 1.3,
      ),
      mealType: MealType.snack,
    ),
    QuickBitePreset(
      id: 'qb_almonds',
      name: 'Handful Almonds',
      icon: '🥜',
      portion: '1 oz (28g)',
      estimatedGrams: 28,
      macros: MacroNutrients(
        calories: 164,
        proteinG: 6,
        carbsG: 6.1,
        fatG: 14.2,
        fiberG: 3.5,
        magnesiumMg: 76,
        vitaminEMg: 7.3,
      ),
      mealType: MealType.snack,
    ),
  ];
}

