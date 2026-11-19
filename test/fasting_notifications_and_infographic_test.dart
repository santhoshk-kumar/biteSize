import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/fasting_model.dart';
import 'package:zen_calorie/models/notification_settings.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/notification_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/bitesize_logo.dart';
import 'package:zen_calorie/widgets/shareable_infographic_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fasting Metabolic Stage Notifications Tests', () {
    late NotificationService notifService;

    setUp(() {
      notifService = NotificationService();
    });

    test('syncAllReminders schedules metabolic stage alerts when fasting is active', () async {
      final startTime = DateTime.now().subtract(const Duration(hours: 2));
      final fasting = FastingState(
        isActive: true,
        startTime: startTime,
        protocol: FastingProtocol.sixteenEight,
      );

      const settings = NotificationSettings(
        enabled: true,
        fastingStageTransitionAlert: true,
        fastingTargetReachedAlert: true,
        fastingWindowClosingAlert: true,
      );

      // Should complete cleanly without uncaught exceptions
      await notifService.syncAllReminders(
        settings: settings,
        fasting: fasting,
      );
    });

    test('syncAllReminders cancels all fasting alerts when fast is not active', () async {
      const fasting = FastingState(
        isActive: false,
        protocol: FastingProtocol.sixteenEight,
      );

      const settings = NotificationSettings(
        enabled: true,
        fastingStageTransitionAlert: true,
        fastingTargetReachedAlert: true,
      );

      await notifService.syncAllReminders(
        settings: settings,
        fasting: fasting,
      );
    });

    test('cancelAll cancels all notifications including fasting stage alerts', () async {
      await notifService.cancelAll();
    });
  });

  group('Shareable Infographic Sheet Tests', () {
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

    testWidgets('Renders ShareableInfographicSheet in daily recap mode', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: ShareableInfographicSheet(
              appState: appState,
              initialMode: InfographicMode.daily,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share Infographic Card'), findsOneWidget);
      expect(find.text('DAILY CALORIES'), findsOneWidget);
      expect(find.byType(BiteSizeLogo), findsOneWidget);
      expect(find.text('Copy Text'), findsOneWidget);
      expect(find.textContaining('Share (WhatsApp / Insta)'), findsOneWidget);
      expect(find.byTooltip('Save Screenshot PNG'), findsOneWidget);
    });

    testWidgets('Switches to Weekly Metabolic mode and displays weekly pillars', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: ShareableInfographicSheet(
              appState: appState,
              initialMode: InfographicMode.weekly,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WEEKLY METABOLIC DEFICIT'), findsOneWidget);
      expect(find.text('Avg Intake'), findsOneWidget);
      expect(find.text('Protein Hit'), findsOneWidget);
      expect(find.text('Days Logged'), findsOneWidget);
    });

    testWidgets('Switches to Fasting Milestone mode and displays fasting stats', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: ShareableInfographicSheet(
              appState: appState,
              initialMode: InfographicMode.fasting,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('FASTING PROTOCOL'), findsOneWidget);
      expect(find.text('Total Hours'), findsOneWidget);
      expect(find.text('Longest Fast'), findsOneWidget);
    });

    testWidgets('Copy Text button copies formatted report to clipboard without crash', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: ShareableInfographicSheet(
              appState: appState,
              initialMode: InfographicMode.daily,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Text'));
      await tester.pumpAndSettle();

      expect(find.text('Formatted report copied to clipboard!'), findsOneWidget);
    });
  });
}
