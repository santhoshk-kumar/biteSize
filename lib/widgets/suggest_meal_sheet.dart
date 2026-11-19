import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'ai_markdown_view.dart';
import 'voice_meal_sheet.dart';

/// Smart AI Nutrition Coach sheet: analyzes remaining calories and macros for today
/// and generates 3 tailored meal suggestions (Quick Grab, High-Protein, and Wholesome/Comfort).
class SuggestMealSheet extends StatefulWidget {
  const SuggestMealSheet({
    super.key,
    required this.appState,
    this.onOpenSettings,
  });

  final AppState appState;
  final VoidCallback? onOpenSettings;

  @override
  State<SuggestMealSheet> createState() => _SuggestMealSheetState();
}

class _SuggestMealSheetState extends State<SuggestMealSheet> {
  bool _isLoading = false;
  String? _suggestions;
  String? _errorMessage;
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions({String? filter}) async {
    if (!widget.appState.isActiveProviderConfigured) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFilter = filter;
    });

    try {
      final res = await widget.appState.suggestNextMeal(dietaryFilter: filter);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _suggestions = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final dayTotals = widget.appState.totalMacrosForDay;
    final targetCal = widget.appState.effectiveCalorieTargetToday;
    final remainingCal = (targetCal - dayTotals.calories).round();
    final remainingProtein = (widget.appState.goals.proteinTargetG - dayTotals.proteinG).round();
    final remainingCarbs = (widget.appState.goals.carbsTargetG - dayTotals.carbsG).round();
    final remainingFat = (widget.appState.goals.fatTargetG - dayTotals.fatG).round();
    final configured = widget.appState.isActiveProviderConfigured;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: zen.borderSoft),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
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
                child: Icon(Icons.auto_awesome_rounded, color: zen.sage, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What to Eat Next? (Smart Coach)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'AI suggestions tailored to your remaining macros',
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
          const SizedBox(height: 14),
          // Remaining targets bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: zen.surfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: zen.borderSoft),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroCol('Remaining', '$remainingCal kcal', zen.sage),
                _buildMacroCol('Protein', '${remainingProtein}g', zen.protein),
                _buildMacroCol('Carbs', '${remainingCarbs}g', zen.carbs),
                _buildMacroCol('Fat', '${remainingFat}g', zen.fat),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Dietary Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Options', null, zen),
                const SizedBox(width: 6),
                _buildFilterChip('🌴 South Indian', 'Authentic South Indian regional cuisine (Idli, Dosa, Pesarattu, Sambar, Rasam, Curd rice, Sundal, Poriyal, Podimas)', zen),
                const SizedBox(width: 6),
                _buildFilterChip('High Protein (>30g)', 'High Protein (>30g protein per serving)', zen),
                const SizedBox(width: 6),
                _buildFilterChip('Vegetarian', 'Vegetarian and plant-based', zen),
                const SizedBox(width: 6),
                _buildFilterChip('Quick (<15m)', 'Quick prep under 15 minutes', zen),
                const SizedBox(width: 6),
                _buildFilterChip('Under 350 kcal', 'Light & low calorie under 350 kcal', zen),
                const SizedBox(width: 6),
                _buildFilterChip('Post-Workout', 'Post-workout recovery fuel', zen),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: !configured
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.key_outlined, size: 36, color: zen.inkMuted),
                        const SizedBox(height: 10),
                        const Text(
                          'LLM key not configured',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure Gemini or OpenAI in Settings to enable the AI Nutrition Coach.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: zen.inkMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onOpenSettings?.call();
                          },
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ),
                  )
                : _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Consulting BiteSize Nutrition Coach...',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: zen.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    size: 36, color: zen.gentleClay),
                                const SizedBox(height: 10),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: zen.gentleClay,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: _fetchSuggestions,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AiMealSuggestionsView(
                                  suggestionsText: _suggestions ?? '',
                                  onLogMealOption: (title, details) {
                                    Navigator.pop(context);
                                    showVoiceMealSheet(
                                      context,
                                      appState: widget.appState,
                                      initialText: title,
                                      onOpenSettings: widget.onOpenSettings,
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _fetchSuggestions,
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('Regenerate'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          showVoiceMealSheet(
                                            context,
                                            appState: widget.appState,
                                            onOpenSettings: widget.onOpenSettings,
                                          );
                                        },
                                        icon: const Icon(Icons.mic_rounded, size: 16),
                                        label: const Text('Log a Meal'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? filterValue, ZenColors zen) {
    final selected = _selectedFilter == filterValue;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      selectedColor: zen.sageSoft,
      visualDensity: VisualDensity.compact,
      onSelected: _isLoading
          ? null
          : (val) {
              HapticFeedback.selectionClick();
              _fetchSuggestions(filter: val ? filterValue : null);
            },
    );
  }

  Widget _buildMacroCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}

/// Helper function to show the Smart Coach suggestion sheet.
Future<void> showSuggestMealSheet(
  BuildContext context, {
  required AppState appState,
  VoidCallback? onOpenSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SuggestMealSheet(
      appState: appState,
      onOpenSettings: onOpenSettings,
    ),
  );
}

