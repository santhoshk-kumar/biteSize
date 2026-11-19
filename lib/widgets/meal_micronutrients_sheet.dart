import 'package:flutter/material.dart';

import '../models/nutrition.dart';
import '../theme/zen_theme.dart';

/// Shows a calm, comprehensive bottom sheet displaying all 14 vitamins, 10 minerals,
/// and lipid/carb details for a specific [MealEntry] or [MacroNutrients].
Future<void> showMealMicronutrientsSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required MacroNutrients macros,
  List<FoodItem> items = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _MealMicronutrientsSheet(
      title: title,
      subtitle: subtitle,
      macros: macros,
      items: items,
    ),
  );
}

class _MealMicronutrientsSheet extends StatefulWidget {
  const _MealMicronutrientsSheet({
    required this.title,
    required this.subtitle,
    required this.macros,
    this.items = const [],
  });

  final String title;
  final String subtitle;
  final MacroNutrients macros;
  final List<FoodItem> items;

  @override
  State<_MealMicronutrientsSheet> createState() =>
      _MealMicronutrientsSheetState();
}

class _MealMicronutrientsSheetState extends State<_MealMicronutrientsSheet> {
  int _categoryIndex = 0; // 0 = Vitamins, 1 = Minerals, 2 = Fiber & Lipids, 3 = Item Breakdown

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final m = widget.macros;

    final vitamins = m.vitamins;
    final minerals = m.minerals;
    final lipidsAndCarbs = m.lipidsAndCarbs;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Grab handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: zen.borderSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: zen.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Macro Summary Pill Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: zen.sageSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat(label: 'Calories', value: '${m.calories.round()} kcal'),
                    _MiniStat(label: 'Protein', value: '${m.proteinG.round()}g'),
                    _MiniStat(label: 'Carbs', value: '${m.carbsG.round()}g'),
                    _MiniStat(label: 'Fat', value: '${m.fatG.round()}g'),
                  ],
                ),
              ),

              // Category Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: 'Vitamins (14)',
                        selected: _categoryIndex == 0,
                        onTap: () => setState(() => _categoryIndex = 0),
                      ),
                      const SizedBox(width: 8),
                      _CategoryChip(
                        label: 'Minerals (10)',
                        selected: _categoryIndex == 1,
                        onTap: () => setState(() => _categoryIndex = 1),
                      ),
                      const SizedBox(width: 8),
                      _CategoryChip(
                        label: 'Fiber & Lipids',
                        selected: _categoryIndex == 2,
                        onTap: () => setState(() => _categoryIndex = 2),
                      ),
                      if (widget.items.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: 'Items (${widget.items.length})',
                          selected: _categoryIndex == 3,
                          onTap: () => setState(() => _categoryIndex = 3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Nutrient Details List
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  children: [
                    if (_categoryIndex == 0) ...[
                      Text(
                        'Vitamins in this meal',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: zen.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      ...vitamins.map(
                        (v) => _NutrientItemTile(detail: v, color: zen.sage),
                      ),
                    ] else if (_categoryIndex == 1) ...[
                      Text(
                        'Minerals in this meal',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: zen.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      ...minerals.map(
                        (min) => _NutrientItemTile(
                          detail: min,
                          color: zen.gentleClay,
                        ),
                      ),
                    ] else if (_categoryIndex == 2) ...[
                      Text(
                        'Lipid & Carbohydrate fractions',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: zen.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      ...lipidsAndCarbs.map(
                        (lip) => _NutrientItemTile(
                          detail: lip,
                          color: zen.protein,
                        ),
                      ),
                    ] else if (_categoryIndex == 3) ...[
                      Text(
                        'Ingredients in this meal',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: zen.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.items.map(
                        (item) => _ItemNutrientCard(item: item),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: zen.inkMuted,
                fontSize: 10,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: zen.inkPrimary,
              ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? zen.sage : zen.surfaceSubtle,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? zen.sage : zen.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? Colors.white : zen.inkPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _NutrientItemTile extends StatelessWidget {
  const _NutrientItemTile({
    required this.detail,
    required this.color,
  });

  final NutrientDetail detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final pct = detail.percentageOfDv;
    final progress = (pct / 100.0).clamp(0.0, 1.0);

    final displayAmount = detail.amount < 10
        ? detail.amount.toStringAsFixed(1)
        : detail.amount.toStringAsFixed(0);
    final displayTarget = detail.dailyValue < 10
        ? detail.dailyValue.toStringAsFixed(1)
        : detail.dailyValue.toStringAsFixed(0);

    final hasValue = detail.amount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: hasValue ? zen.surfaceSubtle : zen.surfaceSubtle.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: zen.borderSoft),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hasValue ? zen.inkPrimary : zen.inkMuted,
                        ),
                  ),
                ),
                Text(
                  '$displayAmount / $displayTarget ${detail.unit}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: hasValue ? zen.inkPrimary : zen.inkMuted,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: detail.isLimit && pct > 100
                        ? Colors.red.withOpacity(0.15)
                        : color.withOpacity(hasValue ? 0.15 : 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${pct.round()}% DV',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: detail.isLimit && pct > 100
                              ? Colors.red
                              : (hasValue ? color : zen.inkMuted),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: zen.borderSoft,
                valueColor: AlwaysStoppedAnimation<Color>(
                  detail.isLimit && pct > 100 ? Colors.red : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemNutrientCard extends StatelessWidget {
  const _ItemNutrientCard({required this.item});

  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final m = item.macros;

    // Collect non-zero micronutrients for this specific item
    final topVitamins = m.vitamins.where((v) => v.amount > 0).take(4).toList();
    final topMinerals = m.minerals.where((min) => min.amount > 0).take(4).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${m.calories.round()} kcal',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: zen.sage,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Portion: ${item.formattedPortion} · P: ${m.proteinG.round()}g, C: ${m.carbsG.round()}g, F: ${m.fatG.round()}g',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: zen.inkMuted,
                  fontSize: 11,
                ),
          ),
          if (topVitamins.isNotEmpty || topMinerals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...topVitamins.map(
                  (v) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: zen.sage.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${v.name}: ${v.amount < 10 ? v.amount.toStringAsFixed(1) : v.amount.round()} ${v.unit}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: zen.sage,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                ...topMinerals.map(
                  (min) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: zen.gentleClay.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${min.name}: ${min.amount < 10 ? min.amount.toStringAsFixed(1) : min.amount.round()} ${min.unit}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: zen.gentleClay,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

