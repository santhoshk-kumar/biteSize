import 'package:flutter/material.dart';

import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'confetti_celebration.dart';

/// Interactive hydration card with animated fluid fill and 1-tap quick increment buttons.
class QuickWaterCard extends StatelessWidget {
  const QuickWaterCard({super.key, required this.appState});

  final AppState appState;

  Future<void> _logWater(BuildContext context, int amountMl) async {
    final prevTotal = appState.totalWaterMlForDay;
    final target = appState.goals.waterTargetMl;

    ZenHaptics.medium();
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
    final ctrl = TextEditingController(text: '350');
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
            hintText: 'e.g. 330 ml can',
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
        final targetMl = appState.goals.waterTargetMl;
        final progress = targetMl > 0 ? (totalMl / targetMl).clamp(0.0, 1.0) : 0.0;
        final percent = (progress * 100).round();
        final hasLogs = appState.waterForDay.isNotEmpty;

        return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: zen.water.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon, Title, Progress & Undo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.water.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.water_drop_rounded, color: zen.water, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hydration & Fluid Balance',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalMl / $targetMl ml ($percent%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: zen.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasLogs)
                  IconButton(
                    tooltip: 'Undo last glass',
                    icon: Icon(Icons.undo_rounded, size: 18, color: zen.inkMuted),
                    onPressed: () {
                      ZenHaptics.light();
                      appState.undoLastWater();
                    },
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: zen.water.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    percent >= 100 ? 'Goal Hit! 🎉' : '${targetMl - totalMl} ml left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: zen.water,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Animated Fluid Fill Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: zen.surfaceSubtle,
                  ),
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: 14,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              zen.water,
                              const Color(0xFF38BDF8), // Ice cyan
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 1-Tap Quick Increment Pills Row
            Row(
              children: [
                Expanded(
                  child: _QuickWaterPill(
                    icon: Icons.local_cafe_rounded,
                    label: '+250 ml',
                    subtext: 'Glass',
                    color: zen.water,
                    onTap: () => _logWater(context, 250),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickWaterPill(
                    icon: Icons.water_drop_outlined,
                    label: '+500 ml',
                    subtext: 'Bottle',
                    color: zen.water,
                    onTap: () => _logWater(context, 500),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickWaterPill(
                    icon: Icons.sports_bar_rounded,
                    label: '+750 ml',
                    subtext: 'Shaker',
                    color: zen.water,
                    onTap: () => _logWater(context, 750),
                  ),
                ),
                const SizedBox(width: 8),
                _CustomWaterButton(
                  color: zen.water,
                  onTap: () => _showCustomWaterDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}

class _QuickWaterPill extends StatelessWidget {
  const _QuickWaterPill({
    required this.icon,
    required this.label,
    required this.subtext,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtext;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: zen.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: zen.inkPrimary,
              ),
            ),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: zen.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomWaterButton extends StatelessWidget {
  const _CustomWaterButton({
    required this.color,
    required this.onTap,
  });

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: zen.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(Icons.add_rounded, size: 20, color: color),
      ),
    );
  }
}
