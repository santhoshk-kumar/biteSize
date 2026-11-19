import 'dart:io';

import 'package:flutter/material.dart';

import '../models/nutrition.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../theme/zen_theme.dart';
import 'meal_micronutrients_sheet.dart';

/// Interactive card showing a logged meal with swipe-to-action gestures
/// (swipe left to delete, swipe right to duplicate) and smooth accordion expansion.
class MealEntryCard extends StatefulWidget {
  const MealEntryCard({
    super.key,
    required this.meal,
    required this.onTapEdit,
    required this.onDelete,
    this.onSaveAsQuickBite,
    this.onSaveAsCombo,
    this.onDuplicate,
  });

  final MealEntry meal;
  final VoidCallback onTapEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSaveAsQuickBite;
  final VoidCallback? onSaveAsCombo;
  final VoidCallback? onDuplicate;

  @override
  State<MealEntryCard> createState() => _MealEntryCardState();
}

class _MealEntryCardState extends State<MealEntryCard> {
  bool _isExpanded = false;

  IconData _iconForMealType(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MealType.lunch:
        return Icons.lunch_dining_outlined;
      case MealType.dinner:
        return Icons.nights_stay_outlined;
      case MealType.snack:
        return Icons.spa_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final meal = widget.meal;
    final macros = meal.totalMacros;
    final hasValidImage = meal.imagePath != null &&
        meal.imagePath!.isNotEmpty &&
        File(meal.imagePath!).existsSync();

    return Dismissible(
      key: ValueKey('meal_${meal.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: zen.sage.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Duplicate',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: zen.gentleClay.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: Duplicate
          ZenHaptics.medium();
          if (widget.onDuplicate != null) {
            widget.onDuplicate!();
          } else {
            widget.onTapEdit();
          }
          return false; // Don't dismiss card
        } else {
          // Swipe left: Delete
          ZenHaptics.warning();
          widget.onDelete();
          return true;
        }
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            ZenHaptics.light();
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Image / Icon + Title + Calories + Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasValidImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(meal.imagePath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: zen.sageSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _iconForMealType(meal.mealType),
                          color: zen.sage,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: zen.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${meal.mealType.label} • ${ZenDateUtils.formatTime(meal.loggedAt)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: zen.inkMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            meal.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${macros.calories.round()} kcal',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: zen.sage,
                              ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 200),
                              turns: _isExpanded ? 0.5 : 0.0,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: zen.inkMuted,
                                size: 20,
                              ),
                            ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: zen.inkMuted,
                                size: 20,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') widget.onTapEdit();
                                if (value == 'duplicate' && widget.onDuplicate != null) {
                                  widget.onDuplicate!();
                                }
                                if (value == 'delete') widget.onDelete();
                                if (value == 'quick_bite' &&
                                    widget.onSaveAsQuickBite != null) {
                                  widget.onSaveAsQuickBite!();
                                }
                                if (value == 'combo' && widget.onSaveAsCombo != null) {
                                  widget.onSaveAsCombo!();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit portions & items'),
                                    ],
                                  ),
                                ),
                                if (widget.onDuplicate != null)
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Repeat / Duplicate meal'),
                                      ],
                                    ),
                                  ),
                                if (widget.onSaveAsQuickBite != null)
                                  const PopupMenuItem(
                                    value: 'quick_bite',
                                    child: Row(
                                      children: [
                                        Icon(Icons.bolt_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Save as Quick Bite'),
                                      ],
                                    ),
                                  ),
                                if (widget.onSaveAsCombo != null)
                                  const PopupMenuItem(
                                    value: 'combo',
                                    child: Row(
                                      children: [
                                        Icon(Icons.lunch_dining_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Save as Meal Combo'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('Remove meal'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Macro badges
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniMacroBadge(
                      label: 'P ${macros.proteinG.round()}g',
                      color: zen.protein,
                    ),
                    _MiniMacroBadge(
                      label: 'C ${macros.carbsG.round()}g',
                      color: zen.carbs,
                    ),
                    _MiniMacroBadge(
                      label: 'F ${macros.fatG.round()}g',
                      color: zen.fat,
                    ),
                    if (macros.fiberG > 0)
                      _MiniMacroBadge(
                        label: 'Fiber ${macros.fiberG.round()}g',
                        color: zen.fiber,
                      ),
                  ],
                ),

                // Accordion Drawer (Expanded on Tap)
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _isExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Items Breakdown
                            if (meal.items.isNotEmpty) ...[
                              Text(
                                'Food Items & Portions',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: zen.inkMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              ...meal.items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 5),
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: zen.sage,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${item.name} (${item.formattedPortion})',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: zen.inkPrimary,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                                Text(
                                                  '${item.macros.calories.round()} kcal',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: zen.sage,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.macros.calories.round()} kcal · ${item.macros.proteinG.round()}g P · ${item.macros.carbsG.round()}g C · ${item.macros.fatG.round()}g F',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: zen.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Micronutrients & Actions Row
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => showMealMicronutrientsSheet(
                                    context,
                                    title: meal.title,
                                    subtitle:
                                        '${meal.mealType.label} • ${ZenDateUtils.formatTime(meal.loggedAt)}',
                                    macros: macros,
                                    items: meal.items,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: zen.sage.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: zen.sage.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.science_outlined,
                                          size: 13,
                                          color: zen.sage,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Vitamins & Minerals',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: zen.sage,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: widget.onTapEdit,
                                  icon: Icon(Icons.edit_outlined, size: 14, color: zen.inkMuted),
                                  label: Text(
                                    'Edit Details',
                                    style: TextStyle(fontSize: 11, color: zen.inkMuted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMacroBadge extends StatelessWidget {
  const _MiniMacroBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
