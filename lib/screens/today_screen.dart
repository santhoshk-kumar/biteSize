import 'dart:io';

import 'package:flutter/material.dart';

import '../models/exercise_entry.dart';
import '../models/nutrition.dart';
import '../models/quick_activity.dart';
import '../models/quick_bite.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/bitesize_logo.dart';
import '../widgets/compact_hydration_card.dart';
import '../widgets/exercise_entry_card.dart';
import '../widgets/log_exercise_sheet.dart';
import '../widgets/macro_progress_card.dart';
import '../widgets/meal_entry_card.dart';
import '../widgets/quick_bite_sheet.dart';
import '../widgets/saved_combos_sheet.dart';
import '../widgets/shareable_infographic_sheet.dart';
import '../widgets/week_strip_calendar.dart';
import '../widgets/zen_calorie_ring.dart';
import 'habits_milestones_screen.dart';
import 'log_meal_sheet.dart';

/// Primary daily BiteSize dashboard.
class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.appState,
    required this.onOpenSettings,
    this.onOpenChat,
  });

  final AppState appState;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final dayTotals = appState.totalMacrosForDay;
    final configured = appState.isActiveProviderConfigured;
    final alert = appState.activeCalorieAlert;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        if (velocity > 260) {
          // Swiped right -> navigate to previous day
          ZenHaptics.selection();
          appState.selectDate(
            appState.selectedDate.subtract(const Duration(days: 1)),
          );
        } else if (velocity < -260) {
          // Swiped left -> navigate to next day
          ZenHaptics.selection();
          appState.selectDate(
            appState.selectedDate.add(const Duration(days: 1)),
          );
        }
      },
      child: RefreshIndicator(
        onRefresh: () => appState.selectDate(appState.selectedDate),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ZenDateUtils.dynamicGreeting(appState.selectedDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: zen.inkMuted,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                      ),
                      const SizedBox(height: 4),
                      BiteSizeBrandHeader(
                        badgeText: appState.pacingStatus,
                        badgeColor: zen.sage,
                      ),
                    ],
                  ),
                ),
                // Top Action Bar Cluster (Compact, uncluttered, fits on any screen)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Achievements / Trophies
                    Tooltip(
                      message: 'Achievements & Milestones',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () {
                          ZenHaptics.selection();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => HabitsMilestonesScreen(
                                appState: appState,
                                initialTab: 1,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: zen.surfaceSubtle,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: zen.borderSoft),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded, size: 16, color: zen.carbs),
                              const SizedBox(width: 4),
                              Text(
                                '${appState.unlockedAchievementsCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: zen.carbs,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 3. Share Infographic
                    Tooltip(
                      message: 'Share Daily Report',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () {
                          ZenHaptics.selection();
                          showShareInfographicSheet(
                            context,
                            appState: appState,
                            initialMode: InfographicMode.daily,
                          );
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: zen.surfaceSubtle,
                            shape: BoxShape.circle,
                            border: Border.all(color: zen.borderSoft),
                          ),
                          child: Center(
                            child: Icon(Icons.share_outlined, size: 16, color: zen.inkPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 4. LLM AI Status Button
                    Tooltip(
                      message: configured
                          ? 'AI Engine Ready (${appState.llmSettings.activeModel})'
                          : 'Setup AI Provider Key',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: onOpenSettings,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: configured
                                ? zen.sageSoft
                                : zen.gentleClay.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: configured
                                  ? zen.sage.withValues(alpha: 0.4)
                                  : zen.gentleClay.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                configured
                                    ? Icons.auto_awesome_rounded
                                    : Icons.auto_awesome_outlined,
                                size: 16,
                                color: configured ? zen.sage : zen.gentleClay,
                              ),
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: configured ? zen.sage : zen.gentleClay,
                                    shape: BoxShape.circle,
                                    boxShadow: configured
                                        ? [
                                            BoxShadow(
                                              color: zen.sage.withValues(alpha: 0.6),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (alert != null) ...[
            const SizedBox(height: 12),
            _CalorieAlertCard(
              alert: alert,
              onDismiss: appState.dismissActiveAlert,
            ),
          ],
          const SizedBox(height: 16),
          WeekStripCalendar(
            selectedDate: appState.selectedDate,
            calorieTarget: appState.effectiveCalorieTargetForDate(appState.selectedDate),
            summaries: appState.recentSummaries,
            onSelectDate: appState.selectDate,
          ),
          const SizedBox(height: 16),
          ZenCalorieRing(
            consumed: dayTotals.calories,
            target: appState.effectiveCalorieTargetToday,
            meals: appState.mealsForDay,
            burned: appState.totalExerciseCaloriesBurned,
            fasting: appState.fasting,
            onTapFasting: () {
              ZenHaptics.selection();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HabitsMilestonesScreen(
                    appState: appState,
                    initialTab: 2,
                  ),
                ),
              );
            },
          ),
          if (appState.calorieBank.enabled) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: zen.sage.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.savings_outlined, size: 14, color: zen.sage),
                    const SizedBox(width: 6),
                    Text(
                      appState.selectedDate.weekday == DateTime.saturday ||
                              appState.selectedDate.weekday == DateTime.sunday
                          ? 'Weekend Bank Active (+${appState.calorieBank.weekendBonusPerDay} kcal bonus)'
                          : 'Weekend Banking Active (-${appState.calorieBank.bankDailyKcal} kcal saved for weekend)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: zen.sage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (appState.prefs.showMacroCard) ...[
            const SizedBox(height: 14),
            MacroProgressCard(
              macros: dayTotals,
              goals: appState.goals,
            ),
          ],
          if (appState.prefs.showHydrationCard) ...[
            const SizedBox(height: 14),
            CompactHydrationCard(appState: appState),
          ],
          if (appState.prefs.showQuickBites) ...[
            const SizedBox(height: 16),
            _QuickBitesRow(
              appState: appState,
              onSelectPreset: (preset) async {
                await appState.logQuickBite(preset);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Logged ${preset.name} (+${preset.macros.calories.round()} kcal)',
                    ),
                  ),
                );
              },
            ),
          ],
          if (appState.prefs.showTodaysPlates) ...[
            const SizedBox(height: 16),
            _TodaysPlatesFilmstrip(meals: appState.mealsForDay),
          ],
          const SizedBox(height: 20),
          // Generic Activity Section Header
          Row(
            children: [
              Text(
                'Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${appState.mealsForDay.length + appState.exercisesForDay.length} logged',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: zen.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // -----------------------------------------------------------------
          // CARD 1: FOODS CARD
          // -----------------------------------------------------------------
          _buildFoodsCard(context, zen, dayTotals),

          const SizedBox(height: 16),

          // -----------------------------------------------------------------
          // CARD 2: EXERCISE ACTIVITIES CARD
          // -----------------------------------------------------------------
          _buildExerciseActivitiesCard(context, zen),
        ],
      ),
      ),
    );
  }

  Widget _buildFoodsCard(BuildContext context, ZenColors zen, MacroNutrients dayTotals) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zen.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: zen.sageSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restaurant_rounded, color: zen.sage, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Foods',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: zen.sageSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${dayTotals.calories.round()} kcal',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: zen.sage,
                            ),
                          ),
                        ),
                        if (appState.mealsForDay.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${appState.mealsForDay.length})',
                            style: TextStyle(fontSize: 11, color: zen.inkMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${dayTotals.proteinG.round()}g P · ${dayTotals.carbsG.round()}g C · ${dayTotals.fatG.round()}g F',
                      style: TextStyle(fontSize: 11, color: zen.inkMuted),
                    ),
                  ],
                ),
              ),
              if (appState.yesterdayMeals.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.repeat_rounded, size: 19),
                  tooltip: 'Repeat yesterday\'s meals',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final count = await appState.repeatMealsFromYesterday();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          count > 0
                              ? 'Repeated $count meal${count > 1 ? 's' : ''} from yesterday!'
                              : 'No meals found from yesterday to copy.',
                        ),
                      ),
                    );
                  },
                ),
              FilledButton.tonalIcon(
                onPressed: () {
                  ZenHaptics.selection();
                  showLogMealSheet(context, appState: appState);
                },
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Add Meal', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RepeatYesterdayGhostChips(appState: appState),
          if (appState.isLoadingDay)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (appState.mealsForDay.isEmpty)
            _EmptyMealsCard(
              onChatLog: () => showLogMealSheet(context, appState: appState),
              onLogMeal: () => showLogMealSheet(context, appState: appState),
              onLoadSample: () async {
                await appState.loadSampleData();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loaded sample BiteSize day')),
                );
              },
              onRepeatYesterday: () async {
                final count = await appState.repeatMealsFromYesterday();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      count > 0
                          ? 'Repeated $count meal${count > 1 ? 's' : ''} from yesterday!'
                          : 'No meals found from yesterday to copy.',
                    ),
                  ),
                );
              },
              onVoiceLog: () => onOpenChat?.call(),
            )
          else
            ...appState.mealsForDay.map(
              (meal) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: MealEntryCard(
                  meal: meal,
                  onTapEdit: () => showLogMealSheet(
                    context,
                    appState: appState,
                    existingMeal: meal,
                    onOpenSettings: onOpenSettings,
                  ),
                  onDelete: () => _deleteMealWithUndo(context, meal),
                  onDuplicate: () async {
                    ZenHaptics.selection();
                    await appState.copyMealToToday(meal);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Duplicated "${meal.title}" to today')),
                    );
                  },
                  onSaveAsQuickBite: () => showQuickBiteSheet(
                    context,
                    appState: appState,
                    initialPreset: QuickBitePreset.fromMealEntry(meal),
                  ),
                  onSaveAsCombo: () => showSaveMealAsComboDialog(
                    context,
                    appState: appState,
                    meal: meal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseActivitiesCard(BuildContext context, ZenColors zen) {
    final exercises = appState.exercisesForDay;
    final totalBurn = appState.totalExerciseCaloriesBurned;
    final totalMinutes = appState.totalExerciseDurationMinutes;
    final totalKm = appState.totalWalkingRunningKm;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zen.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: zen.sageSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.directions_run_rounded, color: zen.sage, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Exercise Activities',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (totalBurn > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: zen.sageSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-${totalBurn.round()} kcal',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: zen.sage,
                              ),
                            ),
                          ),
                        ],
                        if (exercises.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${exercises.length})',
                            style: TextStyle(fontSize: 11, color: zen.inkMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      exercises.isEmpty
                          ? 'Movement & workouts tracked'
                          : '$totalMinutes mins active · ${totalKm > 0 ? '${totalKm.toStringAsFixed(1)} km · ' : ''}${exercises.length} ${exercises.length == 1 ? 'workout' : 'workouts'}',
                      style: TextStyle(fontSize: 11, color: zen.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline_rounded, size: 22, color: zen.sage),
                tooltip: 'Add Workout / Activity',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  ZenHaptics.selection();
                  showLogExerciseSheet(context, appState: appState);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _QuickActivitiesRow(appState: appState),
          if (exercises.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: zen.surfaceSubtle.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: zen.borderSoft),
              ),
              child: Column(
                children: [
                  Icon(Icons.fitness_center_rounded, size: 28, color: zen.inkMuted.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Text(
                    'No exercise activities logged yet today',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: zen.inkMuted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Type e.g. "5km walking" in the chat bar below or tap a Quick Activity above',
                    style: TextStyle(fontSize: 11, color: zen.inkMuted.withValues(alpha: 0.8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            ...exercises.map(
              (entry) => ExerciseEntryCard(
                entry: entry,
                onTapEdit: () => showLogExerciseSheet(
                  context,
                  appState: appState,
                  existingEntry: entry,
                ),
                onDelete: () => _deleteExerciseWithUndo(context, entry),
                onDuplicate: () async {
                  ZenHaptics.selection();
                  final duplicated = entry.copyWith(
                    id: ZenDateUtils.newId('ex'),
                    dateKey: appState.selectedDateKey,
                    loggedAt: DateTime.now(),
                  );
                  await appState.logExercise(duplicated);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Duplicated "${entry.title}" to today')),
                  );
                },
                onSaveAsQuickActivity: () async {
                  ZenHaptics.selection();
                  await appState.saveCustomQuickActivity(QuickActivityPreset.fromEntry(entry));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved "${entry.title}" as a 1-tap Quick Activity!')),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteMealWithUndo(BuildContext context, MealEntry meal) async {
    ZenHaptics.heavy();
    await appState.deleteMeal(meal.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${meal.title}"'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: context.zen.sage,
          onPressed: () async {
            await appState.saveMeal(meal);
          },
        ),
      ),
    );
  }

  Future<void> _deleteExerciseWithUndo(BuildContext context, ExerciseEntry entry) async {
    final zen = context.zen;
    ZenHaptics.heavy();
    await appState.deleteExercise(entry.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${entry.title}"'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: zen.sage,
          onPressed: () async {
            await appState.logExercise(entry);
          },
        ),
      ),
    );
  }
}

/// Floating in-app warning banner for over- or under-calorie consumption.
class _CalorieAlertCard extends StatelessWidget {
  const _CalorieAlertCard({
    required this.alert,
    required this.onDismiss,
  });

  final CalorieAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final accentColor = alert.isOver ? zen.gentleClay : zen.carbs;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              alert.isOver
                  ? Icons.local_fire_department_rounded
                  : Icons.warning_amber_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      alert.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onDismiss,
                      borderRadius: BorderRadius.circular(99),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: zen.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: zen.inkPrimary,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scroll row of 1-tap quick workout and activity presets.
class _QuickActivitiesRow extends StatelessWidget {
  const _QuickActivitiesRow({required this.appState});

  final AppState appState;

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
    final presets = appState.allQuickActivities;
    final userWeight = appState.profile.weightKg > 20
        ? appState.profile.weightKg
        : (appState.latestWeight?.weightKg ?? (appState.goals.targetWeightKg > 20 ? appState.goals.targetWeightKg : 70.0));
    final userHeight = appState.profile.heightCm >= 100 && appState.profile.heightCm <= 240
        ? appState.profile.heightCm
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: zen.sage),
            const SizedBox(width: 4),
            Text(
              'QUICK ACTIVITIES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: zen.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final preset = presets[idx];
              final burn = preset.calculateBurn(userWeight, userHeightCm: userHeight);
              final icon = _iconForType(preset.type);

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  ZenHaptics.medium();
                  await appState.logQuickActivity(preset);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('⚡ Logged ${preset.title} (-${burn.round()} kcal)'),
                      action: SnackBarAction(
                        label: 'UNDO',
                        textColor: zen.sage,
                        onPressed: () async {
                          if (appState.exercisesForDay.isNotEmpty) {
                            await appState.deleteExercise(appState.exercisesForDay.first.id);
                          }
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: zen.sage),
                      const SizedBox(width: 6),
                      Text(
                        preset.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '-${burn.round()} kcal',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: zen.sage,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Horizontal scroll bar with 1-tap fast food logging presets and custom user creations.
class _QuickBitesRow extends StatelessWidget {
  const _QuickBitesRow({
    required this.appState,
    required this.onSelectPreset,
  });

  final AppState appState;
  final ValueChanged<QuickBitePreset> onSelectPreset;

  void _showPresetOptions(BuildContext context, ZenColors zen, QuickBitePreset preset) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: zen.borderSoft),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: zen.inkMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              children: [
                Text(preset.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        '${preset.portion} • ${preset.macros.calories.round()} kcal (P: ${preset.macros.proteinG.round()}g C: ${preset.macros.carbsG.round()}g F: ${preset.macros.fatG.round()}g)',
                        style: TextStyle(color: zen.inkMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              leading: Icon(Icons.bolt_rounded, color: zen.sage),
              title: const Text('Log to Today', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                onSelectPreset(preset);
              },
            ),
            if (preset.isCustom) ...[
              ListTile(
                leading: Icon(Icons.edit_outlined, color: zen.sage),
                title: const Text('Edit Quick Bite'),
                onTap: () {
                  Navigator.pop(ctx);
                  showQuickBiteSheet(context, appState: appState, initialPreset: preset);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: zen.gentleClay),
                title: Text('Delete Quick Bite', style: TextStyle(color: zen.gentleClay)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await appState.deleteCustomQuickBite(preset.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted "${preset.name}"')),
                    );
                  }
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.copy_rounded, color: zen.sage),
                title: const Text('Customize & Save as My Own'),
                onTap: () {
                  Navigator.pop(ctx);
                  showQuickBiteSheet(
                    context,
                    appState: appState,
                    initialPreset: preset.copyWith(
                      id: 'qb_custom_${DateTime.now().millisecondsSinceEpoch}',
                      isCustom: true,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final presets = appState.allQuickBites;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: zen.sage),
            const SizedBox(width: 4),
            Text(
              'Quick Bites (1-Tap)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => showSavedCombosSheet(context, appState: appState),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: zen.borderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🍱', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      'Combos${appState.savedCombos.isNotEmpty ? ' (${appState.savedCombos.length})' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: zen.inkPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => showQuickBiteSheet(context, appState: appState),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: zen.sageSoft,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: zen.sage.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: zen.sage),
                    const SizedBox(width: 4),
                    Text(
                      'Create',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: zen.sage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => showQuickBiteSheet(context, appState: appState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: zen.sage.withOpacity(0.5), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 16, color: zen.sage),
                        const SizedBox(width: 6),
                        Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: zen.sage,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final preset = presets[index - 1];
              return InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => onSelectPreset(preset),
                onLongPress: () => _showPresetOptions(context, zen, preset),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: preset.isCustom ? zen.sageSoft : zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: preset.isCustom ? zen.sage.withOpacity(0.4) : zen.borderSoft,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(preset.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        preset.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (preset.isCustom) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.star_rounded, size: 13, color: zen.carbs),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: zen.sageSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${preset.macros.calories.round()}k',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: zen.sage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyMealsCard extends StatelessWidget {
  const _EmptyMealsCard({
    required this.onLogMeal,
    required this.onLoadSample,
    required this.onRepeatYesterday,
    required this.onVoiceLog,
    this.onChatLog,
  });

  final VoidCallback onLogMeal;
  final VoidCallback onLoadSample;
  final VoidCallback onRepeatYesterday;
  final VoidCallback onVoiceLog;
  final VoidCallback? onChatLog;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: zen.sageSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.spa_outlined, color: zen.sage, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'A calm, blank slate',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Speak hands-free, describe in natural words, snap a photo, or repeat yesterday\'s meals with 1 tap.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: zen.inkMuted,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onChatLog ?? onLogMeal,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Log a Meal'),
                ),
                OutlinedButton.icon(
                  onPressed: onRepeatYesterday,
                  icon: const Icon(Icons.repeat_rounded, size: 18),
                  label: const Text('Repeat Yesterday'),
                ),
                OutlinedButton(
                  onPressed: onLoadSample,
                  child: const Text('Preview Sample'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Repeat Yesterday" ghost chips displayed for meal types not yet logged today.
class _RepeatYesterdayGhostChips extends StatelessWidget {
  const _RepeatYesterdayGhostChips({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    if (appState.yesterdayMeals.isEmpty) return const SizedBox.shrink();

    final loggedMealTypes = appState.mealsForDay.map((m) => m.mealType).toSet();
    final candidates = <MealEntry>[];
    for (final meal in appState.yesterdayMeals) {
      if (!loggedMealTypes.contains(meal.mealType)) {
        if (!candidates.any((c) => c.mealType == meal.mealType)) {
          candidates.add(meal);
        }
      }
    }

    if (candidates.isEmpty) return const SizedBox.shrink();

    final zen = context.zen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 14, color: zen.inkMuted),
              const SizedBox(width: 6),
              Text(
                'REPEAT FROM YESTERDAY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: zen.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: candidates.map((meal) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      ZenHaptics.medium();
                      await appState.copyMealToToday(meal);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added "${meal.title}" to today (${meal.totalMacros.calories.round()} kcal)',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: zen.surfaceSubtle.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: zen.sage.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 15, color: zen.sage),
                          const SizedBox(width: 6),
                          Text(
                            '${meal.mealType.label}: ${meal.title}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: zen.inkPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: zen.sageSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${meal.totalMacros.calories.round()} kcal',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: zen.sage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Today's Plates" horizontal visual gallery displaying photo thumbnails for meals with images.
class _TodaysPlatesFilmstrip extends StatelessWidget {
  const _TodaysPlatesFilmstrip({required this.meals});

  final List<MealEntry> meals;

  @override
  Widget build(BuildContext context) {
    final photoMeals = meals
        .where((m) =>
            m.imagePath != null &&
            m.imagePath!.isNotEmpty &&
            File(m.imagePath!).existsSync())
        .toList();

    if (photoMeals.isEmpty) return const SizedBox.shrink();

    final zen = context.zen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 14, color: zen.sage),
              const SizedBox(width: 6),
              Text(
                "TODAY'S PLATES",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: zen.sage,
                ),
              ),
              const Spacer(),
              Text(
                '${photoMeals.length} plate${photoMeals.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 10, color: zen.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photoMeals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, index) {
                final meal = photoMeals[index];
                final file = File(meal.imagePath!);
                return GestureDetector(
                  onTap: () {
                    ZenHaptics.selection();
                    _showPlateLightbox(ctx, meal, file);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Image.file(
                          file,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                meal.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${meal.totalMacros.calories.round()} kcal',
                                style: TextStyle(
                                  color: zen.sageSoft,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPlateLightbox(BuildContext context, MealEntry meal, File file) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  InteractiveViewer(
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      height: MediaQuery.of(context).size.height * 0.55,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 16,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${meal.mealType.label} • P: ${meal.totalMacros.proteinG.round()}g C: ${meal.totalMacros.carbsG.round()}g F: ${meal.totalMacros.fatG.round()}g',
                          style: TextStyle(fontSize: 11, color: context.zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.zen.sageSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${meal.totalMacros.calories.round()} kcal',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: context.zen.sage,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
