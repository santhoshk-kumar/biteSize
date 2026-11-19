import 'package:flutter/material.dart';

import '../models/nutrition.dart';
import '../theme/zen_theme.dart';

/// Interactive editor card for an AI-estimated or manual [FoodItem].
/// Keeps a baseline copy so sliding portion multipliers never drifts due to rounding.
class FoodItemEditorTile extends StatefulWidget {
  const FoodItemEditorTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final FoodItem item;
  final ValueChanged<FoodItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<FoodItemEditorTile> createState() => _FoodItemEditorTileState();
}

class _FoodItemEditorTileState extends State<FoodItemEditorTile> {
  late FoodItem _baseline;
  double _multiplier = 1.0;

  @override
  void initState() {
    super.initState();
    _baseline = widget.item;
  }

  @override
  void didUpdateWidget(covariant FoodItemEditorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _baseline = widget.item;
      _multiplier = 1.0;
    }
  }

  void _applyMultiplier(double next) {
    final snapped = (next * 4).round() / 4;
    setState(() => _multiplier = snapped.clamp(0.25, 3.0));
    widget.onChanged(_baseline.scaleBy(_multiplier));
  }

  Future<void> _openManualEditDialog() async {
    final current = widget.item;
    final nameCtrl = TextEditingController(text: current.name);
    final qtyCtrl = TextEditingController(text: current.quantity.toString());
    final unitCtrl = TextEditingController(text: current.unit);
    final calCtrl = TextEditingController(
      text: current.macros.calories.round().toString(),
    );
    final pCtrl = TextEditingController(
      text: current.macros.proteinG.toStringAsFixed(1),
    );
    final cCtrl = TextEditingController(
      text: current.macros.carbsG.toStringAsFixed(1),
    );
    final fCtrl = TextEditingController(
      text: current.macros.fatG.toStringAsFixed(1),
    );
    final fiberCtrl = TextEditingController(
      text: current.macros.fiberG.toStringAsFixed(1),
    );

    final updated = await showDialog<FoodItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit food item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Food name'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: calCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Calories (kcal)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Protein g'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: cCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Carbs g'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Fat g'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fiberCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fiber (g)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final nextName = nameCtrl.text.trim();
              final next = current.copyWith(
                name: nextName.isEmpty ? current.name : nextName,
                quantity: parseNonNegativeDouble(
                  qtyCtrl.text,
                  fallback: current.quantity,
                ),
                unit: unitCtrl.text.trim(),
                macros: current.macros.copyWith(
                  calories: parseNonNegativeDouble(
                    calCtrl.text,
                    fallback: current.macros.calories,
                  ),
                  proteinG: parseNonNegativeDouble(
                    pCtrl.text,
                    fallback: current.macros.proteinG,
                  ),
                  carbsG: parseNonNegativeDouble(
                    cCtrl.text,
                    fallback: current.macros.carbsG,
                  ),
                  fatG: parseNonNegativeDouble(
                    fCtrl.text,
                    fallback: current.macros.fatG,
                  ),
                  fiberG: parseNonNegativeDouble(
                    fiberCtrl.text,
                    fallback: current.macros.fiberG,
                  ),
                ),
              );
              Navigator.of(ctx).pop(next);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    calCtrl.dispose();
    pCtrl.dispose();
    cCtrl.dispose();
    fCtrl.dispose();
    fiberCtrl.dispose();

    if (updated != null && mounted) {
      setState(() {
        _baseline = updated;
        _multiplier = 1.0;
      });
      widget.onChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.formattedPortion,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: zen.inkMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.macros.calories.round()} kcal',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: zen.sage,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, size: 18, color: zen.inkMuted),
                tooltip: 'Edit item values',
                onPressed: _openManualEditDialog,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: zen.gentleClay,
                ),
                tooltip: 'Remove item',
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'P ${item.macros.proteinG.toStringAsFixed(1)}g  ·  C ${item.macros.carbsG.toStringAsFixed(1)}g  ·  F ${item.macros.fatG.toStringAsFixed(1)}g'
            '${item.macros.fiberG > 0 ? '  ·  Fiber ${item.macros.fiberG.toStringAsFixed(1)}g' : ''}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: zen.inkMuted,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Portion',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: zen.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              ...const [0.5, 1.0, 1.5, 2.0].map((factor) {
                final selected = (_multiplier - factor).abs() < 0.05;
                final label =
                    factor == factor.roundToDouble()
                        ? '${factor.toInt()}x'
                        : '${factor}x';
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _applyMultiplier(factor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? zen.sage : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? zen.sage : zen.borderSoft,
                        ),
                      ),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: selected ? Colors.white : zen.inkPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              Text(
                '${_multiplier.toStringAsFixed(_multiplier % 1 == 0 ? 0 : 2)}x',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: zen.sage,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _multiplier,
              min: 0.25,
              max: 3.0,
              divisions: 11,
              activeColor: zen.sage,
              inactiveColor: zen.borderSoft,
              onChanged: _applyMultiplier,
            ),
          ),
        ],
      ),
    );
  }
}
