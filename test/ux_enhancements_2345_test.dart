import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/screens/today_screen.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/notification_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/services/zen_haptics.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/confetti_celebration.dart';
import 'package:zen_calorie/widgets/quick_water_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenHaptics Semantic Feedback System Tests', () {
    test('Executes all tactile haptic patterns without errors', () async {
      await ZenHaptics.selection();
      await ZenHaptics.light();
      await ZenHaptics.medium();
      await ZenHaptics.heavy();
      await ZenHaptics.warning();
      await ZenHaptics.celebrationSequence();
    });
  });

  group('QuickWaterCard Interactive Hydration Tests', () {
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

    testWidgets('QuickWaterCard renders initial hydration status and quick pills', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuickWaterCard(appState: appState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hydration & Fluid Balance'), findsOneWidget);
      expect(find.text('+250 ml'), findsOneWidget);
      expect(find.text('+500 ml'), findsOneWidget);
      expect(find.text('+750 ml'), findsOneWidget);
    });

    testWidgets('Tapping +250 ml, +500 ml adds water to AppState correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuickWaterCard(appState: appState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialWater = appState.totalWaterMlForDay;

      // Tap +250 ml
      await tester.tap(find.text('+250 ml'));
      await tester.pumpAndSettle();
      expect(appState.totalWaterMlForDay, initialWater + 250);

      // Tap +500 ml
      await tester.tap(find.text('+500 ml'));
      await tester.pumpAndSettle();
      expect(appState.totalWaterMlForDay, initialWater + 750);
    });

    testWidgets('Undo button appears when water logged and removes last glass', (tester) async {
      final initialWater = appState.totalWaterMlForDay;
      await appState.addWater(300, timestamp: DateTime.now().add(const Duration(hours: 12)));

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuickWaterCard(appState: appState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(appState.totalWaterMlForDay, initialWater + 300);
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();

      expect(appState.totalWaterMlForDay, initialWater);
    });
  });

  group('TodayScreen Horizontal Swipe Day Navigation Tests', () {
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

    testWidgets('TodayScreen renders dashboard cards cleanly without hydration clutter', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: TodayScreen(
              appState: appState,
              onOpenSettings: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuickWaterCard), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('Horizontal drag right navigates to previous day and drag left navigates to next day', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: TodayScreen(
              appState: appState,
              onOpenSettings: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialDate = appState.selectedDate;

      // Swipe Right (velocity > 0): Drag from left to right -> goes to previous day
      await tester.fling(find.byType(TodayScreen), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      expect(
        appState.selectedDate.day,
        initialDate.subtract(const Duration(days: 1)).day,
      );

      // Swipe Left (velocity < 0): Drag from right to left -> goes to next day
      await tester.fling(find.byType(TodayScreen), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(appState.selectedDate.day, initialDate.day);
    });
  });

  group('Target Hit Celebration Overlay Tests', () {
    testWidgets('showTargetCelebration inserts overlay with banner and confetti without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showTargetCelebration(
                      context,
                      title: 'Calorie Target Hit! 🎯',
                      subtitle: '2,000 / 2,000 kcal! Perfect balance.',
                    );
                  },
                  child: const Text('Celebrate'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Celebrate'));
      await tester.pump(); // insert overlay
      await tester.pump(const Duration(milliseconds: 300)); // animate banner in

      expect(find.text('Calorie Target Hit! 🎯'), findsOneWidget);
      expect(find.text('2,000 / 2,000 kcal! Perfect balance.'), findsOneWidget);

      // Tap banner to dismiss
      await tester.tap(find.text('Calorie Target Hit! 🎯'));
      await tester.pumpAndSettle();
    });
  });
}
