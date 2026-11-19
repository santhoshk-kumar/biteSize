import 'dart:async';
import 'package:flutter/material.dart';

import '../models/fasting_model.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'confetti_celebration.dart';

/// Interactive Intermittent Fasting tracker card displaying real-time elapsed duration,
/// metabolic stages (Digestion, Glycogen Depletion, Fat Burning / Ketosis, Autophagy),
/// and protocol selection.
class FastingTimerCard extends StatefulWidget {
  const FastingTimerCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<FastingTimerCard> createState() => _FastingTimerCardState();
}

class _FastingTimerCardState extends State<FastingTimerCard> {
  Timer? _ticker;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant FastingTimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.appState.fasting.isActive) {
      _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && widget.appState.fasting.isActive) {
          setState(() {});
        }
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
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
        title: const Text('End Current Fast?'),
        content: Text(
          'You have completed ${widget.appState.fasting.elapsedHours.toStringAsFixed(1)} hours of fasting. End fast and open eating window?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Fasting'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Fast'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final wasTargetMet = widget.appState.fasting.targetReached;
      final label = widget.appState.fasting.protocol.label;
      await ZenHaptics.medium();
      await widget.appState.endFast();
      if (context.mounted && wasTargetMet) {
        showTargetCelebration(
          context,
          title: 'Fasting Target Reached! 🎉',
          subtitle: 'You completed your $label fast! Eating window is now open.',
          icon: Icons.timer_rounded,
          accentColor: const Color(0xFFA855F7),
        );
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: fasting.isActive
                          ? stage.accentColor.withValues(alpha: 0.15)
                          : zen.surfaceSubtle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      fasting.isActive ? stage.icon : Icons.timer_outlined,
                      color: fasting.isActive ? stage.accentColor : zen.inkMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Intermittent Fasting',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: fasting.isActive
                                    ? stage.accentColor.withValues(alpha: 0.18)
                                    : zen.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                fasting.protocol.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: fasting.isActive ? stage.accentColor : zen.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          fasting.isActive
                              ? '${stage.name} (${fasting.elapsedHours.toStringAsFixed(1)}h elapsed)'
                              : 'Track fasting & fat burning metabolic stages',
                          style: TextStyle(
                            fontSize: 11,
                            color: fasting.isActive ? stage.accentColor : zen.inkMuted,
                            fontWeight: fasting.isActive ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: zen.inkMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              if (fasting.isActive) ...[
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 164,
                        height: 164,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: stage.accentColor.withValues(alpha: 0.18),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: CircularProgressIndicator(
                          value: fasting.progress.clamp(0.0, 1.0),
                          strokeWidth: 10,
                          backgroundColor: zen.borderSoft,
                          valueColor: AlwaysStoppedAnimation<Color>(stage.accentColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: stage.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 10, color: stage.accentColor),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      'Reached: ${stage.name}',
                                      style: TextStyle(
                                        fontSize: 9.5,
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
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(fasting.elapsed),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              fasting.targetReached
                                  ? 'Target Reached! 🎉'
                                  : '${_formatDuration(fasting.remaining)} left',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: fasting.targetReached ? stage.accentColor : zen.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (untilNext != null && nextName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: zen.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⏳ Next: $nextName (${_formatDuration(untilNext)})',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: zen.carbs,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              Text(
                                '✨ Deep Autophagy Peak',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: stage.accentColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: stage.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stage.accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(stage.icon, color: stage.accentColor, size: 20),
                      const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stage.name,
                                style: TextStyle(
                                  color: stage.accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                stage.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: zen.inkPrimary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: stage.accentColor, size: 14),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showProtocolPicker(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text('Protocol (${fasting.protocol.label})'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _confirmEndFast(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: zen.gentleClay,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('End Fast'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Protocol:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
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
                      const SizedBox(height: 8),
                      Text(
                        fasting.protocol.description,
                        style: TextStyle(color: zen.inkMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => widget.appState.startFast(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text('Start Fast (${fasting.protocol.label})'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
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
                title: Text(
                  p.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}
