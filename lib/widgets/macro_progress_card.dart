import 'package:flutter/material.dart';

import '../models/health_log.dart';
import '../models/nutrition.dart';
import '../theme/zen_theme.dart';

/// Displays Protein, Carbs, and Fat bars plus an expandable Micronutrient Explorer
/// featuring all essential vitamins, minerals, and lipid/carbohydrate fractions.
class MacroProgressCard extends StatefulWidget {
  const MacroProgressCard({
    super.key,
    required this.macros,
    required this.goals,
  });

  final MacroNutrients macros;
  final DailyGoals goals;

  @override
  State<MacroProgressCard> createState() => _MacroProgressCardState();
}

class _MacroProgressCardState extends State<MacroProgressCard> {
  bool _showMicros = false;
  int _tabIndex = 0; // 0 = Vitamins, 1 = Minerals, 2 = Fibers & Lipids

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final m = widget.macros;
    final g = widget.goals;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Macronutrients',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _showMicros = !_showMicros),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showMicros ? 'Hide micros' : 'Micronutrients',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: zen.sage,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _showMicros
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: zen.sage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MacroBarTile(
                    label: 'Protein',
                    value: m.proteinG,
                    target: g.proteinTargetG.toDouble(),
                    unit: 'g',
                    color: zen.protein,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MacroBarTile(
                    label: 'Carbs',
                    value: m.carbsG,
                    target: g.carbsTargetG.toDouble(),
                    unit: 'g',
                    color: zen.carbs,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MacroBarTile(
                    label: 'Fat',
                    value: m.fatG,
                    target: g.fatTargetG.toDouble(),
                    unit: 'g',
                    color: zen.fat,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 240),
              crossFadeState: _showMicros
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: zen.borderSoft, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Vitamins & Minerals',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          'FDA Daily Values',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: zen.inkMuted,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Category selector chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryFilterChip(
                            label: 'Vitamins (14)',
                            selected: _tabIndex == 0,
                            onTap: () => setState(() => _tabIndex = 0),
                          ),
                          const SizedBox(width: 8),
                          _CategoryFilterChip(
                            label: 'Minerals (10)',
                            selected: _tabIndex == 1,
                            onTap: () => setState(() => _tabIndex = 1),
                          ),
                          const SizedBox(width: 8),
                          _CategoryFilterChip(
                            label: 'Fiber & Lipids',
                            selected: _tabIndex == 2,
                            onTap: () => setState(() => _tabIndex = 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Nutrient list for selected category
                    if (_tabIndex == 0)
                      ...m.vitamins.map((nut) => _NutrientBarRow(
                            detail: nut,
                            accentColor: zen.sage,
                          ))
                    else if (_tabIndex == 1)
                      ...m.minerals.map((nut) => _NutrientBarRow(
                            detail: nut,
                            accentColor: zen.gentleClay,
                          ))
                    else
                      ...m.lipidsAndCarbs.map((nut) => _NutrientBarRow(
                            detail: nut,
                            accentColor: zen.protein,
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

class _NutrientBarRow extends StatelessWidget {
  const _NutrientBarRow({
    required this.detail,
    required this.accentColor,
  });

  final NutrientDetail detail;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final pct = detail.percentageOfDv;
    final clampedProgress = (pct / 100.0).clamp(0.0, 1.0);

    final displayAmount = detail.amount < 10
        ? detail.amount.toStringAsFixed(1)
        : detail.amount.toStringAsFixed(0);
    final displayTarget = detail.dailyValue < 10
        ? detail.dailyValue.toStringAsFixed(1)
        : detail.dailyValue.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: zen.inkPrimary,
                      ),
                ),
              ),
              Text(
                '$displayAmount / $displayTarget ${detail.unit}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: zen.inkMuted,
                      fontFamily: 'monospace',
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: detail.isLimit && pct > 100
                      ? Colors.red.withValues(alpha: 0.15)
                      : accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${pct.round()}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: detail.isLimit && pct > 100
                            ? Colors.red
                            : accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 5,
              backgroundColor: zen.surfaceSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(
                detail.isLimit && pct > 100 ? Colors.red : accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBarTile extends StatelessWidget {
  const _MacroBarTile({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
  });

  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final safeTarget = target <= 0 ? 1.0 : target;
    final progress = (value / safeTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: zen.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${value.round()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: zen.inkPrimary,
                      ),
                ),
                TextSpan(
                  text: '/${target.round()}$unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: zen.inkMuted,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              builder: (context, anim, _) => LinearProgressIndicator(
                value: anim,
                minHeight: 6,
                backgroundColor: zen.borderSoft,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
