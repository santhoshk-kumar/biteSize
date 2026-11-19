import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zen_calorie/models/health_log.dart';
import 'package:zen_calorie/models/user_profile.dart';
import 'package:zen_calorie/screens/calculators_screen.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';

class MockAppState extends ChangeNotifier implements AppState {
  DailyGoals _goals = const DailyGoals(targetWeightKg: 65.0, calorieTarget: 1900);

  @override
  DailyGoals get goals => _goals;

  UserProfile _profile = const UserProfile(
    isMale: true,
    weightKg: 75.0,
    heightCm: 175.0,
    age: 28,
    isConfigured: true,
  );

  @override
  UserProfile get profile => _profile;

  @override
  String get selectedDateKey => '2026-11-14';

  @override
  Future<void> updateGoals(DailyGoals newGoals) async {
    _goals = newGoals;
    notifyListeners();
  }

  @override
  Future<void> updateUserProfile(UserProfile newProfile) async {
    _profile = newProfile;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAppState appState;

  setUp(() {
    appState = MockAppState();
  });

  Finder tdeeScrollable() => find
      .descendant(
        of: find.byKey(const Key('tdee_tab_listview')),
        matching: find.byType(Scrollable),
      )
      .first;

  group('Fat Loss Planner & Weekly Prediction Tests', () {
    testWidgets('Target weight stepper supports [-], [+], quick chips and tap-to-type dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: CalculatorsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to BMR & TDEE tab
      await tester.tap(find.text('BMR & TDEE'));
      await tester.pumpAndSettle();

      // Scroll down in the ListView to reveal Customizable Fat Loss Planner
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      // Verify Target Goal Weight stepper is rendered
      expect(find.text('Target Goal Weight'), findsWidgets);
      expect(find.text('Tap to type'), findsWidgets);

      // Verify quick pills: -1kg, -0.5kg, +0.5kg, +1kg
      expect(find.text('-1kg'), findsWidgets);
      expect(find.text('+0.5kg'), findsWidgets);

      // Verify Goal Presets
      expect(find.text('-2 kg quick cut'), findsOneWidget);
      expect(find.text('-5 kg steady cut'), findsOneWidget);
      expect(find.text('-10 kg cut'), findsOneWidget);

      // Tap on "Tap to type" to open direct number input dialog
      await tester.tap(find.text('Tap to type').first);
      await tester.pumpAndSettle();

      expect(find.text('Target Goal Weight'), findsWidgets);
      expect(find.text('Apply'), findsOneWidget);

      // Type 67.5 in the dialog textfield
      await tester.enterText(find.byType(TextField), '67.5');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Verify target weight updated to 67.5
      expect(find.textContaining('67.5 kg'), findsWidgets);
    });

    testWidgets('Weekly pace selector cards switch rate and steppers fine-tune by 0.05kg', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: CalculatorsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to BMR & TDEE tab
      await tester.tap(find.text('BMR & TDEE'));
      await tester.pumpAndSettle();

      // Scroll down to Weekly Pace selector
      await tester.scrollUntilVisible(find.textContaining('Gentle'), 300, scrollable: tdeeScrollable());
      await tester.pumpAndSettle();

      // Verify the 4 pace cards: Gentle, Optimal, Active, Intense
      expect(find.textContaining('Gentle'), findsOneWidget);
      expect(find.textContaining('Optimal'), findsOneWidget);
      expect(find.textContaining('Active'), findsOneWidget);
      expect(find.textContaining('Intense'), findsOneWidget);

      // Verify fine tune steppers
      expect(find.textContaining('0.05 kg'), findsWidgets);

      // Tap Gentle pace (0.25 kg/wk)
      await tester.tap(find.textContaining('Gentle'));
      await tester.pumpAndSettle();

      expect(find.textContaining('0.25 kg/wk'), findsWidgets);

      // Tap Active pace (0.75 kg/wk)
      await tester.tap(find.textContaining('Active'));
      await tester.pumpAndSettle();

      expect(find.textContaining('0.75 kg/wk'), findsWidgets);

      // Tap fine-tuning stepper to increase by 0.05kg
      final plus05Button = find.widgetWithText(OutlinedButton, '+ 0.05 kg');
      expect(plus05Button, findsOneWidget);
      await tester.tap(plus05Button);
      await tester.pumpAndSettle();

      expect(find.textContaining('0.80 kg'), findsWidgets);
    });

    testWidgets('Weekly weight loss prediction card calculates progression, milestones, expand toggle and copy roadmap', (tester) async {
      tester.view.physicalSize = const Size(1200, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Mock Clipboard handler to capture copied text
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: CalculatorsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to BMR & TDEE tab
      await tester.tap(find.text('BMR & TDEE'));
      await tester.pumpAndSettle();

      // Scroll down to Weekly Prediction Card
      await tester.scrollUntilVisible(find.text('Collapse Prediction'), 300, scrollable: tdeeScrollable());
      await tester.pumpAndSettle();

      // Verify Weekly Prediction Card exists and is expanded by default
      expect(find.text('Weekly Weight Loss Prediction'), findsOneWidget);
      expect(find.text('Copy Forecast'), findsOneWidget);
      expect(find.text('Collapse Prediction'), findsOneWidget);
      expect(find.text('Wk 1'), findsOneWidget);

      // Verify Milestone tags exist (e.g., 25%, 50%, 75%, Target Reached)
      expect(find.textContaining('25% Achieved'), findsWidgets);

      // Tap Collapse button to collapse table
      await tester.tap(find.text('Collapse Prediction'));
      await tester.pumpAndSettle();

      // Now should show Expand Weekly Forecast button
      expect(find.text('Expand Weekly Forecast'), findsOneWidget);

      // Tap Expand again to show rows
      await tester.tap(find.text('Expand Weekly Forecast'));
      await tester.pumpAndSettle();
      expect(find.text('Collapse Prediction'), findsOneWidget);

      // Tap Copy Forecast button
      await tester.tap(find.text('Copy Forecast'));
      await tester.pumpAndSettle();

      // Verify clipboard received the formatted roadmap
      expect(copiedText != null, true);
      expect(copiedText!.contains('My BiteSize Fat Loss Prediction & Roadmap'), true);
      expect(copiedText!.contains('Starting Weight:'), true);
      expect(copiedText!.contains('Goal Target Weight:'), true);
      expect(copiedText!.contains('WEEK-BY-WEEK FORECAST:'), true);
      expect(copiedText!.contains('Week 1 ('), true);

      // Verify SnackBar was shown
      expect(find.text('Copied Week-by-Week Weight Loss Prediction to Clipboard!'), findsOneWidget);
    });
  });
}
