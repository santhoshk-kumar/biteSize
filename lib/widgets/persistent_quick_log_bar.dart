import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_entry.dart';
import '../models/nutrition.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'voice_meal_sheet.dart';

/// Persistent quick-logging text bar that stays fixed at the bottom of the screen
/// across all tabs in HomeShell. Scrolling never affects it.
///
/// Features:
/// - Generous typing area with spacious touch targets
/// - Food photo upload (camera & gallery) with AI vision parsing
/// - Hands-free voice recording assistant
/// - Bookmark / Saved prompt manager for 1-tap recurrent prompts
/// - Multi-entity natural language parsing for food, workouts, and water
class PersistentQuickLogBar extends StatefulWidget {
  const PersistentQuickLogBar({
    super.key,
    required this.appState,
  });

  final AppState appState;

  @override
  State<PersistentQuickLogBar> createState() => _PersistentQuickLogBarState();
}

class _PersistentQuickLogBarState extends State<PersistentQuickLogBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSubmitting = false;

  static const String _savedPromptsKey = 'zen_quick_log_saved_prompts';
  static const List<String> _defaultPresets = [
    '🥣 Oatmeal with blueberries & honey',
    '🍳 2 boiled eggs and 1 banana',
    '💧 Drank 500ml water',
    '🏃 5km run in 28 mins',
    '🔥 20 min jump rope',
    '🥗 Grilled chicken breast with mixed greens',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- Photo Upload & AI Vision Logging ---
  Future<void> _handlePhotoUpload() async {
    final zen = context.zen;
    ZenHaptics.selection();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: zen.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Upload Food Photo',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: zen.sage, size: 20),
                ),
                title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Snap your plate with camera', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_library_rounded, color: zen.sage, size: 20),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Upload an existing food image', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isSubmitting = true);
      final bytes = await picked.readAsBytes();
      final lower = picked.path.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');

      final result = await widget.appState.estimateMeal(
        imageBytes: bytes,
        imageMimeType: mime,
        description: 'Photo meal log',
      );

      final mealEntry = MealEntry(
        id: ZenDateUtils.newId('meal'),
        dateKey: widget.appState.selectedDateKey,
        loggedAt: DateTime.now(),
        mealType: result.mealTypeSuggestion,
        title: result.mealTitle.isNotEmpty ? result.mealTitle : 'Photo Meal',
        rawInput: 'Photo upload',
        imagePath: picked.path,
        items: result.items,
        providerUsed: result.providerLabel,
        aiNotes: result.aiNotes,
      );

      await widget.appState.addMeal(mealEntry);
      ZenHaptics.heavy();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '🍽️ Logged from photo: ${mealEntry.title} (${mealEntry.totalMacros.calories.round()} kcal)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFFFF8A65),
              onPressed: () => widget.appState.deleteMeal(mealEntry.id),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Error analyzing photo: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- Voice Logging Feature ---
  Future<void> _handleVoiceLog() async {
    ZenHaptics.selection();
    await showVoiceMealSheet(context, appState: widget.appState);
  }

  // --- Saved Prompts Feature ---
  Future<void> _handleSavedPrompts() async {
    ZenHaptics.selection();
    final text = _controller.text.trim();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_savedPromptsKey) ?? [];

    if (text.isNotEmpty) {
      // Save current input as a new custom prompt
      if (!saved.contains(text)) {
        saved.insert(0, text);
        await prefs.setStringList(_savedPromptsKey, saved);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('⭐ Saved prompt: "$text"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // When text field is empty, show saved prompts sheet
    if (!mounted) return;
    final zen = context.zen;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allPrompts = [...saved, ..._defaultPresets.where((p) => !saved.contains(p))];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: zen.borderSoft,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saved Prompts & Presets',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Tap to insert',
                        style: TextStyle(fontSize: 12, color: zen.inkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: allPrompts.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: zen.borderSoft),
                      itemBuilder: (ctx, idx) {
                        final prompt = allPrompts[idx];
                        final isCustom = saved.contains(prompt);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            prompt,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                          ),
                          trailing: isCustom
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                  color: zen.gentleClay,
                                  onPressed: () async {
                                    saved.remove(prompt);
                                    await prefs.setStringList(_savedPromptsKey, saved);
                                    setSheetState(() {});
                                  },
                                )
                              : null,
                          onTap: () {
                            _controller.text = prompt;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: prompt.length),
                            );
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Natural Language Submission Engine ---
  Future<void> _handleSubmit([String? textOverride]) async {
    final raw = (textOverride ?? _controller.text).trim();
    if (raw.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    ZenHaptics.selection();

    try {
      final lower = raw.toLowerCase();

      // Check if this is a general inquiry / status check
      if (lower.startsWith('how much') ||
          lower.startsWith('how many') ||
          lower.startsWith('what are my') ||
          lower.contains('status') ||
          lower.contains('remaining') ||
          lower.contains('summary')) {
        final dayTotals = widget.appState.totalMacrosForDay;
        final target = widget.appState.goals.calorieTarget;
        final water = widget.appState.totalWaterMlForDay;
        final waterTarget = widget.appState.goals.waterTargetMl;
        final remaining = (target - dayTotals.calories).round();

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                '📊 Today: ${dayTotals.calories.round()} / $target kcal (${remaining >= 0 ? '$remaining left' : '${-remaining} over'}) • ${water}ml / ${waterTarget}ml water',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _controller.clear();
        return;
      }

      int? parsedWaterMl;
      final List<ExerciseEntry> loggedExercises = [];
      final List<MealEntry> loggedMeals = [];
      final List<String> feedbackSummaries = [];

      // 1. Water Extraction
      final waterRegexes = [
        RegExp(r'(?:drank|had|logged|added)?\s*(\d+)\s*(?:ml|milliliter|milliliters)(?:\s*(?:of\s*)?water)?', caseSensitive: false),
        RegExp(r'(?:drank|had|logged|added)?\s*(\d+(?:\.\d+)?)\s*(?:l|liter|liters)(?:\s*(?:of\s*)?water)?', caseSensitive: false),
        RegExp(r'(?:drank|had|logged|added)?\s*(\d+)\s*(?:glass|glasses|cup|cups)(?:\s*(?:of\s*)?water)?', caseSensitive: false),
        RegExp(r'(?:drank|had|logged|added)?\s*(\d+)\s*(?:bottle|bottles)(?:\s*(?:of\s*)?water)?', caseSensitive: false),
        RegExp(r'(?:water|hydrate)\s*\+?\s*(\d+)\s*(?:ml)?', caseSensitive: false),
        RegExp(r'(\d+)\s*(?:ml|milliliters|l|liters|glasses|cups|bottles)\s*(?:of\s*)?water', caseSensitive: false),
      ];

      String textWithoutWater = raw;
      for (final r in waterRegexes) {
        final match = r.firstMatch(raw);
        if (match != null) {
          final val = double.tryParse(match.group(1) ?? '0') ?? 0;
          final matchedStr = match.group(0)!.toLowerCase();
          if (matchedStr.contains('liter') || RegExp(r'\b\d+(?:\.\d+)?\s*l\b', caseSensitive: false).hasMatch(matchedStr)) {
            parsedWaterMl = (val * 1000).round();
          } else if (matchedStr.contains('glass') || matchedStr.contains('cup')) {
            parsedWaterMl = (val * 250).round();
          } else if (matchedStr.contains('bottle')) {
            parsedWaterMl = (val * 500).round();
          } else {
            parsedWaterMl = val.round();
          }
          if (parsedWaterMl > 0) {
            textWithoutWater = raw
                .replaceFirst(match.group(0)!, '')
                .replaceAll(RegExp(r'\b(?:water|drank|had|ml|bottle|glass|glasses)\b', caseSensitive: false), '')
                .trim();
            break;
          }
        }
      }
      textWithoutWater = textWithoutWater
          .replaceAll(RegExp(r'^(?:[\s,;]|\band\b)+|(?:[\s,;]|\band\b)+$', caseSensitive: false), '')
          .trim();

      if (parsedWaterMl != null && parsedWaterMl > 0) {
        await widget.appState.addWater(parsedWaterMl);
        feedbackSummaries.add('💧 +$parsedWaterMl ml');
      }

      // 2. Exercise Detection
      final exerciseKeywords = [
        'run', 'running', 'ran', 'runs',
        'jog', 'jogging', 'jogged',
        'walk', 'walking', 'walked', 'walks',
        'sprint', 'sprinted', 'sprinting',
        'jump rope', 'skipping', 'skipped',
        'gym', 'workout', 'worked out', 'lifting', 'lifted', 'lift',
        'push', 'pull', 'legs', 'hiit', 'weights',
        'cycling', 'cycle', 'cycled', 'bike', 'biking', 'biked', 'spin',
        'swim', 'swimming', 'swam', 'rowing', 'elliptical',
        'pushups', 'pullups', 'squats', 'treadmill', 'hike', 'hiking', 'hiked',
      ];

      final foodKeywords = [
        'eat', 'ate', 'eating', 'had', 'having', 'drink', 'drank', 'drinking',
        'breakfast', 'lunch', 'dinner', 'snack', 'meal', 'dessert',
        'food', 'calories', 'kcal', 'protein', 'carbs', 'fat',
        'grams', 'gram', 'cup', 'cups', 'plate', 'plates', 'bowl', 'bowls', 'slice', 'slices', 'piece', 'pieces',
        'egg', 'eggs', 'chicken', 'rice', 'bread', 'salad', 'apple', 'banana', 'meat', 'beef', 'fish', 'pork',
        'milk', 'cheese', 'yogurt', 'shake', 'smoothie', 'sandwich', 'burger', 'pizza', 'pasta', 'soup',
        'oats', 'oatmeal', 'cereal', 'coffee', 'tea', 'biscuit', 'cookie', 'cookies', 'fruit', 'fruits',
        'vegetable', 'vegetables', 'curry', 'roti', 'chapati', 'dal', 'paneer', 'tofu', 'nut', 'nuts',
      ];

      final hasExerciseIntent = exerciseKeywords.any((k) => RegExp(r'\b' + k + r'\b', caseSensitive: false).hasMatch(lower) || lower.contains(k));
      final hasFoodIntent = foodKeywords.any((k) => RegExp(r'\b' + k + r'\b', caseSensitive: false).hasMatch(lower));
      String textWithoutExercise = textWithoutWater;

      if (hasExerciseIntent) {
        final compound = await widget.appState.parseExerciseWithAi(raw);

        if (compound.segments.isNotEmpty) {
          for (final seg in compound.segments) {
            final int? steps = seg.steps ??
                (seg.type == ExerciseType.walking
                    ? ((seg.distanceKm ?? 0.0) * 1300).round()
                    : (seg.type == ExerciseType.running ? ((seg.distanceKm ?? 0.0) * 1100).round() : null));

            final effectiveBurn = seg.caloriesBurned ?? 0.0;

            final entry = ExerciseEntry(
              id: ZenDateUtils.newId('ex'),
              dateKey: widget.appState.selectedDateKey,
              loggedAt: DateTime.now(),
              title: seg.title,
              type: seg.type,
              durationMinutes: seg.durationMinutes > 0 ? seg.durationMinutes : 30,
              caloriesBurned: effectiveBurn,
              distanceKm: seg.distanceKm,
              steps: steps,
              intensity: seg.intensity,
              gymCategory: seg.gymCategory,
              notes: seg.notes,
            );
            await widget.appState.logExercise(entry);
            loggedExercises.add(entry);
          }
          final totalBurn = loggedExercises.fold<double>(0.0, (s, e) => s + e.caloriesBurned);
          feedbackSummaries.add('🔥 -${totalBurn.round()} kcal (${loggedExercises.map((e) => e.title).join(', ')})');
        }

        if (!hasFoodIntent) {
          textWithoutExercise = '';
        } else {
          for (final kw in exerciseKeywords) {
            textWithoutExercise = textWithoutExercise.replaceAll(RegExp(r'\b' + kw + r'\b', caseSensitive: false), '');
          }
          textWithoutExercise = textWithoutExercise.replaceAll(RegExp(r'\d+(?:\.\d+)?\s*(?:mins?|minutes?|km|k|miles?|mi|steps?)\b', caseSensitive: false), '');
          textWithoutExercise = textWithoutExercise
              .replaceAll(RegExp(r'^(?:[\s,;]|\band\b)+|(?:[\s,;]|\band\b)+$', caseSensitive: false), '')
              .trim();
        }
      }

      // 3. Food / Meal Detection
      final isPureWater = parsedWaterMl != null &&
          parsedWaterMl > 0 &&
          textWithoutWater
              .replaceAll(RegExp(r'\b(?:water|drank|had|logged|added|ml|l|bottle|glass|glasses)\b', caseSensitive: false), '')
              .trim()
              .isEmpty;
      final isPureExerciseOrWater = isPureWater || (loggedExercises.isNotEmpty && !hasFoodIntent);

      if (!isPureExerciseOrWater && textWithoutExercise.length >= 3 && (hasFoodIntent || loggedExercises.isEmpty)) {
        final mealResult = await widget.appState.estimateMeal(
          description: textWithoutExercise,
        );

        if (mealResult.totalMacros.calories > 0 || mealResult.items.isNotEmpty) {
          final mealEntry = MealEntry(
            id: ZenDateUtils.newId('meal'),
            dateKey: widget.appState.selectedDateKey,
            loggedAt: DateTime.now(),
            mealType: mealResult.mealTypeSuggestion,
            title: mealResult.mealTitle.isNotEmpty ? mealResult.mealTitle : textWithoutExercise,
            rawInput: raw,
            items: mealResult.items,
            providerUsed: mealResult.providerLabel,
            aiNotes: mealResult.aiNotes,
          );

          await widget.appState.addMeal(mealEntry);
          loggedMeals.add(mealEntry);
          feedbackSummaries.add('🍽️ ${mealEntry.title} (${mealEntry.totalMacros.calories.round()} kcal)');
        }
      }

      _controller.clear();
      _focusNode.unfocus();
      ZenHaptics.heavy();

      if (!mounted) return;

      if (feedbackSummaries.isNotEmpty) {
        final summaryText = feedbackSummaries.join(' • ');
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            content: Text(
              summaryText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFFFF8A65),
              onPressed: () async {
                for (final meal in loggedMeals) {
                  await widget.appState.deleteMeal(meal.id);
                }
                for (final ex in loggedExercises) {
                  await widget.appState.deleteExercise(ex.id);
                }
                if (parsedWaterMl != null && parsedWaterMl > 0) {
                  await widget.appState.undoLastWater();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Reverted last logged entry.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Could not recognize entry. Try e.g. "2 boiled eggs", "500ml water", or "20 min jump rope".',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Error logging entry: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: zen.sage.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Upload Food Photos Icon (compact footprint)
          IconButton(
            icon: Icon(Icons.camera_alt_outlined, size: 19, color: zen.sage),
            tooltip: 'Upload food photo',
            onPressed: _isSubmitting ? null : _handlePhotoUpload,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),

          // 2. Voice Log Icon (compact footprint)
          IconButton(
            icon: Icon(Icons.mic_none_rounded, size: 19, color: zen.sage),
            tooltip: 'Voice log',
            onPressed: _isSubmitting ? null : _handleVoiceLog,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),

          // 3. Save / Saved Prompts Icon (compact footprint)
          IconButton(
            icon: Icon(Icons.bookmark_border_rounded, size: 19, color: zen.sage),
            tooltip: 'Save or pick prompt',
            onPressed: _isSubmitting ? null : _handleSavedPrompts,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),

          const SizedBox(width: 2),

          // 4. Expanded, comfortable text input field with generous width
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: _isSubmitting ? null : _handleSubmit,
              style: TextStyle(
                fontSize: 15.0,
                color: zen.inkPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Log food, workout, or water...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: zen.inkMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // 5. Send Action Button (proportional, sleek)
          if (_isSubmitting)
            SizedBox(
              width: 36,
              height: 36,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: zen.sage,
                ),
              ),
            )
          else
            FilledButton(
              onPressed: () => _handleSubmit(),
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(7),
                backgroundColor: zen.sage,
                foregroundColor: const Color(0xFF090A0E),
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(36, 36),
              ),
              child: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
