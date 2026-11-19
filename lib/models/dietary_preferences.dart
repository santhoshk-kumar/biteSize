/// User dietary preferences and food avoidances/allergies.
/// Automatically steers LLM estimation, nutrition tips, and meal suggestions.
enum DietType {
  balanced('Balanced / Omnivore', 'No strict dietary restrictions'),
  vegetarian('Vegetarian', 'Lacto-vegetarian, plant foods, dairy, no meat/fish'),
  southIndian('South Indian Traditional', 'Traditional rice, lentils, sambar, rasam, curd, veg-centric'),
  eggetarian('Eggetarian', 'Vegetarian plus whole eggs'),
  vegan('Vegan', 'Strictly plant-based, no dairy, eggs, or animal products'),
  keto('Low-Carb / Keto', 'High healthy fat, moderate protein, very low carbohydrate (<50g)'),
  highProtein('High-Protein / Athletic', 'Prioritizes lean protein sources and muscle recovery');

  const DietType(this.label, this.description);

  final String label;
  final String description;

  static DietType fromId(String? id) {
    return DietType.values.firstWhere(
      (e) => e.name == id,
      orElse: () => DietType.balanced,
    );
  }
}

class DietaryPreferences {
  const DietaryPreferences({
    this.dietType = DietType.balanced,
    this.allergies = const [],
    this.customNote = '',
  });

  final DietType dietType;
  final List<String> allergies; // e.g. 'Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Low-Oil'
  final String customNote;

  /// Prompt directive injected into all LLM nutrition prompts.
  String get promptDirective {
    final buffer = StringBuffer();
    buffer.writeln('USER DIETARY PROFILE:');
    buffer.writeln('- Diet Philosophy: ${dietType.label} (${dietType.description})');
    if (allergies.isNotEmpty) {
      buffer.writeln('- Avoidances/Allergies: ${allergies.join(', ')}');
    }
    if (customNote.trim().isNotEmpty) {
      buffer.writeln('- Specific User Note: ${customNote.trim()}');
    }
    buffer.writeln('- Rule: Strictly tailor all meal recommendations, ingredient swaps, and coaching tips to respect this dietary profile.');
    return buffer.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'dietType': dietType.name,
      'allergies': allergies,
      'customNote': customNote,
    };
  }

  factory DietaryPreferences.fromMap(Map<String, dynamic> map) {
    return DietaryPreferences(
      dietType: DietType.fromId(map['dietType']?.toString()),
      allergies: (map['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      customNote: map['customNote']?.toString() ?? '',
    );
  }

  DietaryPreferences copyWith({
    DietType? dietType,
    List<String>? allergies,
    String? customNote,
  }) {
    return DietaryPreferences(
      dietType: dietType ?? this.dietType,
      allergies: allergies ?? this.allergies,
      customNote: customNote ?? this.customNote,
    );
  }
}

