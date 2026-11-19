import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zen_calorie/models/exercise_entry.dart';
import 'package:zen_calorie/models/nutrition.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/date_utils.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/exercise_entry_card.dart';
import 'package:zen_calorie/widgets/log_exercise_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late SettingsRepository settings;
  late SecureKeyStore keyStore;
  late LlmService llmService;
  late AppState appState;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    settings = SettingsRepository();
    keyStore = SecureKeyStore();
    await keyStore.writeGeminiKey('AIzaSyMockKeyForTesting12345');

    final mockHttpClient = MockClient((request) async {
      return http.Response(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'activities': [
                      {
                        'type': 'running',
                        'title': 'Outdoor Running',
                        'durationMinutes': 28,
                        'distanceKm': 5.0,
                        'steps': 5500,
                        'intensity': 'moderate',
                        'caloriesBurned': 350.0,
                        'notes': '5k Run'
                      }
                    ],
                    'compositeTitle': '5k Run',
                    'totalDurationMinutes': 28,
                    'totalDistanceKm': 5.0,
                    'totalCaloriesBurned': 350.0
                  })
                }
              ]
            }
          }
        ]
      }), 200);
    });

    llmService = LlmService(keyStore: keyStore, httpClient: mockHttpClient);
    appState = AppState(
      database: db,
      settingsRepo: settings,
      keyStore: keyStore,
      llmService: llmService,
    );
    await appState.initialize();
  });

  group('ExerciseCalculator & MET Kinetics Tests', () {
    test('Calculates walking energy expenditure and distance/step conversions', () {
      const weight = 70.0;
      // 30 min moderate walking (3.8 MET)
      final burn = ExerciseCalculator.calculateBurn(
        type: ExerciseType.walking,
        durationMinutes: 30,
        userWeightKg: weight,
        intensity: ExerciseIntensity.moderate,
      );
      // Expected = 3.8 * 70 * 0.5 = 133 kcal
      expect(burn, closeTo(133.0, 1.0));

      // Steps from 3.0 km
      final steps = ExerciseCalculator.stepsFromKm(3.0);
      expect(steps, equals(3945));

      // Km from steps
      final km = ExerciseCalculator.kmFromSteps(steps);
      expect(km, closeTo(3.0, 0.05));
    });

    test('Calculates running energy expenditure and pace accurately', () {
      const weight = 75.0;
      // 30 min 5.0 km run -> speed = 10.0 km/h -> MET 11.0
      final burn = ExerciseCalculator.calculateBurn(
        type: ExerciseType.running,
        durationMinutes: 30,
        userWeightKg: weight,
        distanceKm: 5.0,
      );
      // Expected: 11.0 * 75 * 0.5 = 412.5 kcal
      expect(burn, closeTo(412.5, 2.0));

      final pace = ExerciseCalculator.formatPace(30, 5.0);
      expect(pace, equals('6:00 /km'));
    });

    test('Calculates jump rope high MET metabolic burn', () {
      const weight = 65.0;
      // 15 min skipping (11.8 MET)
      final burn = ExerciseCalculator.calculateBurn(
        type: ExerciseType.jumpRope,
        durationMinutes: 15,
        userWeightKg: weight,
      );
      // Expected: 11.8 * 65 * 0.25 = 191.75 kcal
      expect(burn, closeTo(191.8, 1.0));
    });

    test('Calculates gym strength workout energy burn with intensity tiers', () {
      const weight = 80.0;
      // 45 min moderate strength (5.5 MET)
      final modBurn = ExerciseCalculator.calculateBurn(
        type: ExerciseType.gym,
        durationMinutes: 45,
        userWeightKg: weight,
        intensity: ExerciseIntensity.moderate,
      );
      // 5.5 * 80 * 0.75 = 330 kcal
      expect(modBurn, closeTo(330.0, 2.0));

      // 45 min vigorous compound/circuit (5.5 * 1.25 = 6.875 MET)
      final vigBurn = ExerciseCalculator.calculateBurn(
        type: ExerciseType.gym,
        durationMinutes: 45,
        userWeightKg: weight,
        intensity: ExerciseIntensity.vigorous,
      );
      expect(vigBurn, greaterThan(modBurn));
      expect(vigBurn, closeTo(412.5, 2.0));
    });

    test('parseNaturalLanguage accurately infers exercise type, duration, distance and gym split', () {
      // 1. Running 5k
      final runRes = ExerciseCalculator.parseNaturalLanguage('Ran 5km in 28 mins this morning');
      expect(runRes.type, equals(ExerciseType.running));
      expect(runRes.durationMinutes, equals(28));
      expect(runRes.distanceKm, equals(5.0));

      // 2. Walking with steps or km
      final walkRes = ExerciseCalculator.parseNaturalLanguage('Brisk 45 min walk around the lake 3.5 km');
      expect(walkRes.type, equals(ExerciseType.walking));
      expect(walkRes.durationMinutes, equals(45));
      expect(walkRes.distanceKm, equals(3.5));

      // 3. Gym split
      final gymRes = ExerciseCalculator.parseNaturalLanguage('Heavy push day chest and shoulders for 50 minutes');
      expect(gymRes.type, equals(ExerciseType.gym));
      expect(gymRes.durationMinutes, equals(50));
      expect(gymRes.gymCategory, equals('Push'));
      expect(gymRes.title, equals('Push Workout'));

      // 4. Jump rope
      final ropeRes = ExerciseCalculator.parseNaturalLanguage('15 min jump rope skipping intervals');
      expect(ropeRes.type, equals(ExerciseType.jumpRope));
      expect(ropeRes.durationMinutes, equals(15));
    });

    test('parseCompoundNaturalLanguage accurately splits compound multi-activity inputs and computes realistic MET burns', () {
      final compound = ExerciseCalculator.parseCompoundNaturalLanguage(
        '5km run and 20 min jump rope',
        userWeightKg: 70.0,
      );
      expect(compound.isCompound, isTrue);
      expect(compound.segments.length, equals(2));

      // Segment 1: Run
      final runSeg = compound.segments[0];
      expect(runSeg.type, equals(ExerciseType.running));
      expect(runSeg.distanceKm, equals(5.0));
      expect(runSeg.durationMinutes, equals(30));
      expect(runSeg.caloriesBurned, closeTo(385.0, 30.0));

      // Segment 2: Jump Rope
      final ropeSeg = compound.segments[1];
      expect(ropeSeg.type, equals(ExerciseType.jumpRope));
      expect(ropeSeg.distanceKm, isNull);
      expect(ropeSeg.durationMinutes, equals(20));
      expect(ropeSeg.caloriesBurned, closeTo(275.0, 30.0));

      // Total duration = 50 min, Total realistic burn = ~660 kcal (definitively NOT 1000 kcal)
      expect(compound.totalDurationMinutes, equals(50));
      expect(compound.totalCaloriesBurned, closeTo(660.0, 50.0));
      expect(compound.compositeTitle, contains('5.0km Run'));
      expect(compound.compositeTitle, contains('Jump Rope'));
    });
  });

  group('ExerciseEntry Model & Serialization Tests', () {
    test('ExerciseEntry maps to and from JSON and Database representations', () {
      final now = DateTime.now();
      final entry = ExerciseEntry(
        id: 'ex_123',
        dateKey: '2026-11-15',
        loggedAt: now,
        type: ExerciseType.running,
        title: 'Morning 5K',
        durationMinutes: 28,
        caloriesBurned: 350.0,
        distanceKm: 5.0,
        steps: 6500,
        intensity: ExerciseIntensity.vigorous,
        notes: 'Great weather',
      );

      final map = entry.toDbMap();
      expect(map['exercise_type'], equals('running'));
      expect(map['calories_burned'], equals(350.0));
      expect(map['distance_km'], equals(5.0));

      final restored = ExerciseEntry.fromDbMap(map);
      expect(restored.id, equals('ex_123'));
      expect(restored.type, equals(ExerciseType.running));
      expect(restored.title, equals('Morning 5K'));
      expect(restored.durationMinutes, equals(28));
      expect(restored.caloriesBurned, equals(350.0));
      expect(restored.distanceKm, equals(5.0));
      expect(restored.formattedPace, equals('5:36 /km'));
      expect(restored.speedKmh, closeTo(10.71, 0.1));
    });
  });

  group('DatabaseService & AppState Exercise Integration Tests', () {
    test('DatabaseService stores, retrieves, and deletes exercise entries', () async {
      final db = DatabaseService();
      final todayKey = ZenDateUtils.toDateKey(DateTime.now());

      final entry1 = ExerciseEntry(
        id: 'ex_test_1',
        dateKey: todayKey,
        loggedAt: DateTime.now(),
        type: ExerciseType.walking,
        title: 'Lunch Stroll',
        durationMinutes: 20,
        caloriesBurned: 90.0,
        distanceKm: 1.8,
      );

      final entry2 = ExerciseEntry(
        id: 'ex_test_2',
        dateKey: todayKey,
        loggedAt: DateTime.now(),
        type: ExerciseType.gym,
        title: 'Push Day',
        durationMinutes: 50,
        caloriesBurned: 310.0,
        gymCategory: 'Push',
      );

      await db.insertExercise(entry1);
      await db.insertExercise(entry2);

      final list = await db.getExercisesForDate(todayKey);
      expect(list.length, equals(2));

      await db.deleteExercise('ex_test_1');
      final updatedList = await db.getExercisesForDate(todayKey);
      expect(updatedList.length, equals(1));
      expect(updatedList.first.id, equals('ex_test_2'));
    });

    test('AppState logs exercise and correctly updates total burn and net calories', () async {
      // Log a meal (500 kcal)
      final meal = MealEntry(
        id: 'meal_test',
        dateKey: appState.selectedDateKey,
        loggedAt: DateTime.now(),
        mealType: MealType.lunch,
        title: 'Chicken Rice Bowl',
        rawInput: 'Chicken rice bowl',
        items: const [
          FoodItem(
            id: 'item_1',
            name: 'Chicken Rice',
            quantity: 1,
            unit: 'bowl',
            estimatedGrams: 350,
            macros: MacroNutrients(
              calories: 500,
              proteinG: 40,
              carbsG: 50,
              fatG: 12,
            ),
          ),
        ],
      );
      final initialCalories = appState.totalMacrosForDay.calories;
      final initialExerciseBurn = appState.totalExerciseCaloriesBurned;

      await appState.addMeal(meal);
      expect(appState.totalMacrosForDay.calories, equals(initialCalories + 500.0));

      // Before exercise: net calories = food - initial exercise burn
      expect(appState.netCaloriesForDay, equals(initialCalories + 500.0 - initialExerciseBurn));

      // Log an exercise (200 kcal burn)
      final workout = ExerciseEntry(
        id: 'ex_app_1',
        dateKey: appState.selectedDateKey,
        loggedAt: DateTime.now(),
        type: ExerciseType.running,
        title: 'Evening Run',
        durationMinutes: 20,
        caloriesBurned: 200.0,
        distanceKm: 2.5,
      );
      await appState.logExercise(workout);

      // Verify active burn and net deficit
      expect(appState.totalExerciseCaloriesBurned, equals(initialExerciseBurn + 200.0));
      expect(appState.totalExerciseDurationMinutes, greaterThanOrEqualTo(20));
      expect(appState.netCaloriesForDay, equals(initialCalories + 500.0 - (initialExerciseBurn + 200.0)));

      // Delete exercise
      await appState.deleteExercise('ex_app_1');
      expect(appState.totalExerciseCaloriesBurned, equals(initialExerciseBurn));
      expect(appState.netCaloriesForDay, equals(initialCalories + 500.0 - initialExerciseBurn));
    });
  });

  group('UI & Widget Tests', () {
    testWidgets('ExerciseEntryCard renders rich metrics and popup actions', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sampleEntry = ExerciseEntry(
        id: 'ex_test_card',
        dateKey: '2026-11-16',
        title: 'Morning 5km Run',
        type: ExerciseType.running,
        intensity: ExerciseIntensity.moderate,
        durationMinutes: 30,
        caloriesBurned: 350.0,
        distanceKm: 5.0,
        loggedAt: DateTime.now(),
      );

      bool editTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseEntryCard(
                entry: sampleEntry,
                onTapEdit: () => editTriggered = true,
                onDelete: () {},
                onDuplicate: () {},
                onSaveAsQuickActivity: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Morning 5km Run'), findsOneWidget);
      expect(find.text('-350 kcal'), findsOneWidget);
      expect(find.textContaining('30 min'), findsOneWidget);
      expect(find.textContaining('5.0 km'), findsOneWidget);

      // Open popup menu
      final popupBtn = find.byIcon(Icons.more_horiz_rounded);
      expect(popupBtn, findsOneWidget);
      await tester.tap(popupBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Exercise'), findsOneWidget);
      expect(find.text('Save as Quick Activity'), findsOneWidget);
      expect(find.text('Duplicate to Today'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Edit Exercise
      await tester.tap(find.text('Edit Exercise'));
      await tester.pumpAndSettle();
      expect(editTriggered, isTrue);
    });

    testWidgets('LogExerciseSheet renders form and allows saving a workout with AI Smart-Log', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showLogExerciseSheet(ctx, appState: appState),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Log Workout & Activity'), findsOneWidget);
      expect(find.text('Select Activity'), findsOneWidget);
      expect(find.textContaining('AI Smart-Log'), findsOneWidget);

      // Tap 5k Run AI quick pill
      final runPill = find.text('🏃 5k Run (28m)');
      await tester.ensureVisible(runPill);
      await tester.tap(runPill);
      await tester.pumpAndSettle();

      // Verify fields got auto-populated
      expect(find.text('28'), findsOneWidget); // Duration
      expect(find.text('5.0'), findsOneWidget); // Distance

      final saveBtn = find.textContaining('Save Workout');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      expect(saveBtn, findsOneWidget);

      // Tap Save Workout
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the exercise was saved into AppState
      expect(appState.exercisesForDay.isNotEmpty, isTrue);
      expect(appState.exercisesForDay.first.type, equals(ExerciseType.running));
      expect(appState.exercisesForDay.first.durationMinutes, equals(28));
    });
  });
}
