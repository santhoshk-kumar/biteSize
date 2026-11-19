import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_log.dart';
import '../services/date_utils.dart';
import '../theme/zen_theme.dart';

/// Smooth Bezier weight progression chart with goal line.
class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({
    super.key,
    required this.entriesDesc,
    required this.targetWeightKg,
    required this.useKg,
    required this.onLogWeight,
  });

  final List<WeightEntry> entriesDesc;
  final double targetWeightKg;
  final bool useKg;
  final VoidCallback onLogWeight;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final chronological = entriesDesc.reversed.take(20).toList();
    final latest = entriesDesc.isEmpty ? null : entriesDesc.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight Trend',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      latest != null
                          ? 'Latest: ${ZenDateUtils.formatWeight(latest.weightKg, useKg: useKg)}  ·  Goal: ${ZenDateUtils.formatWeight(targetWeightKg, useKg: useKg)}'
                          : 'Goal: ${ZenDateUtils.formatWeight(targetWeightKg, useKg: useKg)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: zen.inkMuted),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onLogWeight,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Log'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (chronological.length < 2)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      color: zen.sage,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chronological.isEmpty
                          ? 'Log your weight to see calm trend curves over time.'
                          : 'Log one more check-in to plot your trend line.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: zen.inkMuted),
                    ),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: 145,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WeightLinePainter(
                    points: chronological,
                    targetKg: targetWeightKg,
                    lineColor: zen.sage,
                    fillColor: zen.sage.withOpacity(0.16),
                    goalColor: zen.carbs.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ZenDateUtils.shortMonthDay(chronological.first.loggedAt),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: zen.inkMuted),
                  ),
                  Text(
                    ZenDateUtils.shortMonthDay(chronological.last.loggedAt),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: zen.inkMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeightLinePainter extends CustomPainter {
  _WeightLinePainter({
    required this.points,
    required this.targetKg,
    required this.lineColor,
    required this.fillColor,
    required this.goalColor,
  });

  final List<WeightEntry> points;
  final double targetKg;
  final Color lineColor;
  final Color fillColor;
  final Color goalColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var minVal = targetKg;
    var maxVal = targetKg;
    for (final p in points) {
      minVal = math.min(minVal, p.weightKg);
      maxVal = math.max(maxVal, p.weightKg);
    }
    final padding = math.max(1.0, (maxVal - minVal) * 0.25);
    minVal -= padding;
    maxVal += padding;
    final range = math.max(0.5, maxVal - minVal);

    double yFor(double kg) {
      final norm = (kg - minVal) / range;
      return size.height - 12 - norm * (size.height - 24);
    }

    // Dashed target line
    final goalY = yFor(targetKg);
    final goalPaint = Paint()
      ..color = goalColor
      ..strokeWidth = 1.3;
    var dx = 0.0;
    while (dx < size.width) {
      canvas.drawLine(
        Offset(dx, goalY),
        Offset(math.min(dx + 6, size.width), goalY),
        goalPaint,
      );
      dx += 10;
    }

    final coords = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = 10 + (i / (points.length - 1)) * (size.width - 20);
      final y = yFor(points[i].weightKg);
      coords.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (var i = 0; i < coords.length - 1; i++) {
      final curr = coords[i];
      final next = coords[i + 1];
      final midX = (curr.dx + next.dx) / 2;
      linePath.cubicTo(midX, curr.dy, midX, next.dy, next.dx, next.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(coords.last.dx, size.height)
      ..lineTo(coords.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillColor, fillColor.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < coords.length; i++) {
      final isLast = i == coords.length - 1;
      canvas.drawCircle(
        coords[i],
        isLast ? 5.0 : 3.4,
        Paint()..color = lineColor,
      );
      if (isLast) {
        canvas.drawCircle(
          coords[i],
          2.2,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightLinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.targetKg != targetKg;
  }
}
