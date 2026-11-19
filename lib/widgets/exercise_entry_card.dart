import 'package:flutter/material.dart';

import '../models/exercise_entry.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../theme/zen_theme.dart';

/// Rich interactive card showcasing a logged exercise/workout session.
/// Features swipe-to-duplicate & swipe-to-delete gestures, kinematic metric chips,
/// flame-styled calorie burn badge, and smooth accordion expansion for deep biomechanics.
class ExerciseEntryCard extends StatefulWidget {
  const ExerciseEntryCard({
    super.key,
    required this.entry,
    required this.onTapEdit,
    required this.onDelete,
    this.onDuplicate,
    this.onSaveAsQuickActivity,
  });

  final ExerciseEntry entry;
  final VoidCallback onTapEdit;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onSaveAsQuickActivity;

  @override
  State<ExerciseEntryCard> createState() => _ExerciseEntryCardState();
}

class _ExerciseEntryCardState extends State<ExerciseEntryCard> {
  bool _isExpanded = false;

  Color _accentForType(ExerciseType type) {
    switch (type) {
      case ExerciseType.walking:
        return const Color(0xFF10B981); // Emerald
      case ExerciseType.running:
        return const Color(0xFFFF7A45); // Flame orange
      case ExerciseType.cycling:
        return const Color(0xFF3B82F6); // Vibrant Blue
      case ExerciseType.jumpRope:
        return const Color(0xFFA855F7); // Purple
      case ExerciseType.gym:
        return const Color(0xFFEC4899); // Rose / Gym Pink
      case ExerciseType.custom:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  IconData _iconForType(ExerciseType type) {
    switch (type) {
      case ExerciseType.walking:
        return Icons.directions_walk_rounded;
      case ExerciseType.running:
        return Icons.directions_run_rounded;
      case ExerciseType.cycling:
        return Icons.directions_bike_rounded;
      case ExerciseType.jumpRope:
        return Icons.sports_gymnastics_rounded;
      case ExerciseType.gym:
        return Icons.fitness_center_rounded;
      case ExerciseType.custom:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final entry = widget.entry;
    final accent = _accentForType(entry.type);
    final icon = _iconForType(entry.type);

    return Dismissible(
      key: ValueKey('exercise_${entry.id}'),
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
        margin: const EdgeInsets.symmetric(vertical: 5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: zen.borderSoft),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            ZenHaptics.light();
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Type Icon + Title & Time + Burned Cal + Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: accent,
                        size: 24,
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
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: zen.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${entry.type.displayName}${entry.gymCategory != null ? ' • ${entry.gymCategory}' : ''} • ${ZenDateUtils.formatTime(entry.loggedAt)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: zen.inkMuted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            entry.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: zen.sageSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-${entry.caloriesBurned.round()} kcal',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: zen.sage,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
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
                                if (value == 'quick_activity' && widget.onSaveAsQuickActivity != null) {
                                  widget.onSaveAsQuickActivity!();
                                }
                                if (value == 'delete') widget.onDelete();
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(child: Text('Edit Exercise')),
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
                                        Expanded(child: Text('Duplicate to Today')),
                                      ],
                                    ),
                                  ),
                                if (widget.onSaveAsQuickActivity != null)
                                  const PopupMenuItem(
                                    value: 'quick_activity',
                                    child: Row(
                                      children: [
                                        Icon(Icons.bolt_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Expanded(child: Text('Save as Quick Activity')),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded,
                                          color: zen.gentleClay, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Delete',
                                          style: TextStyle(color: zen.gentleClay),
                                        ),
                                      ),
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

                // Metrics Badges Row (Duration, Distance, Steps, Intensity)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _metricBadge(
                      context,
                      icon: Icons.timer_outlined,
                      label: '${entry.durationMinutes} min',
                      color: zen.inkPrimary,
                    ),
                    if (entry.distanceKm != null && entry.distanceKm! > 0)
                      _metricBadge(
                        context,
                        icon: Icons.straighten_rounded,
                        label: '${entry.distanceKm!.toStringAsFixed(1)} km',
                        color: accent,
                      ),
                    if (entry.steps != null && entry.steps! > 0)
                      _metricBadge(
                        context,
                        icon: Icons.directions_walk_rounded,
                        label: '${entry.steps} steps',
                        color: zen.inkMuted,
                      ),
                    _metricBadge(
                      context,
                      icon: Icons.speed_rounded,
                      label: entry.intensity.label,
                      color: _colorForIntensity(entry.intensity),
                    ),
                    if (entry.hasRoute)
                      _metricBadge(
                        context,
                        icon: Icons.route_rounded,
                        label: 'GPS Route (${entry.routePoints.length} pts)',
                        color: const Color(0xFF3B82F6),
                      ),
                  ],
                ),

                // Expanded Details & Kinematics
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // Biomechanics / Kinematics Row
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: zen.surfaceSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: zen.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.insights_rounded, size: 15, color: accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    'KINEMATICS & BIOENERGETICS',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: zen.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _subMetric(
                                    label: 'Base MET',
                                    value: '${entry.type.baseMet}',
                                    zen: zen,
                                  ),
                                  _subMetric(
                                    label: 'Intensity Multiplier',
                                    value: '${entry.intensity.metMultiplier}×',
                                    zen: zen,
                                  ),
                                  if (entry.formattedPace != null)
                                    _subMetric(
                                      label: 'Avg Pace',
                                      value: entry.formattedPace!,
                                      zen: zen,
                                    ),
                                  if (entry.speedKmh != null)
                                    _subMetric(
                                      label: 'Avg Speed',
                                      value: '${entry.speedKmh!.toStringAsFixed(1)} km/h',
                                      zen: zen,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Optional Notes
                        if (entry.notes.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: zen.surfaceSubtle.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: zen.borderSoft),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.sticky_note_2_outlined, size: 14, color: zen.inkMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entry.notes,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: zen.inkPrimary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Actions Row: Edit & Duplicate
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onTapEdit,
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                label: const Text('Edit Workout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: zen.borderSoft),
                                ),
                              ),
                            ),
                            if (widget.onDuplicate != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.onDuplicate,
                                  icon: const Icon(Icons.copy_rounded, size: 15),
                                  label: const Text('Duplicate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(color: zen.borderSoft),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: zen.gentleClay, size: 19),
                              tooltip: 'Delete',
                              onPressed: widget.onDelete,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 220),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final zen = context.zen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subMetric({
    required String label,
    required String value,
    required ZenColors zen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: zen.inkMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: zen.inkPrimary,
          ),
        ),
      ],
    );
  }

  Color _colorForIntensity(ExerciseIntensity intensity) {
    switch (intensity) {
      case ExerciseIntensity.light:
        return const Color(0xFF10B981); // Emerald
      case ExerciseIntensity.moderate:
        return const Color(0xFF3B82F6); // Blue
      case ExerciseIntensity.vigorous:
        return const Color(0xFFFF7A45); // Orange
      case ExerciseIntensity.extreme:
        return const Color(0xFFEF4444); // Red
    }
  }
}
