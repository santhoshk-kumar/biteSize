import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/nutrition.dart';
import '../services/date_utils.dart';
import '../services/llm_provider.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/ai_markdown_view.dart';
import '../widgets/bitesize_logo.dart';
import '../widgets/confetti_celebration.dart';
import '../widgets/food_item_editor_tile.dart';
import '../widgets/meal_micronutrients_sheet.dart';
import '../widgets/shimmer_meal_skeleton.dart';

/// Opens the modal sheet to log a new meal with LLM or edit an existing [MealEntry].
Future<void> showLogMealSheet(
  BuildContext context, {
  required AppState appState,
  MealEntry? existingMeal,
  String? initialDescription,
  ImageSource? initialImageSource,
  VoidCallback? onOpenSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _LogMealSheet(
      appState: appState,
      existingMeal: existingMeal,
      initialDescription: initialDescription,
      initialImageSource: initialImageSource,
      onOpenSettings: onOpenSettings,
    ),
  );
}

class _LogMealSheet extends StatefulWidget {
  const _LogMealSheet({
    required this.appState,
    this.existingMeal,
    this.initialDescription,
    this.initialImageSource,
    this.onOpenSettings,
  });

  final AppState appState;
  final MealEntry? existingMeal;
  final String? initialDescription;
  final ImageSource? initialImageSource;
  final VoidCallback? onOpenSettings;

  @override
  State<_LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends State<_LogMealSheet> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _inputCtrl;
  late final TextEditingController _titleCtrl;

  MealType _mealType = MealType.suggestedForTime(DateTime.now());
  String? _imagePath;
  Uint8List? _imageBytes;
  String _imageMimeType = 'image/jpeg';

  bool _isAnalyzing = false;
  bool _inReviewMode = false;
  String? _errorMessage;

  List<FoodItem> _items = [];
  String _aiNotes = '';
  String _providerUsed = '';

  static const List<String> _quickExamples = [
    '2 scrambled eggs, 2 sourdough toast, butter, iced oat latte',
    'Grilled chicken breast 180g, 1 cup jasmine rice, steamed broccoli',
    'Greek yogurt bowl with blueberries, banana, and 2 tbsp granola',
    'Salmon avocado poke bowl with edamame and sesame dressing',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMeal;
    if (existing != null) {
      _inputCtrl = TextEditingController(text: existing.rawInput);
      _titleCtrl = TextEditingController(text: existing.title);
      _mealType = existing.mealType;
      _imagePath = existing.imagePath;
      _items = List<FoodItem>.from(existing.items);
      _aiNotes = existing.aiNotes;
      _providerUsed = existing.providerUsed;
      _inReviewMode = true;
    } else {
      _inputCtrl = TextEditingController(text: widget.initialDescription ?? '');
      _titleCtrl = TextEditingController();
      if (widget.initialImageSource != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pickImage(widget.initialImageSource!);
        });
      }
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 72,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final lower = picked.path.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');

      if (!mounted) return;
      setState(() {
        _imagePath = picked.path;
        _imageBytes = bytes;
        _imageMimeType = mime;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load image: $e';
      });
    }
  }

  Future<void> _analyzeWithLlm() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && _imageBytes == null) {
      setState(() {
        _errorMessage = 'Describe what you ate or attach a meal photo first.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.appState.estimateMeal(
        description: text,
        imageBytes: _imageBytes,
        imageMimeType: _imageMimeType,
        mealTypeHint: _mealType,
      );
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _inReviewMode = true;
        _titleCtrl.text = result.mealTitle;
        _mealType = result.mealTypeSuggestion;
        _items = List<FoodItem>.from(result.items);
        _aiNotes = result.aiNotes;
        _providerUsed = result.providerLabel;
      });
    } on LlmException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Failed to analyze meal: $e';
      });
    }
  }

  void _startManualReview() {
    setState(() {
      _inReviewMode = true;
      _errorMessage = null;
      _providerUsed = 'Manual entry';
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text = _inputCtrl.text.trim().isNotEmpty
            ? _inputCtrl.text.trim()
            : '${_mealType.label} Meal';
      }
      if (_items.isEmpty) {
        _items = [
          FoodItem(
            id: ZenDateUtils.newId('item'),
            name: _titleCtrl.text.trim(),
            quantity: 1,
            unit: 'serving',
            estimatedGrams: 150,
            macros: const MacroNutrients(
              calories: 250,
              proteinG: 15,
              carbsG: 25,
              fatG: 10,
            ),
            confidence: 'high',
          ),
        ];
      }
    });
  }

  Future<void> _addCustomFoodItem() async {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController(text: '150');
    final pCtrl = TextEditingController(text: '10');
    final cCtrl = TextEditingController(text: '15');
    final fCtrl = TextEditingController(text: '5');

    final added = await showDialog<FoodItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add food item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Food name',
                  hintText: 'e.g. Side salad or Espresso',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: calCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Calories (kcal)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Protein g'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: cCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Carbs g'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Fat g'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop(
                FoodItem(
                  id: ZenDateUtils.newId('item'),
                  name: name,
                  quantity: 1,
                  unit: 'serving',
                  estimatedGrams: 100,
                  confidence: 'high',
                  macros: MacroNutrients(
                    calories: parseNonNegativeDouble(calCtrl.text),
                    proteinG: parseNonNegativeDouble(pCtrl.text),
                    carbsG: parseNonNegativeDouble(cCtrl.text),
                    fatG: parseNonNegativeDouble(fCtrl.text),
                  ),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    calCtrl.dispose();
    pCtrl.dispose();
    cCtrl.dispose();
    fCtrl.dispose();

    if (added != null && mounted) {
      setState(() => _items = [..._items, added]);
    }
  }

  Future<void> _saveMeal() async {
    if (_items.isEmpty) {
      setState(() {
        _errorMessage = 'Add at least one food item before saving.';
      });
      return;
    }

    final existing = widget.existingMeal;
    final now = DateTime.now();
    final selectedDate = widget.appState.selectedDate;
    final isToday =
        ZenDateUtils.toDateKey(selectedDate) == ZenDateUtils.toDateKey(now);

    final loggedAt = existing?.loggedAt ??
        (isToday
            ? now
            : selectedDate.add(Duration(hours: now.hour, minutes: now.minute)));

    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : '${_mealType.label} Meal';

    // Intermittent Fasting check: prompt to end fast when logging a meal
    if (widget.existingMeal == null && widget.appState.fasting.isActive) {
      final fasting = widget.appState.fasting;
      final breakFast = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bolt_rounded, color: fasting.currentStage.accentColor),
              const SizedBox(width: 8),
              const Text('Active Fast in Progress'),
            ],
          ),
          content: Text(
            'You are currently ${fasting.elapsedHours.toStringAsFixed(1)} hours into your fast (${fasting.currentStage.name}).\n\nLogging this meal marks the start of your eating window. Would you like to end and record your fast to history?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Fast Running'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End & Record Fast'),
            ),
          ],
        ),
      );
      if (breakFast == true) {
        await widget.appState.endFast();
      }
    }

    final entry = MealEntry(
      id: existing?.id ?? ZenDateUtils.newId('meal'),
      dateKey: existing?.dateKey ?? widget.appState.selectedDateKey,
      loggedAt: loggedAt,
      mealType: _mealType,
      title: title,
      rawInput: _inputCtrl.text.trim(),
      imagePath: _imagePath,
      items: _items,
      providerUsed: _providerUsed,
      aiNotes: _aiNotes,
    );

    final prevTotals = widget.appState.totalMacrosForDay;
    final calorieTarget = widget.appState.goals.calorieTarget;
    final proteinTarget = widget.appState.goals.proteinTargetG;

    await ZenHaptics.medium();
    await widget.appState.saveMeal(entry);

    if (!mounted) return;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();

    if (rootContext.mounted) {
      final newTotals = widget.appState.totalMacrosForDay;
      final wasInZone = (prevTotals.calories - calorieTarget).abs() <= calorieTarget * 0.05;
      final isNowInZone = (newTotals.calories - calorieTarget).abs() <= calorieTarget * 0.05;

      if (!wasInZone && isNowInZone) {
        showTargetCelebration(
          rootContext,
          title: 'Daily Calorie Target Hit! 🎯',
          subtitle: '${newTotals.calories.round()} / $calorieTarget kcal! Perfect energy balance.',
          icon: Icons.track_changes_rounded,
          accentColor: const Color(0xFF10B981),
        );
      } else if (prevTotals.proteinG < proteinTarget && newTotals.proteinG >= proteinTarget) {
        showTargetCelebration(
          rootContext,
          title: 'Protein Target Crushed! 💪',
          subtitle: '${newTotals.proteinG.round()}g logged! Optimal muscle recovery.',
          icon: Icons.fitness_center_rounded,
          accentColor: const Color(0xFF38BDF8),
        );
      }
    }
  }

  MacroNutrients get _reviewTotals {
    var total = MacroNutrients.zero;
    for (final item in _items) {
      total = total + item.macros;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.zen.borderSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: _inReviewMode
                      ? _buildReviewContent(context)
                      : _buildInputContent(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildInputContent(BuildContext context) {
    final zen = context.zen;
    final configured = widget.appState.isActiveProviderConfigured;
    final providerLabel =
        '${widget.appState.llmSettings.provider.displayName} · ${widget.appState.llmSettings.activeModel}';

    return [
      Row(
        children: [
          const BiteSizeLogo(size: 26),
          const SizedBox(width: 10),
          Text(
            'Log a Meal',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Describe your meal in plain words, snap a photo, or combine both.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: zen.inkMuted),
      ),
      if (!configured) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: zen.gentleClay.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: zen.gentleClay.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.key_outlined, color: zen.gentleClay),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add your ${widget.appState.llmSettings.provider.displayName} API key or endpoint in Settings to calculate with AI.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (widget.onOpenSettings != null)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onOpenSettings!();
                  },
                  child: const Text('Settings'),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        children: MealType.values.map((type) {
          return ChoiceChip(
            label: Text(type.label),
            selected: _mealType == type,
            onSelected: (_) => setState(() => _mealType = type),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _inputCtrl,
        maxLines: 4,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText:
              'e.g. "Bowl of oatmeal with half a banana, 1 tbsp almond butter, and black coffee"',
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 19),
              label: const Text('Camera'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 19),
              label: const Text('Gallery'),
            ),
          ),
        ],
      ),
      if (_imageBytes != null ||
          (_imagePath != null && File(_imagePath!).existsSync())) ...[
        const SizedBox(height: 12),
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _imageBytes != null
                  ? Image.memory(
                      _imageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_imagePath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () => setState(() {
                    _imagePath = null;
                    _imageBytes = null;
                  }),
                ),
              ),
            ),
          ],
        ),
      ],
      if (_errorMessage != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: zen.gentleClay.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _errorMessage!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: zen.gentleClay, fontWeight: FontWeight.w500),
          ),
        ),
      ],
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _isAnalyzing ? null : _analyzeWithLlm,
        icon: _isAnalyzing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(
          _isAnalyzing
              ? 'Estimating with ${widget.appState.llmSettings.activeModel}...'
              : 'Calculate Calories with AI',
        ),
      ),
      if (_isAnalyzing) ...[
        const SizedBox(height: 16),
        const ShimmerMealSkeleton(),
      ],
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            providerLabel,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: zen.inkMuted),
          ),
          TextButton(
            onPressed: _isAnalyzing ? null : _startManualReview,
            child: const Text('Enter manually instead'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        'Try an example',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: zen.inkMuted,
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _quickExamples.map((sample) {
          return ActionChip(
            label: Text(
              sample,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: _isAnalyzing
                ? null
                : () => setState(() => _inputCtrl.text = sample),
          );
        }).toList(),
      ),
    ];
  }

  List<Widget> _buildReviewContent(BuildContext context) {
    final zen = context.zen;
    final totals = _reviewTotals;
    final isEditingExisting = widget.existingMeal != null;

    return [
      Row(
        children: [
          if (!isEditingExisting)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back to input',
              onPressed: () => setState(() => _inReviewMode = false),
            ),
          Expanded(
            child: Text(
              isEditingExisting ? 'Edit Meal & Portions' : 'Review & Fine-Tune',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _titleCtrl,
        decoration: const InputDecoration(labelText: 'Meal title'),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: MealType.values.map((type) {
          return ChoiceChip(
            label: Text(type.label),
            selected: _mealType == type,
            onSelected: (_) => setState(() => _mealType = type),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: zen.sageSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${totals.calories.round()} kcal',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: zen.sage,
                      ),
                ),
                const Spacer(),
                Text(
                  'P ${totals.proteinG.round()}g · C ${totals.carbsG.round()}g · F ${totals.fatG.round()}g',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: zen.inkPrimary,
                      ),
                ),
              ],
            ),
            if (_aiNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              AiInsightBadge(
                text: _aiNotes,
                provider: _providerUsed,
              ),
            ],
            const SizedBox(height: 10),
            Divider(color: zen.borderSoft, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_outlined, size: 14, color: zen.sage),
                    const SizedBox(width: 6),
                    Text(
                      'Vitamins & Minerals',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: zen.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showMealMicronutrientsSheet(
                    context,
                    title: _titleCtrl.text.trim().isNotEmpty
                        ? _titleCtrl.text.trim()
                        : 'Meal Nutrition',
                    subtitle: '${_mealType.label} • Comprehensive Profile',
                    macros: totals,
                    items: _items,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View profile',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: zen.sage,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: zen.sage),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            'Items (${_items.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _addCustomFoodItem,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add item'),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ...List.generate(_items.length, (index) {
        final item = _items[index];
        return FoodItemEditorTile(
          key: ValueKey(item.id),
          item: item,
          onChanged: (updated) {
            setState(() {
              final next = List<FoodItem>.from(_items);
              next[index] = updated;
              _items = next;
            });
          },
          onRemove: () {
            setState(() {
              final next = List<FoodItem>.from(_items);
              next.removeAt(index);
              _items = next;
            });
          },
        );
      }),
      if (_errorMessage != null) ...[
        const SizedBox(height: 8),
        Text(
          _errorMessage!,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: zen.gentleClay),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _saveMeal,
        icon: const Icon(Icons.check_rounded),
        label: Text(isEditingExisting ? 'Update Meal' : 'Save Meal to Today'),
      ),
    ];
  }
}
