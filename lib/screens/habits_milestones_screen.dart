import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/habit.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/achievement_detail_sheet.dart';
import '../widgets/add_habit_sheet.dart';
import '../widgets/fasting_timer_card.dart';
import '../widgets/fasting_trend_card.dart';

extension on AchievementCategory {
  String get label {
    switch (this) {
      case AchievementCategory.streaks:
        return 'Habits & Streaks';
      case AchievementCategory.nutrition:
        return 'Nutrition';
      case AchievementCategory.fasting:
        return 'Fasting';
      case AchievementCategory.hydration:
        return 'Hydration';
      case AchievementCategory.body:
        return 'Body';
      case AchievementCategory.activity:
        return 'Activity';
      case AchievementCategory.mastery:
        return 'Mastery';
    }
  }
}

/// Consolidated screen housing:
/// 1. Daily Habits & Streaks (with date scroll, edit/delete options, and habit insights)
/// 2. Milestones & Gamified Achievements (Trophy Room)
/// 3. Intermittent Fasting Insights
class HabitsMilestonesScreen extends StatefulWidget {
  const HabitsMilestonesScreen({
    super.key,
    required this.appState,
    this.initialTab = 0,
  });

  final AppState appState;
  final int initialTab;

  @override
  State<HabitsMilestonesScreen> createState() => _HabitsMilestonesScreenState();
}

class _HabitsMilestonesScreenState extends State<HabitsMilestonesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _habitFilter = 'All'; // 'All', 'Daily', 'Weekly', 'Monthly'
  AchievementCategory? _selectedAchievementCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _calculateRankTitle(int unlocked) {
    if (unlocked >= 18) return 'Zen Legend';
    if (unlocked >= 14) return 'Metabolic Master';
    if (unlocked >= 9) return 'Nutrition Champion';
    if (unlocked >= 4) return 'Consistent Achiever';
    return 'Mindful Beginner';
  }

  Future<void> _confirmDeleteHabit(BuildContext context, HabitItem habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit?'),
        content: Text(
          'Are you sure you want to delete "${habit.title}"? Your streak and completion history will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ZenHaptics.heavy();
      await widget.appState.deleteHabit(habit.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${habit.title}"'),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: context.zen.sage,
              onPressed: () async {
                await widget.appState.addHabit(habit);
              },
            ),
          ),
        );
      }
    }
  }

  void _showHabitInsights(BuildContext context, HabitItem habit) {
    final zen = context.zen;
    final totalCompleted = habit.completedDates.length;
    final today = ZenDateUtils.dateOnly(DateTime.now());

    // Compute last 14 days consistency
    final last14Days = List.generate(14, (i) => today.subtract(Duration(days: 13 - i)));
    final completedLast14 = last14Days.where((d) => habit.isCompletedOn(d)).length;
    final rateLast14 = ((completedLast14 / 14) * 100).round();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF12141C),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: zen.sage.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(habit.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: zen.surfaceSubtle,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              habit.category.label,
                              style: TextStyle(fontSize: 10.5, color: zen.inkMuted, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: zen.surfaceSubtle,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              habit.frequency.label,
                              style: TextStyle(fontSize: 10.5, color: zen.inkMuted, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Metrics row: Streak, Best, Total, 14d Rate
            Row(
              children: [
                Expanded(
                  child: _buildInsightMetric(
                    context,
                    label: 'CURRENT STREAK',
                    value: '${habit.currentStreak}d',
                    color: zen.carbs,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInsightMetric(
                    context,
                    label: 'BEST STREAK',
                    value: '${habit.bestStreak}d',
                    color: zen.sage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInsightMetric(
                    context,
                    label: 'TOTAL DAYS',
                    value: '$totalCompleted',
                    color: zen.protein,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInsightMetric(
                    context,
                    label: '14-DAY RATE',
                    value: '$rateLast14%',
                    color: zen.fat,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 14-day history strip
            Text(
              'Last 14 Days Adherence',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: zen.inkMuted),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: last14Days.map((d) {
                final done = habit.isCompletedOn(d);
                return Column(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? zen.sage : zen.surfaceSubtle,
                        border: Border.all(color: done ? zen.sage : zen.borderSoft),
                      ),
                      child: done
                          ? const Icon(Icons.check, size: 12, color: Color(0xFF090A0E))
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d.day}',
                      style: TextStyle(fontSize: 9, color: zen.inkMuted),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Reminder schedule
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: zen.borderSoft),
              ),
              child: Row(
                children: [
                  Icon(
                    habit.reminder != null && habit.reminder!.isEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_outlined,
                    size: 18,
                    color: habit.reminder != null && habit.reminder!.isEnabled ? zen.sage : zen.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.reminder != null && habit.reminder!.isEnabled
                          ? 'Daily reminder set for ${habit.reminder!.timeFormatted}'
                          : 'No push reminder set for this habit',
                      style: TextStyle(fontSize: 12, color: zen.inkPrimary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions row: Edit and Delete
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: zen.borderSoft),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      showAddHabitSheet(
                        context,
                        appState: widget.appState,
                        existingHabit: habit,
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Habit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteHabit(context, habit);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Habits & Milestones', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: zen.sage,
          labelColor: zen.sage,
          unselectedLabelColor: zen.inkMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.check_circle_outline_rounded), text: 'Habits'),
            Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Milestones'),
            Tab(icon: Icon(Icons.timer_outlined), text: 'Fasting'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // -------------------------------------------------------------
          // TAB 1: DAILY HABITS
          // -------------------------------------------------------------
          _buildHabitsTab(context),

          // -------------------------------------------------------------
          // TAB 2: MILESTONES & ACHIEVEMENTS
          // -------------------------------------------------------------
          _buildMilestonesTab(context),

          // -------------------------------------------------------------
          // TAB 3: INTERMITTENT FASTING INSIGHTS
          // -------------------------------------------------------------
          _buildFastingTab(context),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: HABITS
  // =========================================================================
  Widget _buildHabitsTab(BuildContext context) {
    final zen = context.zen;
    final habits = widget.appState.habits;

    final filteredHabits = habits.where((h) {
      if (h.isArchived) return false;
      if (_habitFilter == 'Daily') return h.frequency == HabitFrequency.daily;
      if (_habitFilter == 'Weekly') return h.frequency == HabitFrequency.weekly;
      if (_habitFilter == 'Monthly') return h.frequency == HabitFrequency.monthly;
      return true;
    }).toList();

    final totalHabitsCount = habits.where((h) => !h.isArchived).length;
    int totalCurrentStreak = 0;
    int completedForSelectedDate = 0;
    int totalCompletionsCount = 0;

    for (final h in habits) {
      if (h.currentStreak > totalCurrentStreak) {
        totalCurrentStreak = h.currentStreak;
      }
      if (h.isCompletedOn(_selectedDate)) {
        completedForSelectedDate++;
      }
      totalCompletionsCount += h.completedDates.length;
    }

    // 7-day adherence rate
    final today = ZenDateUtils.dateOnly(DateTime.now());
    int totalPossibleCompletionsLast7 = 0;
    int totalActualCompletionsLast7 = 0;
    for (int i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      for (final h in habits) {
        if (!h.isArchived) {
          totalPossibleCompletionsLast7++;
          if (h.isCompletedOn(day)) {
            totalActualCompletionsLast7++;
          }
        }
      }
    }
    final int weeklyAdherenceRate = totalPossibleCompletionsLast7 > 0
        ? ((totalActualCompletionsLast7 / totalPossibleCompletionsLast7) * 100).round()
        : 0;

    final double completionPercent =
        totalHabitsCount > 0 ? (completedForSelectedDate / totalHabitsCount).clamp(0.0, 1.0) : 0.0;

    final isToday = ZenDateUtils.dateOnly(_selectedDate) == today;
    final String completionTitle = isToday
        ? 'TODAY\'S COMPLETION'
        : '${ZenDateUtils.friendlyDateLabel(_selectedDate).toUpperCase()} COMPLETION';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // 1. Date selector strip at the top (like in TodayScreen)
        _buildHabitDateStrip(context),
        const SizedBox(height: 14),

        // 2. Summary & Completion Banner
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: zen.borderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        completionTitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: zen.inkMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(completionPercent * 100).round()}% Completed',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: zen.sage,
                        ),
                      ),
                      Text(
                        '$completedForSelectedDate of $totalHabitsCount habits done',
                        style: TextStyle(fontSize: 11, color: zen.inkMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 48,
                  width: 1,
                  color: zen.borderSoft,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOP STREAK',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: zen.inkMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: zen.carbs, size: 22),
                        const SizedBox(width: 4),
                        Text(
                          '$totalCurrentStreak days',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: zen.carbs,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Habit Insights & Consistency Summary Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: zen.borderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_graph_rounded, color: zen.sage, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Habit Insights & Consistency',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: zen.sageSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$weeklyAdherenceRate% 7d Rate',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: zen.sage),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInsightMetric(
                        context,
                        label: '7-DAY RATE',
                        value: '$weeklyAdherenceRate%',
                        color: zen.sage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInsightMetric(
                        context,
                        label: 'ALL-TIME DONE',
                        value: '$totalCompletionsCount',
                        color: zen.carbs,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInsightMetric(
                        context,
                        label: 'ACTIVE HABITS',
                        value: '$totalHabitsCount',
                        color: zen.protein,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, size: 16, color: zen.carbs),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Habit Stacking Tip: Anchor new habits right after established cues (like morning water after wake-up) to solidify automatic neural loops.',
                          style: TextStyle(fontSize: 11, color: zen.inkMuted, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 4. Habit Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Daily', 'Weekly', 'Monthly'].map((filter) {
              final isSelected = _habitFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: zen.sage,
                  backgroundColor: zen.surfaceSubtle,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF090A0E) : zen.inkPrimary,
                  ),
                  side: BorderSide(
                    color: isSelected ? zen.sage : zen.borderSoft,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      ZenHaptics.selection();
                      setState(() => _habitFilter = filter);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // 5. Section Header & Refined "New Habit" Action Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'My Habits',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (filteredHabits.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: zen.borderSoft),
                    ),
                    child: Text(
                      '${filteredHabits.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: zen.inkMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                ZenHaptics.selection();
                showAddHabitSheet(context, appState: widget.appState);
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'New Habit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: zen.sageSoft,
                foregroundColor: zen.sage,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: zen.sage.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (filteredHabits.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: zen.borderSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.spa_outlined, color: zen.sage, size: 36),
                  const SizedBox(height: 10),
                  const Text('No habits found in this category', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Build consistency with a daily or weekly routine.',
                    style: TextStyle(fontSize: 12, color: zen.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      ZenHaptics.selection();
                      showAddHabitSheet(context, appState: widget.appState);
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Create Habit', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: zen.sageSoft,
                      foregroundColor: zen.sage,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredHabits.map((habit) {
            final isDone = habit.isCompletedOn(_selectedDate);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDone ? zen.sage.withValues(alpha: 0.4) : zen.borderSoft),
              ),
              child: ListTile(
                leading: IconButton(
                  icon: Icon(
                    isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isDone ? zen.sage : zen.inkMuted,
                    size: 26,
                  ),
                  onPressed: () {
                    ZenHaptics.selection();
                    widget.appState.toggleHabitCompletion(habit.id, _selectedDate);
                  },
                ),
                title: Row(
                  children: [
                    Text(habit.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        habit.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone ? zen.inkMuted : zen.inkPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Streak: ${habit.currentStreak}d • Best: ${habit.bestStreak}d • ${habit.frequency.label}',
                  style: TextStyle(fontSize: 11, color: zen.inkMuted),
                ),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded, color: zen.inkMuted, size: 20),
                  tooltip: 'Habit options',
                  onSelected: (val) {
                    if (val == 'insights') {
                      _showHabitInsights(context, habit);
                    } else if (val == 'edit') {
                      showAddHabitSheet(context, appState: widget.appState, existingHabit: habit);
                    } else if (val == 'delete') {
                      _confirmDeleteHabit(context, habit);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'insights',
                      child: Row(
                        children: [
                          Icon(Icons.auto_graph_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Habit Insights'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Habit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete Habit', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () => _showHabitInsights(context, habit),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildHabitDateStrip(BuildContext context) {
    final zen = context.zen;
    final weekDates = ZenDateUtils.weekDatesFor(_selectedDate);
    final today = ZenDateUtils.dateOnly(DateTime.now());
    final selectedOnly = ZenDateUtils.dateOnly(_selectedDate);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Previous week',
              onPressed: () {
                ZenHaptics.selection();
                setState(() {
                  _selectedDate = selectedOnly.subtract(const Duration(days: 7));
                });
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  ZenDateUtils.friendlyDateLabel(selectedOnly),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: zen.inkPrimary,
                      ),
                ),
              ),
            ),
            if (selectedOnly != today)
              TextButton(
                onPressed: () {
                  ZenHaptics.selection();
                  setState(() => _selectedDate = today);
                },
                child: const Text('Today'),
              )
            else
              const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Next week',
              onPressed: () {
                ZenHaptics.selection();
                setState(() {
                  _selectedDate = selectedOnly.add(const Duration(days: 7));
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: weekDates.map((date) {
            final isSelected = date == selectedOnly;
            final isToday = date == today;
            final weekdayLabel = ZenDateUtils.formatWeekdayShort(date);
            final habits = widget.appState.habits.where((h) => !h.isArchived).toList();
            final completedCount = habits.where((h) => h.isCompletedOn(date)).length;
            final isAllDone = habits.isNotEmpty && completedCount == habits.length;
            final hasSome = completedCount > 0;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  ZenHaptics.selection();
                  setState(() => _selectedDate = date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? zen.sageSoft
                        : (isToday ? zen.surfaceSubtle : Colors.transparent),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? zen.sage
                          : (isToday ? zen.borderSoft : Colors.transparent),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        weekdayLabel.substring(0, 1),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? zen.sage : zen.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? zen.inkPrimary : zen.inkPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAllDone
                              ? zen.sage
                              : (hasSome ? zen.carbs : Colors.transparent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInsightMetric(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final zen = context.zen;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: zen.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: MILESTONES & ACHIEVEMENTS
  // =========================================================================
  Widget _buildMilestonesTab(BuildContext context) {
    final zen = context.zen;
    final allAchievements = widget.appState.allAchievements;
    final unlockedCount = widget.appState.unlockedAchievementsCount;
    final totalCount = widget.appState.totalAchievementsCount;
    final overallRatio = totalCount > 0 ? (unlockedCount / totalCount) : 0.0;
    final rank = _calculateRankTitle(unlockedCount);

    final filteredAchievements = _selectedAchievementCategory == null
        ? allAchievements
        : allAchievements.where((a) => a.category == _selectedAchievementCategory).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // Trophy Room Header Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: zen.borderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: zen.carbs.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.emoji_events_rounded, color: zen.carbs, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rank,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$unlockedCount of $totalCount milestones unlocked',
                            style: TextStyle(fontSize: 12, color: zen.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: overallRatio,
                    minHeight: 8,
                    backgroundColor: zen.surfaceSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(zen.sage),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Category filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedAchievementCategory == null,
                  selectedColor: zen.sage,
                  backgroundColor: zen.surfaceSubtle,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _selectedAchievementCategory == null ? FontWeight.w800 : FontWeight.w600,
                    color: _selectedAchievementCategory == null ? const Color(0xFF090A0E) : zen.inkPrimary,
                  ),
                  side: BorderSide(
                    color: _selectedAchievementCategory == null ? zen.sage : zen.borderSoft,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      ZenHaptics.selection();
                      setState(() => _selectedAchievementCategory = null);
                    }
                  },
                ),
              ),
              ...AchievementCategory.values.map((cat) {
                final isSelected = _selectedAchievementCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat.label),
                    selected: isSelected,
                    selectedColor: zen.sage,
                    backgroundColor: zen.surfaceSubtle,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF090A0E) : zen.inkPrimary,
                    ),
                    side: BorderSide(
                      color: isSelected ? zen.sage : zen.borderSoft,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        ZenHaptics.selection();
                        setState(() => _selectedAchievementCategory = cat);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Achievement Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: filteredAchievements.length,
          itemBuilder: (context, idx) {
            final ach = filteredAchievements[idx];
            final unlocked = ach.isUnlocked;

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ZenHaptics.selection();
                showAchievementDetailSheet(context, achievement: ach);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: unlocked ? zen.surfaceSubtle : zen.surfaceSubtle.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: unlocked ? zen.sage.withValues(alpha: 0.5) : zen.borderSoft,
                    width: unlocked ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: unlocked ? zen.sageSoft : Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ach.icon,
                        size: 22,
                        color: unlocked ? zen.sage : zen.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ach.title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: unlocked ? zen.inkPrimary : zen.inkMuted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (unlocked)
                      Text(
                        'Unlocked',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: zen.sage,
                        ),
                      )
                    else
                      Text(
                        '${(ach.progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: zen.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: INTERMITTENT FASTING INSIGHTS
  // =========================================================================
  Widget _buildFastingTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // Full Circular Fasting Ring & Live Timer Controls
        FastingTimerCard(appState: widget.appState),
        const SizedBox(height: 14),

        // Consistency History, Stage Breakdown & Metabolic Insights
        FastingTrendCard(appState: widget.appState),
      ],
    );
  }
}
