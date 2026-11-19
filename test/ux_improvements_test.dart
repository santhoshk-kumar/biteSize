import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/fasting_model.dart';
import 'package:zen_calorie/models/user_profile.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/zen_calorie_ring.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UX Improvements & Auto-Sync Tests', () {
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseService();
      final settings = SettingsRepository();
      final keyStore = SecureKeyStore();
      final llm = LlmService(keyStore: keyStore);
      appState = AppState(
        database: db,
        settingsRepo: settings,
        keyStore: keyStore,
        llmService: llm,
      );
      await appState.initialize();
    });

    test('Weight Tracker automatically syncs logged weight to UserProfile & Calculators', () async {
      // Set initial profile weight
      await appState.updateUserProfile(const UserProfile(
        isMale: true,
        age: 28,
        heightCm: 178,
        weightKg: 75.0,
        isConfigured: true,
      ));
      expect(appState.profile.weightKg, 75.0);

      // Log new weight with syncToProfile: true (the default)
      await appState.logWeight(80.0, syncToProfile: true);

      // Verify profile weight was updated
      expect(appState.profile.weightKg, 80.0);
    });

    test('Active Fasting stage alerts surface in activeCalorieAlert', () async {
      // Start a fast 13 hours ago (Fat Burning stage) with a 24-hour protocol so target is not reached yet
      final thirteenHoursAgo = DateTime.now().subtract(const Duration(hours: 13));
      await appState.startFast(
        protocol: FastingProtocol.twentyFour,
        customStartTime: thirteenHoursAgo,
      );

      final alert = appState.activeCalorieAlert;
      expect(alert, isNotNull);
      expect(alert!.title, contains('Fat Burning & Ketosis'));
      expect(alert.severity, 'info');
    });

    test('Fasting stage alert transitions to Deep Autophagy at 18+ hours', () async {
      final nineteenHoursAgo = DateTime.now().subtract(const Duration(hours: 19));
      await appState.startFast(
        protocol: FastingProtocol.twentyFour,
        customStartTime: nineteenHoursAgo,
      );

      final alert = appState.activeCalorieAlert;
      expect(alert, isNotNull);
      expect(alert!.title, contains('Deep Autophagy'));
      expect(alert.message, contains('mitochondria'));
    });

    testWidgets('ZenCalorieRing cycles modes on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: ZenCalorieRing(
                consumed: 1500,
                target: 2000,
                meals: [],
              ),
            ),
          ),
        ),
      );

      // Default mode: Consumed vs Target
      expect(find.text('1500'), findsOneWidget);
      expect(find.text('of 2000 kcal'), findsOneWidget);

      // Tap the ring (GestureDetector) -> Mode 1: Deficit / Remaining mode
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('500'), findsOneWidget);
      expect(find.text('kcal remaining'), findsOneWidget);

      // Tap second time -> Mode 2: Percentage Reached mode
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('of goal reached'), findsOneWidget);

      // Tap third time -> Mode 3: Deficit/Surplus Balance mode
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('-500'), findsOneWidget);
      expect(find.text('energy deficit'), findsOneWidget);

      // Tap fourth time -> Returns to Mode 0: Consumed vs Target
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('1500'), findsOneWidget);
      expect(find.text('of 2000 kcal'), findsOneWidget);
    });
  });
}
