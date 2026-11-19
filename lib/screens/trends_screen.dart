import 'package:flutter/material.dart';

import '../models/exercise_entry.dart';
import '../models/health_log.dart';
import '../models/nutrition.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/weight_trend_chart.dart';
import 'calculators_screen.dart';

/// Redesigned Trends screen featuring:
/// - Core cards: Period overview, Totals, Activity summary, and Breakdown (weekly/yearly)
/// - Time options: Weekly, Monthly, and Yearly
/// - Monthly view omits 31-day daily breakdown table per user request
/// - Yearly view shows 12-month summary breakdown
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

enum TrendsTimeScope { weekly, monthly, yearly }

class _TrendsScreenState extends State<TrendsScreen> {
  TrendsTimeScope _scope = TrendsTimeScope.weekly;
  int _selectedWeekOffset = 0; // 0 = This week, 1 = Last week, 2 = 2 weeks ago, 3 = 3 weeks ago
  int _selectedMonthOffset = 0; // 0 = This month, 1 = Last month, etc.
  int _selectedYearOffset = 0; // 0 = This year, 1 = Last year, etc.
  List<ExerciseEntry> _periodExercises = [];
  Map<String, DailyCalorieSummary> _customPeriodSummaries = {};
  bool _loadingExercises = false;

  bool get _isWeekly => _scope == TrendsTimeScope.weekly;
  bool get _isMonthly => _scope == TrendsTimeScope.monthly;
  bool get _isYearly => _scope == TrendsTimeScope.yearly;

  static const List<String> _weekLabels = [
    'This week',
    'Last week',
    '2 weeks ago',
    '3 weeks ago',
  ];

  @override
  void initState() {
    super.initState();
    _fetchExercisesForActivePeriod();
  }

  @override
  void didUpdateWidget(covariant TrendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchExercisesForActivePeriod();
  }

  Future<void> _fetchExercisesForActivePeriod() async {
    setState(() => _loadingExercises = true);
    final dates = _getActiveDates();
    if (dates.isEmpty) {
      if (mounted) setState(() => _loadingExercises = false);
      return;
    }
    final startKey = ZenDateUtils.toDateKey(dates.first);
    final endKey = ZenDateUtils.toDateKey(dates.last);
    final exList = await widget.appState.getExercisesForDateRange(startKey, endKey);
    final summaries = await widget.appState.getDailySummaries(dates);
    if (mounted) {
      setState(() {
        _periodExercises = exList;
        _customPeriodSummaries = summaries;
        _loadingExercises = false;
      });
    }
  }

  List<DateTime> _getActiveDates() {
    final today = ZenDateUtils.dateOnly(DateTime.now());
    switch (_scope) {
      case TrendsTimeScope.weekly:
        final anchor = today.subtract(Duration(days: _selectedWeekOffset * 7));
        return ZenDateUtils.weekDatesFor(anchor);
      case TrendsTimeScope.monthly:
        final targetDate = DateTime(today.year, today.month - _selectedMonthOffset, 1);
        final daysInMonth = DateTime(targetDate.year, targetDate.month + 1, 0).day;
        return List.generate(
          daysInMonth,
          (i) => DateTime(targetDate.year, targetDate.month, i + 1),
        );
      case TrendsTimeScope.yearly:
        final targetYear = today.year - _selectedYearOffset;
        final isLeap = (targetYear % 4 == 0 && targetYear % 100 != 0) || (targetYear % 400 == 0);
        final daysInYear = isLeap ? 366 : 365;
        final startOfYear = DateTime(targetYear, 1, 1);
        return List.generate(
          daysInYear,
          (i) => startOfYear.add(Duration(days: i)),
        );
    }
  }

  Future<void> _showLogWeightDialog(BuildContext context) async {
    final useKg = widget.appState.prefs.useKg;
    final latestKg = widget.appState.latestWeight?.weightKg ?? widget.appState.goals.targetWeightKg;
    final initialVal = useKg ? latestKg : ZenDateUtils.kgToLb(latestKg);

    final weightCtrl = TextEditingController(text: initialVal.toStringAsFixed(1));
    final noteCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Weight'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: useKg ? 'Weight (kg)' : 'Weight (lb)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Morning check-in',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final entered = parseNonNegativeDouble(weightCtrl.text);
      if (entered > 0) {
        final kg = useKg ? entered : ZenDateUtils.lbToKg(entered);
        await widget.appState.logWeight(kg, note: noteCtrl.text);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Logged ${useKg ? "${entered.toStringAsFixed(1)} kg" : "${entered.toStringAsFixed(1)} lbs"}!',
              ),
            ),
          );
        }
      }
    }

    weightCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final dates = _getActiveDates();

    // Aggregations
    int daysTracked = 0;
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    int totalMeals = 0;

    final Map<DateTime, DailyCalorieSummary?> daySummaryMap = {};

    for (final day in dates) {
      final key = ZenDateUtils.toDateKey(day);
      final s = _customPeriodSummaries[key] ?? widget.appState.recentSummaries[key];
      daySummaryMap[day] = s;
      if (s != null && s.mealCount > 0) {
        daysTracked++;
        totalCalories += s.calories;
        totalProtein += s.proteinG;
        totalCarbs += s.carbsG;
        totalFat += s.fatG;
        totalMeals += s.mealCount;
      }
    }

    final int avgDailyCalories = daysTracked > 0 ? (totalCalories / daysTracked).round() : 0;
    final int totalWorkouts = _periodExercises.length;
    final int totalBurned = _periodExercises.fold(0.0, (acc, e) => acc + e.caloriesBurned).round();

    final String dateRangeLabel = switch (_scope) {
      TrendsTimeScope.weekly =>
        '${ZenDateUtils.monthShort(dates.first)} ${dates.first.day} – ${ZenDateUtils.monthShort(dates.last)} ${dates.last.day}, ${dates.last.year}',
      TrendsTimeScope.monthly => '${ZenDateUtils.monthShort(dates.first)} ${dates.first.year}',
      TrendsTimeScope.yearly => '${dates.first.year} Full Year',
    };

    final String subtitleLabel = switch (_scope) {
      TrendsTimeScope.weekly => 'Weekly consistency & macro breakdown',
      TrendsTimeScope.monthly => 'Monthly historical performance',
      TrendsTimeScope.yearly => 'Yearly macro & activity progression',
    };

    final String card1Badge = switch (_scope) {
      TrendsTimeScope.weekly => _weekLabels[_selectedWeekOffset],
      TrendsTimeScope.monthly => 'Monthly Summary',
      TrendsTimeScope.yearly => 'Yearly Summary',
    };

    final String totalsTitle = switch (_scope) {
      TrendsTimeScope.weekly => 'Weekly Totals',
      TrendsTimeScope.monthly => 'Monthly Totals',
      TrendsTimeScope.yearly => 'Yearly Totals',
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          // Header Bar with Title & Calculators Shortcut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trends & Analytics',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(Icons.calculate_outlined, size: 15, color: zen.inkMuted),
                label: const Text('Calculators', style: TextStyle(fontSize: 12)),
                backgroundColor: zen.surfaceSubtle,
                side: BorderSide(color: zen.borderSoft),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CalculatorsScreen(appState: widget.appState),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scope Switcher: Weekly View | Monthly View | Yearly View
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  avatar: Icon(
                    Icons.view_week_rounded,
                    size: 14,
                    color: _isWeekly ? const Color(0xFF090A0E) : zen.sage,
                  ),
                  label: const Text('Weekly View'),
                  selected: _isWeekly,
                  selectedColor: zen.sage,
                  backgroundColor: zen.surfaceSubtle,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _isWeekly ? FontWeight.w800 : FontWeight.w600,
                    color: _isWeekly ? const Color(0xFF090A0E) : zen.inkPrimary,
                  ),
                  side: BorderSide(color: _isWeekly ? zen.sage : zen.borderSoft),
                  onSelected: (selected) {
                    if (selected) {
                      ZenHaptics.selection();
                      setState(() {
                        _scope = TrendsTimeScope.weekly;
                        _selectedWeekOffset = 0;
                      });
                      _fetchExercisesForActivePeriod();
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: Icon(
                    Icons.calendar_month_rounded,
                    size: 14,
                    color: _isMonthly ? const Color(0xFF090A0E) : zen.carbs,
                  ),
                  label: const Text('Monthly View'),
                  selected: _isMonthly,
                  selectedColor: zen.sage,
                  backgroundColor: zen.surfaceSubtle,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _isMonthly ? FontWeight.w800 : FontWeight.w600,
                    color: _isMonthly ? const Color(0xFF090A0E) : zen.inkPrimary,
                  ),
                  side: BorderSide(color: _isMonthly ? zen.sage : zen.borderSoft),
                  onSelected: (selected) {
                    if (selected) {
                      ZenHaptics.selection();
                      setState(() {
                        _scope = TrendsTimeScope.monthly;
                        _selectedMonthOffset = 0;
                      });
                      _fetchExercisesForActivePeriod();
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: _isYearly ? const Color(0xFF090A0E) : zen.protein,
                  ),
                  label: const Text('Yearly View'),
                  selected: _isYearly,
                  selectedColor: zen.sage,
                  backgroundColor: zen.surfaceSubtle,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _isYearly ? FontWeight.w800 : FontWeight.w600,
                    color: _isYearly ? const Color(0xFF090A0E) : zen.inkPrimary,
                  ),
                  side: BorderSide(color: _isYearly ? zen.sage : zen.borderSoft),
                  onSelected: (selected) {
                    if (selected) {
                      ZenHaptics.selection();
                      setState(() {
                        _scope = TrendsTimeScope.yearly;
                        _selectedYearOffset = 0;
                      });
                      _fetchExercisesForActivePeriod();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Period Selector: This week / Last week (or Month Selector / Year Selector)
          if (_isWeekly)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_weekLabels.length, (idx) {
                  final isSelected = _selectedWeekOffset == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_weekLabels[idx]),
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
                          setState(() => _selectedWeekOffset = idx);
                          _fetchExercisesForActivePeriod();
                        }
                      },
                    ),
                  );
                }),
              ),
            )
          else if (_isMonthly)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(4, (idx) {
                  final now = DateTime.now();
                  final target = DateTime(now.year, now.month - idx, 1);
                  final label = idx == 0
                      ? 'This month (${ZenDateUtils.monthShort(target)})'
                      : idx == 1
                          ? 'Last month (${ZenDateUtils.monthShort(target)})'
                          : '${ZenDateUtils.monthShort(target)} ${target.year}';
                  final isSelected = _selectedMonthOffset == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
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
                          setState(() => _selectedMonthOffset = idx);
                          _fetchExercisesForActivePeriod();
                        }
                      },
                    ),
                  );
                }),
              ),
            )
          else
            // Yearly Selector: 2026 (This Year) / 2025 (Last Year)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(2, (idx) {
                  final now = DateTime.now();
                  final targetYear = now.year - idx;
                  final label = idx == 0 ? '$targetYear (This Year)' : '$targetYear (Last Year)';
                  final isSelected = _selectedYearOffset == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
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
                          setState(() => _selectedYearOffset = idx);
                          _fetchExercisesForActivePeriod();
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 16),

          // ---------------------------------------------------------
          // CARD 1: Date Range, Avg Calorie Daily, Days Tracked
          // ---------------------------------------------------------
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: zen.borderSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: zen.sage),
                          const SizedBox(width: 8),
                          Text(
                            dateRangeLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: zen.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: zen.borderSoft),
                        ),
                        child: Text(
                          card1Badge,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: zen.inkMuted),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AVG CALORIE DAILY',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: zen.inkMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              avgDailyCalories > 0 ? '$avgDailyCalories' : '—',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: zen.carbs,
                              ),
                            ),
                            Text(
                              'kcal / tracked day',
                              style: TextStyle(fontSize: 11, color: zen.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 50,
                        width: 1,
                        color: zen.borderSoft,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DAYS TRACKED',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: zen.inkMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$daysTracked / ${dates.length}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: zen.sage,
                              ),
                            ),
                            Text(
                              daysTracked == dates.length ? '100% adherence' : '$daysTracked days with logs',
                              style: TextStyle(fontSize: 11, color: zen.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // CARD 2: Weekly / Monthly / Yearly Totals
          // ---------------------------------------------------------
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: zen.borderSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        totalsTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(
                        '${totalCalories.round()} kcal total',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: zen.sage),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMacroBox(
                          context,
                          label: 'Calories',
                          value: '${totalCalories.round()}',
                          unit: 'kcal',
                          color: zen.sage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMacroBox(
                          context,
                          label: 'Protein',
                          value: '${totalProtein.round()}',
                          unit: 'g',
                          color: zen.protein,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMacroBox(
                          context,
                          label: 'Carbs',
                          value: '${totalCarbs.round()}',
                          unit: 'g',
                          color: zen.carbs,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMacroBox(
                          context,
                          label: 'Fat',
                          value: '${totalFat.round()}',
                          unit: 'g',
                          color: zen.fat,
                        ),
                      ),
                    ],
                  ),
                  if (totalProtein + totalCarbs + totalFat > 0) ...[
                    const SizedBox(height: 14),
                    _buildMacroRatioBar(
                      proteinG: totalProtein,
                      carbsG: totalCarbs,
                      fatG: totalFat,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // CARD 3: Activity & Expenditure (Meals, Workouts, Burned)
          // ---------------------------------------------------------
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: zen.borderSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Activity & Expenditure',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (_loadingExercises)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: zen.sage),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActivityItem(
                          context,
                          icon: Icons.restaurant_rounded,
                          label: 'Meals',
                          value: '$totalMeals',
                          unit: 'logged',
                          color: zen.sage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActivityItem(
                          context,
                          icon: Icons.fitness_center_rounded,
                          label: 'Workouts',
                          value: '$totalWorkouts',
                          unit: 'completed',
                          color: zen.gentleClay,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActivityItem(
                          context,
                          icon: Icons.local_fire_department_rounded,
                          label: 'Burned',
                          value: '$totalBurned',
                          unit: 'kcal',
                          color: zen.carbs,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // CARD 4: Daily Breakdown (Weekly) OR Monthly Breakdown (Yearly)
          // NOTE: Omitted completely in Monthly view per user instruction:
          // "No need of daily breakdown in monthly view in trends screen instead we can also add a yearly view"
          // ---------------------------------------------------------
          if (_isWeekly) ...[
            _buildWeeklyDailyBreakdownCard(context, dates, daySummaryMap),
            const SizedBox(height: 14),
          ] else if (_isYearly) ...[
            _buildYearlyMonthlyBreakdownCard(context, dates.first.year, daySummaryMap),
            const SizedBox(height: 14),
          ],

          // Weight Trend & Quick Logging
          WeightTrendChart(
            entriesDesc: widget.appState.weightHistory,
            targetWeightKg: widget.appState.goals.targetWeightKg,
            useKg: widget.appState.prefs.useKg,
            onLogWeight: () => _showLogWeightDialog(context),
          ),
          const SizedBox(height: 14),

          // Calculators Link
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Calculators & Planning'),
                      ),
                      body: CalculatorsScreen(appState: widget.appState),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('Body Composition & Calorie Calculators'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyDailyBreakdownCard(
    BuildContext context,
    List<DateTime> dates,
    Map<DateTime, DailyCalorieSummary?> daySummaryMap,
  ) {
    final zen = context.zen;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: zen.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Breakdown',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  'Day • Cal • P • C • F',
                  style: TextStyle(fontSize: 11, color: zen.inkMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ...dates.map((day) {
              final summary = daySummaryMap[day];
              final dayLabel = ZenDateUtils.formatWeekdayShort(day);
              final dateLabel = '${day.day} ${ZenDateUtils.monthShort(day)}';
              final cal = summary?.calories.round() ?? 0;
              final p = summary?.proteinG.round() ?? 0;
              final c = summary?.carbsG.round() ?? 0;
              final f = summary?.fatG.round() ?? 0;
              final hasLogs = (summary?.mealCount ?? 0) > 0;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: zen.borderSoft.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 68,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: hasLogs ? zen.inkPrimary : zen.inkMuted,
                            ),
                          ),
                          Text(
                            dateLabel,
                            style: TextStyle(fontSize: 10, color: zen.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTableCol(cal > 0 ? '$cal' : '—', 'Cal', zen.sage, hasLogs),
                          _buildTableCol(p > 0 ? '${p}g' : '—', 'Prot', zen.protein, hasLogs),
                          _buildTableCol(c > 0 ? '${c}g' : '—', 'Carb', zen.carbs, hasLogs),
                          _buildTableCol(f > 0 ? '${f}g' : '—', 'Fat', zen.fat, hasLogs),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasLogs ? zen.sageSoft : zen.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasLogs ? '$cal kcal' : 'None',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasLogs ? zen.sage : zen.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyMonthlyBreakdownCard(
    BuildContext context,
    int year,
    Map<DateTime, DailyCalorieSummary?> daySummaryMap,
  ) {
    final zen = context.zen;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: zen.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Breakdown ($year)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  'Month • Avg Cal • Days • Total',
                  style: TextStyle(fontSize: 11, color: zen.inkMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ...List.generate(12, (mIdx) {
              final month = mIdx + 1;
              final monthDate = DateTime(year, month, 1);
              final daysInMonth = DateTime(year, month + 1, 0).day;
              int monthTracked = 0;
              double monthCal = 0;

              for (int d = 1; d <= daysInMonth; d++) {
                final day = DateTime(year, month, d);
                final summary = daySummaryMap[day];
                if (summary != null && summary.mealCount > 0) {
                  monthTracked++;
                  monthCal += summary.calories;
                }
              }

              final hasLogs = monthTracked > 0;
              final avgDaily = hasLogs ? (monthCal / monthTracked).round() : 0;
              final monthName = ZenDateUtils.monthShort(monthDate);

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: zen.borderSoft.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: hasLogs ? zen.inkPrimary : zen.inkMuted,
                            ),
                          ),
                          Text(
                            '$daysInMonth days',
                            style: TextStyle(fontSize: 10, color: zen.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTableCol(avgDaily > 0 ? '$avgDaily' : '—', 'Avg Cal', zen.sage, hasLogs),
                          _buildTableCol('$monthTracked/$daysInMonth', 'Tracked', zen.carbs, hasLogs),
                          _buildTableCol(hasLogs ? '${monthCal.round()}' : '—', 'Total kcal', zen.protein, hasLogs),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasLogs ? zen.sageSoft : zen.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasLogs ? '$monthTracked d' : 'None',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasLogs ? zen.sage : zen.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCol(String value, String header, Color color, bool active) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? color : Colors.grey,
          ),
        ),
        Text(
          header,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMacroBox(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
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
          Text(label, style: TextStyle(fontSize: 11, color: zen.inkMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          Text(unit, style: TextStyle(fontSize: 10, color: zen.inkMuted)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    final zen = context.zen;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            '$label $unit',
            style: TextStyle(fontSize: 11, color: zen.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRatioBar({
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) {
    final total = (proteinG * 4) + (carbsG * 4) + (fatG * 9);
    if (total <= 0) return const SizedBox.shrink();

    final pRatio = ((proteinG * 4) / total).clamp(0.0, 1.0);
    final cRatio = ((carbsG * 4) / total).clamp(0.0, 1.0);
    final fRatio = ((fatG * 9) / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(flex: (pRatio * 100).round(), child: Container(color: context.zen.protein)),
                Expanded(flex: (cRatio * 100).round(), child: Container(color: context.zen.carbs)),
                Expanded(flex: (fRatio * 100).round(), child: Container(color: context.zen.fat)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Protein ${(pRatio * 100).round()}%', style: TextStyle(fontSize: 10, color: context.zen.protein, fontWeight: FontWeight.bold)),
            Text('Carbs ${(cRatio * 100).round()}%', style: TextStyle(fontSize: 10, color: context.zen.carbs, fontWeight: FontWeight.bold)),
            Text('Fat ${(fRatio * 100).round()}%', style: TextStyle(fontSize: 10, color: context.zen.fat, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
