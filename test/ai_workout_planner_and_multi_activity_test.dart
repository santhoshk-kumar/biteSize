import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zen_calorie/models/exercise_entry.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/notification_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/log_exercise_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late SettingsRepository settingsRepo;
  late NotificationService notificationService;
  late SecureKeyStore keyStore;
  late LlmService llmService;
  late AppState appState;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    settingsRepo = SettingsRepository();
    notificationService = NotificationService();
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
                        'durationMinutes': 30,
                        'distanceKm': 5.0,
                        'steps': 5500,
                        'intensity': 'moderate',
                        'caloriesBurned': 385.0,
                        'notes': '5km run'
                      },
                      {
                        'type': 'jumpRope',
                        'title': 'Jump Rope Skipping',
                        'durationMinutes': 20,
                        'distanceKm': null,
                        'steps': null,
                        'intensity': 'moderate',
                        'caloriesBurned': 275.0,
                        'notes': '20 min jump rope'
                      }
                    ],
                    'compositeTitle': 'Run & Jump Rope Combo',
                    'totalDurationMinutes': 50,
                    'totalCaloriesBurned': 660.0
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
      settingsRepo: settingsRepo,
      notificationService: notificationService,
      keyStore: keyStore,
      llmService: llmService,
    );
    await appState.initialize();
  });

  group('Compound Multi-Activity Parsing & Kinematics', () {
    test('Correctly splits "5km run and 20 min jump rope" into separate activities without leaking distance or overestimating burn', () {
      final res = ExerciseCalculator.parseCompoundNaturalLanguage(
        '5km run and 20 min jump rope',
        userWeightKg: 70.0,
      );

      expect(res.isCompound, isTrue);
      expect(res.segments.length, equals(2));

      // Segment 1: Running
      final runSeg = res.segments[0];
      expect(runSeg.type, equals(ExerciseType.running));
      expect(runSeg.distanceKm, equals(5.0));
      expect(runSeg.durationMinutes, equals(30)); // 5km @ 6 min/km
      expect(runSeg.caloriesBurned, closeTo(385.0, 30.0));

      // Segment 2: Jump Rope
      final ropeSeg = res.segments[1];
      expect(ropeSeg.type, equals(ExerciseType.jumpRope));
      expect(ropeSeg.distanceKm, isNull); // Jump rope must NOT have 5km distance!
      expect(ropeSeg.durationMinutes, equals(20));
      expect(ropeSeg.caloriesBurned, closeTo(275.0, 30.0));

      // Combined results: ~660 kcal (NOT 1000 kcal)
      expect(res.totalDurationMinutes, equals(50));
      expect(res.totalCaloriesBurned, closeTo(660.0, 50.0));
      expect(res.totalCaloriesBurned, lessThan(800.0));
    });

    test('Splits "45 min gym push then 15 min walk" accurately', () {
      final res = ExerciseCalculator.parseCompoundNaturalLanguage(
        '45 min gym push then 15 min walk',
        userWeightKg: 75.0,
      );

      expect(res.isCompound, isTrue);
      expect(res.segments.length, equals(2));

      expect(res.segments[0].type, equals(ExerciseType.gym));
      expect(res.segments[0].gymCategory, equals('Push'));
      expect(res.segments[0].durationMinutes, equals(45));

      expect(res.segments[1].type, equals(ExerciseType.walking));
      expect(res.segments[1].durationMinutes, equals(15));
      expect(res.totalDurationMinutes, equals(60));
    });

    test('Does NOT falsely split single gym workouts like "chest and shoulders"', () {
      final res = ExerciseCalculator.parseCompoundNaturalLanguage(
        'Heavy push day chest and shoulders for 50 minutes',
        userWeightKg: 75.0,
      );

      expect(res.isCompound, isFalse);
      expect(res.segments.length, equals(1));
      expect(res.primarySegment.type, equals(ExerciseType.gym));
      expect(res.primarySegment.gymCategory, equals('Push'));
      expect(res.primarySegment.durationMinutes, equals(50));
    });
  });

  group('Multi-Activity & LogExerciseSheet Tests', () {
    testWidgets('LogExerciseSheet displays multi-activity breakdown for compound workout queries', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: LogExerciseSheet(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter compound prompt
      final aiField = find.byType(TextField).first;
      await tester.enterText(aiField, '5km run and 20 min jump rope');
      await tester.tap(find.text('Fill'));
      await tester.pumpAndSettle();

      // Multi-activity card should appear
      expect(find.text('MULTI-ACTIVITY WORKOUT DETECTED'), findsOneWidget);
      expect(find.text('2 Activities'), findsOneWidget);
      expect(find.textContaining('Log Both As Separate Entries'), findsOneWidget);

      // Tap Log Both As Separate Entries
      await tester.tap(find.textContaining('Log Both As Separate Entries'));
      await tester.pumpAndSettle();

      // AppState should now have both logged exercises!
      expect(appState.exercisesForDay.length, equals(2));
      expect(appState.exercisesForDay.any((e) => e.type == ExerciseType.running), isTrue);
      expect(appState.exercisesForDay.any((e) => e.type == ExerciseType.jumpRope), isTrue);
    });

    testWidgets('AI Workout Planner is removed from LogExerciseSheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: LogExerciseSheet(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Workout Planner'), findsNothing);
      expect(find.text('Plan ✨'), findsNothing);
      expect(find.text('Headless GPS Walker / Runner'), findsNothing);
    });
  });
}
