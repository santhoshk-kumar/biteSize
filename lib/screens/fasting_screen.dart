import 'dart:async';
import 'package:flutter/material.dart';

import '../models/fasting_model.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/confetti_celebration.dart';
import '../widgets/shareable_infographic_sheet.dart';

/// Dedicated full-featured Intermittent Fasting screen with an interactive 4-stage
/// biological metabolic timeline, live countdown to next state, physiological benefits,
/// and fasting history statistics.
class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.appState.fasting.isActive) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _confirmEndFast(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End & Record Fast?'),
        content: Text(
          'You have completed ${widget.appState.fasting.elapsedHours.toStringAsFixed(1)} hours. End fast, record to history, and open eating window?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Fasting'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End & Record'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final wasTargetMet = widget.appState.fasting.targetReached;
      final protocolLabel = widget.appState.fasting.protocol.label;
      await ZenHaptics.medium();
      await widget.appState.endFast();
      if (context.mounted) {
        if (wasTargetMet) {
          showTargetCelebration(
            context,
            title: 'Fasting Protocol Completed! 🎉',
            subtitle: 'You completed your $protocolLabel fast! Eating window is now open.',
            icon: Icons.timer_rounded,
            accentColor: const Color(0xFFA855F7),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fast recorded to history! Eating window open.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final fasting = widget.appState.fasting;
    final stage = fasting.currentStage;
    final untilNext = fasting.timeUntilNextStage;
    final nextName = fasting.nextStageName;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Intermittent Fasting',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share Fasting Milestone',
            onPressed: () => _showShareMilestoneSheet(context, fasting, stage, zen),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: fasting.isActive
                  ? stage.accentColor.withOpacity(0.18)
                  : zen.surfaceSubtle,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: fasting.isActive ? stage.accentColor.withOpacity(0.4) : zen.borderSoft,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  fasting.isActive ? Icons.bolt_rounded : Icons.timer_outlined,
                  size: 14,
                  color: fasting.isActive ? stage.accentColor : zen.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  fasting.protocol.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: fasting.isActive ? stage.accentColor : zen.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        children: [
          // Hero Timer Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: fasting.isActive
                                ? [
                                    BoxShadow(
                                      color: stage.accentColor.withOpacity(0.22),
                                      blurRadius: 28,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: CircularProgressIndicator(
                            value: fasting.progress.clamp(0.0, 1.0),
                            strokeWidth: 12,
                            backgroundColor: zen.borderSoft,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              fasting.isActive ? stage.accentColor : zen.inkMuted,
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (fasting.isActive) ...[
                                // 1. Reached metabolic state badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: stage.accentColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: stage.accentColor.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 12, color: stage.accentColor),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Reached: ${stage.name}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: stage.accentColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // 2. Elapsed duration timer
                                Text(
                                  _formatDuration(fasting.elapsed),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                Text(
                                  fasting.targetReached
                                      ? 'Goal Hit! 🎉'
                                      : '${_formatDuration(fasting.remaining)} left to target',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: fasting.targetReached ? stage.accentColor : zen.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // 3. Next metabolic transition state
                                if (untilNext != null && nextName != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: zen.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: zen.borderSoft),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.hourglass_top_rounded, size: 11, color: zen.carbs),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Next: $nextName in ${_formatDuration(untilNext)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: zen.carbs,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: stage.accentColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: stage.accentColor.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome_rounded, size: 11, color: stage.accentColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Deep Autophagy Peak Active',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: stage.accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ] else ...[
                                Icon(
                                  Icons.timer_outlined,
                                  color: zen.inkMuted,
                                  size: 32,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '0h 00m',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                Text(
                                  'Fast Inactive',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: zen.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Select protocol & tap start below',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: zen.inkMuted.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (fasting.isActive) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showProtocolPicker(context),
                            child: Text('Protocol (${fasting.protocol.label})'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _confirmEndFast(context),
                            style: FilledButton.styleFrom(backgroundColor: zen.gentleClay),
                            child: const Text('End Fast'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Hydration Reminder Tip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: zen.water.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: zen.water.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.water_drop_rounded, size: 18, color: zen.water),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Hydration Tip: In ${stage.name}, insulin drops and kidneys flush electrolytes. Sip 300–500ml water with a pinch of salt or lemon.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: zen.water,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Start fast options
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: FastingProtocol.values.map((p) {
                        final selected = p == fasting.protocol;
                        return ChoiceChip(
                          label: Text(p.label),
                          selected: selected,
                          onSelected: (val) {
                            if (val) widget.appState.updateFastingProtocol(p);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await ZenHaptics.medium();
                          await widget.appState.startFast();
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Start Fast (${fasting.protocol.label})'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Metabolic States Timeline Section
          Row(
            children: [
              Icon(Icons.bubble_chart_rounded, size: 18, color: zen.sage),
              const SizedBox(width: 6),
              Text(
                'Metabolic States & Cellular Biology',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...FastingStage.allStages.map((st) {
            final isCurrent = fasting.isActive && st.stageIndex == stage.stageIndex;
            final isPassed = fasting.isActive && fasting.elapsedHours >= (st.stageIndex == 0 ? 4.0 : st.stageIndex == 1 ? 12.0 : 18.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrent
                    ? st.accentColor.withOpacity(0.12)
                    : zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCurrent
                      ? st.accentColor
                      : (isPassed ? st.accentColor.withOpacity(0.4) : zen.borderSoft),
                  width: isCurrent ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: st.accentColor.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(st.icon, color: st.accentColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  st.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isCurrent ? st.accentColor : zen.inkPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: st.accentColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    st.hoursRange,
                                    style: TextStyle(
                                      color: st.accentColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isCurrent)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '● ACTIVE NOW (${fasting.elapsedHours.toStringAsFixed(1)}h elapsed)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: st.accentColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    st.description,
                    style: TextStyle(fontSize: 12, color: zen.inkMuted, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  ...st.benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 13, color: st.accentColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(fontSize: 11, color: zen.inkPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          // History & Consistency Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: zen.sage),
                      const SizedBox(width: 6),
                      Text(
                        'Fasting History & Consistency',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCol('Completed Fasts', '${fasting.totalFastsCompleted}', zen.sage),
                      _statCol('Total Fasted', '${fasting.totalHoursFasted.toStringAsFixed(0)}h', zen.carbs),
                      _statCol('Longest Fast', '${fasting.longestFastHours.toStringAsFixed(1)}h', zen.protein),
                    ],
                  ),
                  if (fasting.history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(color: zen.borderSoft, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Completed Fast Sessions',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: zen.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...fasting.history.take(10).map((entry) {
                      final stg = FastingStage.forHours(entry.durationHours);
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
                                Icon(stg.icon, size: 14, color: stg.accentColor),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.durationHours.toStringAsFixed(1)}h Fast (${entry.protocol.label})',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${entry.endTime.month}/${entry.endTime.day} • ${stg.name}',
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
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  void _showProtocolPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.zen.borderSoft),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Fasting Protocol',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...FastingProtocol.values.map(
              (p) => ListTile(
                title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(p.description),
                trailing: p == widget.appState.fasting.protocol
                    ? Icon(Icons.check_circle_rounded, color: context.zen.sage)
                    : null,
                onTap: () {
                  widget.appState.updateFastingProtocol(p);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareMilestoneSheet(
    BuildContext context,
    FastingState fasting,
    FastingStage stage,
    ZenColors zen,
  ) {
    showShareInfographicSheet(
      context,
      appState: widget.appState,
      initialMode: InfographicMode.fasting,
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

/// Helper function to open the full Fasting Screen.
void showFastingScreen(BuildContext context, {required AppState appState}) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => FastingScreen(appState: appState),
    ),
  );
}

