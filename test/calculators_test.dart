import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zen_calorie/models/health_log.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/models/user_profile.dart';
import 'package:zen_calorie/screens/calculators_screen.dart';
import 'package:zen_calorie/services/metabolic_analyzer.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';

class FakeAppState extends ChangeNotifier implements AppState {
  DailyGoals _goals = const DailyGoals(targetWeightKg: 68.0, calorieTarget: 2000);

  @override
  DailyGoals get goals => _goals;

  UserProfile _profile = const UserProfile(
    isMale: true,
    weightKg: 68.0,
    heightCm: 172.0,
    age: 26,
    isConfigured: true,
  );

  @override
  UserProfile get profile => _profile;

  @override
  String get selectedDateKey => '2026-11-13';

  final List<MealEntry> savedMeals = [];

  @override
  Future<void> saveMeal(MealEntry entry) async {
    savedMeals.add(entry);
    notifyListeners();
  }

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
  late FakeAppState appState;

  setUp(() {
    appState = FakeAppState();
  });

  group('Calculators & Personal Profile Integration Tests', () {
    testWidgets('CalculatorsScreen renders 3 focused tabs and persistent profile header', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
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

      // Check header and tabs
      expect(find.text('Health Hub & Calculators'), findsOneWidget);
      expect(find.text('Saved Personal Profile'), findsOneWidget);
      expect(find.textContaining('Male • 26 yrs • 172 cm • 68.0 kg'), findsOneWidget);
      expect(find.text('BMI (Asian WHO)'), findsOneWidget);
      expect(find.text('Body Fat %'), findsOneWidget);
      expect(find.text('BMR & TDEE'), findsOneWidget);

      // Verify removed tabs are no longer present
      expect(find.text('South Indian Plan'), findsNothing);
      expect(find.text('Water & Ideal Wt'), findsNothing);
    });

    testWidgets('Calculators automatically use configured personal profile details', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Set custom profile
      await appState.updateUserProfile(
        const UserProfile(
          isMale: false,
          weightKg: 55.0,
          heightCm: 160.0,
          age: 30,
          neckCm: 32.0,
          waistCm: 70.0,
          hipCm: 94.0,
          isConfigured: true,
        ),
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

      // Header should reflect female profile
      expect(find.textContaining('Female • 30 yrs • 160 cm • 55.0 kg'), findsOneWidget);

      // BMI Calculator should be pre-filled with 55 kg and 160 cm (BMI ~ 21.5)
      expect(find.text('21.5'), findsOneWidget);
      expect(find.text('Normal (Healthy South Asian)'), findsOneWidget);

      // Switch to Body Fat % tab
      await tester.tap(find.text('Body Fat %'));
      await tester.pumpAndSettle();

      // Should automatically use female mode
      expect(find.text('Hips (widest point)'), findsOneWidget);
      expect(find.text('U.S. Navy Body Fat Calculator'), findsOneWidget);

      // Switch to BMR & TDEE tab
      await tester.tap(find.text('BMR & TDEE'));
      await tester.pumpAndSettle();

      // Should show female BMR for 30y, 55kg, 160cm (~1239 kcal)
      expect(find.text('30 years'), findsOneWidget);
      expect(find.text('Basal Metabolic Rate (BMR)'), findsOneWidget);
    });

    testWidgets('Tapping Edit in profile header opens UserProfileSheet and saves updates', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
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

      // Tap Edit button
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Modal sheet should appear
      expect(find.text('Personal Details'), findsOneWidget);
      expect(find.text('Configured once, auto-filled in all calculators'), findsOneWidget);

      // Change age in text field
      final ageField = find.widgetWithText(TextField, 'Age (years)');
      expect(ageField, findsOneWidget);
      await tester.enterText(ageField, '28');

      // Tap Save Profile Details
      await tester.tap(find.text('Save Profile Details'));
      await tester.pumpAndSettle();

      // AppState profile should be updated to 28
      expect(appState.profile.age, 28);
      expect(find.textContaining('28 yrs'), findsOneWidget);
    });

    test('MetabolicAnalyzer deconstructs walking 5km, rope skipping, and desk job', () async {
      const routine = 'Walk 5km every morning, desk job 8 hours, 15 min rope skip in evening';
      final profile = await MetabolicAnalyzer.analyzeDailyActivity(
        description: routine,
        weightKg: 68.0,
        bmr: 1650.0,
      );

      expect(profile.activityFactor > 1.30, true);
      expect(profile.dailyActiveCalories > 300, true);
      expect(profile.activities.isNotEmpty, true);

      final hasWalk = profile.activities.any((a) => a.name.contains('Walk'));
      final hasSkip = profile.activities.any((a) => a.name.contains('Rope') || a.name.contains('Skip'));
      final hasDesk = profile.activities.any((a) => a.name.contains('Desk'));

      expect(hasWalk, true);
      expect(hasSkip, true);
      expect(hasDesk, true);
    });

    test('MetabolicAnalyzer generates South Asian body composition review', () async {
      final review = await MetabolicAnalyzer.generateBodyCompositionDiagnosis(
        bmi: 24.2,
        bodyFatPct: 22.5,
        weightKg: 70.0,
        heightCm: 170.0,
        isMale: true,
        activityDescription: 'Walking 5km, desk job',
      );

      expect(review.isNotEmpty, true);
      expect(review.contains('AI Clinical Diagnosis'), true);
      expect(review.contains('Protocol'), true);
    });

    test('MetabolicAnalyzer generates personalized fat loss plan and strategy', () async {
      final plan = await MetabolicAnalyzer.generateFatLossPlan(
        currentWeightKg: 75.0,
        targetWeightKg: 68.0,
        weeklyLossRateKg: 0.50,
        bmr: 1650,
        tdee: 2200,
        dailyCalorieBudget: 1700,
        macroSplitType: 'high_protein',
        proteinGrams: 130,
        carbsGrams: 170,
        fatGrams: 55,
        isMale: true,
      );

      expect(plan.isNotEmpty, true);
      expect(plan.contains('Fat Loss Strategy'), true);
      expect(plan.contains('Pacing & Timeline'), true);
      expect(plan.contains('Muscle Preservation'), true);
    });

    testWidgets('Customizable fat loss planner updates AppState live target on button tap', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
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

      // Go to BMR & TDEE tab
      await tester.tap(find.text('BMR & TDEE'));
      await tester.pumpAndSettle();

      expect(find.text('Customizable Fat Loss Planner'), findsOneWidget);
      expect(find.text('Set as My Live BiteSize Target'), findsOneWidget);

      // Scroll and Tap Set as Live Target
      await tester.ensureVisible(find.text('Set as My Live BiteSize Target'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as My Live BiteSize Target'));
      await tester.pumpAndSettle();

      // Goals should have been updated in appState
      expect(appState.goals.calorieTarget > 1000, true);
      expect(appState.goals.targetWeightKg > 0, true);
    });

    testWidgets('BMR & TDEE tab displays Current Body Weight, Height, Sex inputs and quick presets', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
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

      // Verify BMR & TDEE has current body weight, height, age, and sex selectors
      expect(find.text('Current Body Weight'), findsWidgets);
      expect(find.text('Height'), findsWidgets);
      expect(find.text('Target Goal Weight'), findsWidgets);
      expect(find.text('-2 kg quick cut'), findsOneWidget);
      expect(find.text('-5 kg steady cut'), findsOneWidget);

      // Tap +1kg stepper on current weight
      final plus1kgButtons = find.text('+1kg');
      expect(plus1kgButtons, findsWidgets);
      await tester.tap(plus1kgButtons.first);
      await tester.pumpAndSettle();

      // Tap -2 kg quick cut preset chip
      await tester.ensureVisible(find.text('-2 kg quick cut'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('-2 kg quick cut'));
      await tester.pumpAndSettle();

      // Verify Total Fat Loss Required reflects the 2kg cut
      expect(find.textContaining('2.0 kg'), findsWidgets);
    });
  });
}
