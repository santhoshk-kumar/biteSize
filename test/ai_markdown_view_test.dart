import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/ai_markdown_view.dart';

void main() {
  group('AiMarkdownView & AI Rich Rendering Tests', () {
    testWidgets('AiMarkdownView renders headers, bold text, bullets, and callouts', (tester) async {
      const sampleText = '''
### 1. Daily Pacing
• **Breakfast:** 350 kcal with 25g protein.
• **Lunch:** 520 kcal with 40g protein.
> Keep hydration high during your afternoon fast.
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AiMarkdownView(
                content: sampleText,
                badgeLabel: 'AI Coach Debrief',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Coach Debrief'), findsOneWidget);
      expect(find.text('1. Daily Pacing'), findsOneWidget);
      expect(find.text('Keep hydration high during your afternoon fast.'), findsOneWidget);
    });

    testWidgets('AiMealSuggestionsView splits text into interactive option cards with Log This button', (tester) async {
      const suggestions = '''
### 1. Quick Grab: Greek Yogurt Bowl
• Portion: 200g Greek yogurt with 15g almonds
• Nutrients: 240 kcal | 22g protein | 14g carbs
• Why: Fast convenient protein hit.

### 2. High-Protein: Grilled Paneer Skewers
• Portion: 150g grilled paneer with bell peppers
• Nutrients: 380 kcal | 28g protein | 10g carbs
• Why: Satiating dinner option.
''';

      String? loggedTitle;

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiMealSuggestionsView(
                suggestionsText: suggestions,
                onLogMealOption: (title, details) {
                  loggedTitle = title;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 Tailored Meal Recommendations'), findsOneWidget);
      expect(find.text('Quick Grab'), findsOneWidget);
      expect(find.text('Greek Yogurt Bowl'), findsOneWidget);
      expect(find.text('Log This'), findsNWidgets(2));

      // Tap Log This on the first card
      await tester.tap(find.text('Log This').first);
      await tester.pumpAndSettle();

      expect(loggedTitle, 'Greek Yogurt Bowl');
    });

    testWidgets('AiInsightBadge renders compact glowing badge with provider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: const Scaffold(
            body: AiInsightBadge(
              text: 'High in bioavailable leucine and healthy fats.',
              provider: 'Gemini 2.0 Flash',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI NUTRITIONAL INSIGHT'), findsOneWidget);
      expect(find.text('Gemini 2.0 Flash'), findsOneWidget);
      expect(find.text('High in bioavailable leucine and healthy fats.'), findsOneWidget);
    });
  });
}
