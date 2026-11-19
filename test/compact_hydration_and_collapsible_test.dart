import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/compact_hydration_card.dart';
import 'package:zen_calorie/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late SettingsRepository settings;
  late SecureKeyStore keyStore;
  late LlmService llmService;
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    settings = SettingsRepository();
    keyStore = SecureKeyStore();
    llmService = LlmService(keyStore: keyStore);
    appState = AppState(
      database: db,
      settingsRepo: settings,
      keyStore: keyStore,
      llmService: llmService,
    );
    await appState.initialize();
  });

  group('CompactHydrationCard Widget Tests', () {
    testWidgets('CompactHydrationCard renders slim height, current intake, goal and quick buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: CompactHydrationCard(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sample data seeds 1,000 ml
      expect(find.textContaining('1,000 / 2,500 ml'), findsOneWidget);
      expect(find.text('+250'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);

      // Tap +250ml
      await tester.tap(find.text('+250'));
      await tester.pumpAndSettle();

      expect(appState.totalWaterMlForDay, equals(1250));
      expect(find.textContaining('1,250 / 2,500 ml'), findsOneWidget);

      // Tap +500ml
      await tester.tap(find.text('+500'));
      await tester.pumpAndSettle();

      expect(appState.totalWaterMlForDay, equals(1750));
      expect(find.textContaining('1,750 / 2,500 ml'), findsOneWidget);

      // Undo button should appear after logging
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();

      expect(appState.totalWaterMlForDay, equals(1250));
    });
  });

  group('SettingsScreen Collapsible Sections Tests', () {
    testWidgets('SettingsScreen sections toggle open and closed without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: SettingsScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // Profile is collapsed by default
      expect(find.textContaining('Your biological sex, age, height, and weight are saved here'), findsNothing);

      // Tap header to expand
      final profileHeader = find.text('Personal Profile');
      await tester.ensureVisible(profileHeader);
      await tester.tap(profileHeader);
      await tester.pumpAndSettle();

      // Explanatory text should now be visible
      expect(find.textContaining('Your biological sex, age, height, and weight are saved here'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(profileHeader);
      await tester.pumpAndSettle();

      expect(find.textContaining('Your biological sex, age, height, and weight are saved here'), findsNothing);
    });
  });
}
