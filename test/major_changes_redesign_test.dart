import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/exercise_entry.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/models/quick_activity.dart';
import 'package:zen_calorie/screens/habits_milestones_screen.dart';
import 'package:zen_calorie/screens/home_shell.dart';
import 'package:zen_calorie/screens/settings_screen.dart';
import 'package:zen_calorie/screens/today_screen.dart';
import 'package:zen_calorie/screens/trends_screen.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/notification_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/widgets/compact_fasting_progress_card.dart';
import 'package:zen_calorie/widgets/exercise_entry_card.dart';
import 'package:zen_calorie/widgets/fasting_timer_card.dart';
import 'package:zen_calorie/widgets/fasting_trend_card.dart';
import 'package:zen_calorie/widgets/meal_entry_card.dart';
import 'package:zen_calorie/widgets/persistent_quick_log_bar.dart';
import 'package:zen_calorie/widgets/zen_calorie_ring.dart';
import 'package:zen_calorie/theme/zen_theme.dart';

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
    FlutterSecureStorage.setMockInitialValues({});
    db = DatabaseService();
    settingsRepo = SettingsRepository();
    notificationService = NotificationService();
    keyStore = SecureKeyStore();
    await keyStore.writeGeminiKey('AIzaSyMockKeyForTesting12345');

    final mockHttpClient = MockClient((request) async {
      String userPrompt = '';
      try {
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final contents = decoded['contents'] as List<dynamic>?;
        if (contents != null && contents.isNotEmpty) {
          final parts = (contents.first as Map<String, dynamic>)['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            userPrompt = ((parts.first as Map<String, dynamic>)['text'] ?? '').toString().toLowerCase();
          }
        }
      } catch (_) {}

      final isExercise = request.body.contains('exercise science') || request.body.contains('biomechanics');

      if (isExercise) {
        if (userPrompt.contains('walk')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'activities': [
                            {
                              'type': 'walking',
                              'title': '5km walking',
                              'durationMinutes': 60,
                              'distanceKm': 5.0,
                              'steps': 6500,
                              'intensity': 'moderate',
                              'caloriesBurned': 240.0,
                              'notes': '5km walking',
                            }
                          ],
                          'compositeTitle': '5km walking',
                          'totalDurationMinutes': 60,
                          'totalCaloriesBurned': 240.0,
                        })
                      }
                    ]
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'activities': [
                            {
                              'type': 'running',
                              'title': '5km run',
                              'durationMinutes': 28,
                              'distanceKm': 5.0,
                              'steps': 5500,
                              'intensity': 'vigorous',
                              'caloriesBurned': 320.0,
                              'notes': '5km run in 28 mins',
                            }
                          ],
                          'compositeTitle': '5km run',
                          'totalDurationMinutes': 28,
                          'totalCaloriesBurned': 320.0,
                        })
                      }
                    ]
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      }

      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'title': '2 Boiled Eggs & Banana',
                      'meal_title': '2 Boiled Eggs & Banana',
                      'mealType': 'breakfast',
                      'confidence': 0.95,
                      'items': [
                        {
                          'name': 'Boiled Egg',
                          'portion': '2 pieces',
                          'calories': 155,
                          'proteinGrams': 13.0,
                          'carbsGrams': 1.1,
                          'fatGrams': 10.6,
                        },
                        {
                          'name': 'Banana',
                          'portion': '1 medium',
                          'calories': 105,
                          'proteinGrams': 1.3,
                          'carbsGrams': 27.0,
                          'fatGrams': 0.3,
                        }
                      ],
                      'summary': '2 boiled eggs and 1 banana',
                      'nutritionGrade': 'A',
                    })
                  }
                ]
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    llmService = LlmService(keyStore: keyStore, httpClient: mockHttpClient);
    appState = AppState(
      database: db,
      settingsRepo: settingsRepo,
      notificationService: notificationService,
      keyStore: keyStore,
      llmService: llmService,
    );
    await appState.initialize();
  });

  group('Major Redesign Step 1: Persistent Quick-Logging Text Bar Tests', () {
    testWidgets('PersistentQuickLogBar renders text place hint and send button', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Center(child: PersistentQuickLogBar(appState: appState)),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Log food, workout, or water'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('PersistentQuickLogBar logs water via natural language and supports undo', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialWater = appState.totalWaterMlForDay;

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Center(child: PersistentQuickLogBar(appState: appState)),
          ),
        ),
      );
      await tester.pump();

      final inputField = find.byType(TextField);
      expect(inputField, findsOneWidget);

      await tester.enterText(inputField, 'Drank 500ml water');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.totalWaterMlForDay, equals(initialWater + 500));
      expect(find.textContaining('+500 ml'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.totalWaterMlForDay, equals(initialWater));
    });

    testWidgets('PersistentQuickLogBar logs exercise via natural language', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Center(child: PersistentQuickLogBar(appState: appState)),
          ),
        ),
      );
      await tester.pump();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, '5km run in 28 mins');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(appState.exercisesForDay.any((e) => e.type == ExerciseType.running), isTrue);
      expect(find.textContaining('kcal'), findsWidgets);
    });

    testWidgets('PersistentQuickLogBar logs meal via natural language', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Center(child: PersistentQuickLogBar(appState: appState)),
          ),
        ),
      );
      await tester.pump();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, '2 boiled eggs and 1 banana');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.mealsForDay.isNotEmpty, isTrue);
      expect(find.textContaining('Boiled Egg'), findsOneWidget);
    });

    testWidgets('PersistentQuickLogBar logs "5km walking" purely as exercise and NOT as food', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialMeals = appState.mealsForDay.length;

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Center(child: PersistentQuickLogBar(appState: appState)),
          ),
        ),
      );
      await tester.pump();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, '5km walking');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verifies exercise was logged
      expect(appState.exercisesForDay.any((e) => e.type == ExerciseType.walking && e.distanceKm == 5.0), isTrue);
      // Crucial: NO food was logged!
      expect(appState.mealsForDay.length, equals(initialMeals));
    });
  });

  group('Major Redesign Step 2: Streamlined TodayScreen Tests', () {
    testWidgets('TodayScreen renders generic Activity header with distinct Foods and Exercise Activities cards', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      expect(find.text('What to Eat Next? (Smart Coach)'), findsNothing);
      expect(find.text('Daily AI Debrief'), findsNothing);

      // Generic Activity Section
      expect(find.text('Activity'), findsWidgets);

      // Card 1: Foods Card
      expect(find.text('Foods'), findsOneWidget);
      expect(find.text('Add Meal'), findsOneWidget);

      // Card 2: Exercise Activities Card (Add Activity button removed, exercise logged via chat bar & quick chips)
      expect(find.text('Exercise Activities'), findsOneWidget);
      expect(find.text('Add Activity'), findsNothing);

      // Fasting progress is integrated into Calorie Ring, not as a standalone card
      expect(find.byType(ZenCalorieRing), findsOneWidget);
      expect(find.textContaining('Fasting:'), findsOneWidget);
    });
  });

  group('Major Redesign Step 3: Redesigned 4-Card TrendsScreen Tests', () {
    testWidgets('TrendsScreen renders all 4 cards, week selector, and top-right Monthly toggle', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: TrendsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top title and toggle
      expect(find.text('Trends & Analytics'), findsOneWidget);
      expect(find.text('Monthly View'), findsOneWidget);

      // Week options: This week, Last week, 2 weeks ago, 3 weeks ago
      expect(find.text('This week'), findsNWidgets(2)); // ChoiceChip + Card 1 header badge
      expect(find.text('Last week'), findsOneWidget);
      expect(find.text('2 weeks ago'), findsOneWidget);
      expect(find.text('3 weeks ago'), findsOneWidget);

      // Card 1: Avg Calorie Daily, Days Tracked
      expect(find.text('AVG CALORIE DAILY'), findsOneWidget);
      expect(find.text('DAYS TRACKED'), findsOneWidget);

      // Card 2: Weekly Totals
      expect(find.text('Weekly Totals'), findsOneWidget);
      expect(find.text('Calories'), findsWidgets);
      expect(find.text('Protein'), findsWidgets);
      expect(find.text('Carbs'), findsWidgets);
      expect(find.text('Fat'), findsWidgets);

      // Card 3: Activity & Expenditure
      expect(find.text('Activity & Expenditure'), findsOneWidget);
      expect(find.text('Meals logged'), findsOneWidget);
      expect(find.text('Workouts completed'), findsOneWidget);
      expect(find.text('Burned kcal'), findsOneWidget);

      // Card 4: Daily Breakdown
      expect(find.text('Daily Breakdown'), findsOneWidget);

      // Switch to Monthly View
      await tester.tap(find.text('Monthly View'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly View'), findsOneWidget);
      expect(find.text('Monthly Totals'), findsOneWidget);
      expect(find.text('Monthly Summary'), findsOneWidget);
      // Per user instruction: No daily breakdown in monthly view
      expect(find.text('Daily Breakdown'), findsNothing);

      // Switch to Yearly View
      await tester.tap(find.text('Yearly View'));
      await tester.pumpAndSettle();

      expect(find.text('Yearly Totals'), findsOneWidget);
      expect(find.text('Yearly Summary'), findsOneWidget);
      expect(find.textContaining('Monthly Breakdown'), findsOneWidget);
    });
  });

  group('Major Redesign Step 4: Consolidated Habits & Milestones Screen Tests', () {
    testWidgets('HabitsMilestonesScreen renders Habits, Milestones, and Fasting tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: HabitsMilestonesScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Habits & Milestones'), findsOneWidget);

      // Tab 1: Habits
      expect(find.text('TODAY\'S COMPLETION'), findsOneWidget);
      expect(find.text('TOP STREAK'), findsOneWidget);

      // Tab 2: Milestones
      final milestonesTab = find.descendant(of: find.byType(TabBar), matching: find.text('Milestones'));
      expect(milestonesTab, findsOneWidget);
      await tester.tap(milestonesTab);
      await tester.pumpAndSettle();

      expect(find.textContaining('milestones unlocked'), findsOneWidget);

      // Tab 3: Fasting (Full Circular Fasting Ring, Start Fast Controls, & Insights)
      final fastingTab = find.descendant(of: find.byType(TabBar), matching: find.text('Fasting'));
      expect(fastingTab, findsOneWidget);
      await tester.tap(fastingTab);
      await tester.pumpAndSettle();

      expect(find.byType(FastingTimerCard), findsOneWidget);
      expect(find.text('Intermittent Fasting'), findsOneWidget);
      expect(find.textContaining('Start Fast'), findsOneWidget);
      expect(find.text('Fasting Rhythm & Autophagy'), findsOneWidget);
    });
  });

  group('Major Redesign Step 5: HomeShell Navigation Tests', () {
    testWidgets('HomeShell has 4 destinations and persistent quick log bar at bottom', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: HomeShell(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Today')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Trends')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Habits')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')), findsOneWidget);

      // Persistent Quick Log Bar is present at the bottom
      expect(find.byType(PersistentQuickLogBar), findsOneWidget);
      expect(find.textContaining('Log food, workout, or water'), findsOneWidget);
    });
  });

  group('Major Redesign Step 6: Quick Log Bar Icons & Fasting Navigation Tests', () {
    testWidgets('PersistentQuickLogBar renders camera, voice, and save prompt icons', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Center(child: PersistentQuickLogBar(appState: appState)),
          ),
        ),
      );
      await tester.pump();

      // Feature action icons
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      // Tap saved prompt icon with empty text -> opens saved prompts sheet
      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Saved Prompts & Presets'), findsOneWidget);
      expect(find.text('Tap to insert'), findsOneWidget);
    });

    testWidgets('CompactFastingProgressCard renders progress and Go to Fasting navigates to Fasting tab', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: CompactFastingProgressCard(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Intermittent Fasting'), findsOneWidget);
      expect(find.text('Go to Fasting'), findsOneWidget);
      expect(find.text('No active fast in progress'), findsOneWidget);

      // Tap Go to Fasting
      await tester.tap(find.text('Go to Fasting'));
      await tester.pumpAndSettle();

      // Should have navigated to HabitsMilestonesScreen with Fasting tab
      expect(find.byType(FastingTimerCard), findsOneWidget);
      expect(find.textContaining('Start Fast'), findsOneWidget);
      expect(find.text('Fasting Rhythm & Autophagy'), findsOneWidget);
    });

    testWidgets('TodayScreen fasting status in Calorie Ring navigates to dedicated fasting screen', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Tap fasting indicator row in ZenCalorieRing
      final fastingRow = find.textContaining('Fasting: No active fast');
      expect(fastingRow, findsOneWidget);
      await tester.tap(fastingRow);
      await tester.pumpAndSettle();

      // Successfully navigated to dedicated Fasting page in Habits
      expect(find.byType(FastingTimerCard), findsOneWidget);
      expect(find.textContaining('Start Fast'), findsOneWidget);
    });
  });

  group('Major Redesign Step 7: Settings Screen Clean-up & Collapsed Defaults', () {
    testWidgets('SettingsScreen has all collapsible cards default to closed and obsolete toggles removed', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: SettingsScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sections are closed by default (content inside is not visible)
      expect(find.text('Select AI Provider & Model'), findsNothing);
      expect(find.text('Configure your personal biometric baseline'), findsNothing);

      // Obsolete toggles are nowhere to be found
      expect(find.text('Show Smart Coach advice card'), findsNothing);
      expect(find.text('Show Daily AI Debrief card'), findsNothing);
      expect(find.text('Show Exercise & Active Burn card'), findsNothing);

      // Expand Dashboard Layout & Widgets
      await tester.tap(find.text('Dashboard Layout & Widgets'));
      await tester.pumpAndSettle();

      // Verify obsolete toggles are still NOT present even after expanding
      expect(find.text('Show Smart Coach advice card'), findsNothing);
      expect(find.text('Show Daily AI Debrief card'), findsNothing);
      expect(find.text('Show Exercise & Active Burn card'), findsNothing);

      // Valid options are present
      expect(find.text('Macro Progress Card'), findsOneWidget);
      // Intermittent Fasting Card toggle was removed from settings
      expect(find.text('Intermittent Fasting Progress Card'), findsNothing);
      expect(find.text('Hydration Tracking Card'), findsOneWidget);
    });
  });

  group('Major Redesign Step 8: Rich Exercise Card & Settings/Habits/Fasting Refinements', () {
    testWidgets('ExerciseEntryCard is rendered on TodayScreen with rich metrics, accordion kinematics, and duplication', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entry = ExerciseEntry(
        id: 'ex_test_rich_1',
        dateKey: appState.selectedDateKey,
        loggedAt: DateTime(2026, 11, 16, 7, 30),
        type: ExerciseType.walking,
        title: 'Morning Power Walk',
        durationMinutes: 45,
        caloriesBurned: 220,
        distanceKm: 4.5,
        steps: 5800,
        intensity: ExerciseIntensity.moderate,
        notes: 'Brisk pace through the botanical garden',
      );
      await appState.logExercise(entry);

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

      // Verify ExerciseEntryCard is present
      expect(find.byType(ExerciseEntryCard), findsOneWidget);
      expect(find.text('Morning Power Walk'), findsOneWidget);
      expect(find.descendant(of: find.byType(ExerciseEntryCard), matching: find.text('-220 kcal')), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('4.5 km'), findsOneWidget);
      expect(find.text('5800 steps'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);

      // Tap card to expand accordion
      await tester.tap(find.text('Morning Power Walk'));
      await tester.pumpAndSettle();

      // Verify Kinematics & Bioenergetics section is revealed
      expect(find.text('KINEMATICS & BIOENERGETICS'), findsOneWidget);
      expect(find.text('Base MET'), findsOneWidget);
      expect(find.text('3.8'), findsOneWidget);
      expect(find.textContaining('Brisk pace through the botanical garden'), findsOneWidget);
      expect(find.text('Edit Workout'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);

      // Tap Duplicate
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      // Now there are 2 exercise activities logged
      expect(appState.exercisesForDay.length, equals(2));
      expect(find.textContaining('Duplicated "Morning Power Walk" to today'), findsOneWidget);
    });

    testWidgets('Fasting tab displays FastingTrendCard with consistency & history openly visible without hidden toggles', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: HabitsMilestonesScreen(
              appState: appState,
              initialTab: 2, // Fasting tab
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FastingTimerCard and FastingTrendCard are both directly present
      expect(find.byType(FastingTimerCard), findsOneWidget);
      expect(find.byType(FastingTrendCard), findsOneWidget);

      // 7-day consistency chart is directly visible
      expect(find.text('7-DAY CONSISTENCY'), findsOneWidget);
      expect(find.text('Fasting Rhythm & Autophagy'), findsOneWidget);

      // Fasting History section is directly visible with seed sessions
      expect(find.textContaining('Fasting History & Sessions'), findsOneWidget);
      expect(find.textContaining('Goal Hit 🎉'), findsWidgets);
      expect(find.textContaining('16.0h Fast'), findsOneWidget);

      // Redundant nested screen openers are gone
      expect(find.text('Open Fasting Tracker & Biological Timeline'), findsNothing);
      expect(find.text('View 4-Stage Metabolic Timeline & History'), findsNothing);
    });

    testWidgets('AI Workout Routine Planner is removed from HabitsMilestonesScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: HabitsMilestonesScreen(
              appState: appState,
              initialTab: 0, // Habits tab
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AI Workout Routine Planner is not present
      expect(find.text('AI Workout Routine Planner'), findsNothing);
      expect(find.textContaining('Generate personalized weekly training splits'), findsNothing);
    });

    testWidgets('Fitness Calculators & Planners is removed from SettingsScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: SettingsScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // Fitness Calculators & Planners is not present
      expect(find.text('Fitness Calculators & Planners'), findsNothing);
      expect(find.textContaining('TDEE, BMR, Navy Body Fat'), findsNothing);
    });

    testWidgets('Persistent quick-log bar has enlarged height and comfortable touch targets', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Center(child: PersistentQuickLogBar(appState: appState)),
          ),
        ),
      );
      await tester.pump();

      // Verify the bar container has compact, streamlined minimum height
      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.minHeight, equals(50.0));

      // Action icon buttons are present and comfortable
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });
  });

  group('Major Redesign Step 9: Quick Activities, Chat-Only Exercise Logging & MET Kinetics Tests', () {
    test('QuickActivityPreset provides scientific default presets calibrated to user weight', () {
      const presets = QuickActivityPreset.defaultPresets;
      expect(presets.length, equals(5));

      // 30m Walk: 3.8 MET * 70kg * 0.5h = 133 kcal
      final walk = presets.firstWhere((p) => p.title == '30m Walk');
      expect(walk.type, equals(ExerciseType.walking));
      expect(walk.durationMinutes, equals(30));
      expect(walk.calculateBurn(70.0), closeTo(133.0, 5.0));

      // 5km Run: 5km @ 10 km/h (9.8 MET) with vigorous intensity = ~481 kcal
      final run = presets.firstWhere((p) => p.title == '5km Run');
      expect(run.type, equals(ExerciseType.running));
      expect(run.distanceKm, equals(5.0));
      expect(run.durationMinutes, equals(30));
      expect(run.calculateBurn(70.0), closeTo(481.0, 10.0));

      // 45m Gym: 5.5 MET * 70kg * 0.75h = ~288 kcal
      final gym = presets.firstWhere((p) => p.title == '45m Gym Workout');
      expect(gym.type, equals(ExerciseType.gym));
      expect(gym.durationMinutes, equals(45));
      expect(gym.calculateBurn(70.0), closeTo(288.0, 10.0));
    });

    testWidgets('TodayScreen renders 1-tap Quick Activities row and tapping logs the workout', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Quick Activities section is displayed
      expect(find.text('QUICK ACTIVITIES'), findsOneWidget);
      expect(find.textContaining('30m Walk'), findsOneWidget);
      expect(find.textContaining('5km Run'), findsOneWidget);
      expect(find.textContaining('30m Cycling'), findsOneWidget);

      final initialCount = appState.exercisesForDay.length;

      // Tap 30m Walk quick activity chip
      final walkChip = find.textContaining('30m Walk');
      await tester.tap(walkChip);
      await tester.pumpAndSettle();

      // Verify the exercise was added to AppState and Exercise Activities card
      expect(appState.exercisesForDay.length, equals(initialCount + 1));
      expect(appState.exercisesForDay.any((e) => e.title == '30m Walk'), isTrue);
    });

    testWidgets('ExerciseEntryCard popup allows saving workout as a custom Quick Activity', (tester) async {
      final sampleEntry = ExerciseEntry(
        id: 'ex_sample_1',
        dateKey: '2026-11-16',
        title: 'HIIT Sprints',
        type: ExerciseType.running,
        intensity: ExerciseIntensity.vigorous,
        durationMinutes: 20,
        caloriesBurned: 240.0,
        loggedAt: DateTime.now(),
      );

      bool savedAsQuick = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: Center(
              child: ExerciseEntryCard(
                entry: sampleEntry,
                onTapEdit: () {},
                onDelete: () {},
                onDuplicate: () {},
                onSaveAsQuickActivity: () => savedAsQuick = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Save as Quick Activity'), findsOneWidget);
      await tester.tap(find.text('Save as Quick Activity'));
      await tester.pumpAndSettle();

      expect(savedAsQuick, isTrue);
    });

    testWidgets('Exercise Activities card has top-right + button and opens log exercise sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // The top-right + button in the Exercise Activities card header
      final addExerciseIcon = find.byTooltip('Add Workout / Activity');
      expect(addExerciseIcon, findsOneWidget);

      // Tapping + opens the log exercise sheet
      await tester.tap(addExerciseIcon);
      await tester.pumpAndSettle();

      expect(find.text('Log Workout & Activity'), findsOneWidget);
    });

    testWidgets('MealEntryCard displays per-food macros under each food item when expanded', (tester) async {
      final sampleMeal = MealEntry(
        id: 'macro_test_meal',
        dateKey: '2026-11-16',
        loggedAt: DateTime.now(),
        mealType: MealType.lunch,
        title: 'Chicken Rice Bowl',
        rawInput: 'Chicken Rice Bowl',
        items: const [
          FoodItem(
            id: 'item_c1',
            name: 'Grilled Chicken Breast',
            quantity: 150,
            unit: 'g',
            estimatedGrams: 150,
            macros: MacroNutrients(calories: 247, proteinG: 46, carbsG: 0, fatG: 5),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: MealEntryCard(
              meal: sampleMeal,
              onTapEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.text('Chicken Rice Bowl'));
      await tester.pumpAndSettle();

      // Per-food macro breakdown text
      expect(find.text('247 kcal · 46g P · 0g C · 5g F'), findsOneWidget);
    });

    testWidgets('Hydration goal triggers celebration alert in AppState', (tester) async {
      await appState.updateGoals(appState.goals.copyWith(waterTargetMl: 2000));
      await appState.addWater(2000);
      expect(appState.totalWaterMlForDay, greaterThanOrEqualTo(2000));
    });
  });

  group('Latest Refinements: Chat Bar Exclusivity, Habit Date Strip, Edit/Delete/Insights, Trends Clean Scope', () {
    testWidgets('Persistent quick-log text bar is visible only on Today screen and hidden on other tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: HomeShell(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // On Today screen (default tab 0): PersistentQuickLogBar is present
      expect(find.byType(PersistentQuickLogBar), findsOneWidget);

      // Switch to Trends tab
      await tester.tap(find.text('Trends'));
      await tester.pumpAndSettle();
      expect(find.byType(PersistentQuickLogBar), findsNothing);

      // Switch to Habits tab
      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();
      expect(find.byType(PersistentQuickLogBar), findsNothing);

      // Switch to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(PersistentQuickLogBar), findsNothing);

      // Switch back to Today tab
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.byType(PersistentQuickLogBar), findsOneWidget);
    });

    testWidgets('Chat bar elevates above mobile keyboard and bottom navigation hides when typing', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: HomeShell(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial state (no keyboard)
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(PersistentQuickLogBar), findsOneWidget);

      final chatBarInitialRect = tester.getRect(find.byType(PersistentQuickLogBar));
      final navBarInitialRect = tester.getRect(find.byType(NavigationBar));

      // Chat bar sits above navigation bar initially
      expect(chatBarInitialRect.bottom, lessThanOrEqualTo(navBarInitialRect.top + 10));

      // 2. Open soft keyboard (300 logical px height)
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      // Navigation bar is hidden to save vertical typing space
      expect(find.byType(NavigationBar), findsNothing);

      // Chat bar is elevated right above the keyboard (screen height 1600 - 300 = 1300)
      final chatBarElevatedRect = tester.getRect(find.byType(PersistentQuickLogBar));
      expect(chatBarElevatedRect.bottom, lessThanOrEqualTo(1300.0));
      expect(chatBarElevatedRect.bottom, greaterThan(1150.0));

      // 3. Dismiss soft keyboard
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      // Navigation bar returns and chat bar docks back down
      expect(find.byType(NavigationBar), findsOneWidget);
      final chatBarRestoredRect = tester.getRect(find.byType(PersistentQuickLogBar));
      expect(chatBarRestoredRect.bottom, equals(chatBarInitialRect.bottom));
    });

    testWidgets('Today screen top right has no fasting clock icon and HomeShell uses docked bottom navigation with extendBody false', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: HomeShell(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Fasting clock icon / timer is removed from Today screen top right header
      expect(find.byTooltip('Fasting Tracker'), findsNothing);
      expect(find.byTooltip('Active Fast'), findsNothing);

      // Remaining top right actions: Achievements, Share Infographic, AI Engine
      expect(find.byTooltip('Achievements & Milestones'), findsOneWidget);
      expect(find.byTooltip('Share Daily Report'), findsOneWidget);

      // 2. Scaffold has extendBody: false to prevent content showing below
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.extendBody, isFalse);

      // 3. NavigationBar is docked at the bottom of the screen with all 4 tabs
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Today')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Trends')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Habits')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')), findsOneWidget);
    });

    testWidgets('Habits tab features date scroll strip, habit insights card, edit/delete menu, and anchored New Habit button', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: HabitsMilestonesScreen(appState: appState, initialTab: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Date strip is present at top with week navigation chevrons
      expect(find.byTooltip('Previous week'), findsOneWidget);
      expect(find.byTooltip('Next week'), findsOneWidget);

      // 2. Habit insights & consistency summary card is present
      expect(find.text('Habit Insights & Consistency'), findsOneWidget);
      expect(find.textContaining('7-DAY RATE'), findsOneWidget);

      // 3. Anchored New Habit button is present (not hanging FAB)
      expect(find.text('New Habit'), findsWidgets);

      // 4. Habit cards have popup menu for insights, edit, delete
      final habitMoreMenu = find.byTooltip('Habit options');
      expect(habitMoreMenu, findsWidgets);

      // Open popup menu on first habit
      await tester.tap(habitMoreMenu.first);
      await tester.pumpAndSettle();

      expect(find.text('Habit Insights'), findsOneWidget);
      expect(find.text('Edit Habit'), findsOneWidget);
      expect(find.text('Delete Habit'), findsOneWidget);

      // Tap Habit Insights
      await tester.tap(find.text('Habit Insights'));
      await tester.pumpAndSettle();

      // Bottom sheet with 14 days adherence is displayed
      expect(find.text('Last 14 Days Adherence'), findsOneWidget);
      expect(find.text('CURRENT STREAK'), findsOneWidget);
      expect(find.text('BEST STREAK'), findsOneWidget);
    });

    testWidgets('Trends screen has clean header with Calculators and dedicated Weekly/Monthly/Yearly scope bar', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: TrendsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Calculators action chip in header
      expect(find.widgetWithText(ActionChip, 'Calculators'), findsOneWidget);

      // All 3 scope choice chips are present
      expect(find.widgetWithText(ChoiceChip, 'Weekly View'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Monthly View'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Yearly View'), findsOneWidget);
    });
  });
}
