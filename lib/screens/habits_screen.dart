import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/add_habit_sheet.dart';
import '../widgets/bitesize_logo.dart';

/// Screen for tracking daily, weekly, and monthly habits, consistency streaks, and community challenges.
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _filter = 'All'; // 'All', 'Daily', 'Weekly', 'Monthly'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DateTime> _getCurrentWeekDates() {
    final now = _selectedDate;
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final habits = widget.appState.habits;
    final challenges = widget.appState.challenges;

    // Filter habits
    final filteredHabits = habits.where((h) {
      if (h.isArchived) return false;
      if (_filter == 'Daily') return h.frequency == HabitFrequency.daily;
      if (_filter == 'Weekly') return h.frequency == HabitFrequency.weekly;
      if (_filter == 'Monthly') return h.frequency == HabitFrequency.monthly;
      return true;
    }).toList();

    // Calculate overall streak and completion stats
    int totalCurrentStreak = 0;
    int completedToday = 0;
    for (final h in habits) {
      if (h.currentStreak > totalCurrentStreak) {
        totalCurrentStreak = h.currentStreak;
      }
      if (h.isCompletedOn(_selectedDate)) {
        completedToday++;
      }
    }

    final double completionPercent =
        habits.isNotEmpty ? (completedToday / habits.length).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          heroTag: 'add_habit_fab',
          backgroundColor: zen.sage,
          foregroundColor: const Color(0xFF090A0E),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          onPressed: () => showAddHabitSheet(context, appState: widget.appState),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'New Habit',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Top Header Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const BiteSizeLogo(size: 26),
                          const SizedBox(width: 8),
                          Text(
                            'HABITS & STREAKS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: zen.sage,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      // Overall streak pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: zen.carbs.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: zen.carbs.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              '$totalCurrentStreak Day Streak',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: zen.carbs,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Weekly Calendar Consistency Strip
                  _buildWeeklyCalendarStrip(zen, habits),
                  const SizedBox(height: 16),

                  // Metric Stat Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          zen,
                          title: 'COMPLETED TODAY',
                          value: '$completedToday / ${habits.length}',
                          subtitle: habits.isEmpty
                              ? 'No habits yet'
                              : (completedToday == habits.length ? 'All done! 🎉' : '${habits.length - completedToday} remaining'),
                          color: zen.sage,
                          icon: Icons.check_circle_outline_rounded,
                          progressPercent: completionPercent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          zen,
                          title: 'ACTIVE CHALLENGES',
                          value: '${challenges.where((c) => c.isJoined && !c.isCompleted).length} Active',
                          subtitle: '${challenges.where((c) => c.isCompleted).length} Finished',
                          color: zen.water,
                          icon: Icons.emoji_events_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Segmented Tabs: My Habits vs Challenges
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: zen.borderSoft),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: zen.sage.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: zen.sage.withValues(alpha: 0.3)),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: zen.sage,
                      unselectedLabelColor: zen.inkMuted,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      tabs: [
                        Tab(text: '⚡ My Habits (${habits.length})'),
                        Tab(text: '🏆 Challenges (${challenges.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab View Body
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. My Habits Tab
                _buildHabitsTab(zen, filteredHabits),

                // 2. Challenges Tab
                _buildChallengesTab(zen, challenges),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendarStrip(ZenColors zen, List<HabitItem> habits) {
    final weekDates = _getCurrentWeekDates();
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final date = weekDates[i];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, DateTime.now());

          // Count how many habits are completed on this date
          int doneCount = 0;
          for (final h in habits) {
            if (h.isCompletedOn(date)) doneCount++;
          }
          final isAllDone = habits.isNotEmpty && doneCount == habits.length;
          final isPartiallyDone = doneCount > 0 && !isAllDone;

          return GestureDetector(
            onTap: () {
              ZenHaptics.selection();
              setState(() => _selectedDate = date);
            },
            child: Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? zen.sage.withValues(alpha: 0.22)
                    : (isToday ? zen.borderSoft.withValues(alpha: 0.4) : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? zen.sage
                      : (isToday ? zen.borderSoft : Colors.transparent),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    dayNames[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? zen.sage : zen.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected ? zen.inkPrimary : zen.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Completion Dot Indicator
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAllDone
                          ? zen.sage
                          : (isPartiallyDone ? zen.carbs : zen.borderSoft),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricCard(
    ZenColors zen, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    double? progressPercent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: zen.inkMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (progressPercent != null) ...[
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        value: progressPercent,
                        strokeWidth: 3.5,
                        backgroundColor: zen.borderSoft,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Text(
                      '${(progressPercent * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: zen.inkPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsTab(ZenColors zen, List<HabitItem> habits) {
    return Column(
      children: [
        // Filter Chips Row
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: ['All', 'Daily', 'Weekly', 'Monthly'].map((filter) {
              final isSel = _filter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSel,
                  onSelected: (_) {
                    ZenHaptics.selection();
                    setState(() => _filter = filter);
                  },
                  backgroundColor: zen.surfaceSubtle,
                  selectedColor: zen.sage.withValues(alpha: 0.2),
                  checkmarkColor: zen.sage,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? zen.sage : zen.inkMuted,
                  ),
                  side: BorderSide(
                    color: isSel ? zen.sage.withValues(alpha: 0.4) : zen.borderSoft,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            }).toList(),
          ),
        ),

        // Habit Cards List
        Expanded(
          child: habits.isEmpty
              ? _buildEmptyHabitsView(zen)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 125),
                  itemCount: habits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final habit = habits[i];
                    return _buildHabitCard(zen, habit);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHabitCard(ZenColors zen, HabitItem habit) {
    final isDone = habit.isCompletedOn(_selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone
              ? zen.sage.withValues(alpha: 0.35)
              : habit.category.color.withValues(alpha: 0.22),
          width: isDone ? 1.4 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category Color Indicator Strip
              Container(
                width: 4,
                color: isDone ? zen.sage : habit.category.color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Completion Toggle Button
                      GestureDetector(
                        onTap: () {
                          ZenHaptics.success();
                          widget.appState.toggleHabitCompletion(habit.id, _selectedDate);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? zen.sage : Colors.transparent,
                            border: Border.all(
                              color: isDone ? zen.sage : zen.borderSoft,
                              width: 2,
                            ),
                          ),
                          child: isDone
                              ? const Icon(Icons.check_rounded, size: 22, color: Color(0xFF090A0E))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Emoji Icon
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: habit.category.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(habit.emoji, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),

                      // Habit Title & Subtitle Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: zen.inkPrimary,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                decorationColor: zen.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Frequency Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: zen.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: zen.borderSoft),
                                  ),
                                  child: Text(
                                    habit.frequency == HabitFrequency.weekly
                                        ? '${habit.targetDaysPerWeek}x / week'
                                        : (habit.frequency == HabitFrequency.monthly
                                            ? '${habit.targetDaysPerMonth}x / mo'
                                            : 'Daily'),
                                    style: TextStyle(fontSize: 10, color: zen.inkMuted, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Streak pill
                                if (habit.currentStreak > 0) ...[
                                  Text(
                                    '🔥 ${habit.currentStreak}d',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: zen.carbs),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                // Reminder time if enabled
                                if (habit.reminder != null && habit.reminder!.isEnabled) ...[
                                  Icon(Icons.notifications_active_outlined, size: 12, color: zen.sage),
                                  const SizedBox(width: 2),
                                  Text(
                                    habit.reminder!.timeFormatted,
                                    style: TextStyle(fontSize: 11, color: zen.sage, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Options Menu
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, size: 20, color: zen.inkMuted),
                        color: Theme.of(context).cardTheme.color ?? zen.surfaceSubtle,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: zen.borderSoft),
                        ),
                        onSelected: (val) {
                          if (val == 'edit') {
                            showAddHabitSheet(context, appState: widget.appState, existingHabit: habit);
                          } else if (val == 'delete') {
                            ZenHaptics.warning();
                            widget.appState.deleteHabit(habit.id);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: zen.inkMuted),
                                const SizedBox(width: 8),
                                Text('Edit Habit', style: TextStyle(color: zen.inkPrimary, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: zen.gentleClay),
                                const SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: zen.gentleClay, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHabitsView(ZenColors zen) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: zen.sage.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Text('✨', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 16),
            Text(
              'No Habits Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: zen.inkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Build your daily routine by adding your first habit or choosing from community presets.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: zen.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => showAddHabitSheet(context, appState: widget.appState),
              style: ElevatedButton.styleFrom(
                backgroundColor: zen.sage,
                foregroundColor: const Color(0xFF090A0E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a Habit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesTab(ZenColors zen, List<HabitChallenge> challenges) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 125),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final challenge = challenges[i];
        return _buildChallengeCard(zen, challenge);
      },
    );
  }

  Widget _buildChallengeCard(ZenColors zen, HabitChallenge challenge) {
    final isDoneToday = challenge.isCompletedOn(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: challenge.isJoined
              ? (challenge.isCompleted
                  ? zen.carbs.withValues(alpha: 0.45)
                  : zen.sage.withValues(alpha: 0.35))
              : zen.borderSoft,
          width: challenge.isJoined ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge Emoji
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: challenge.category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(challenge.badgeEmoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: zen.inkPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        // Duration Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: zen.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: zen.borderSoft),
                          ),
                          child: Text(
                            '${challenge.durationDays} Days',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: zen.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: TextStyle(fontSize: 12, color: zen.inkMuted, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress and Action Row
          if (challenge.isJoined) ...[
            // Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress: ${challenge.daysCompleted} / ${challenge.durationDays} Days',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: zen.inkMuted),
                ),
                Text(
                  '${(challenge.progress * 100).toInt()}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: zen.sage),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: challenge.progress,
                minHeight: 6,
                backgroundColor: zen.borderSoft,
                valueColor: AlwaysStoppedAnimation(challenge.isCompleted ? zen.carbs : zen.sage),
              ),
            ),
            const SizedBox(height: 10),

            // Milestone Step Bubbles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (stepIdx) {
                final milestoneFraction = (stepIdx + 1) / 5.0;
                final milestoneDay = (milestoneFraction * challenge.durationDays).round();
                final isReached = challenge.daysCompleted >= milestoneDay;

                return Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReached ? zen.sage : zen.surfaceSubtle,
                        border: Border.all(
                          color: isReached ? zen.sage : zen.borderSoft,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isReached
                          ? const Icon(Icons.check_rounded, size: 14, color: Color(0xFF090A0E))
                          : Text(
                              '${milestoneDay}d',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: zen.inkMuted,
                              ),
                            ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 12),

            // Daily Check-in, XP Badge & Leave Button Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ZenHaptics.success();
                      widget.appState.toggleChallengeDay(challenge.id, _selectedDate);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDoneToday ? Colors.black : zen.sage,
                      backgroundColor: isDoneToday ? zen.sage : Colors.transparent,
                      side: BorderSide(color: zen.sage),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(isDoneToday ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18),
                    label: Text(
                      isDoneToday ? 'Checked in Today! 🎉' : 'Log Today\'s Win',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: zen.carbs.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: zen.carbs.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '+${challenge.durationDays * 15} XP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: zen.carbs,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Leave challenge',
                  icon: Icon(Icons.exit_to_app_rounded, size: 20, color: zen.inkMuted),
                  onPressed: () {
                    ZenHaptics.warning();
                    widget.appState.leaveChallenge(challenge.id);
                  },
                ),
              ],
            ),
          ] else ...[
            // Join Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  ZenHaptics.success();
                  widget.appState.joinChallenge(challenge.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: zen.sage,
                  foregroundColor: const Color(0xFF090A0E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: Text(
                  'Join Challenge (+${challenge.rewardPoints} XP)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
