import 'package:flutter/material.dart';

import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'confetti_celebration.dart';

/// Ultra-compact, low-profile Hydration Tracker Card for the daily dashboard (~54px height).
/// Delivers glanceable progress, fluid indicator, 1-tap quick increments (+250 / +500 ml),
/// and undo capabilities without taking up vertical screen space.
class CompactHydrationCard extends StatelessWidget {
  const CompactHydrationCard({
    super.key,
    required this.appState,
  });

  final AppState appState;

  Future<void> _logWater(BuildContext context, int amountMl) async {
    final prevTotal = appState.totalWaterMlForDay;
    final target = appState.goals.waterTargetMl;

    ZenHaptics.selection();
    await appState.addWater(amountMl);

    final newTotal = appState.totalWaterMlForDay;
    if (context.mounted && prevTotal < target && newTotal >= target) {
      showTargetCelebration(
        context,
        title: 'Hydration Target Reached! 💧',
        subtitle: '${newTotal}ml logged today! Optimal cellular recovery & metabolism active.',
        icon: Icons.water_drop_rounded,
        accentColor: const Color(0xFF2DD4BF),
      );
    }
  }

  Future<void> _showCustomWaterDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: '250');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Custom Water'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount (ml)',
            hintText: 'e.g. 330',
            suffixText: 'ml',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              Navigator.of(ctx).pop(val != null && val > 0 ? val : null);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result > 0 && context.mounted) {
      await _logWater(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final zen = context.zen;
        final totalMl = appState.totalWaterMlForDay;
        final targetMl = appState.goals.waterTargetMl <= 0 ? 2500 : appState.goals.waterTargetMl;
        final progress = (totalMl / targetMl).clamp(0.0, 1.0);
        final percent = (progress * 100).round();
        final hasLogs = appState.waterForDay.isNotEmpty;
        final useMl = appState.prefs.useMl;

        final smallIncrement = useMl ? 250 : 237;
        final largeIncrement = useMl ? 500 : 473;
        final smallLabel = useMl ? '+250' : '+8oz';
        final largeLabel = useMl ? '+500' : '+16oz';

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: zen.water.withValues(alpha: 0.28),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 1. Water Drop Icon with subtle water tint
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => _showCustomWaterDialog(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: zen.water.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: zen.water.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 18,
                    color: zen.water,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Middle Column: Text and slim progress bar
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showCustomWaterDialog(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Hydration',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${totalMl.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} / ${targetMl.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ml · $percent%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: zen.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: zen.borderSoft,
                          valueColor: AlwaysStoppedAnimation<Color>(zen.water),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Quick Action Buttons
              if (hasLogs) ...[
                IconButton(
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  color: zen.inkMuted,
                  tooltip: 'Undo last water log',
                  onPressed: () async {
                    ZenHaptics.selection();
                    await appState.undoLastWater();
                  },
                ),
                const SizedBox(width: 4),
              ],

              // +250 button
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _logWater(context, smallIncrement),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: zen.water.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: zen.water.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    smallLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: zen.water,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // +500 button
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _logWater(context, largeIncrement),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: zen.water.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: zen.water.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    largeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: zen.water,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
