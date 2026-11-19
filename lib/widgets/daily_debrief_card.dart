import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import 'ai_markdown_view.dart';

/// Evening AI Nutrition Coach Debrief card: summarizes daily adherence, highlights wins,
/// and delivers an evidence-based tip for tomorrow with interactive follow-up capability.
class DailyDebriefCard extends StatefulWidget {
  const DailyDebriefCard({
    super.key,
    required this.appState,
    this.onOpenSettings,
  });

  final AppState appState;
  final VoidCallback? onOpenSettings;

  @override
  State<DailyDebriefCard> createState() => _DailyDebriefCardState();
}

class _DailyDebriefCardState extends State<DailyDebriefCard> {
  bool _isGenerating = false;
  String? _debrief;
  String? _errorMessage;

  final TextEditingController _questionCtrl = TextEditingController();
  bool _isAsking = false;
  String? _followUpAnswer;
  String? _lastQuestion;

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _askFollowUp(String question) async {
    final q = question.trim();
    if (q.isEmpty || _debrief == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isAsking = true;
      _lastQuestion = q;
    });

    try {
      final answer = await widget.appState.askDebriefFollowUp(_debrief!, q);
      if (mounted) {
        setState(() {
          _isAsking = false;
          _followUpAnswer = answer;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAsking = false;
          _followUpAnswer = 'Could not get answer: $e';
        });
      }
    }
  }

  Future<void> _generateDebrief() async {
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
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.appState.generateDailyDebrief();
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _debrief = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final mealsCount = widget.appState.mealsForDay.length;

    // Only show if at least 1 meal logged or evening
    if (mealsCount == 0 && DateTime.now().hour < 18) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: zen.sage,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily AI Coach Debrief',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Evening assessment & tomorrow\'s focus',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: zen.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                if (_debrief != null)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: _isGenerating ? null : _generateDebrief,
                    tooltip: 'Regenerate debrief',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isGenerating) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'BiteSize Coach is reviewing today\'s nutrition...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: zen.gentleClay.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: zen.gentleClay, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: zen.gentleClay, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _generateDebrief,
                child: const Text('Try Again'),
              ),
            ] else if (_debrief != null) ...[
              AiMarkdownView(
                content: _debrief!,
                badgeLabel: 'Evening AI Coach Debrief',
                badgeIcon: Icons.psychology_rounded,
              ),
              const SizedBox(height: 14),
              // Interactive Follow-up Question Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: zen.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.question_answer_rounded, size: 14, color: zen.sage),
                        const SizedBox(width: 6),
                        Text(
                          'Ask Coach a Follow-up Question',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: zen.sage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Preset suggestions
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFollowUpChip('+20g protein tomorrow?', 'How can I easily get 20g more protein tomorrow without adding excess calories?', zen),
                          const SizedBox(width: 6),
                          _buildFollowUpChip('Night craving snack?', 'What is a high-satiety evening snack that prevents cravings?', zen),
                          const SizedBox(width: 6),
                          _buildFollowUpChip('Calorie pacing tip?', 'What is the best way to pace my meals tomorrow to avoid late spikes?', zen),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _questionCtrl,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Type your question to AI Coach...',
                              hintStyle: TextStyle(fontSize: 11, color: zen.inkMuted),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onSubmitted: _isAsking ? null : (val) {
                              _askFollowUp(val);
                              _questionCtrl.clear();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: _isAsking
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_rounded, size: 16),
                          onPressed: _isAsking
                              ? null
                              : () {
                                  _askFollowUp(_questionCtrl.text);
                                  _questionCtrl.clear();
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_followUpAnswer != null) ...[
                const SizedBox(height: 10),
                AiMarkdownView(
                  content: _followUpAnswer!,
                  badgeLabel: _lastQuestion != null ? 'Q: $_lastQuestion' : 'Coach Advice',
                  badgeIcon: Icons.auto_awesome_rounded,
                ),
              ],
            ] else ...[
              Text(
                'Ready for your daily check-in? Get an objective assessment of your calorie pacing, macro distribution, and hydration.',
                style: TextStyle(fontSize: 12, color: zen.inkMuted, height: 1.35),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _generateDebrief,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('Generate Daily Debrief'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpChip(String label, String fullQuestion, ZenColors zen) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10.5)),
      visualDensity: VisualDensity.compact,
      onPressed: _isAsking ? null : () => _askFollowUp(fullQuestion),
    );
  }
}
