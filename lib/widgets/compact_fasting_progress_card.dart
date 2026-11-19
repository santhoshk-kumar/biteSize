import 'package:flutter/material.dart';

import '../screens/habits_milestones_screen.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';

/// Compact Intermittent Fasting progress card for TodayScreen.
/// Displays progress summary and a direct button to open the full Fasting tab in Habits.
class CompactFastingProgressCard extends StatelessWidget {
  const CompactFastingProgressCard({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final fasting = appState.fasting;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zen.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title & Button to Fasting Page in Habits
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    color: zen.sage,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Intermittent Fasting',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    ZenHaptics.selection();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HabitsMilestonesScreen(
                          appState: appState,
                          initialTab: 2, // Fasting tab in Habits screen
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text(
                    'Go to Fasting',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    foregroundColor: zen.sage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress Display
            if (fasting.isActive) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: zen.sageSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Stage: ${fasting.currentStage.name}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: zen.sage,
                      ),
                    ),
                  ),
                  Text(
                    '${fasting.elapsed.inHours}h ${fasting.elapsed.inMinutes.remainder(60)}m elapsed (${(fasting.progress * 100).round()}%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: zen.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fasting.progress.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: zen.surfaceSubtle,
                  color: zen.sage,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fasting.startTime != null
                        ? 'Started ${ZenDateUtils.formatTime(fasting.startTime!)}'
                        : 'Active fast',
                    style: TextStyle(fontSize: 11, color: zen.inkMuted),
                  ),
                  Text(
                    'Target: ${fasting.targetHours.round()}h (${fasting.protocol.label})',
                    style: TextStyle(fontSize: 11, color: zen.inkMuted),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: zen.inkMuted.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No active fast in progress',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: zen.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${fasting.totalFastsCompleted} completed',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: zen.sage,
                    ),
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
