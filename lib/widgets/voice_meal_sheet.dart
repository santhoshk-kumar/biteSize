import 'package:flutter/material.dart';

import '../models/nutrition.dart';
import '../services/date_utils.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'ai_markdown_view.dart';
import 'shimmer_meal_skeleton.dart';

/// Interactive hands-free Voice-to-Meal logging sheet with pulsing microphone animation,
/// quick speech templates, and instant LLM nutritional analysis.
class VoiceMealSheet extends StatefulWidget {
  const VoiceMealSheet({
    super.key,
    required this.appState,
    this.initialText,
    this.onOpenSettings,
  });

  final AppState appState;
  final String? initialText;
  final VoidCallback? onOpenSettings;

  @override
  State<VoiceMealSheet> createState() => _VoiceMealSheetState();
}

class _VoiceMealSheetState extends State<VoiceMealSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final TextEditingController _voiceTextCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  MealType _selectedMealType = MealType.lunch;
  bool _isAnalyzing = false;
  String? _analysisError;
  MealEntry? _estimatedMeal;

  static const List<String> _sampleVoicePhrases = [
    '3 idlis with sambar, coconut chutney, and filter coffee',
    '2 chapatis with paneer tikka masala and cucumber salad',
    'Bowl of oatmeal with scoop of whey, blueberries, and 10 almonds',
    '200g grilled chicken breast with roasted sweet potato and broccoli',
    'Masala dosa with potato masala and mint chutney',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _voiceTextCtrl.text = widget.initialText!;
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceTextCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _analyzeVoiceInput() async {
    final text = _voiceTextCtrl.text.trim();
    if (text.isEmpty) return;

    if (!widget.appState.isActiveProviderConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configure an LLM provider first in Settings.'),
          action: widget.onOpenSettings != null
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: widget.onOpenSettings!,
                )
              : null,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
      _estimatedMeal = null;
    });

    try {
      final res = await widget.appState.estimateMeal(
        description: text,
        mealTypeHint: _selectedMealType,
      );

      final meal = MealEntry(
        id: ZenDateUtils.newId('meal'),
        dateKey: widget.appState.selectedDateKey,
        loggedAt: DateTime.now(),
        mealType: _selectedMealType,
        title: res.mealTitle.isNotEmpty ? res.mealTitle : 'Voice Logged Meal',
        rawInput: '🎙️ $text',
        items: res.items,
        providerUsed: res.providerLabel,
        aiNotes: res.aiNotes,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _estimatedMeal = meal;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisError = e.toString();
        });
      }
    }
  }

  Future<void> _saveAndClose() async {
    if (_estimatedMeal == null) return;
    await widget.appState.saveMeal(_estimatedMeal!);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged ${_estimatedMeal!.title} (+${_estimatedMeal!.totalMacros.calories.round()} kcal)',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: zen.borderSoft),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: zen.inkMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zen.sageSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mic_rounded, color: zen.sage, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice-to-Meal Instant Log',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          'Speak your meal hands-free — AI calculates everything',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: zen.inkMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Interactive Pulsing Mic Graphic
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (_isAnalyzing) return;
                    if (_voiceTextCtrl.text.trim().isNotEmpty) {
                      _analyzeVoiceInput();
                    } else {
                      _focusNode.requestFocus();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          duration: Duration(seconds: 2),
                          content: Text('Type or use your keyboard microphone to dictate your meal!'),
                        ),
                      );
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isAnalyzing ? 1.0 : _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: zen.sage.withOpacity(0.12),
                            border: Border.all(
                              color: zen.sage.withOpacity(0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: zen.sage.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isAnalyzing
                                ? Icons.hourglass_top_rounded
                                : Icons.mic_rounded,
                            size: 38,
                            color: zen.sage,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _isAnalyzing
                      ? 'AI is analyzing calories, portions & macros...'
                      : _voiceTextCtrl.text.trim().isNotEmpty
                          ? 'Tap mic or button below to estimate nutrition with AI'
                          : 'Tap microphone to speak or type your meal',
                  style: TextStyle(
                    fontSize: 12,
                    color: _voiceTextCtrl.text.trim().isNotEmpty ? zen.sage : zen.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _voiceTextCtrl,
                focusNode: _focusNode,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. "2 dosas with coconut chutney and a glass of milk"',
                  suffixIcon: _voiceTextCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _voiceTextCtrl.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              // Meal Type Selector
              Row(
                children: [
                  Text(
                    'Meal:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: zen.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: MealType.values.map((type) {
                          final selected = type == _selectedMealType;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(type.label),
                              selected: selected,
                              onSelected: (val) {
                                if (val) setState(() => _selectedMealType = type);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick Voice Sample Chips
              const Text(
                'Quick Speech Ideas (tap to try):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _sampleVoicePhrases.map((phrase) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          phrase,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          setState(() {
                            _voiceTextCtrl.text = phrase;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (_analysisError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: zen.gentleClay.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: zen.gentleClay.withOpacity(0.4)),
                  ),
                  child: Text(
                    _analysisError!,
                    style: TextStyle(color: zen.gentleClay, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Shimmer loading skeleton during AI analysis
              if (_isAnalyzing) ...[
                const SizedBox(height: 12),
                const ShimmerMealSkeleton(),
                const SizedBox(height: 12),
              ],
              // Estimated meal preview
              if (_estimatedMeal != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: zen.sage.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _estimatedMeal!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: zen.sageSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${_estimatedMeal!.totalMacros.calories.round()} kcal',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: zen.sage,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'P: ${_estimatedMeal!.totalMacros.proteinG.round()}g  •  C: ${_estimatedMeal!.totalMacros.carbsG.round()}g  •  F: ${_estimatedMeal!.totalMacros.fatG.round()}g',
                        style: TextStyle(fontSize: 12, color: zen.inkMuted),
                      ),
                      const Divider(height: 18),
                      ..._estimatedMeal!.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text('• ', style: TextStyle(color: zen.sage)),
                              Expanded(
                                child: Text(
                                  '${item.name} (${item.quantity > 1 ? '${item.quantity} ' : ''}${item.unit})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                '${item.macros.calories.round()} kcal',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: zen.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_estimatedMeal!.aiNotes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        AiInsightBadge(
                          text: _estimatedMeal!.aiNotes,
                          provider: _estimatedMeal!.providerUsed,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saveAndClose,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save to Today'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _isAnalyzing || _voiceTextCtrl.text.trim().isEmpty
                      ? null
                      : _analyzeVoiceInput,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze & Estimate Meal'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to open the Voice-to-Meal modal bottom sheet.
Future<void> showVoiceMealSheet(
  BuildContext context, {
  required AppState appState,
  String? initialText,
  VoidCallback? onOpenSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VoiceMealSheet(
      appState: appState,
      initialText: initialText,
      onOpenSettings: onOpenSettings,
    ),
  );
}

