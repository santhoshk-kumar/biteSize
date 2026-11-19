import '../services/date_utils.dart';
import 'nutrition.dart';

/// Reusable multi-item saved meal combo (e.g. "Mom's Sunday Lunch", "Post-Workout Smoothie").
/// Allows 1-tap logging of complete custom food combinations.
class SavedMealCombo {
  const SavedMealCombo({
    required this.id,
    required this.name,
    this.icon = '🍱',
    this.mealType = MealType.lunch,
    required this.items,
    this.notes = '',
  });

  final String id;
  final String name;
  final String icon;
  final MealType mealType;
  final List<FoodItem> items;
  final String notes;

  MacroNutrients get totalMacros {
    var total = MacroNutrients.zero;
    for (final item in items) {
      total = total + item.macros;
    }
    return total;
  }

  /// Converts this combo into a live MealEntry for today's log.
  MealEntry toMealEntry({required String dateKey}) {
    final now = DateTime.now();
    return MealEntry(
      id: ZenDateUtils.newId('meal'),
      dateKey: dateKey,
      loggedAt: now,
      mealType: mealType,
      title: name,
      rawInput: 'Saved Combo: $name',
      items: items
          .map((item) => item.copyWith(id: ZenDateUtils.newId('item')))
          .toList(),
      providerUsed: 'BiteSize Combo',
      aiNotes: notes.isNotEmpty ? notes : '1-tap saved combo meal',
    );
  }

  /// Creates a SavedMealCombo directly from a logged MealEntry.
  factory SavedMealCombo.fromMealEntry(MealEntry meal, {String? customName, String? icon}) {
    return SavedMealCombo(
      id: ZenDateUtils.newId('combo'),
      name: customName ?? meal.title,
      icon: icon ?? '🍱',
      mealType: meal.mealType,
      items: meal.items
          .map((it) => it.copyWith(id: ZenDateUtils.newId('item')))
          .toList(),
      notes: meal.aiNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'mealType': mealType.name,
      'items': items.map((item) => item.toMap()).toList(),
      'notes': notes,
    };
  }

  factory SavedMealCombo.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return SavedMealCombo(
      id: json['id'] as String? ?? ZenDateUtils.newId('combo'),
      name: json['name'] as String? ?? 'Saved Combo',
      icon: json['icon'] as String? ?? '🍱',
      mealType: MealType.values.firstWhere(
        (t) => t.name == json['mealType'],
        orElse: () => MealType.lunch,
      ),
      items: rawItems
          .map((e) => FoodItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String? ?? '',
    );
  }

  SavedMealCombo copyWith({
    String? id,
    String? name,
    String? icon,
    MealType? mealType,
    List<FoodItem>? items,
    String? notes,
  }) {
    return SavedMealCombo(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      mealType: mealType ?? this.mealType,
      items: items ?? this.items,
      notes: notes ?? this.notes,
    );
  }
}

