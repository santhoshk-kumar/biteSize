import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'bitesize_logo.dart';

/// Available presentation modes for the shareable infographic card.
enum InfographicMode {
  daily('Daily Recap', Icons.today_rounded),
  weekly('Weekly Metabolic', Icons.auto_graph_rounded),
  fasting('Fasting Milestone', Icons.timer_rounded);

  const InfographicMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Opens the unified modal sheet displaying the aesthetic Titanium Emerald
/// infographic card with 1-tap text and high-res image export.
Future<void> showShareInfographicSheet(
  BuildContext context, {
  required AppState appState,
  InfographicMode initialMode = InfographicMode.daily,
}) {
  ZenHaptics.light();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ShareableInfographicSheet(
      appState: appState,
      initialMode: initialMode,
    ),
  );
}

class ShareableInfographicSheet extends StatefulWidget {
  const ShareableInfographicSheet({
    super.key,
    required this.appState,
    this.initialMode = InfographicMode.daily,
  });

  final AppState appState;
  final InfographicMode initialMode;

  @override
  State<ShareableInfographicSheet> createState() =>
      _ShareableInfographicSheetState();
}

class _ShareableInfographicSheetState extends State<ShareableInfographicSheet> {
  late InfographicMode _mode;
  final GlobalKey _repaintKey = GlobalKey();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  void _onModeChanged(Set<InfographicMode> selected) {
    if (selected.isNotEmpty) {
      ZenHaptics.selection();
      setState(() => _mode = selected.first);
    }
  }

  String _generateShareableText() {
    final app = widget.appState;
    final useKg = app.prefs.useKg;
    final dateStr = ZenDateUtils.friendlyDateLabel(app.selectedDate);

    switch (_mode) {
      case InfographicMode.daily:
        final cal = app.totalMacrosForDay.calories;
        final target = app.currentEffectiveTarget;
        final diff = cal - target;
        final diffText = diff <= 0
            ? '${diff.abs()} kcal Deficit'
            : '+$diff kcal Surplus';

        final prot = app.totalMacrosForDay.proteinG.round();
        final protT = app.goals.proteinTargetG;
        final carbs = app.totalMacrosForDay.carbsG.round();
        final carbsT = app.goals.carbsTargetG;
        final fat = app.totalMacrosForDay.fatG.round();
        final fatT = app.goals.fatTargetG;

        final water = app.totalWaterMlForDay;
        final waterT = app.goals.waterTargetMl;
        final waterPct = waterT > 0 ? ((water / waterT) * 100).round() : 0;

        return '''🌿 BiteSize — Daily Nutrition Recap
📅 $dateStr

🎯 Calories: $cal / $target kcal ($diffText)
🥩 Protein: ${prot}g / ${protT}g
🍞 Carbs: ${carbs}g / ${carbsT}g
🥑 Fat: ${fat}g / ${fatT}g

💧 Hydration: $water / $waterT ml ($waterPct% Goal)
🔥 Habit Streak: ${app.currentStreakDays} Days Active
✨ Pacing Status: ${app.pacingStatus}

Tracked with BiteSize • Mindful Nutrition & Metabolism''';

      case InfographicMode.weekly:
        final report = app.currentWeeklyReport;
        return report.toShareableText(useKg: useKg);

      case InfographicMode.fasting:
        final fasting = app.fasting;
        final stage = fasting.currentStage;
        final elapsed = fasting.elapsedHours.toStringAsFixed(1);
        final target = fasting.protocol.fastHours;

        if (fasting.isActive) {
          return '''⏳ BiteSize — Intermittent Fasting Milestone
⚡ Protocol: ${fasting.protocol.label} (${fasting.protocol.description})
⏱️ Elapsed Time: ${elapsed}h / ${target}h
🔥 Metabolic Stage: ${stage.name} (${stage.hoursRange})
🧬 Cellular State: ${stage.description}

Completed Fasts: ${fasting.totalFastsCompleted} | Total Fasted: ${fasting.totalHoursFasted.toStringAsFixed(0)}h
✨ Tracked with BiteSize''';
        } else {
          return '''🎉 BiteSize — Intermittent Fasting Journey
🏆 Total Fasts Completed: ${fasting.totalFastsCompleted}
⌛ Total Hours Fasted: ${fasting.totalHoursFasted.toStringAsFixed(0)} hrs
⭐ Longest Fast: ${fasting.longestFastHours.toStringAsFixed(1)} hrs
⚡ Primary Protocol: ${fasting.protocol.label}

✨ Tracked with BiteSize''';
        }
    }
  }

  void _copyText() {
    try {
      final text = _generateShareableText();
      Clipboard.setData(ClipboardData(text: text));
      ZenHaptics.celebrationSequence();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Formatted report copied to clipboard!')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('_copyText failed: $e');
    }
  }

  Future<void> _shareOrSaveCard({bool saveOnly = false}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes != null && mounted) {
        await ZenHaptics.celebrationSequence();

        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${tempDir.path}/bitesize_${_mode.name}_$timestamp.png';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        if (saveOnly) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Card screenshot saved to: ${file.path}')),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          // Native system share sheet -> WhatsApp, Instagram, Messages, etc.
          final caption = _generateShareableText();
          final xFile = XFile(
            filePath,
            mimeType: 'image/png',
            name: 'bitesize_${_mode.name}_$timestamp.png',
          );
          await Share.shareXFiles(
            [xFile],
            text: caption,
            subject: 'BiteSize Daily Nutrition Recap',
          );
        }
      }
    } catch (e) {
      debugPrint('Error generating / sharing infographic card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing failed ($e). Formatted text was copied instead.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _copyText();
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: zen.borderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.ios_share_rounded, color: zen.sage, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Infographic Card',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        'Export aesthetic visual cards or formatted text',
                        style: TextStyle(fontSize: 12, color: zen.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Save Screenshot PNG',
                  icon: const Icon(Icons.camera_alt_outlined),
                  onPressed: _isExporting ? null : () => _shareOrSaveCard(saveOnly: true),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Mode Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<InfographicMode>(
              segments: InfographicMode.values.map((m) {
                return ButtonSegment<InfographicMode>(
                  value: m,
                  label: Text(m.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  icon: Icon(m.icon, size: 16),
                );
              }).toList(),
              selected: {_mode},
              onSelectionChanged: _onModeChanged,
            ),
          ),

          const SizedBox(height: 12),

          // Card Scrollable Preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: _buildInfographicCard(context),
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: zen.borderSoft)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _copyText,
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                    label: const Text(
                      'Copy Text',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: zen.sage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isExporting ? null : () => _shareOrSaveCard(),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share_rounded, size: 18),
                    label: Text(
                      _isExporting ? 'Preparing...' : 'Share (WhatsApp / Insta)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfographicCard(BuildContext context) {
    final zen = context.zen;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF064E3B), // Emerald 900
            Color(0xFF022C22), // Deep Teal obsidian
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: zen.sage.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: zen.sage.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding Header
          Row(
            children: [
              const BiteSizeLogo(size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'BITE',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: 'SIZE',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'METABOLIC INTELLIGENCE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF6EE7B7).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ZenDateUtils.shortMonthDay(widget.appState.selectedDate),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Content body based on mode
          if (_mode == InfographicMode.daily)
            _buildDailyContent(context)
          else if (_mode == InfographicMode.weekly)
            _buildWeeklyContent(context)
          else
            _buildFastingContent(context),

          const SizedBox(height: 18),

          // Bottom Signature Footer
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: zen.sage,
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          'Mindful Nutrition & Fasting',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Streak: ${widget.appState.currentStreakDays}d 🔥',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyContent(BuildContext context) {
    final app = widget.appState;
    final zen = context.zen;
    final totalCal = app.totalMacrosForDay.calories;
    final targetCal = app.currentEffectiveTarget;
    final diff = totalCal - targetCal;
    final isDeficit = diff <= 0;

    final prot = app.totalMacrosForDay.proteinG.round();
    final protTarget = app.goals.proteinTargetG;
    final protPct = protTarget > 0 ? (prot / protTarget).clamp(0.0, 1.0) : 0.0;

    final carbs = app.totalMacrosForDay.carbsG.round();
    final carbsTarget = app.goals.carbsTargetG;
    final carbsPct = carbsTarget > 0 ? (carbs / carbsTarget).clamp(0.0, 1.0) : 0.0;

    final fat = app.totalMacrosForDay.fatG.round();
    final fatTarget = app.goals.fatTargetG;
    final fatPct = fatTarget > 0 ? (fat / fatTarget).clamp(0.0, 1.0) : 0.0;

    final water = app.totalWaterMlForDay;
    final waterTarget = app.goals.waterTargetMl;
    final waterPercent = waterTarget > 0 ? ((water / waterTarget) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Calorie Hero Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAILY CALORIES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$totalCal',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: ' / $targetCal kcal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDeficit
                      ? zen.sage.withValues(alpha: 0.25)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDeficit ? zen.sage : const Color(0xFFF59E0B),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isDeficit ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                      color: isDeficit ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                      size: 18,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDeficit ? '${diff.abs()} Deficit' : '+$diff Surplus',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDeficit ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Macro Bars
        _buildMacroProgressBar('Protein', '${prot}g / ${protTarget}g', protPct, zen.sage),
        const SizedBox(height: 8),
        _buildMacroProgressBar('Carbs', '${carbs}g / ${carbsTarget}g', carbsPct, const Color(0xFF38BDF8)),
        const SizedBox(height: 8),
        _buildMacroProgressBar('Fat', '${fat}g / ${fatTarget}g', fatPct, const Color(0xFFFBBF24)),

        const SizedBox(height: 14),

        // 2-Column Hydration & Fasting Grid
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: zen.water.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.water_drop_rounded, color: zen.water, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HYDRATION',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            '$water ml ($waterPercent%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, color: Color(0xFFA855F7), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FASTING',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            app.fasting.isActive
                                ? '${app.fasting.elapsedHours.toStringAsFixed(1)}h Active'
                                : app.fasting.protocol.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyContent(BuildContext context) {
    final app = widget.appState;
    final zen = context.zen;
    final useKg = app.prefs.useKg;
    final report = app.currentWeeklyReport;

    final fatLossStr = useKg
        ? '${report.predictedFatLossKg.toStringAsFixed(2)} kg'
        : '${report.predictedFatLossLb.toStringAsFixed(2)} lbs';

    final deficit = report.netWeeklyEnergyBalance;
    final deficitStr = deficit <= 0
        ? '${deficit.abs().round()} kcal Deficit'
        : '+${deficit.round()} kcal Surplus';

    final proteinRatio = report.proteinTargetG > 0
        ? (report.averageProteinG / report.proteinTargetG)
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Weekly Balance Hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'WEEKLY METABOLIC DEFICIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: zen.sage.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Score: ${report.adherenceScore}/100',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: zen.sage,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                deficitStr,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Projected Adipose Loss: $fatLossStr',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3 Key Pillar Metrics
        Row(
          children: [
            Expanded(
              child: _buildWeeklyMetricPill(
                'Avg Intake',
                '${report.averageDailyCalories.round()} kcal',
                Icons.restaurant_rounded,
                zen.sage,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWeeklyMetricPill(
                'Protein Hit',
                '${(proteinRatio * 100).round()}%',
                Icons.fitness_center_rounded,
                const Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWeeklyMetricPill(
                'Days Logged',
                '${report.daysLogged}/${report.totalDays}d',
                Icons.calendar_today_rounded,
                const Color(0xFFFBBF24),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6EE7B7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report.scaleVsFatExplanation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFCBD5E1),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFastingContent(BuildContext context) {
    final fasting = widget.appState.fasting;
    final stage = fasting.currentStage;
    final elapsed = fasting.elapsedHours;
    final target = fasting.protocol.fastHours;
    final isTargetMet = fasting.targetReached;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fasting Hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: stage.accentColor.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${fasting.protocol.label} FASTING PROTOCOL',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: stage.accentColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isTargetMet ? 'Goal Achieved! 🎉' : 'In Progress',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: stage.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    fasting.isActive ? elapsed.toStringAsFixed(1) : '${target}h',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    ' / ${target}h target',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(stage.icon, size: 16, color: stage.accentColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${stage.name} (${stage.hoursRange})',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: stage.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Fasting Stats Row
        Row(
          children: [
            Expanded(
              child: _buildWeeklyMetricPill(
                'Completed',
                '${fasting.totalFastsCompleted} Fasts',
                Icons.check_circle_rounded,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWeeklyMetricPill(
                'Total Hours',
                '${fasting.totalHoursFasted.toStringAsFixed(0)}h',
                Icons.timelapse_rounded,
                const Color(0xFFA855F7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWeeklyMetricPill(
                'Longest Fast',
                '${fasting.longestFastHours.toStringAsFixed(1)}h',
                Icons.emoji_events_rounded,
                const Color(0xFFFBBF24),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            stage.description,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFCBD5E1),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroProgressBar(
    String label,
    String value,
    double progress,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyMetricPill(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
