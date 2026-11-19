import 'package:flutter/material.dart';

import '../models/fasting_model.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';

/// Interactive Intermittent Fasting consistency & history card designed for Trends.
/// Displays a 7-day fasting depth bar chart against the protocol target,
/// lifetime fasting milestones, metabolic stages reached, and recent session logs.
class FastingTrendCard extends StatefulWidget {
  const FastingTrendCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<FastingTrendCard> createState() => _FastingTrendCardState();
}

class _FastingTrendCardState extends State<FastingTrendCard> {
  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final fasting = widget.appState.fasting;
    final protocol = fasting.protocol;
    final targetH = protocol.fastHours.toDouble();

    final today = ZenDateUtils.dateOnly(DateTime.now());
    final last7Days = ZenDateUtils.trailingDates(today, 7);

    // Calculate daily hours for the 7-day chart
    final dailyHours = <DateTime, double>{};
    for (final day in last7Days) {
      dailyHours[day] = fasting.hoursFastedOnDate(day);
    }

    final successCount = fasting.history.where((e) => e.targetMet).length;
    final successRate = fasting.history.isNotEmpty
        ? ((successCount / fasting.history.length) * 100).round()
        : (fasting.totalFastsCompleted > 0 ? 100 : 0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: zen.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.timer_rounded,
                    color: Color(0xFFA855F7),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fasting Rhythm & Autophagy',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${protocol.label} Protocol (${protocol.fastHours}h Fast / ${protocol.eatHours}h Window)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: zen.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: fasting.isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.14)
                        : zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: fasting.isActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : zen.borderSoft,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fasting.isActive
                              ? const Color(0xFF10B981)
                              : zen.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        fasting.isActive
                            ? '${fasting.elapsedHours.toStringAsFixed(1)}h Active'
                            : 'Eating Window',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: fasting.isActive
                              ? const Color(0xFF10B981)
                              : zen.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 7-Day Fasting Depth Consistency Bar Chart
            Container(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              decoration: BoxDecoration(
                color: zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: zen.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '7-DAY CONSISTENCY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: zen.inkMuted,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 2,
                            color: const Color(0xFFA855F7).withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Target ${protocol.fastHours}h',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: zen.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: last7Days.map((date) {
                        final h = dailyHours[date] ?? 0.0;
                        final isToday = ZenDateUtils.isSameDay(date, today);
                        final fraction = (h / 24.0).clamp(0.0, 1.0);
                        final met = h >= targetH;

                        // Metabolic stage color
                        Color barColor;
                        if (h >= 18.0) {
                          barColor = const Color(0xFFA855F7); // Autophagy purple
                        } else if (h >= 12.0) {
                          barColor = const Color(0xFF10B981); // Ketosis emerald
                        } else if (h >= 4.0) {
                          barColor = const Color(0xFFFBBF24); // Glycogen amber
                        } else if (h > 0.0) {
                          barColor = const Color(0xFF38BDF8); // Digestion blue
                        } else {
                          barColor = zen.borderSoft;
                        }

                        final dayName = ZenDateUtils.formatWeekdayShort(date);

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (h > 0)
                                  Text(
                                    '${h.toStringAsFixed(1)}h',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: met
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: met ? barColor : zen.inkMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else
                                  Text(
                                    '—',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: zen.inkMuted.withValues(alpha: 0.5),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      // Target benchmark line at targetH/24
                                      Positioned(
                                        bottom: 120 * (targetH / 24.0) - 1,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 1.5,
                                          color: const Color(0xFFA855F7)
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      // Progress bar
                                      FractionallySizedBox(
                                        heightFactor:
                                            fraction > 0 ? fraction : 0.05,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: h > 0
                                                ? barColor
                                                : zen.borderSoft
                                                    .withValues(alpha: 0.3),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            boxShadow: met
                                                ? [
                                                    BoxShadow(
                                                      color: barColor.withValues(
                                                          alpha: 0.3),
                                                      blurRadius: 4,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isToday ? 'Today' : dayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isToday ? zen.sage : zen.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Lifetime Fasting Stats Row
            Row(
              children: [
                Expanded(
                  child: _MiniStatBox(
                    label: 'Fasts Done',
                    value: '${fasting.totalFastsCompleted}',
                    accent: zen.sage,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStatBox(
                    label: 'Total Fasted',
                    value: '${fasting.totalHoursFasted.toStringAsFixed(0)}h',
                    accent: const Color(0xFFA855F7),
                    icon: Icons.hourglass_bottom_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStatBox(
                    label: 'Longest Fast',
                    value: '${fasting.longestFastHours.toStringAsFixed(1)}h',
                    accent: const Color(0xFF10B981),
                    icon: Icons.military_tech_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStatBox(
                    label: 'Success Rate',
                    value: '$successRate%',
                    accent: zen.carbs,
                    icon: Icons.track_changes_rounded,
                  ),
                ),
              ],
            ),

            // Fasting History & Consistency Section (Always Visible)
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: Color(0xFFA855F7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Fasting History & Sessions (${fasting.history.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                if (fasting.history.isNotEmpty)
                  Text(
                    'Last ${fasting.history.length > 10 ? 10 : fasting.history.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: zen.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (fasting.history.isNotEmpty)
              ...fasting.history
                  .take(10)
                  .map((entry) => _HistoryEntryRow(entry: entry, zen: zen))
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: zen.borderSoft),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_empty_rounded,
                      size: 26,
                      color: zen.inkMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No completed fast sessions recorded yet',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: zen.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Start and complete your first fast above to track rhythm',
                      style: TextStyle(
                        fontSize: 11,
                        color: zen.inkMuted.withValues(alpha: 0.8),
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

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: zen.inkMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryRow extends StatelessWidget {
  const _HistoryEntryRow({required this.entry, required this.zen});

  final CompletedFastEntry entry;
  final ZenColors zen;

  @override
  Widget build(BuildContext context) {
    final stage = FastingStage.forHours(entry.durationHours);
    final dateStr =
        '${entry.endTime.month}/${entry.endTime.day} (${ZenDateUtils.formatWeekdayShort(entry.endTime)})';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(stage.icon, size: 14, color: stage.accentColor),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.durationHours.toStringAsFixed(1)}h Fast (${entry.protocol.label})',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 10, color: zen.inkMuted),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: entry.targetMet
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : zen.gentleClay.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.targetMet ? 'Goal Hit 🎉' : 'Short',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: entry.targetMet ? const Color(0xFF10B981) : zen.gentleClay,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
