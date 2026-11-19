import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/fasting_model.dart';
import '../models/nutrition.dart';
import '../services/zen_haptics.dart';
import '../theme/zen_theme.dart';

/// Calm animated circular progress ring showing daily calorie intake vs target,
/// with interactive tap-to-cycle display modes (Consumed, Net Remaining, Percentage, Deficit),
/// and integrated fasting progress indicator.
class ZenCalorieRing extends StatefulWidget {
  const ZenCalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    required this.meals,
    this.burned = 0.0,
    this.fasting,
    this.onTapFasting,
  });

  final double consumed;
  final int target;
  final List<MealEntry> meals;
  final double burned;
  final FastingState? fasting;
  final VoidCallback? onTapFasting;

  @override
  State<ZenCalorieRing> createState() => _ZenCalorieRingState();
}

class _ZenCalorieRingState extends State<ZenCalorieRing> {
  int _ringMode =
      0; // 0: Consumed vs Target, 1: Remaining, 2: Percentage Reached, 3: Net Energy Deficit

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final safeTarget = widget.target <= 0 ? 2000 : widget.target;
    final ratio = (widget.consumed / safeTarget).clamp(0.0, 1.35);
    final isOver = widget.consumed > safeTarget;
    final delta = (safeTarget - widget.consumed).abs().round();

    final statusColor = isOver ? zen.gentleClay : zen.sage;
    final statusHeadline =
        isOver ? '+$delta kcal over target' : '$delta kcal remaining';
    final statusSubline = isOver
        ? 'Daily energy logged — keep staying consistent!'
        : (widget.consumed == 0
            ? 'Ready to log your first meal today'
            : '${((widget.consumed / safeTarget) * 100).round()}% of daily energy reached');

    String centerNumber;
    String centerSubline;
    if (_ringMode == 1) {
      centerNumber = isOver ? '+$delta' : delta.toString();
      centerSubline = isOver ? 'kcal over' : 'kcal remaining';
    } else if (_ringMode == 2) {
      centerNumber = '${((widget.consumed / safeTarget) * 100).round()}%';
      centerSubline = 'of goal reached';
    } else if (_ringMode == 3) {
      if (widget.burned > 0) {
        final net = (widget.consumed - widget.burned).round();
        centerNumber = '$net';
        centerSubline = 'net kcal (${widget.burned.round()} burn)';
      } else {
        centerNumber = isOver ? '+$delta' : '-$delta';
        centerSubline = isOver ? 'energy surplus' : 'energy deficit';
      }
    } else {
      centerNumber = widget.consumed.round().toString();
      centerSubline = 'of $safeTarget kcal';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    ZenHaptics.selection();
                    setState(() => _ringMode = (_ringMode + 1) % 4);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween:
                            Tween<double>(begin: 0, end: ratio.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedRatio, _) {
                          return SizedBox(
                            width: 148,
                            height: 148,
                            child: CustomPaint(
                              painter: _CalorieRingPainter(
                                progress: animatedRatio,
                                trackColor: zen.surfaceSubtle,
                                arcColor: statusColor,
                                glowColor: statusColor.withValues(alpha: 0.16),
                                fastingProgress: widget.fasting?.isActive == true
                                    ? widget.fasting?.progress
                                    : null,
                                fastingColor: widget.fasting?.isActive == true
                                    ? widget.fasting?.currentStage.accentColor
                                    : null,
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 240),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale:
                                          Tween<double>(begin: 0.88, end: 1.0)
                                              .animate(
                                        CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic),
                                      ),
                                      child: FadeTransition(
                                          opacity: animation, child: child),
                                    );
                                  },
                                  child: Column(
                                    key: ValueKey<int>(_ringMode),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        centerNumber,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: zen.inkPrimary,
                                              letterSpacing: -0.5,
                                            ),
                                      ),
                                      Text(
                                        centerSubline,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: zen.inkMuted,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // 4-Dot Mode indicator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(4, (idx) {
                          final isSelected = idx == _ringMode;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: isSelected ? 12 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: isSelected
                                  ? zen.sage
                                  : zen.inkMuted.withValues(alpha: 0.3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isOver
                              ? zen.gentleClay.withValues(alpha: 0.14)
                              : zen.sageSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusHeadline,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      if (widget.burned > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A45).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFFF7A45)),
                              const SizedBox(width: 4),
                              Text(
                                '-${widget.burned.round()} kcal active burn',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFF7A45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        statusSubline,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: zen.inkMuted,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 14),
                      _MealDistributionRow(meals: widget.meals),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.fasting != null) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  ZenHaptics.selection();
                  widget.onTapFasting?.call();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.fasting!.isActive
                        ? widget.fasting!.currentStage.accentColor.withValues(alpha: 0.12)
                        : zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.fasting!.isActive
                          ? widget.fasting!.currentStage.accentColor.withValues(alpha: 0.35)
                          : zen.borderSoft,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.fasting!.isActive
                            ? Icons.hourglass_top_rounded
                            : Icons.timer_outlined,
                        size: 15,
                        color: widget.fasting!.isActive
                            ? widget.fasting!.currentStage.accentColor
                            : zen.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.fasting!.isActive
                              ? 'Fasting: ${widget.fasting!.elapsed.inHours}h ${widget.fasting!.elapsed.inMinutes.remainder(60)}m (${(widget.fasting!.progress * 100).round()}%) • ${widget.fasting!.currentStage.name}'
                              : 'Fasting: No active fast • Tap to open',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: widget.fasting!.isActive
                                ? widget.fasting!.currentStage.accentColor
                                : zen.inkMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: widget.fasting!.isActive
                            ? widget.fasting!.currentStage.accentColor
                            : zen.inkMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealDistributionRow extends StatelessWidget {
  const _MealDistributionRow({required this.meals});

  final List<MealEntry> meals;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final totals = <MealType, double>{
      MealType.breakfast: 0,
      MealType.lunch: 0,
      MealType.dinner: 0,
      MealType.snack: 0,
    };
    for (final meal in meals) {
      totals[meal.mealType] =
          (totals[meal.mealType] ?? 0) + meal.totalMacros.calories;
    }

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: MealType.values.map((type) {
        final kcal = totals[type]?.round() ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kcal > 0 ? zen.sage : zen.borderSoft,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${type.label.substring(0, 1)} $kcal',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kcal > 0 ? zen.inkPrimary : zen.inkMuted,
                    fontWeight: kcal > 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  _CalorieRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.glowColor,
    this.fastingProgress,
    this.fastingColor,
  });

  final double progress;
  final Color trackColor;
  final Color arcColor;
  final Color glowColor;
  final double? fastingProgress;
  final Color? fastingColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Optional Concentric Outer Fasting Arc
    if (fastingProgress != null && fastingProgress! > 0 && fastingColor != null) {
      final fastingRadius = radius + 8.5;
      final fastingRect = Rect.fromCircle(center: center, radius: fastingRadius);
      final fastingTrackPaint = Paint()
        ..color = trackColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, fastingRadius, fastingTrackPaint);

      final fastingArcPaint = Paint()
        ..color = fastingColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      const startAngle = -math.pi / 2;
      final fastingSweep = 2 * math.pi * fastingProgress!.clamp(0.0, 1.0);
      canvas.drawArc(fastingRect, startAngle, fastingSweep, false, fastingArcPaint);
    }

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.001) return;

    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.fastingProgress != fastingProgress ||
        oldDelegate.fastingColor != fastingColor;
  }
}
