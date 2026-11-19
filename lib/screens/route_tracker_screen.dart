import 'package:flutter/material.dart';

import '../models/gps_route.dart';
import '../services/gps_tracking_service.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/route_breadcrumb_canvas.dart';

/// Full-screen headless GPS route tracker dashboard for walk, run, and cycle sessions.
/// Features live vector breadcrumbs, real-time pace/distance HUD, and an offline walk simulator.
class RouteTrackerScreen extends StatefulWidget {
  const RouteTrackerScreen({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  State<RouteTrackerScreen> createState() => _RouteTrackerScreenState();
}

class _RouteTrackerScreenState extends State<RouteTrackerScreen> {
  GpsTrackingService get _tracker => widget.appState.gpsTracker;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_onTrackerUpdate);
  }

  @override
  void dispose() {
    _tracker.removeListener(_onTrackerUpdate);
    super.dispose();
  }

  void _onTrackerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handleStart() async {
    ZenHaptics.selection();
    final success = await _tracker.startTracking();
    if (!success && mounted && _tracker.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tracker.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handlePause() {
    ZenHaptics.selection();
    _tracker.pauseTracking();
  }

  void _handleResume() {
    ZenHaptics.selection();
    _tracker.resumeTracking();
  }

  Future<void> _handleDiscard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Workout?'),
        content: const Text(
          'Are you sure you want to discard this recorded route? All distance and coordinate data will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ZenHaptics.selection();
      _tracker.resetSession();
    }
  }

  Future<void> _handleFinishAndSave() async {
    ZenHaptics.success();
    _tracker.stopTracking();

    final titleController = TextEditingController(
      text:
          '${_tracker.activityType.label} (${_tracker.distanceKm.toStringAsFixed(2)} km)',
    );
    final notesController = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.zen.surfaceSubtle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final zen = ctx.zen;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: zen.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Save ${_tracker.activityType.label} Session',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: zen.inkPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_tracker.distanceKm.toStringAsFixed(2)} km in ${_tracker.formattedDuration} • ${_tracker.calculateCaloriesBurned(widget.appState.profile.weightKg).round()} kcal',
                style: TextStyle(
                  fontSize: 14,
                  color: zen.sage,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                style: TextStyle(color: zen.inkPrimary),
                decoration: InputDecoration(
                  labelText: 'Workout Title',
                  filled: true,
                  fillColor: Theme.of(ctx).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                style: TextStyle(color: zen.inkPrimary),
                decoration: InputDecoration(
                  labelText: 'Notes & Reflections (optional)',
                  hintText: 'Weather, route notes, how it felt...',
                  filled: true,
                  fillColor: Theme.of(ctx).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Back to Session'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Save Workout'),
                      style: FilledButton.styleFrom(
                        backgroundColor: zen.sage,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      final entry = await widget.appState.saveActiveGpsRoute(
        customTitle: titleController.text,
        notes: notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entry?.title ?? "Workout"} saved to your activity timeline! (+${entry?.caloriesBurned.round() ?? 0} kcal burned)',
            ),
            backgroundColor: context.zen.sage,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIdle = _tracker.status == TrackingStatus.idle;
    final isTracking = _tracker.status == TrackingStatus.active;
    final isPaused = _tracker.status == TrackingStatus.paused;
    final isCompleted = _tracker.status == TrackingStatus.completed;

    final caloriesBurned =
        _tracker.calculateCaloriesBurned(widget.appState.profile.weightKg);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Headless Route Tracker',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: zen.inkPrimary,
          ),
        ),
        actions: [
          // Dev Simulator Switch Chip
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _tracker.isSimulated
                  ? zen.sage.withValues(alpha: 0.18)
                  : zen.surfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _tracker.isSimulated ? zen.sage : zen.borderSoft,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 14,
                  color: _tracker.isSimulated ? zen.sage : zen.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Simulate',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _tracker.isSimulated ? zen.sage : zen.inkMuted,
                  ),
                ),
                Switch(
                  value: _tracker.isSimulated,
                  onChanged: (val) {
                    ZenHaptics.selection();
                    _tracker.setSimulationMode(val);
                  },
                  activeColor: zen.sage,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─────────────────────────────────────────────────────
              // 1. Activity Mode Selector & GPS Signal Quality Pill
              // ─────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: zen.surfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: zen.borderSoft),
                      ),
                      child: Row(
                        children: TrackingActivityType.values.map((type) {
                          final isSelected = _tracker.activityType == type;
                          return Expanded(
                            child: GestureDetector(
                              onTap: isTracking
                                  ? null
                                  : () {
                                      ZenHaptics.selection();
                                      _tracker.setActivityType(type);
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? zen.sage
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  type.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : zen.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // GPS Lock Quality Badge
                  _buildSignalQualityBadge(zen),
                ],
              ),
              const SizedBox(height: 16),

              // ─────────────────────────────────────────────────────
              // 2. Pure 2D Route Breadcrumb Canvas (Zero Map API costs)
              // ─────────────────────────────────────────────────────
              RouteBreadcrumbWidget(
                points: _tracker.routePoints,
                pathColor: zen.sage,
                accentColor: zen.gentleClay,
                isLive: isTracking,
                height: 250,
              ),
              const SizedBox(height: 20),

              // ─────────────────────────────────────────────────────
              // 3. Big-Digit Primary Readout (Distance or Jump Rope Skips)
              // ─────────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      _tracker.activityType == TrackingActivityType.jumpRope
                          ? 'ESTIMATED SKIPS'
                          : 'DISTANCE',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: zen.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _tracker.activityType == TrackingActivityType.jumpRope
                              ? '${(_tracker.elapsedSeconds * 1.9).round()}'
                              : _tracker.distanceKm.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            color: zen.inkPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _tracker.activityType == TrackingActivityType.jumpRope
                              ? 'skips'
                              : 'km',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: zen.sage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─────────────────────────────────────────────────────
              // 4. Secondary Metrics Grid (Duration, Pace/Cadence, Cal)
              // ─────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: zen.borderSoft),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricTile(
                      label: 'TIME',
                      value: _tracker.formattedDuration,
                      zen: zen,
                    ),
                    Container(width: 1, height: 36, color: zen.borderSoft),
                    _buildMetricTile(
                      label: _tracker.activityType == TrackingActivityType.jumpRope
                          ? 'CADENCE'
                          : 'AVG PACE',
                      value: _tracker.activityType == TrackingActivityType.jumpRope
                          ? (isTracking ? '~115/min' : '--')
                          : _tracker.formattedPace,
                      zen: zen,
                    ),
                    Container(width: 1, height: 36, color: zen.borderSoft),
                    _buildMetricTile(
                      label: 'CALORIES',
                      value: '${caloriesBurned.round()} kcal',
                      zen: zen,
                      valueColor: zen.gentleClay,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─────────────────────────────────────────────────────
              // 5. Tactile Controls
              // ─────────────────────────────────────────────────────
              if (isIdle)
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: _handleStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      'Start ${_tracker.activityType.label}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: zen.sage,
                      foregroundColor: const Color(0xFF090A0E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 4,
                      shadowColor: zen.sage.withValues(alpha: 0.4),
                    ),
                  ),
                )
              else if (isTracking)
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: _handlePause,
                    icon: const Icon(Icons.pause_rounded, size: 26),
                    label: const Text(
                      'Pause Tracking',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: zen.carbs,
                      foregroundColor: const Color(0xFF090A0E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                )
              else if (isPaused || isCompleted)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton.icon(
                              onPressed: _handleResume,
                              icon: Icon(Icons.play_arrow_rounded, color: zen.sage),
                              label: Text(
                                'Resume',
                                style: TextStyle(
                                  color: zen.sage,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: zen.sage, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: _handleFinishAndSave,
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text(
                                'Finish & Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: zen.sage,
                                foregroundColor: const Color(0xFF090A0E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _handleDiscard,
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: Theme.of(context).colorScheme.error),
                      label: Text(
                        'Discard Session',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalQualityBadge(ZenColors zen) {
    final quality = _tracker.signalQuality;
    Color dotColor;
    String text;

    if (_tracker.isSimulated) {
      dotColor = zen.sage;
      text = 'Simulated';
    } else {
      switch (quality) {
        case GpsSignalQuality.good:
          dotColor = const Color(0xFF00E676);
          text = 'GPS Good';
          break;
        case GpsSignalQuality.fair:
          dotColor = const Color(0xFFFBBF24);
          text = 'GPS Fair';
          break;
        case GpsSignalQuality.searching:
          dotColor = const Color(0xFF94A3B8);
          text = 'Searching';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: zen.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required ZenColors zen,
    Color? valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: zen.inkMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor ?? zen.inkPrimary,
          ),
        ),
      ],
    );
  }
}
