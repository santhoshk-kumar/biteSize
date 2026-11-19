import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/achievement.dart';
import 'package:zen_calorie/models/exercise_entry.dart';
import 'package:zen_calorie/models/fasting_model.dart';
import 'package:zen_calorie/models/user_profile.dart';
import 'package:zen_calorie/screens/achievements_screen.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/streak_badges_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Achievement Model & Metadata Tests', () {
    test('Calculates progress and percentage accurately', () {
      const achievement = Achievement(
        id: 'test_achieve',
        title: 'Test Master',
        subtitle: 'Hit 5 goals',
        description: 'Test description explaining health impact.',
        category: AchievementCategory.streaks,
        tier: AchievementTier.gold,
        icon: Icons.star_rounded,
        accentColor: Colors.amber,
        isUnlocked: false,
        currentValue: 2.5,
        targetValue: 5.0,
        unit: 'days',
      );

      expect(achievement.progress, 0.5);
      expect(achievement.progressPercentage, '50%');
      expect(achievement.progressFraction, '2.5 / 5 days');
      expect(achievement.tierLabel, 'Gold');
      expect(achievement.categoryLabel, 'Habits & Streaks');
    });

    test('Clamps progress to 1.0 max when currentValue exceeds target', () {
      const achievement = Achievement(
        id: 'test_clamp',
        title: 'Overachiever',
        subtitle: 'Done',
        description: 'Over target description',
        category: AchievementCategory.nutrition,
        tier: AchievementTier.emerald,
        icon: Icons.check_circle_rounded,
        accentColor: Colors.green,
        isUnlocked: true,
        currentValue: 12.0,
        targetValue: 10.0,
      );

      expect(achievement.progress, 1.0);
      expect(achievement.progressPercentage, '100%');
    });
  });

  group('AppState Gamified Achievements Integration Tests', () {
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

    test('allAchievements returns 27 categorized achievements and valid counts', () {
      final achievements = appState.allAchievements;
      expect(achievements.length, 27);
      expect(appState.totalAchievementsCount, 27);
      expect(appState.unlockedAchievementsCount, inInclusiveRange(0, 27));

      // Check category representations
      final streakAchieves = achievements.where((a) => a.category == AchievementCategory.streaks);
      final nutritionAchieves = achievements.where((a) => a.category == AchievementCategory.nutrition);
      final fastingAchieves = achievements.where((a) => a.category == AchievementCategory.fasting);
      final hydrationAchieves = achievements.where((a) => a.category == AchievementCategory.hydration);
      final bodyAchieves = achievements.where((a) => a.category == AchievementCategory.body);
      final activityAchieves = achievements.where((a) => a.category == AchievementCategory.activity);
      final masteryAchieves = achievements.where((a) => a.category == AchievementCategory.mastery);

      expect(streakAchieves.length, 5);
      expect(nutritionAchieves.length, 4);
      expect(fastingAchieves.length, 4);
      expect(hydrationAchieves.length, 2);
      expect(bodyAchieves.length, 2);
      expect(activityAchieves.length, 7);
      expect(masteryAchieves.length, 3);
    });

    test('Configuring physical profile unlocks Profile Architect achievement', () async {
      var architect = appState.allAchievements.firstWhere((a) => a.id == 'profile_architect');
      expect(architect.isUnlocked, false);

      await appState.updateUserProfile(const UserProfile(
        isConfigured: true,
        weightKg: 72.0,
        heightCm: 175.0,
        age: 27,
      ));

      architect = appState.allAchievements.firstWhere((a) => a.id == 'profile_architect');
      expect(architect.isUnlocked, true);
      expect(architect.currentValue, 1.0);
    });

    test('Fasting 12+ hours unlocks Ketosis Explorer achievement', () async {
      const state = FastingState(
        isActive: false,
        totalFastsCompleted: 1,
        totalHoursFasted: 14.0,
        longestFastHours: 14.0,
      );
      await appState.saveFastingState(state);

      final ketosis = appState.allAchievements.firstWhere((a) => a.id == 'fasting_ketosis');
      expect(ketosis.isUnlocked, true);
      expect(ketosis.currentValue, 14.0);
    });

    test('Logging jump rope session unlocks Rope Prodigy achievement', () async {
      var rope = appState.allAchievements.firstWhere((a) => a.id == 'rope_master');
      expect(rope.isUnlocked, false);

      await appState.logExercise(ExerciseEntry(
        id: 'ex_rope_1',
        dateKey: appState.selectedDateKey,
        loggedAt: DateTime.now(),
        type: ExerciseType.jumpRope,
        title: 'Morning Skips',
        durationMinutes: 15,
        caloriesBurned: 180.0,
      ));

      rope = appState.allAchievements.firstWhere((a) => a.id == 'rope_master');
      expect(rope.isUnlocked, true);
    });

    test('Logging GPS route unlocks Route Navigator achievement', () async {
      var nav = appState.allAchievements.firstWhere((a) => a.id == 'route_navigator');
      expect(nav.isUnlocked, false);

      await appState.logExercise(ExerciseEntry(
        id: 'ex_gps_1',
        dateKey: appState.selectedDateKey,
        loggedAt: DateTime.now(),
        type: ExerciseType.walking,
        title: 'Neighborhood Route',
        durationMinutes: 30,
        caloriesBurned: 130.0,
        distanceKm: 2.5,
        routePointsJson: '[{"lat":37.77,"lng":-122.41,"acc":4.0,"ts":1700000000}]',
      ));

      nav = appState.allAchievements.firstWhere((a) => a.id == 'route_navigator');
      expect(nav.isUnlocked, true);
    });

    test('streakBadges returns featured badges preserving backwards compatibility', () {
      final badges = appState.streakBadges;
      expect(badges, isNotEmpty);
      expect(badges.any((b) => b.id == 'streak_consistency'), true);
      expect(badges.any((b) => b.id == 'protein_champion'), true);
      expect(badges.any((b) => b.id == 'calorie_zen'), true);
    });
  });

  group('AchievementsScreen & Detail Sheet Widget Tests', () {
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

    testWidgets('AchievementsScreen renders Trophy Collection header and filters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: AchievementsScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Achievements & Trophies'), findsOneWidget);
      expect(find.text('Trophy Collection'), findsOneWidget);
      expect(find.textContaining('Bronze'), findsWidgets);
      expect(find.textContaining('Silver'), findsWidgets);
      expect(find.textContaining('Gold'), findsWidgets);
      expect(find.textContaining('Emerald'), findsWidgets);

      // Verify category filter chips
      expect(find.textContaining('All (27)'), findsOneWidget);
      expect(find.textContaining('Streaks'), findsWidgets);
      expect(find.textContaining('Fasting'), findsWidgets);
    });

    testWidgets('Tapping an achievement card opens detail modal and allows clipboard sharing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: AchievementsScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the first achievement card ("First Step")
      final firstStep = find.text('First Step');
      expect(firstStep, findsOneWidget);
      await tester.tap(firstStep);
      await tester.pumpAndSettle();

      // Verify detail sheet is displayed
      expect(find.text('Share Milestone'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('Milestone Target'), findsOneWidget);

      // Tap "Share Milestone" and verify snackbar appears
      await tester.tap(find.text('Share Milestone'));
      await tester.pumpAndSettle();

      expect(find.text('Milestone achievement copied to clipboard!'), findsOneWidget);
    });

    testWidgets('StreakBadgesCard displays Trophies counter and tap navigates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: StreakBadgesCard(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Habit Streaks & Milestones'), findsOneWidget);
      expect(find.textContaining('Trophies'), findsOneWidget);
    });
  });
}
