import 'package:flutter/material.dart';

import '../services/date_utils.dart';
import '../theme/zen_theme.dart';

/// Calm hydration progress card with one-tap water logging and undo.
class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard({
    super.key,
    required this.totalMl,
    required this.targetMl,
    required this.useMl,
    required this.canUndo,
    required this.onAddMl,
    required this.onUndo,
  });

  final int totalMl;
  final int targetMl;
  final bool useMl;
  final bool canUndo;
  final ValueChanged<int> onAddMl;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final safeTarget = targetMl <= 0 ? 2500 : targetMl;
    final progress = (totalMl / safeTarget).clamp(0.0, 1.0);

    final smallStepMl = useMl ? 250 : 237; // 250 ml or ~8 fl oz
    final largeStepMl = useMl ? 500 : 473; // 500 ml or ~16 fl oz
    final smallLabel = useMl ? '+250 ml' : '+8 oz';
    final largeLabel = useMl ? '+500 ml' : '+16 oz';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.water.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.water_drop_outlined,
                    size: 20,
                    color: zen.water,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hydration',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${ZenDateUtils.formatWater(totalMl, useMl: useMl)} / ${ZenDateUtils.formatWater(safeTarget, useMl: useMl)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: zen.inkMuted,
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                if (canUndo)
                  IconButton(
                    tooltip: 'Undo last water log',
                    onPressed: onUndo,
                    icon: Icon(
                      Icons.undo_rounded,
                      size: 20,
                      color: zen.inkMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 450),
                builder: (context, anim, _) => LinearProgressIndicator(
                  value: anim,
                  minHeight: 8,
                  backgroundColor: zen.surfaceSubtle,
                  valueColor: AlwaysStoppedAnimation<Color>(zen.water),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAddMl(smallStepMl),
                    icon: Icon(Icons.add_rounded, size: 18, color: zen.water),
                    label: Text(smallLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAddMl(largeStepMl),
                    icon: Icon(
                      Icons.local_drink_outlined,
                      size: 18,
                      color: zen.water,
                    ),
                    label: Text(largeLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
