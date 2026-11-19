import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zen_calorie/models/habit.dart';
import 'package:zen_calorie/screens/habits_screen.dart';
import 'package:zen_calorie/screens/home_shell.dart';
import 'package:zen_calorie/screens/settings_screen.dart';
import 'package:zen_calorie/screens/trends_screen.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/notification_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/add_habit_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late SettingsRepository settingsRepo;
  late NotificationService notificationService;
  late SecureKeyStore keyStore;
  late LlmService llmService;
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    settingsRepo = SettingsRepository();
    notificationService = NotificationService();
    keyStore = SecureKeyStore();
    llmService = LlmService(keyStore: keyStore);
    appState = AppState(
      database: db,
      settingsRepo: settingsRepo,
      notificationService: notificationService,
      keyStore: keyStore,
      llmService: llmService,
    );
    await appState.initialize();
  });

  group('Habit & Challenge Unit Tests', () {
    test('HabitItem dateKey formats dates consistently', () {
      final date = DateTime(2026, 11, 15);
      expect(HabitItem.dateKey(date), '2026-11-15');
    });

    test('HabitItem calculates current and best streaks accurately', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d0 = HabitItem.dateKey(today);
      final d1 = HabitItem.dateKey(today.subtract(const Duration(days: 1)));
      final d2 = HabitItem.dateKey(today.subtract(const Duration(days: 2)));
      final d3 = HabitItem.dateKey(today.subtract(const Duration(days: 3)));

      // 4-day continuous streak
      final habit4d = HabitItem(
        id: 'test_1',
        title: 'Walk',
        completedDates: {d0, d1, d2, d3},
      );
      expect(habit4d.currentStreak, 4);
      expect(habit4d.bestStreak, 4);

      // Streak broken 2 days ago: only d1 completed, today not completed yet
      final habitActiveYesterday = HabitItem(
        id: 'test_2',
        title: 'Read',
        completedDates: {d1},
      );
      // If yesterday was completed, current streak is 1 (today is still pending)
      expect(habitActiveYesterday.currentStreak, 1);

      // No recent completions
      final habitOld = HabitItem(
        id: 'test_3',
        title: 'Stretch',
        completedDates: {
          HabitItem.dateKey(today.subtract(const Duration(days: 10))),
          HabitItem.dateKey(today.subtract(const Duration(days: 11))),
        },
      );
      expect(habitOld.currentStreak, 0);
      expect(habitOld.bestStreak, 2);
    });

    test('HabitItem and HabitChallenge serialize to and from JSON Map', () {
      final habit = HabitItem(
        id: 'h_101',
        title: 'Morning Yoga',
        description: 'Vinyasa flow',
        emoji: '🧘',
        category: HabitCategory.fitness,
        frequency: HabitFrequency.weekly,
        targetDaysPerWeek: 4,
        reminder: const HabitReminder(isEnabled: true, hour: 7, minute: 30),
        completedDates: {'2026-11-14', '2026-11-15'},
      );

      final map = habit.toMap();
      final restored = HabitItem.fromMap(map);

      expect(restored.id, 'h_101');
      expect(restored.title, 'Morning Yoga');
      expect(restored.emoji, '🧘');
      expect(restored.category, HabitCategory.fitness);
      expect(restored.frequency, HabitFrequency.weekly);
      expect(restored.targetDaysPerWeek, 4);
      expect(restored.reminder?.isEnabled, true);
      expect(restored.reminder?.hour, 7);
      expect(restored.reminder?.minute, 30);
      expect(restored.reminder?.timeFormatted, '7:30 AM');
      expect(restored.completedDates.length, 2);

      final challenge = HabitChallenge(
        id: 'c_sugar',
        title: '7-Day Zero Added Sugar',
        description: 'Cut refined sugar',
        badgeEmoji: '🥗',
        durationDays: 7,
        category: HabitCategory.nutrition,
        isJoined: true,
        completedDates: {'2026-11-14', '2026-11-15'},
      );
      final cMap = challenge.toMap();
      final cRestored = HabitChallenge.fromMap(cMap);

      expect(cRestored.id, 'c_sugar');
      expect(cRestored.daysCompleted, 2);
      expect(cRestored.progress, closeTo(2 / 7, 0.01));
      expect(cRestored.isCompleted, false);
    });
  });

  group('AppState Habit Management Integration Tests', () {
    test('AppState initializes default habits and challenges', () {
      expect(appState.habits.isNotEmpty, true);
      expect(appState.habits.any((h) => h.id == 'habit_water_default'), true);
      expect(appState.habits.any((h) => h.id == 'habit_walk_default'), true);

      expect(appState.challenges.isNotEmpty, true);
      expect(appState.challenges.any((c) => c.id == 'challenge_sugar_free'), true);
    });

    test('AppState adds, toggles, updates, and deletes habits', () async {
      final newHabit = HabitItem(
        id: 'custom_creatine',
        title: 'Take Creatine Monohydrate',
        emoji: '💊',
        category: HabitCategory.health,
        frequency: HabitFrequency.daily,
      );

      await appState.addHabit(newHabit);
      expect(appState.habits.any((h) => h.id == 'custom_creatine'), true);

      // Toggle completion for today
      final today = DateTime.now();
      await appState.toggleHabitCompletion('custom_creatine', today);
      final habitAfterToggle = appState.habits.firstWhere((h) => h.id == 'custom_creatine');
      expect(habitAfterToggle.isCompletedOn(today), true);

      // Untoggle completion
      await appState.toggleHabitCompletion('custom_creatine', today);
      final habitAfterUntoggle = appState.habits.firstWhere((h) => h.id == 'custom_creatine');
      expect(habitAfterUntoggle.isCompletedOn(today), false);

      // Update habit
      final updatedHabit = newHabit.copyWith(title: 'Take 5g Creatine Monohydrate');
      await appState.updateHabit(updatedHabit);
      expect(
        appState.habits.firstWhere((h) => h.id == 'custom_creatine').title,
        'Take 5g Creatine Monohydrate',
      );

      // Delete habit
      await appState.deleteHabit('custom_creatine');
      expect(appState.habits.any((h) => h.id == 'custom_creatine'), false);
    });

    test('AppState joins, tracks, and leaves challenges', () async {
      const challengeId = 'challenge_sugar_free';

      // Join
      await appState.joinChallenge(challengeId);
      var challenge = appState.challenges.firstWhere((c) => c.id == challengeId);
      expect(challenge.isJoined, true);
      expect(challenge.startDate, isNotNull);

      // Check-in day
      final today = DateTime.now();
      await appState.toggleChallengeDay(challengeId, today);
      challenge = appState.challenges.firstWhere((c) => c.id == challengeId);
      expect(challenge.isCompletedOn(today), true);
      expect(challenge.daysCompleted, 1);

      // Leave
      await appState.leaveChallenge(challengeId);
      challenge = appState.challenges.firstWhere((c) => c.id == challengeId);
      expect(challenge.isJoined, false);
      expect(challenge.daysCompleted, 0);
    });
  });

  group('HabitsScreen & HomeShell Widget Integration Tests', () {
    testWidgets('HomeShell includes Habits tab as Destination 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: HomeShell(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // Destination tabs in bottom bar: Today, Trends, Habits, Settings
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Today')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Trends')), findsOneWidget);
      final habitsTab = find.descendant(of: find.byType(NavigationBar), matching: find.text('Habits'));
      expect(habitsTab, findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')), findsOneWidget);

      // Tap on Habits tab
      await tester.tap(habitsTab);
      await tester.pumpAndSettle();

      // Verify HabitsMilestonesScreen is loaded
      expect(find.text('TODAY\'S COMPLETION'), findsOneWidget);
      expect(find.text('TOP STREAK'), findsOneWidget);
    });

    testWidgets('HabitsScreen switches between My Habits and Challenges tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(body: HabitsScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Default tab: My Habits
      expect(find.textContaining('My Habits'), findsOneWidget);
      expect(find.text('Drink 2.5L Clean Water'), findsOneWidget);

      // Switch to Challenges tab
      await tester.tap(find.textContaining('Challenges'));
      await tester.pumpAndSettle();

      expect(find.text('7-Day Zero Added Sugar'), findsOneWidget);
      expect(find.text('14-Day 10k Steps Odyssey'), findsOneWidget);
      expect(find.textContaining('Join Challenge'), findsWidgets);
    });

    testWidgets('SettingsScreen has Calculators & Planning card removed', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(body: SettingsScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure Calculators card was removed from Settings
      expect(find.text('Fitness Calculators & Planners'), findsNothing);
    });

    testWidgets('TrendsScreen displays Calculators ActionChip that pushes CalculatorsScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(body: TrendsScreen(appState: appState)),
        ),
      );
      await tester.pumpAndSettle();

      // ActionChip 'Calculators' at top of Trends
      final calcChip = find.widgetWithText(ActionChip, 'Calculators');
      expect(calcChip, findsOneWidget);

      await tester.tap(calcChip);
      await tester.pumpAndSettle();

      expect(find.text('Health Hub & Calculators'), findsOneWidget);
    });

    testWidgets('showAddHabitSheet allows adding a new habit with quick preset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showAddHabitSheet(ctx, appState: appState),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Habit'), findsOneWidget);
      expect(find.text('QUICK PRESETS'), findsOneWidget);

      // Tap quick preset 'No Added Sugar'
      await tester.tap(find.text('No Added Sugar'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Start Tracking Habit 🔥'));
      await tester.pumpAndSettle();

      // Habit added to state
      expect(appState.habits.any((h) => h.title == 'No Added Sugar'), true);
    });
  });
}
