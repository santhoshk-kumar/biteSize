import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_calorie/models/calorie_bank.dart';
import 'package:zen_calorie/models/fasting_model.dart';
import 'package:zen_calorie/models/habit_streak.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/fasting_timer_card.dart';
import 'package:zen_calorie/widgets/streak_badges_card.dart';

class FakeAdvancedAppState extends ChangeNotifier implements AppState {
  FastingState _fasting = const FastingState();

  @override
  FastingState get fasting => _fasting;

  @override
  Future<void> updateFastingProtocol(FastingProtocol protocol) async {
    _fasting = _fasting.copyWith(protocol: protocol);
    notifyListeners();
  }

  @override
  Future<void> startFast({FastingProtocol? protocol, DateTime? customStartTime}) async {
    _fasting = FastingState(
      isActive: true,
      startTime: customStartTime ?? DateTime.now(),
      protocol: protocol ?? _fasting.protocol,
    );
    notifyListeners();
  }

  @override
  Future<void> endFast() async {
    _fasting = _fasting.copyWith(isActive: false);
    notifyListeners();
  }

  @override
  List<HabitBadge> get streakBadges => [
        const HabitBadge(
          id: 'streak_consistency',
          title: 'Daily Logger',
          subtitle: '3-day streak',
          icon: Icons.local_fire_department_rounded,
          accentColor: Color(0xFF10B981),
          isUnlocked: true,
        ),
        const HabitBadge(
          id: 'protein_champion',
          title: 'Protein Champion',
          subtitle: '5/7 days',
          icon: Icons.fitness_center_rounded,
          accentColor: Color(0xFF60A5FA),
          isUnlocked: true,
        ),
      ];

  @override
  int get unlockedAchievementsCount => 2;

  @override
  int get totalAchievementsCount => 20;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Intermittent Fasting Model Tests', () {
    test('FastingStage accurately maps metabolic stages from elapsed hours', () {
      expect(FastingStage.forHours(2.0).name, 'Digestion & Anabolic');
      expect(FastingStage.forHours(8.0).name, 'Glycogen Depletion');
      expect(FastingStage.forHours(14.0).name, 'Fat Burning & Ketosis');
      expect(FastingStage.forHours(20.0).name, 'Autophagy & Deep Repair');
    });

    test('FastingProtocol labels and hours are correct', () {
      expect(FastingProtocol.sixteenEight.fastHours, 16);
      expect(FastingProtocol.sixteenEight.eatHours, 8);
      expect(FastingProtocol.fourteenTen.fastHours, 14);
      expect(FastingProtocol.eighteenSix.fastHours, 18);
      expect(FastingProtocol.twentyFour.fastHours, 20);
      expect(FastingProtocol.circadian.fastHours, 13);
    });

    test('FastingState progress, remaining, and serialization', () {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 12));
      final state = FastingState(
        isActive: true,
        startTime: startTime,
        protocol: FastingProtocol.sixteenEight,
      );

      expect(state.elapsedHours, closeTo(12.0, 0.1));
      expect(state.progress, closeTo(0.75, 0.05));
      expect(state.targetReached, false);
      expect(state.remaining.inMinutes, closeTo(240, 10));

      final map = state.toMap();
      final restored = FastingState.fromMap(map);
      expect(restored.isActive, true);
      expect(restored.protocol, FastingProtocol.sixteenEight);
      expect(restored.startTime?.millisecondsSinceEpoch,
          state.startTime?.millisecondsSinceEpoch);
    });
  });

  group('Weekend Calorie Banking Math Tests', () {
    test('Calculates exact weekday deficit and weekend bonus preserving weekly balance', () {
      const bank = CalorieBankSettings(
        enabled: true,
        bankDailyKcal: 150,
      );

      expect(bank.totalBankedKcal, 750);
      expect(bank.weekendBonusPerDay, 375);

      const baseTarget = 2000;
      final monday = DateTime(2026, 11, 16);
      final saturday = DateTime(2026, 11, 21);
      final sunday = DateTime(2026, 11, 22);

      final mondayTarget = bank.adjustedTarget(baseTarget: baseTarget, date: monday);
      final satTarget = bank.adjustedTarget(baseTarget: baseTarget, date: saturday);
      final sunTarget = bank.adjustedTarget(baseTarget: baseTarget, date: sunday);

      expect(mondayTarget, 1850);
      expect(satTarget, 2375);
      expect(sunTarget, 2375);

      // Verify weekly total equals exactly baseTarget * 7
      final totalWeeklyIntake = (mondayTarget * 5) + satTarget + sunTarget;
      expect(totalWeeklyIntake, baseTarget * 7);
    });

    test('CalorieBankSettings serialization toMap and fromMap', () {
      const bank = CalorieBankSettings(enabled: true, bankDailyKcal: 200);
      final map = bank.toMap();
      final restored = CalorieBankSettings.fromMap(map);
      expect(restored.enabled, true);
      expect(restored.bankDailyKcal, 200);
      expect(restored.totalBankedKcal, 1000);
      expect(restored.weekendBonusPerDay, 500);
    });
  });

  group('Widget Tests for Advanced Features', () {
    testWidgets('FastingTimerCard renders protocol options and start button', (tester) async {
      final fakeState = FakeAdvancedAppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: FastingTimerCard(appState: fakeState),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Intermittent Fasting'), findsOneWidget);
      expect(find.text('Start Fast (16:8)'), findsOneWidget);
    });

    testWidgets('FastingTimerCard active fast displays reached metabolic state and next countdown in circle', (tester) async {
      final fakeState = FakeAdvancedAppState();
      // Start fast 6 hours ago (Glycogen Depletion stage)
      final sixHoursAgo = DateTime.now().subtract(const Duration(hours: 6));
      await fakeState.startFast(protocol: FastingProtocol.sixteenEight, customStartTime: sixHoursAgo);

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: FastingTimerCard(appState: fakeState),
          ),
        ),
      );

      await tester.pump();

      // Check reached metabolic state inside circle
      expect(find.text('Reached: Glycogen Depletion'), findsOneWidget);
      // Check next state indicator inside circle
      expect(find.textContaining('Next: Fat Burning & Ketosis'), findsOneWidget);
    });

    testWidgets('StreakBadgesCard renders all milestone badges', (tester) async {
      final fakeState = FakeAdvancedAppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: ZenTheme.dark(),
          home: Scaffold(
            body: StreakBadgesCard(appState: fakeState),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Habit Streaks & Milestones'), findsOneWidget);
      expect(find.text('Daily Logger'), findsOneWidget);
      expect(find.text('Protein Champion'), findsOneWidget);
    });
  });
}
