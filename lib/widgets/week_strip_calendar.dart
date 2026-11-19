import 'package:flutter/material.dart';

import '../models/health_log.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../theme/zen_theme.dart';

/// Soft 7-day horizontal date selector with subtle daily progress indicators.
class WeekStripCalendar extends StatelessWidget {
  const WeekStripCalendar({
    super.key,
    required this.selectedDate,
    required this.calorieTarget,
    required this.summaries,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final int calorieTarget;
  final Map<String, DailyCalorieSummary> summaries;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final weekDates = ZenDateUtils.weekDatesFor(selectedDate);
    final today = ZenDateUtils.dateOnly(DateTime.now());
    final selectedOnly = ZenDateUtils.dateOnly(selectedDate);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Previous week',
              onPressed: () {
                ZenHaptics.selection();
                onSelectDate(selectedOnly.subtract(const Duration(days: 7)));
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
                  onSelectDate(today);
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
                onSelectDate(selectedOnly.add(const Duration(days: 7)));
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: weekDates.map((date) {
            final key = ZenDateUtils.toDateKey(date);
            final summary = summaries[key];
            final calories = summary?.calories ?? 0;
            final fillRatio =
                (calories / (calorieTarget <= 0 ? 2000 : calorieTarget))
                    .clamp(0.0, 1.0);
            final isSelected = date == selectedOnly;
            final isToday = date == today;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  ZenHaptics.selection();
                  onSelectDate(date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? zen.sageSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? zen.sage
                          : (isToday ? zen.borderSoft : Colors.transparent),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        ZenDateUtils.weekdayShort(date).substring(0, 2),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isSelected ? zen.sage : zen.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: fillRatio,
                              strokeWidth: 2.8,
                              backgroundColor: zen.surfaceSubtle,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                calories > calorieTarget
                                    ? zen.gentleClay
                                    : zen.sage,
                              ),
                            ),
                            Text(
                              '${date.day}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: zen.inkPrimary,
                                  ),
                            ),
                          ],
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
}
