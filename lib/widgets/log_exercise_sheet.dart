import 'package:flutter/material.dart';

import '../models/exercise_entry.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';

/// Modal bottom sheet to log walking, running, jump rope, gym, or custom workouts
/// with live kinematic & MET energy expenditure cross-calculations.
class LogExerciseSheet extends StatefulWidget {
  const LogExerciseSheet({
    super.key,
    required this.appState,
    this.initialType = ExerciseType.walking,
    this.existingEntry,
  });

  final AppState appState;
  final ExerciseType initialType;
  final ExerciseEntry? existingEntry;

  @override
  State<LogExerciseSheet> createState() => _LogExerciseSheetState();
}

class _LogExerciseSheetState extends State<LogExerciseSheet> {
  late ExerciseType _selectedType;
  late ExerciseIntensity _intensity;

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: '30');
  final TextEditingController _distanceController = TextEditingController(text: '3.0');
  final TextEditingController _stepsController = TextEditingController(text: '3900');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _aiInputController = TextEditingController();
  bool _isAiParsing = false;
  CompoundExerciseParseResult? _compoundResult;

  String _selectedGymSplit = 'Full Body';
  static const List<String> _gymSplits = [
    'Push',
    'Pull',
    'Legs',
    'Upper Body',
    'Lower Body',
    'Full Body',
    'Core & Abs',
    'Circuit / HIIT',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;
    if (existing != null) {
      _selectedType = existing.type;
      _intensity = existing.intensity;
      _titleController.text = existing.title;
      _durationController.text = '${existing.durationMinutes}';
      _distanceController.text = existing.distanceKm != null ? '${existing.distanceKm}' : '';
      _stepsController.text = existing.steps != null ? '${existing.steps}' : '';
      _notesController.text = existing.notes;
      if (existing.gymCategory != null && _gymSplits.contains(existing.gymCategory)) {
        _selectedGymSplit = existing.gymCategory!;
      }
    } else {
      _selectedType = widget.initialType;
      _intensity = ExerciseIntensity.moderate;
      _syncDefaultsForType(_selectedType);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _stepsController.dispose();
    _notesController.dispose();
    _aiInputController.dispose();
    super.dispose();
  }

  Future<void> _handleAiFill(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    setState(() => _isAiParsing = true);
    ZenHaptics.selection();

    try {
      final parsed = await widget.appState.parseExerciseWithAi(query);
      if (!mounted) return;

      setState(() {
        _isAiParsing = false;
        _compoundResult = parsed;
        final primary = parsed.primarySegment;
        _selectedType = primary.type;
        _intensity = primary.intensity;
        _titleController.text = parsed.compositeTitle;
        _durationController.text = '${parsed.totalDurationMinutes}';
        _distanceController.text = parsed.totalDistanceKm != null ? '${parsed.totalDistanceKm}' : '';
        _stepsController.text = parsed.totalSteps != null ? '${parsed.totalSteps}' : '';
        if (primary.gymCategory != null && _gymSplits.contains(primary.gymCategory)) {
          _selectedGymSplit = primary.gymCategory!;
        }
        _notesController.text = parsed.notes;
      });

      ZenHaptics.success();
      final snackMsg = parsed.isCompound
          ? '✨ Detected ${parsed.segments.length} activities (${parsed.compositeTitle}): ${parsed.totalDurationMinutes}m · ~${parsed.totalCaloriesBurned.round()} kcal'
          : '✨ AI detected: ${parsed.compositeTitle} (${parsed.totalDurationMinutes}m)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMsg),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAiParsing = false);
    }
  }

  Future<void> _handleLogAllCompound() async {
    final comp = _compoundResult;
    if (comp == null || !comp.isCompound) return;

    ZenHaptics.success();
    final now = DateTime.now();
    final isToday = widget.appState.selectedDateKey == ZenDateUtils.toDateKey(now);
    final effectiveTime = isToday
        ? now
        : widget.appState.selectedDate.add(Duration(hours: now.hour, minutes: now.minute));

    for (int i = 0; i < comp.segments.length; i++) {
      final s = comp.segments[i];
      final cal = s.caloriesBurned ?? 0.0;

      int? steps = s.steps;
      if (steps == null && s.distanceKm != null && s.distanceKm! > 0) {
        steps = ExerciseCalculator.stepsFromKm(s.distanceKm!, userHeightCm: _userHeightCm);
      }

      final entry = ExerciseEntry(
        id: ZenDateUtils.newId('ex'),
        dateKey: widget.appState.selectedDateKey,
        loggedAt: effectiveTime.add(Duration(minutes: i * 5)),
        type: s.type,
        title: s.title,
        durationMinutes: s.durationMinutes,
        caloriesBurned: cal,
        distanceKm: s.distanceKm,
        steps: steps,
        intensity: s.intensity,
        gymCategory: s.gymCategory,
        notes: s.notes,
      );
      await widget.appState.logExercise(entry);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔥 Logged ${comp.segments.length} activities: -${comp.totalCaloriesBurned.round()} kcal burned!',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _syncDefaultsForType(ExerciseType type) {
    switch (type) {
      case ExerciseType.walking:
        _titleController.text = 'Brisk Walk';
        _durationController.text = '35';
        _distanceController.text = '2.8';
        _stepsController.text = '${ExerciseCalculator.stepsFromKm(2.8)}';
        break;
      case ExerciseType.running:
        _titleController.text = 'Outdoor Run';
        _durationController.text = '25';
        _distanceController.text = '4.0';
        _stepsController.text = '${ExerciseCalculator.stepsFromKm(4.0)}';
        break;
      case ExerciseType.jumpRope:
        _titleController.text = 'Jump Rope Session';
        _durationController.text = '15';
        _distanceController.text = '';
        _stepsController.text = '${15 * 115} skips';
        break;
      case ExerciseType.gym:
        _titleController.text = '$_selectedGymSplit Workout';
        _durationController.text = '50';
        _distanceController.text = '';
        _stepsController.text = '';
        break;
      case ExerciseType.cycling:
        _titleController.text = 'Cycling Ride';
        _durationController.text = '30';
        _distanceController.text = '10.0';
        _stepsController.text = '';
        break;
      case ExerciseType.custom:
        _titleController.text = 'General Workout';
        _durationController.text = '30';
        _distanceController.text = '';
        _stepsController.text = '';
        break;
    }
  }

  double get _userWeightKg {
    final profileWeight = widget.appState.profile.weightKg;
    if (profileWeight > 20) return profileWeight;
    final latestLogged = widget.appState.latestWeight?.weightKg;
    if (latestLogged != null && latestLogged > 20) return latestLogged;
    final target = widget.appState.goals.targetWeightKg;
    if (target > 20) return target;
    return 68.0; // standard default
  }

  double? get _userHeightCm {
    final h = widget.appState.profile.heightCm;
    if (h >= 100 && h <= 240) return h;
    return null;
  }

  String get _bodyStatsLabel {
    final useKg = widget.appState.prefs.useKg;
    final weightStr = useKg
        ? '${_userWeightKg.toStringAsFixed(1)} kg'
        : '${ZenDateUtils.kgToLb(_userWeightKg).toStringAsFixed(1)} lbs';
    final heightStr = _userHeightCm != null
        ? ' · ${_userHeightCm!.round()} cm'
        : '';
    final isConfigured = widget.appState.profile.isConfigured;
    return 'Calibrated to $weightStr$heightStr · ${_intensity.label} intensity${isConfigured ? ' 🎯' : ''}';
  }

  int get _parsedDuration => int.tryParse(_durationController.text.trim()) ?? 0;
  double? get _parsedDistance => double.tryParse(_distanceController.text.trim());

  double get _calculatedCalories {
    return ExerciseCalculator.calculateBurn(
      type: _selectedType,
      durationMinutes: _parsedDuration,
      userWeightKg: _userWeightKg,
      intensity: _intensity,
      distanceKm: _parsedDistance,
      userHeightCm: _userHeightCm,
    );
  }

  void _onDistanceChanged(String val) {
    final km = double.tryParse(val.trim());
    if (km != null && km > 0 && (_selectedType == ExerciseType.walking || _selectedType == ExerciseType.running)) {
      final calculatedSteps = ExerciseCalculator.stepsFromKm(km, userHeightCm: _userHeightCm);
      _stepsController.text = '$calculatedSteps';
    }
    setState(() {});
  }

  void _onStepsChanged(String val) {
    final steps = int.tryParse(val.trim());
    if (steps != null && steps > 0 && _selectedType == ExerciseType.walking) {
      final km = ExerciseCalculator.kmFromSteps(steps, userHeightCm: _userHeightCm);
      _distanceController.text = km.toStringAsFixed(2);
    }
    setState(() {});
  }

  Future<void> _handleSave() async {
    final duration = _parsedDuration;
    if (duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid workout duration.')),
      );
      return;
    }

    ZenHaptics.success();

    final now = DateTime.now();
    final isToday = widget.appState.selectedDateKey == ZenDateUtils.toDateKey(now);
    final effectiveTime = isToday
        ? now
        : widget.appState.selectedDate.add(Duration(hours: now.hour, minutes: now.minute));

    int? parsedSteps;
    if (_selectedType == ExerciseType.walking || _selectedType == ExerciseType.running) {
      parsedSteps = int.tryParse(_stepsController.text.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsedSteps == null && _parsedDistance != null && _parsedDistance! > 0) {
        parsedSteps = ExerciseCalculator.stepsFromKm(_parsedDistance!, userHeightCm: _userHeightCm);
      }
    }

    final existing = widget.existingEntry;
    final entry = ExerciseEntry(
      id: existing?.id ?? ZenDateUtils.newId('ex'),
      dateKey: existing?.dateKey ?? widget.appState.selectedDateKey,
      loggedAt: existing?.loggedAt ?? effectiveTime,
      type: _selectedType,
      title: _titleController.text.trim().isEmpty ? _selectedType.displayName : _titleController.text.trim(),
      durationMinutes: duration,
      caloriesBurned: _calculatedCalories,
      distanceKm: _parsedDistance,
      steps: parsedSteps,
      intensity: _intensity,
      gymCategory: _selectedType == ExerciseType.gym ? _selectedGymSplit : null,
      notes: _notesController.text.trim(),
      routePointsJson: existing?.routePointsJson,
    );

    await widget.appState.logExercise(entry);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing != null
                ? '🔥 Updated ${entry.title}: -${entry.caloriesBurned.round()} kcal burned!'
                : '🔥 Logged ${entry.title}: -${entry.caloriesBurned.round()} kcal burned!',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final burn = _calculatedCalories;
    final distance = _parsedDistance;
    final duration = _parsedDuration;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sheet handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: zen.inkMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zen.sageSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.fitness_center_rounded, size: 20, color: zen.sage),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingEntry != null ? 'Edit Workout & Activity' : 'Log Workout & Activity',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          widget.existingEntry != null
                              ? 'Adjust workout details & recalculates energy expenditure'
                              : 'Calculates active calorie expenditure & net deficit',
                          style: TextStyle(fontSize: 11, color: zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable form body
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // AI Smart-Fill Box
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: zen.sage.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: zen.sage, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'AI Smart-Log',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: zen.sage,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'LLM AI Response',
                              style: TextStyle(fontSize: 10, color: zen.inkMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _aiInputController,
                                decoration: InputDecoration(
                                  hintText: 'e.g., "Ran 5k in 28 mins" or "1 hr chest gym"',
                                  hintStyle: TextStyle(fontSize: 12, color: zen.inkMuted),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: zen.borderSoft),
                                  ),
                                  isDense: true,
                                ),
                                onSubmitted: (val) => _handleAiFill(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: _isAiParsing ? null : () => _handleAiFill(_aiInputController.text),
                              child: _isAiParsing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Fill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick suggestion pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              '🏃 5k Run (28m)',
                              '🚶 3k Walk (35m)',
                              '🏋️ Push Day (50m)',
                              '🪢 Jump Rope (15m)',
                              '🚴 10k Cycle (30m)',
                            ].map((preset) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(99),
                                  onTap: () {
                                    _aiInputController.text = preset;
                                    _handleAiFill(preset);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: zen.borderSoft),
                                    ),
                                    child: Text(
                                      preset,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: zen.inkPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Multi-Activity Breakdown Card (when compound workout detected)
                  _buildCompoundBreakdownCard(zen),

                  // Activity Selector Pills
                  Text(
                    'Select Activity',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: zen.inkMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ExerciseType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              ZenHaptics.selection();
                              setState(() {
                                _selectedType = type;
                                _syncDefaultsForType(type);
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? zen.sage.withValues(alpha: 0.18)
                                    : zen.surfaceSubtle,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? zen.sage : zen.borderSoft,
                                  width: isSelected ? 1.6 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(type.emoji, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Text(
                                    type.displayName,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? zen.sage : zen.inkPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Real-time Energy Burn Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          zen.surfaceSubtle,
                          zen.sageSoft.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: zen.sage.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: zen.sage.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFFF7A45),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '-${burn.round()}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF7A45),
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'kcal burned',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: zen.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _bodyStatsLabel,
                                style: TextStyle(fontSize: 11, color: zen.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        if (distance != null && distance > 0 && duration > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: zen.borderSoft),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  ExerciseCalculator.formatPace(duration, distance),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: zen.carbs,
                                  ),
                                ),
                                Text(
                                  'avg pace',
                                  style: TextStyle(fontSize: 9, color: zen.inkMuted),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title Field
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Workout Name',
                      hintText: 'e.g. Morning Brisk Walk, 5K Tempo Run',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      filled: true,
                      fillColor: zen.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: zen.borderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: zen.borderSoft),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Duration & Distance Row
                  Row(
                    children: [
                      // Duration Input
                      Expanded(
                        child: TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Duration (mins)',
                            hintText: '30',
                            prefixIcon: const Icon(Icons.schedule_rounded),
                            filled: true,
                            fillColor: zen.surfaceSubtle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: zen.borderSoft),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: zen.borderSoft),
                            ),
                          ),
                        ),
                      ),

                      // Distance Input (for walking, running, cycling)
                      if (_selectedType == ExerciseType.walking ||
                          _selectedType == ExerciseType.running ||
                          _selectedType == ExerciseType.cycling) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _distanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: _onDistanceChanged,
                            decoration: InputDecoration(
                              labelText: 'Distance (km)',
                              hintText: '3.0',
                              prefixIcon: const Icon(Icons.straighten_rounded),
                              filled: true,
                              fillColor: zen.surfaceSubtle,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: zen.borderSoft),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: zen.borderSoft),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Walking / Running Specifics: Step Count
                  if (_selectedType == ExerciseType.walking || _selectedType == ExerciseType.running) ...[
                    TextField(
                      controller: _stepsController,
                      keyboardType: TextInputType.number,
                      onChanged: _onStepsChanged,
                      decoration: InputDecoration(
                        labelText: 'Estimated Steps',
                        hintText: 'e.g. 4000',
                        prefixIcon: const Icon(Icons.directions_walk_rounded),
                        filled: true,
                        fillColor: zen.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: zen.borderSoft),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: zen.borderSoft),
                        ),
                        helperText: 'Auto-calculates from distance (~1,315 steps/km)',
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Gym Workout Specifics: Split Selection Chips
                  if (_selectedType == ExerciseType.gym) ...[
                    Text(
                      'Workout Focus / Split',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: zen.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _gymSplits.map((split) {
                        final isSelected = _selectedGymSplit == split;
                        return ChoiceChip(
                          label: Text(split),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              ZenHaptics.selection();
                              setState(() {
                                _selectedGymSplit = split;
                                _titleController.text = '$split Workout';
                              });
                            }
                          },
                          selectedColor: zen.sage.withValues(alpha: 0.22),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? zen.sage : zen.inkPrimary,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Intensity Selector
                  Text(
                    'Perceived Intensity',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: zen.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ExerciseIntensity.values.map((tier) {
                      final isSelected = _intensity == tier;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              ZenHaptics.selection();
                              setState(() => _intensity = tier);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? zen.sage.withValues(alpha: 0.2)
                                    : zen.surfaceSubtle,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? zen.sage : zen.borderSoft,
                                  width: isSelected ? 1.6 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                tier.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: isSelected ? zen.sage : zen.inkPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Optional Notes
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: _selectedType == ExerciseType.gym
                          ? 'e.g. Bench press 4x8, Squats 4x10, DB Press'
                          : 'e.g. Felt light on my feet, scenic park route',
                      filled: true,
                      fillColor: zen.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: zen.borderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: zen.borderSoft),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: zen.sage,
                        foregroundColor: const Color(0xFF090A0E),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        widget.existingEntry != null
                            ? 'Update Workout (-${burn.round()} kcal)'
                            : 'Save Workout (-${burn.round()} kcal)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
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

  Widget _buildCompoundBreakdownCard(ZenColors zen) {
    final comp = _compoundResult;
    if (comp == null || !comp.isCompound) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A45).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF7A45).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'MULTI-ACTIVITY WORKOUT DETECTED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Color(0xFFFF7A45),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${comp.segments.length} Activities',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF7A45),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...comp.segments.map((seg) {
            final cal = seg.caloriesBurned ??
                ExerciseCalculator.calculateBurn(
                  type: seg.type,
                  durationMinutes: seg.durationMinutes,
                  userWeightKg: _userWeightKg,
                  intensity: seg.intensity,
                  distanceKm: seg.distanceKm,
                  userHeightCm: _userHeightCm,
                );
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  ZenHaptics.selection();
                  setState(() {
                    _selectedType = seg.type;
                    _intensity = seg.intensity;
                    _titleController.text = seg.title;
                    _durationController.text = '${seg.durationMinutes}';
                    _distanceController.text = seg.distanceKm != null ? '${seg.distanceKm}' : '';
                    _stepsController.text = seg.steps != null ? '${seg.steps}' : '';
                    if (seg.gymCategory != null && _gymSplits.contains(seg.gymCategory)) {
                      _selectedGymSplit = seg.gymCategory!;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Text(seg.type.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seg.title,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${seg.durationMinutes}m${seg.distanceKm != null ? ' · ${seg.distanceKm}km' : ''} · ${seg.intensity.label}',
                              style: TextStyle(fontSize: 10, color: zen.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '-${cal.round()} kcal',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF7A45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Duration: ${comp.totalDurationMinutes} mins',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              Text(
                'Combined Burn: -${comp.totalCaloriesBurned.round()} kcal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF7A45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A45),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _handleLogAllCompound,
              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: Text(
                'Log Both As Separate Entries (-${comp.totalCaloriesBurned.round()} kcal)',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to display the Log Exercise modal bottom sheet.
void showLogExerciseSheet(
  BuildContext context, {
  required AppState appState,
  ExerciseType initialType = ExerciseType.walking,
  ExerciseEntry? existingEntry,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LogExerciseSheet(
      appState: appState,
      initialType: initialType,
      existingEntry: existingEntry,
    ),
  );
}
