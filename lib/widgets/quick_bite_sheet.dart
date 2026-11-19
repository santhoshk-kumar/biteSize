import 'package:flutter/material.dart';

import '../models/nutrition.dart';
import '../models/quick_bite.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';

/// Interactive modal sheet to create or edit a custom 1-tap Quick Bite.
Future<void> showQuickBiteSheet(
  BuildContext context, {
  required AppState appState,
  QuickBitePreset? initialPreset,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuickBiteSheetContent(
      appState: appState,
      initialPreset: initialPreset,
    ),
  );
}

class _QuickBiteSheetContent extends StatefulWidget {
  const _QuickBiteSheetContent({
    required this.appState,
    this.initialPreset,
  });

  final AppState appState;
  final QuickBitePreset? initialPreset;

  @override
  State<_QuickBiteSheetContent> createState() => _QuickBiteSheetContentState();
}

class _QuickBiteSheetContentState extends State<_QuickBiteSheetContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _portionController;
  late final TextEditingController _gramsController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _fiberController;
  late final TextEditingController _customEmojiController;

  late String _selectedEmoji;
  late MealType _mealType;

  static const List<String> _popularEmojis = [
    '🥞', '🫓', '🍚', '☕', '🥤', '🥚', '🍌', '🥣',
    '🥜', '🍛', '🍲', '🥗', '🥪', '🍎', '🍗', '🥛',
    '🍪', '🥑', '🥟', '🥘',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialPreset;
    _nameController = TextEditingController(text: p?.name ?? '');
    _portionController = TextEditingController(text: p?.portion ?? '1 serving');
    _gramsController = TextEditingController(
      text: p != null ? p.estimatedGrams.round().toString() : '150',
    );
    _caloriesController = TextEditingController(
      text: p != null ? p.macros.calories.round().toString() : '200',
    );
    _proteinController = TextEditingController(
      text: p != null ? p.macros.proteinG.toStringAsFixed(1) : '10.0',
    );
    _carbsController = TextEditingController(
      text: p != null ? p.macros.carbsG.toStringAsFixed(1) : '25.0',
    );
    _fatController = TextEditingController(
      text: p != null ? p.macros.fatG.toStringAsFixed(1) : '5.0',
    );
    _fiberController = TextEditingController(
      text: p != null ? p.macros.fiberG.toStringAsFixed(1) : '3.0',
    );
    _customEmojiController = TextEditingController();

    _selectedEmoji = p?.icon ?? '🍛';
    _mealType = p?.mealType ?? MealType.snack;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.dispose();
    _gramsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _customEmojiController.dispose();
    super.dispose();
  }

  void _calculateCaloriesFromMacros() {
    final p = double.tryParse(_proteinController.text.trim()) ?? 0;
    final c = double.tryParse(_carbsController.text.trim()) ?? 0;
    final f = double.tryParse(_fatController.text.trim()) ?? 0;
    final total = (4 * p) + (4 * c) + (9 * f);
    setState(() {
      _caloriesController.text = total.round().toString();
    });
  }

  Future<void> _saveQuickBite() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for your Quick Bite')),
      );
      return;
    }

    final portion = _portionController.text.trim().isEmpty
        ? '1 serving'
        : _portionController.text.trim();
    final grams = double.tryParse(_gramsController.text.trim()) ?? 100.0;
    final calories = double.tryParse(_caloriesController.text.trim()) ?? 100.0;
    final protein = double.tryParse(_proteinController.text.trim()) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? 0.0;
    final fat = double.tryParse(_fatController.text.trim()) ?? 0.0;
    final fiber = double.tryParse(_fiberController.text.trim()) ?? 0.0;

    final id = widget.initialPreset?.id ??
        'qb_custom_${DateTime.now().millisecondsSinceEpoch}';

    final preset = QuickBitePreset(
      id: id,
      name: name,
      icon: _selectedEmoji,
      portion: portion,
      estimatedGrams: grams,
      macros: MacroNutrients(
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        fiberG: fiber,
      ),
      mealType: _mealType,
      isCustom: true,
    );

    await widget.appState.saveCustomQuickBite(preset);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "${preset.name}" to Quick Bites!')),
    );
  }

  Future<void> _deleteQuickBite() async {
    final p = widget.initialPreset;
    if (p == null) return;

    await widget.appState.deleteCustomQuickBite(p.id);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed "${p.name}" from Quick Bites.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialPreset != null;

    final cardBg = Theme.of(context).cardColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: zen.borderSoft),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: zen.inkMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: zen.sageSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: zen.sage.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    _selectedEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Quick Bite' : 'Create Custom Quick Bite',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    Text(
                      'Personal 1-tap meals for instant tracking',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: zen.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
              if (isEditing && widget.initialPreset?.isCustom == true)
                IconButton(
                  tooltip: 'Delete Quick Bite',
                  icon: Icon(Icons.delete_outline_rounded, color: zen.gentleClay),
                  onPressed: _deleteQuickBite,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable Body
          Expanded(
            child: ListView(
              children: [
                // Emoji Picker Row
                Text(
                  'Choose Icon',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _popularEmojis.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final emoji = _popularEmojis[idx];
                      final isSelected = emoji == _selectedEmoji;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _selectedEmoji = emoji),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? zen.sageSoft : zen.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? zen.sage : zen.borderSoft,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Name Field
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Bite Name *',
                    hintText: 'e.g. Amma\'s Rasam Rice, Whey + PB',
                    prefixIcon: const Icon(Icons.restaurant_rounded),
                    filled: true,
                    fillColor: zen.surfaceSubtle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: zen.borderSoft),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Portion & Grams Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _portionController,
                        decoration: InputDecoration(
                          labelText: 'Portion Description',
                          hintText: '1 cup / 1 plate',
                          filled: true,
                          fillColor: zen.surfaceSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: zen.borderSoft),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _gramsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Grams (g)',
                          hintText: '150',
                          filled: true,
                          fillColor: zen.surfaceSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: zen.borderSoft),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Meal Category
                Text(
                  'Default Meal Type',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: MealType.values.map((type) {
                    final isSelected = type == _mealType;
                    return ChoiceChip(
                      label: Text(type.label),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _mealType = type);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Nutrition Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'NUTRITIONAL VALUES',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            icon: Icon(Icons.auto_fix_high_rounded, size: 14, color: zen.sage),
                            label: Text(
                              'Atwater 4P+4C+9F',
                              style: TextStyle(fontSize: 11, color: zen.sage, fontWeight: FontWeight.w700),
                            ),
                            onPressed: _calculateCaloriesFromMacros,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Calories
                      TextField(
                        controller: _caloriesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Calories (kcal) *',
                          prefixIcon: Icon(Icons.local_fire_department_rounded, color: zen.sage),
                          filled: true,
                          fillColor: cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: zen.borderSoft),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Macros Row: Protein, Carbs, Fat
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _proteinController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Protein (g)',
                                labelStyle: TextStyle(color: zen.protein),
                                filled: true,
                                fillColor: cardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: zen.borderSoft),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _carbsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Carbs (g)',
                                labelStyle: TextStyle(color: zen.carbs),
                                filled: true,
                                fillColor: cardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: zen.borderSoft),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _fatController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Fat (g)',
                                labelStyle: TextStyle(color: zen.fat),
                                filled: true,
                                fillColor: cardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: zen.borderSoft),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Optional Fiber
                      TextField(
                        controller: _fiberController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Dietary Fiber (g)',
                          labelStyle: TextStyle(color: zen.fiber),
                          filled: true,
                          fillColor: cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: zen.borderSoft),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: zen.sage,
                foregroundColor: const Color(0xFF090A0E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _saveQuickBite,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                isEditing ? 'Update Quick Bite' : 'Save Quick Bite',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
