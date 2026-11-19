import 'package:flutter/material.dart';

import '../models/nutrition.dart';
import '../models/saved_combo.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';

/// Interactive modal sheet to view, manage, create, and 1-tap log Custom Saved Meal Combos.
class SavedCombosSheet extends StatefulWidget {
  const SavedCombosSheet({super.key, required this.appState});

  final AppState appState;

  @override
  State<SavedCombosSheet> createState() => _SavedCombosSheetState();
}

class _SavedCombosSheetState extends State<SavedCombosSheet> {
  Future<void> _logCombo(SavedMealCombo combo) async {
    await widget.appState.logSavedCombo(combo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged "${combo.name}" (${combo.totalMacros.calories.round()} kcal)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteCombo(SavedMealCombo combo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Saved Combo?'),
        content: Text('Are you sure you want to remove "${combo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.zen.gentleClay),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.appState.deleteSavedCombo(combo.id);
    }
  }

  void _openCreateComboDialog([SavedMealCombo? existing]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateComboSheet(
        appState: widget.appState,
        existingCombo: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final combos = widget.appState.savedCombos;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: zen.borderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: zen.sageSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🍱', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved Meal Combos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '1-tap log recurring multi-item meals & recipes',
                      style: TextStyle(color: zen.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Create New Combo',
                onPressed: () => _openCreateComboDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (combos.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: zen.borderSoft),
              ),
              child: Column(
                children: [
                  const Text('🍱', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text(
                    'No Saved Combos Yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: zen.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Save your favorite multi-item meals (e.g. Rice + Sambar + Salad, or Oats + Whey + Banana) from your meal card menu or create one right here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: zen.inkMuted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openCreateComboDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Meal Combo'),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: combos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final combo = combos[index];
                  final macros = combo.totalMacros;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: zen.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(combo.icon, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          combo.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: zen.borderSoft),
                                        ),
                                        child: Text(
                                          combo.mealType.label,
                                          style: TextStyle(fontSize: 10, color: zen.inkMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${macros.calories.round()} kcal • ${macros.proteinG.round()}g P • ${macros.carbsG.round()}g C • ${macros.fatG.round()}g F',
                                    style: TextStyle(
                                      color: zen.sage,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.more_vert_rounded, size: 18, color: zen.inkMuted),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _openCreateComboDialog(combo);
                                } else if (val == 'delete') {
                                  _deleteCombo(combo);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit Combo'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Delete Combo'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (combo.items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: combo.items.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${item.name} (${item.macros.calories.round()} kcal)',
                                  style: TextStyle(color: zen.inkMuted, fontSize: 11),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _logCombo(combo),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.bolt_rounded, size: 16),
                            label: Text('Log ${combo.name} (${macros.calories.round()} kcal)'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateComboSheet extends StatefulWidget {
  const _CreateComboSheet({
    required this.appState,
    this.existingCombo,
  });

  final AppState appState;
  final SavedMealCombo? existingCombo;

  @override
  State<_CreateComboSheet> createState() => _CreateComboSheetState();
}

class _CreateComboSheetState extends State<_CreateComboSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _notesCtrl;
  late MealType _mealType;
  late List<FoodItem> _items;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingCombo?.name ?? '');
    _iconCtrl = TextEditingController(text: widget.existingCombo?.icon ?? '🍱');
    _notesCtrl = TextEditingController(text: widget.existingCombo?.notes ?? '');
    _mealType = widget.existingCombo?.mealType ?? MealType.lunch;
    _items = widget.existingCombo != null
        ? List<FoodItem>.from(widget.existingCombo!.items)
        : [
            FoodItem(
              id: ZenDateUtils.newId('item'),
              name: '',
              quantity: 1,
              unit: 'serving',
              estimatedGrams: 100,
              macros: MacroNutrients.zero,
              confidence: 'medium',
            ),
          ];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(
        FoodItem(
          id: ZenDateUtils.newId('item'),
          name: '',
          quantity: 1,
          unit: 'serving',
          estimatedGrams: 100,
          macros: MacroNutrients.zero,
          confidence: 'medium',
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(index);
    });
  }

  void _editItem(int index) {
    final item = _items[index];
    final nameCtrl = TextEditingController(text: item.name);
    final unitCtrl = TextEditingController(text: item.unit);
    final calCtrl = TextEditingController(text: item.macros.calories.round().toString());
    final pCtrl = TextEditingController(text: item.macros.proteinG.round().toString());
    final cCtrl = TextEditingController(text: item.macros.carbsG.round().toString());
    final fCtrl = TextEditingController(text: item.macros.fatG.round().toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item in Combo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name (e.g. Brown Rice)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Portion / Unit (e.g. 1 bowl)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: calCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Protein (g)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Carbs (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fat (g)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              setState(() {
                _items[index] = item.copyWith(
                  name: newName,
                  unit: unitCtrl.text.trim().isEmpty ? 'serving' : unitCtrl.text.trim(),
                  macros: MacroNutrients(
                    calories: double.tryParse(calCtrl.text.trim()) ?? 0,
                    proteinG: double.tryParse(pCtrl.text.trim()) ?? 0,
                    carbsG: double.tryParse(cCtrl.text.trim()) ?? 0,
                    fatG: double.tryParse(fCtrl.text.trim()) ?? 0,
                  ),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save Item'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCombo() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a combo name.')),
      );
      return;
    }

    final validItems = _items.where((i) => i.name.trim().isNotEmpty).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item with a name.')),
      );
      return;
    }

    final combo = SavedMealCombo(
      id: widget.existingCombo?.id ?? ZenDateUtils.newId('combo'),
      name: name,
      icon: _iconCtrl.text.trim().isEmpty ? '🍱' : _iconCtrl.text.trim(),
      mealType: _mealType,
      items: validItems,
      notes: _notesCtrl.text.trim(),
    );

    await widget.appState.saveSavedCombo(combo);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved combo "${combo.name}"!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: zen.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existingCombo != null ? 'Edit Meal Combo' : 'Create Meal Combo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 55,
                  child: TextField(
                    controller: _iconCtrl,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Icon'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Combo Name (e.g. Classic South Indian Lunch)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Meal Slot: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DropdownButton<MealType>(
                  value: _mealType,
                  underline: const SizedBox.shrink(),
                  onChanged: (val) {
                    if (val != null) setState(() => _mealType = val);
                  },
                  items: MealType.values.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t.label));
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Items in Combo:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final it = _items[i];
                final hasDetails = it.name.trim().isNotEmpty;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasDetails ? it.name : 'Unnamed Item (tap to edit)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: hasDetails ? zen.inkPrimary : zen.inkMuted,
                              ),
                            ),
                            Text(
                              '${it.macros.calories.round()} kcal • ${it.unit}',
                              style: TextStyle(fontSize: 11, color: zen.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editItem(i),
                      ),
                      if (_items.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => _removeItem(i),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveCombo,
                child: const Text('Save Combo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to open the Saved Combos Sheet.
void showSavedCombosSheet(BuildContext context, {required AppState appState}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SavedCombosSheet(appState: appState),
  );
}

/// Helper dialog to save an existing MealEntry as a reusable SavedMealCombo.
Future<void> showSaveMealAsComboDialog(
  BuildContext context, {
  required AppState appState,
  required MealEntry meal,
}) async {
  final nameCtrl = TextEditingController(text: meal.title);
  final iconCtrl = TextEditingController(text: '🍱');

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save as Meal Combo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Save this entire multi-item meal as a reusable combo for 1-tap logging anytime.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 55,
                child: TextField(
                  controller: iconCtrl,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Icon'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Combo Name'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            final combo = SavedMealCombo.fromMealEntry(
              meal,
              customName: name,
              icon: iconCtrl.text.trim().isEmpty ? '🍱' : iconCtrl.text.trim(),
            );
            await appState.saveSavedCombo(combo);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved combo "${combo.name}"!')),
            );
          },
          child: const Text('Save Combo'),
        ),
      ],
    ),
  );
}
