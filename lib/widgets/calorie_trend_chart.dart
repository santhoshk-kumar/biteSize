import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_log.dart';
import '../services/date_utils.dart';
import '../theme/zen_theme.dart';

/// Calm 14-day calorie bar chart with dashed goal line and tap inspection.
class CalorieTrendChart extends StatefulWidget {
  const CalorieTrendChart({
    super.key,
    required this.days,
    required this.summaries,
    required this.calorieTarget,
  });

  final List<DateTime> days;
  final Map<String, DailyCalorieSummary> summaries;
  final int calorieTarget;

  @override
  State<CalorieTrendChart> createState() => _CalorieTrendChartState();
}

class _CalorieTrendChartState extends State<CalorieTrendChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final target = widget.calorieTarget <= 0 ? 2000 : widget.calorieTarget;

    var maxVal = target * 1.25;
    for (final day in widget.days) {
      final cal = widget.summaries[ZenDateUtils.toDateKey(day)]?.calories ?? 0;
      maxVal = math.max(maxVal, cal * 1.12);
    }

    final activeIdx = _selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < widget.days.length
        ? _selectedIndex!
        : widget.days.length - 1;
    final activeDate = widget.days[activeIdx];
    final activeSummary =
        widget.summaries[ZenDateUtils.toDateKey(activeDate)];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '14-Day Calorie Rhythm',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  'Goal $target kcal',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: zen.inkMuted,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${ZenDateUtils.friendlyDateLabel(activeDate)}: ${(activeSummary?.calories ?? 0).round()} kcal'
              '${activeSummary != null && activeSummary.mealCount > 0 ? '  ·  P ${activeSummary.proteinG.round()}g  C ${activeSummary.carbsG.round()}g  F ${activeSummary.fatG.round()}g' : '  ·  No meals logged'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: zen.sage,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      if (widget.days.isEmpty) return;
                      final slotW = constraints.maxWidth / widget.days.length;
                      final idx = (details.localPosition.dx / slotW)
                          .floor()
                          .clamp(0, widget.days.length - 1);
                      setState(() => _selectedIndex = idx);
                    },
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, 150),
                      painter: _CalorieBarsPainter(
                        days: widget.days,
                        summaries: widget.summaries,
                        target: target.toDouble(),
                        maxVal: maxVal,
                        selectedIndex: activeIdx,
                        barColor: zen.sage,
                        overColor: zen.gentleClay,
                        trackColor: zen.surfaceSubtle,
                        dashedColor: zen.inkMuted.withOpacity(0.45),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ZenDateUtils.shortMonthDay(widget.days.first),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: zen.inkMuted),
                ),
                Text(
                  'Tap any bar to inspect',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: zen.inkMuted),
                ),
                Text(
                  ZenDateUtils.shortMonthDay(widget.days.last),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: zen.inkMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieBarsPainter extends CustomPainter {
  _CalorieBarsPainter({
    required this.days,
    required this.summaries,
    required this.target,
    required this.maxVal,
    required this.selectedIndex,
    required this.barColor,
    required this.overColor,
    required this.trackColor,
    required this.dashedColor,
  });

  final List<DateTime> days;
  final Map<String, DailyCalorieSummary> summaries;
  final double target;
  final double maxVal;
  final int selectedIndex;
  final Color barColor;
  final Color overColor;
  final Color trackColor;
  final Color dashedColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || maxVal <= 0) return;

    final goalY = size.height - (target / maxVal) * size.height;
    final dashPaint = Paint()
      ..color = dashedColor
      ..strokeWidth = 1.2;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, goalY),
        Offset(math.min(x + dashWidth, size.width), goalY),
        dashPaint,
      );
      x += dashWidth + dashSpace;
    }

    final slotW = size.width / days.length;
    final barW = math.min(16.0, slotW * 0.56);

    for (var i = 0; i < days.length; i++) {
      final key = ZenDateUtils.toDateKey(days[i]);
      final cal = summaries[key]?.calories ?? 0;
      final cx = slotW * i + slotW / 2;

      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, 0, barW, size.height),
        const Radius.circular(8),
      );
      canvas.drawRRect(bgRect, Paint()..color = trackColor);

      if (cal > 0) {
        final h = ((cal / maxVal) * size.height).clamp(6.0, size.height);
        final isSelected = i == selectedIndex;
        final baseColor = cal > target ? overColor : barColor;
        final paint = Paint()
          ..color = isSelected ? baseColor : baseColor.withOpacity(0.72);
        final barRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, size.height - h, barW, h),
          const Radius.circular(8),
        );
        canvas.drawRRect(barRect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieBarsPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.summaries != summaries ||
        oldDelegate.target != target;
  }
}
