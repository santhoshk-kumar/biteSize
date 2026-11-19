import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/fasting_model.dart';
import 'package:zen_calorie/models/health_log.dart';
import 'package:zen_calorie/models/notification_settings.dart';
import 'package:zen_calorie/models/user_profile.dart';
import 'package:zen_calorie/models/weekly_metabolic_report.dart';
import 'package:zen_calorie/screens/trends_screen.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/notification_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/weekly_metabolic_report_card.dart';
import 'package:zen_calorie/widgets/weekly_report_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeeklyMetabolicReport Mathematical & Scientific Modeling Tests', () {
    test('Calculates caloric deficit and predicted fat loss at 7700 kcal/kg correctly', () {
      final now = DateTime(2026, 11, 14);
      final dates = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

      const goals = DailyGoals(
        calorieTarget: 1800,
        proteinTargetG: 140,
        carbsTargetG: 180,
        fatTargetG: 60,
        fiberTargetG: 30,
        waterTargetMl: 2500,
      );

      const profile = UserProfile(
        isConfigured: true,
        isMale: true,
        weightKg: 75.0,
        heightCm: 178.0,
        age: 28,
      );

      // Mifflin-St Jeor BMR: 10*75 + 6.25*178 - 5*28 + 5 = 750 + 1112.5 - 140 + 5 = 1727.5
      // TDEE (1.375): 1727.5 * 1.375 ≈ 2375.3 kcal
      // Daily intake: 1800 kcal (deficit of ~575 kcal / day)
      // 7 days deficit ≈ 4027 kcal -> predicted fat loss = 4027 / 7700 ≈ 0.523 kg

      final summaries = <String, DailyCalorieSummary>{};
      for (final d in dates) {
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        summaries[key] = DailyCalorieSummary(
          dateKey: key,
          calories: 1800,
          proteinG: 140,
          carbsG: 180,
          fatG: 60,
          fiberG: 30,
          sugarG: 15,
          sodiumMg: 1800,
          waterMl: 2600,
          mealCount: 3,
        );
      }

      final report = WeeklyMetabolicReport.compute(
        dates: dates,
        summaries: summaries,
        goals: goals,
        profile: profile,
        weightHistory: const [],
        fasting: const FastingState(
          isActive: false,
          totalFastsCompleted: 5,
          totalHoursFasted: 80,
        ),
      );

      expect(report.daysLogged, 7);
      expect(report.averageDailyCalories, closeTo(1800, 1));
      expect(report.isDeficit, isTrue);
      expect(report.predictedFatLossKg, closeTo(0.52, 0.05));
      expect(report.predictedFatLossLb, closeTo(1.15, 0.10));
      expect(report.adherenceScore, inInclusiveRange(85, 100));
      expect(report.letterGrade, anyOf('A+', 'A'));
    });

    test('Handles zero logged days gracefully without zero division errors', () {
      final now = DateTime(2026, 11, 14);
      final dates = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

      final report = WeeklyMetabolicReport.compute(
        dates: dates,
        summaries: const {},
        goals: const DailyGoals(),
        profile: const UserProfile(),
        weightHistory: const [],
        fasting: const FastingState(),
      );

      expect(report.daysLogged, 0);
      expect(report.totalCaloriesConsumed, 0.0);
      expect(report.averageDailyCalories, 0.0);
      expect(report.letterGrade, 'D');
      expect(report.adherenceScore, 0);
      expect(report.keyInsights, isNotEmpty);
    });

    test('Generates complete formatted shareable text for clipboard export', () {
      final now = DateTime(2026, 11, 14);
      final dates = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

      final report = WeeklyMetabolicReport.compute(
        dates: dates,
        summaries: {
          '2026-11-14': const DailyCalorieSummary(
            dateKey: '2026-11-14',
            calories: 1950,
            proteinG: 135,
            carbsG: 210,
            fatG: 65,
            fiberG: 28,
            sugarG: 18,
            sodiumMg: 1900,
            waterMl: 2500,
            mealCount: 3,
          ),
        },
        goals: const DailyGoals(),
        profile: const UserProfile(),
        weightHistory: const [],
        fasting: const FastingState(),
      );

      final textKg = report.toShareableText(useKg: true);
      final textLb = report.toShareableText(useKg: false);

      expect(textKg, contains('BITESIZE WEEKLY METABOLIC REPORT'));
      expect(textKg, contains('ENERGY & FAT LOSS PREDICTOR'));
      expect(textKg, contains('kg fat / week'));
      expect(textLb, contains('lb fat / week'));
      expect(textKg, contains('Tracked with BiteSize'));
    });
  });

  group('Ongoing Fasting Notification Architecture Tests', () {
    test('NotificationSettings toggles fastingOngoingNotification cleanly', () {
      const defaultSettings = NotificationSettings();
      expect(defaultSettings.fastingOngoingNotification, isTrue);

      final updated = defaultSettings.copyWith(fastingOngoingNotification: false);
      expect(updated.fastingOngoingNotification, isFalse);

      final map = updated.toMap();
      expect(map['fastingOngoingNotification'], isFalse);

      final restored = NotificationSettings.fromMap(map);
      expect(restored.fastingOngoingNotification, isFalse);
    });

    test('NotificationService manages ongoing fasting chronometer channel and ID', () {
      expect(NotificationService.channelFastingLive, 'bitesize_fasting_live');
      expect(NotificationService.idOngoingFasting, 200);
    });
  });

  group('Weekly Metabolic Report UI & Integration Tests', () {
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseService();
      final settings = SettingsRepository();
      final keyStore = SecureKeyStore();
      final llm = LlmService(keyStore: keyStore);
      final notif = NotificationService();

      appState = AppState(
        database: db,
        settingsRepo: settings,
        keyStore: keyStore,
        llmService: llm,
        notificationService: notif,
      );
      await appState.initialize();
    });

    testWidgets('WeeklyMetabolicReportCard renders successfully in widget tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyMetabolicReportCard(appState: appState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly Metabolic Report'), findsOneWidget);
      expect(find.text('PREDICTED FAT LOSS'), findsOneWidget);
      expect(find.text('NET ENERGY BALANCE'), findsOneWidget);
      expect(find.text('View Full Metabolic Breakdown →'), findsOneWidget);
    });

    testWidgets('WeeklyReportSheet renders score, pillars, and responds to week toggle', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: WeeklyReportSheet(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly Metabolic Report'), findsOneWidget);
      expect(find.text('Current 7 Days'), findsOneWidget);
      expect(find.text('Prior 7 Days'), findsOneWidget);
      expect(find.text('Fat Loss Rate Predictor'), findsOneWidget);
      expect(find.text('7-Day Caloric Distribution'), findsOneWidget);
      expect(find.text('Metabolic Pillars'), findsOneWidget);
      expect(find.text('Protein Pacing'), findsOneWidget);
      expect(find.text('Fasting Depth'), findsOneWidget);
      expect(find.text('Hydration'), findsOneWidget);
      expect(find.text('Dietary Fiber'), findsOneWidget);
      expect(find.text('Copy Full Report to Clipboard'), findsOneWidget);

      // Tap Prior 7 Days
      await tester.tap(find.text('Prior 7 Days'));
      await tester.pumpAndSettle();
    });

    testWidgets('TrendsScreen renders redesigned 4-card analytics and week options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: TrendsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trends & Analytics'), findsOneWidget);
      expect(find.text('This week'), findsNWidgets(2));
      expect(find.text('AVG CALORIE DAILY'), findsOneWidget);
      expect(find.text('Weekly Totals'), findsOneWidget);
      expect(find.text('Activity & Expenditure'), findsOneWidget);
      expect(find.text('Daily Breakdown'), findsOneWidget);
    });
  });
}
