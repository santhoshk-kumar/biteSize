import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/zen_theme.dart';

/// A rich, structured AI Response and Markdown renderer with Titanium Emerald luxury styling.
/// Replaces plain monospaced walls of text with elegant cards, macro pills, accent bullets, and callouts.
class AiMarkdownView extends StatelessWidget {
  const AiMarkdownView({
    super.key,
    required this.content,
    this.badgeLabel,
    this.badgeIcon = Icons.auto_awesome_rounded,
    this.showHeader = true,
  });

  final String content;
  final String? badgeLabel;
  final IconData badgeIcon;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final blocks = _parseBlocks(content);

    return Container(
      decoration: BoxDecoration(
        color: zen.surfaceSubtle.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zen.sage.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(badgeIcon, size: 16, color: zen.sage),
                ),
                const SizedBox(width: 8),
                Text(
                  badgeLabel ?? 'AI Coach Analysis',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: zen.sage,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: zen.borderSoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Evidence-Based',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: zen.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: zen.borderSoft, height: 1),
            const SizedBox(height: 12),
          ],
          ...blocks.map((b) => _renderBlock(context, b, zen)),
        ],
      ),
    );
  }

  List<_AiBlock> _parseBlocks(String raw) {
    final lines = raw.split('\n');
    final blocks = <_AiBlock>[];

    _BlockType currentType = _BlockType.paragraph;
    final currentBuffer = StringBuffer();

    void flush() {
      final str = currentBuffer.toString().trim();
      if (str.isNotEmpty) {
        blocks.add(_AiBlock(type: currentType, text: str));
      }
      currentBuffer.clear();
      currentType = _BlockType.paragraph;
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flush();
        continue;
      }

      if (trimmed.startsWith('### ') || trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        flush();
        blocks.add(_AiBlock(
          type: _BlockType.header,
          text: trimmed.replaceFirst(RegExp(r'^#+\s*'), ''),
        ));
        continue;
      }

      if (trimmed.startsWith('• ') ||
          trimmed.startsWith('- ') ||
          trimmed.startsWith('* ')) {
        flush();
        blocks.add(_AiBlock(
          type: _BlockType.bullet,
          text: trimmed.replaceFirst(RegExp(r'^[•\-\*]\s*'), ''),
        ));
        continue;
      }

      if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        flush();
        final match = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
        if (match != null) {
          blocks.add(_AiBlock(
            type: _BlockType.numbered,
            number: int.tryParse(match.group(1) ?? '1') ?? 1,
            text: match.group(2) ?? '',
          ));
          continue;
        }
      }

      if (trimmed.startsWith('> ')) {
        flush();
        blocks.add(_AiBlock(
          type: _BlockType.quote,
          text: trimmed.replaceFirst(RegExp(r'^>\s*'), ''),
        ));
        continue;
      }

      currentBuffer.writeln(trimmed);
    }

    flush();
    return blocks;
  }

  Widget _renderBlock(BuildContext context, _AiBlock block, ZenColors zen) {
    switch (block.type) {
      case _BlockType.header:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: zen.sage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: zen.inkPrimary,
                      ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.numbered:
        return Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: zen.borderSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: zen.sageSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${block.number}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: zen.sage,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RichInlineText(text: block.text, zen: zen),
              ),
            ],
          ),
        );

      case _BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: zen.sage,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: _RichInlineText(text: block.text, zen: zen),
              ),
            ],
          ),
        );

      case _BlockType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: zen.sage.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: zen.sage, width: 3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: zen.sage),
              const SizedBox(width: 8),
              Expanded(
                child: _RichInlineText(text: block.text, zen: zen, isItalic: true),
              ),
            ],
          ),
        );

      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: _RichInlineText(text: block.text, zen: zen),
        );
    }
  }
}

enum _BlockType { header, numbered, bullet, quote, paragraph }

class _AiBlock {
  const _AiBlock({required this.type, required this.text, this.number = 1});

  final _BlockType type;
  final String text;
  final int number;
}

/// Parses inline bold `**text**` and macro values with high-contrast typography.
class _RichInlineText extends StatelessWidget {
  const _RichInlineText({
    required this.text,
    required this.zen,
    this.isItalic = false,
  });

  final String text;
  final ZenColors zen;
  final bool isItalic;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    var currentIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        final before = text.substring(currentIndex, match.start);
        spans.addAll(_highlightMacros(before, zen, isItalic));
      }

      final boldContent = match.group(1) ?? '';
      spans.add(
        TextSpan(
          text: boldContent,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: zen.inkPrimary,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      final remaining = text.substring(currentIndex);
      spans.addAll(_highlightMacros(remaining, zen, isItalic));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: 13,
        height: 1.55,
        color: zen.inkPrimary.withValues(alpha: 0.9),
      ),
    );
  }

  List<InlineSpan> _highlightMacros(String raw, ZenColors zen, bool isItalic) {
    final spans = <InlineSpan>[];
    // Matches calorie numbers (e.g. "240 kcal", "25g protein", "14g carbs", "8g fat")
    final macroRegex = RegExp(
      r'(\b\d+(?:\.\d+)?\s*(?:kcal|calories|g\s*(?:protein|carbs|fat|fiber)|ml)\b)',
      caseSensitive: false,
    );

    var idx = 0;
    for (final match in macroRegex.allMatches(raw)) {
      if (match.start > idx) {
        spans.add(TextSpan(
          text: raw.substring(idx, match.start),
          style: TextStyle(
            color: zen.inkPrimary.withValues(alpha: 0.85),
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ));
      }

      final matchStr = match.group(1) ?? '';
      final lower = matchStr.toLowerCase();
      Color macroColor = zen.sage;
      if (lower.contains('protein')) {
        macroColor = zen.protein;
      } else if (lower.contains('carb')) {
        macroColor = zen.carbs;
      } else if (lower.contains('fat')) {
        macroColor = zen.fat;
      } else if (lower.contains('water') || lower.contains('ml')) {
        macroColor = zen.water;
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: macroColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: macroColor.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Text(
              matchStr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: macroColor,
              ),
            ),
          ),
        ),
      );

      idx = match.end;
    }

    if (idx < raw.length) {
      spans.add(TextSpan(
        text: raw.substring(idx),
        style: TextStyle(
          color: zen.inkPrimary.withValues(alpha: 0.85),
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        ),
      ));
    }

    return spans;
  }
}

/// Specialized interactive cards for AI Meal Suggestions in "What to Eat Next?".
/// Splits options into individual cards with macro badges and a 1-tap "Log This Meal" action.
class AiMealSuggestionsView extends StatelessWidget {
  const AiMealSuggestionsView({
    super.key,
    required this.suggestionsText,
    required this.onLogMealOption,
  });

  final String suggestionsText;
  final void Function(String title, String details) onLogMealOption;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final options = _extractMealOptions(suggestionsText);

    if (options.isEmpty) {
      return AiMarkdownView(
        content: suggestionsText,
        badgeLabel: 'Smart Nutrition Coach',
        badgeIcon: Icons.auto_awesome_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: zen.sageSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.restaurant_menu_rounded, size: 16, color: zen.sage),
            ),
            const SizedBox(width: 8),
            Text(
              '3 Tailored Meal Recommendations',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: zen.sage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...options.map((opt) => _MealOptionCard(opt: opt, zen: zen, onLog: onLogMealOption)),
      ],
    );
  }
}

class _MealOptionCard extends StatefulWidget {
  const _MealOptionCard({
    required this.opt,
    required this.zen,
    required this.onLog,
  });

  final _MealOption opt;
  final ZenColors zen;
  final void Function(String title, String details) onLog;

  @override
  State<_MealOptionCard> createState() => _MealOptionCardState();
}

class _MealOptionCardState extends State<_MealOptionCard> {
  bool _showRecipe = false;

  @override
  Widget build(BuildContext context) {
    final opt = widget.opt;
    final zen = widget.zen;

    Color tagColor = zen.sage;
    IconData tagIcon = Icons.bolt_rounded;

    if (opt.category.toLowerCase().contains('high-protein') ||
        opt.category.toLowerCase().contains('protein')) {
      tagColor = zen.protein;
      tagIcon = Icons.fitness_center_rounded;
    } else if (opt.category.toLowerCase().contains('quick') ||
        opt.category.toLowerCase().contains('grab')) {
      tagColor = zen.carbs;
      tagIcon = Icons.electric_bolt_rounded;
    } else if (opt.category.toLowerCase().contains('comfort') ||
        opt.category.toLowerCase().contains('wholesome') ||
        opt.category.toLowerCase().contains('veg')) {
      tagColor = zen.sage;
      tagIcon = Icons.spa_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tagColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: tagColor.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tagIcon, size: 12, color: tagColor),
                    const SizedBox(width: 4),
                    Text(
                      opt.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: tagColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onLog(opt.title, opt.body);
                },
                icon: const Icon(Icons.add_task_rounded, size: 14),
                label: const Text('Log This', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            opt.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 8),
          _RichInlineText(text: opt.body, zen: zen),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showRecipe = !_showRecipe);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: zen.borderSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showRecipe ? Icons.kitchen_rounded : Icons.menu_book_rounded,
                    size: 14,
                    color: zen.sage,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showRecipe ? 'Hide 3-Step Recipe & Prep' : '🍳 View 3-Step Recipe & Prep',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: zen.sage,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showRecipe ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 14,
                    color: zen.sage,
                  ),
                ],
              ),
            ),
          ),
          if (_showRecipe) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: zen.sageSoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: zen.sage.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.outdoor_grill_rounded, size: 14, color: zen.sage),
                      const SizedBox(width: 6),
                      Text(
                        '3-Step Quick Prep Guide:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: zen.sage),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildPrepStep('1', 'Portion & Prep', 'Measure the ingredients to align with your macro target.', zen),
                  _buildPrepStep('2', 'Quick Cook / Mix', 'Lightly saute, blend, or toss with minimal cooking oil to keep nutrient density high.', zen),
                  _buildPrepStep('3', 'Plate & Enjoy', 'Pair with a glass of water or electrolyte drink to support steady satiety.', zen),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrepStep(String stepNum, String title, String desc, ZenColors zen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: zen.sage,
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNum,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11, color: zen.inkPrimary, height: 1.3),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: desc, style: TextStyle(color: zen.inkMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

  List<_MealOption> _extractMealOptions(String text) {
    final options = <_MealOption>[];
    final lines = text.split('\n');

    int? currentNumber;
    String? currentRawHeader;
    final currentBodyLines = <String>[];

    void flushOption() {
      if (currentNumber != null && currentRawHeader != null) {
        String category = 'Option $currentNumber';
        String title = currentRawHeader!;

        if (currentRawHeader!.contains(':')) {
          final parts = currentRawHeader!.split(':');
          category = parts.first.trim();
          title = parts.sublist(1).join(':').trim();
        } else if (currentRawHeader!.contains('-')) {
          final parts = currentRawHeader!.split('-');
          category = parts.first.trim();
          title = parts.sublist(1).join('-').trim();
        }
        if (title.isEmpty) title = currentRawHeader!;

        // Clean markdown marks from title and category
        category = category.replaceAll(RegExp(r'[#\*]'), '').trim();
        title = title.replaceAll(RegExp(r'[#\*]'), '').trim();

        options.add(_MealOption(
          number: currentNumber!,
          category: category.isNotEmpty ? category : 'Option $currentNumber',
          title: title,
          body: currentBodyLines.join('\n').trim(),
        ));
      }
      currentNumber = null;
      currentRawHeader = null;
      currentBodyLines.clear();
    }

    final headerMatchRegex = RegExp(r'^(?:#+\s*)?(?:Option\s*)?(\d+)[\.:\)]\s*(.*)$');

    for (final line in lines) {
      final trimmed = line.trim();
      final match = headerMatchRegex.firstMatch(trimmed);

      if (match != null) {
        flushOption();
        currentNumber = int.tryParse(match.group(1) ?? '1') ?? (options.length + 1);
        currentRawHeader = match.group(2)?.trim() ?? '';
      } else if (currentNumber != null) {
        if (trimmed.isNotEmpty) {
          currentBodyLines.add(line);
        }
      }
    }

    flushOption();
    return options;
  }

class _MealOption {
  const _MealOption({
    required this.number,
    required this.category,
    required this.title,
    required this.body,
  });

  final int number;
  final String category;
  final String title;
  final String body;
}

/// Compact glowing AI Insight pill for meal notes and confidence indicators.
class AiInsightBadge extends StatelessWidget {
  const AiInsightBadge({
    super.key,
    required this.text,
    this.provider,
  });

  final String text;
  final String? provider;

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: zen.sage.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zen.sage.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.auto_awesome_rounded, size: 14, color: zen.sage),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI NUTRITIONAL INSIGHT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: zen.sage,
                      ),
                    ),
                    if (provider != null && provider!.isNotEmpty)
                      Text(
                        provider!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: zen.inkMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: zen.inkPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
