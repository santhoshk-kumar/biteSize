import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zen_calorie/models/exercise_entry.dart';
import 'package:zen_calorie/models/gps_route.dart';
import 'package:zen_calorie/models/user_profile.dart';
import 'package:zen_calorie/screens/route_tracker_screen.dart';
import 'package:zen_calorie/services/database_service.dart';
import 'package:zen_calorie/services/gps_tracking_service.dart';
import 'package:zen_calorie/services/llm_service.dart';
import 'package:zen_calorie/services/notification_service.dart';
import 'package:zen_calorie/services/settings_repository.dart';
import 'package:zen_calorie/state/app_state.dart';
import 'package:zen_calorie/theme/zen_theme.dart';
import 'package:zen_calorie/widgets/route_breadcrumb_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Haversine Distance Formula Tests', () {
    test('Calculates zero distance between identical coordinates', () {
      final dist = GpsPoint.distanceBetween(37.7749, -122.4194, 37.7749, -122.4194);
      expect(dist, closeTo(0.0, 0.001));
    });

    test('Accurately calculates 1 degree of longitude along the equator (~111.195 km)', () {
      final dist = GpsPoint.distanceBetween(0.0, 0.0, 0.0, 1.0);
      const expected = GpsPoint.earthRadiusMeters * (math.pi / 180.0); // ~111,194.9 m
      expect(dist, closeTo(expected, 1.0));
      expect(dist / 1000.0, closeTo(111.2, 0.1));
    });

    test('Accurately calculates known short walking baseline (~145m in San Francisco)', () {
      final p1 = GpsPoint(
        latitude: 37.774929,
        longitude: -122.419416,
        accuracy: 4.0,
        timestamp: DateTime(2026, 11, 15, 10, 0, 0),
      );
      final p2 = GpsPoint(
        latitude: 37.775200,
        longitude: -122.417800,
        accuracy: 4.0,
        timestamp: DateTime(2026, 11, 15, 10, 2, 0),
      );

      final dist = p1.distanceTo(p2);
      expect(dist, inInclusiveRange(140.0, 155.0));
    });
  });

  group('3-Step Strict Anti-Drift Filter Tests', () {
    late GpsTrackingService tracker;

    setUp(() {
      tracker = GpsTrackingService();
    });

    tearDown(() {
      tracker.dispose();
    });

    test('Gate 1: Accuracy Gate rejects weak/indoor GPS pings (>20m)', () {
      tracker.activateForTesting();

      // Ping with poor accuracy (35m)
      final poorPing = GpsPoint(
        latitude: 37.774929,
        longitude: -122.419416,
        accuracy: 35.0,
        timestamp: DateTime.now(),
      );

      final accepted = tracker.processGpsPing(poorPing);
      expect(accepted, isFalse);
      expect(tracker.routePoints, isEmpty);
      expect(tracker.totalDistanceMeters, 0.0);

      // Ping with good accuracy (8.5m)
      final goodPing = GpsPoint(
        latitude: 37.774929,
        longitude: -122.419416,
        accuracy: 8.5,
        timestamp: DateTime.now(),
      );

      final goodAccepted = tracker.processGpsPing(goodPing);
      expect(goodAccepted, isTrue);
      expect(tracker.routePoints.length, 1);
    });

    test('Gate 2: Minimum Movement Threshold suppresses stationary jitter (<2.5m)', () {
      tracker.activateForTesting();

      final t0 = DateTime(2026, 11, 15, 8, 0, 0);
      final anchor = GpsPoint(
        latitude: 37.774929,
        longitude: -122.419416,
        accuracy: 4.0,
        timestamp: t0,
      );
      expect(tracker.processGpsPing(anchor), isTrue);

      // Jitter ping: slight drift of ~1.1 meters while sitting at desk
      final jitterPing = GpsPoint(
        latitude: 37.774939, // ~1.1m north
        longitude: -122.419416,
        accuracy: 4.0,
        timestamp: t0.add(const Duration(seconds: 3)),
      );
      final jitterDist = anchor.distanceTo(jitterPing);
      expect(jitterDist, lessThan(2.5));

      final jitterAccepted = tracker.processGpsPing(jitterPing);
      expect(jitterAccepted, isFalse, reason: 'Must suppress movement < 2.5m');
      expect(tracker.totalDistanceMeters, 0.0, reason: 'Distance should not accumulate on jitter');

      // Valid movement: 5.5 meters away
      final validPing = GpsPoint(
        latitude: 37.774979, // ~5.5m north
        longitude: -122.419416,
        accuracy: 4.0,
        timestamp: t0.add(const Duration(seconds: 6)),
      );
      final validDist = anchor.distanceTo(validPing);
      expect(validDist, greaterThan(2.5));

      final validAccepted = tracker.processGpsPing(validPing);
      expect(validAccepted, isTrue);
      expect(tracker.totalDistanceMeters, closeTo(validDist, 0.1));
      expect(tracker.routePoints.length, 2);
    });

    test('Gate 3: Teleportation Spike Filter rejects unphysical speed jumps', () {
      tracker.activateForTesting(type: TrackingActivityType.run);
      expect(tracker.activityType.maxSpeedMps, 12.0); // Run max speed = 12 m/s (~43.2 km/h)

      final t0 = DateTime(2026, 11, 15, 8, 0, 0);
      final anchor = GpsPoint(
        latitude: 37.774929,
        longitude: -122.419416,
        accuracy: 4.0,
        timestamp: t0,
      );
      tracker.processGpsPing(anchor);

      // Teleportation spike: 100 meters away in 2 seconds (50 m/s = 180 km/h)
      final spikePing = GpsPoint(
        latitude: 37.775830, // ~100m north
        longitude: -122.419416,
        accuracy: 5.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      final spikeDist = anchor.distanceTo(spikePing);
      expect(spikeDist / 2.0, greaterThan(12.0));

      final spikeAccepted = tracker.processGpsPing(spikePing);
      expect(spikeAccepted, isFalse, reason: 'Teleportation spike must be discarded');
      expect(tracker.routePoints.length, 1);
      expect(tracker.totalDistanceMeters, 0.0);

      // Plausible running stride: 7.0 meters in 2 seconds (3.5 m/s = 12.6 km/h)
      final plausiblePing = GpsPoint(
        latitude: 37.774992, // ~7m north
        longitude: -122.419416,
        accuracy: 4.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      final plausibleDist = anchor.distanceTo(plausiblePing);
      expect(plausibleDist / 2.0, lessThan(12.0));

      final plausibleAccepted = tracker.processGpsPing(plausiblePing);
      expect(plausibleAccepted, isTrue);
      expect(tracker.routePoints.length, 2);
      expect(tracker.totalDistanceMeters, closeTo(plausibleDist, 0.1));
    });
  });

  group('Session Kinetics & Energy Expenditure Tests', () {
    test('Calculates speed-adjusted MET and calorie burn correctly', () {
      final tracker = GpsTrackingService();
      tracker.setActivityType(TrackingActivityType.walk);

      // Walk at 1.4 m/s (5.0 km/h) -> MET 3.5
      expect(tracker.activityType.calculateMet(1.4), closeTo(3.5, 0.1));

      // Run at 2.9 m/s (10.4 km/h) -> MET 11.5
      expect(TrackingActivityType.run.calculateMet(2.9), closeTo(11.5, 0.1));

      // Cycle at 7.0 m/s (25 km/h) -> MET 10.0
      expect(TrackingActivityType.cycle.calculateMet(7.0), closeTo(10.0, 0.1));

      tracker.dispose();
    });

    test('Pace formatting handles zero, active, and boundary states', () {
      final tracker = GpsTrackingService();
      expect(tracker.formattedPace, '--:-- /km');

      tracker.dispose();
    });
  });

  group('Route Serialization & Persistence Tests', () {
    test('GpsPoint serialization and deserialization roundtrip', () {
      final points = [
        GpsPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 4.2,
          timestamp: DateTime(2026, 11, 15, 12, 0, 0),
          altitude: 45.0,
          speedMps: 1.4,
        ),
        GpsPoint(
          latitude: 37.7751,
          longitude: -122.4192,
          accuracy: 3.8,
          timestamp: DateTime(2026, 11, 15, 12, 0, 2),
          altitude: 46.0,
          speedMps: 1.5,
        ),
      ];

      final json = GpsPoint.listToJson(points);
      final restored = GpsPoint.listFromJson(json);

      expect(restored.length, 2);
      expect(restored[0].latitude, closeTo(37.7749, 0.0001));
      expect(restored[0].longitude, closeTo(-122.4194, 0.0001));
      expect(restored[0].accuracy, 4.2);
      expect(restored[0].altitude, 45.0);
      expect(restored[0].speedMps, 1.4);
      expect(restored[1].latitude, closeTo(37.7751, 0.0001));
    });

    test('ExerciseEntry with routePointsJson correctly exposes hasRoute and points', () {
      final points = [
        GpsPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 4.0,
          timestamp: DateTime(2026, 11, 15, 12, 0, 0),
        ),
        GpsPoint(
          latitude: 37.7755,
          longitude: -122.4188,
          accuracy: 4.0,
          timestamp: DateTime(2026, 11, 15, 12, 2, 0),
        ),
      ];
      final json = GpsPoint.listToJson(points);

      final entry = ExerciseEntry(
        id: 'gps_test_1',
        dateKey: '2026-11-15',
        loggedAt: DateTime(2026, 11, 15, 12, 0, 0),
        type: ExerciseType.walking,
        title: 'Lunch Walk',
        durationMinutes: 20,
        caloriesBurned: 85.0,
        distanceKm: 1.2,
        routePointsJson: json,
      );

      expect(entry.hasRoute, isTrue);
      expect(entry.routePoints.length, 2);

      // Verify DB mapping roundtrip
      final dbMap = entry.toDbMap();
      expect(dbMap['route_points_json'], json);

      final fromDb = ExerciseEntry.fromDbMap(dbMap);
      expect(fromDb.hasRoute, isTrue);
      expect(fromDb.routePoints.length, 2);
    });
  });

  group('UI & Widget Integration Tests', () {
    late AppState appState;
    late DatabaseService db;
    late SettingsRepository settingsRepo;
    late SecureKeyStore keyStore;
    late LlmService llmService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = DatabaseService();
      settingsRepo = SettingsRepository();
      keyStore = SecureKeyStore();
      llmService = LlmService(keyStore: keyStore);

      appState = AppState(
        database: db,
        settingsRepo: settingsRepo,
        keyStore: keyStore,
        llmService: llmService,
        notificationService: NotificationService(),
      );
      await appState.initialize();
      await appState.updateUserProfile(const UserProfile(weightKg: 70.0, heightCm: 175.0));
    });

    tearDown(() {
      appState.dispose();
    });

    testWidgets('RouteBreadcrumbWidget renders 2D vector path without errors', (tester) async {
      final points = [
        GpsPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 3.5,
          timestamp: DateTime(2026, 11, 15, 10, 0, 0),
        ),
        GpsPoint(
          latitude: 37.7758,
          longitude: -122.4180,
          accuracy: 3.5,
          timestamp: DateTime(2026, 11, 15, 10, 1, 0),
        ),
        GpsPoint(
          latitude: 37.7765,
          longitude: -122.4172,
          accuracy: 3.5,
          timestamp: DateTime(2026, 11, 15, 10, 2, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [ZenColors.dark],
          ),
          home: Scaffold(
            body: RouteBreadcrumbWidget(
              points: points,
              isLive: true,
              height: 200,
            ),
          ),
        ),
      );

      expect(find.byType(RouteBreadcrumbWidget), findsOneWidget);
      expect(find.text('3 GPS Points Recorded'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('RouteTrackerScreen displays HUD, metrics, and simulator toggle', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [ZenColors.dark],
          ),
          home: RouteTrackerScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // Verify HUD Elements
      expect(find.text('Headless Route Tracker'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('km'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('AVG PACE'), findsOneWidget);
      expect(find.text('CALORIES'), findsOneWidget);
      expect(find.text('Simulate'), findsOneWidget);

      // Start button is present
      expect(find.text('Start Walk'), findsOneWidget);

      // Toggle simulator
      final simSwitch = find.byType(Switch);
      expect(simSwitch, findsOneWidget);
      await tester.tap(simSwitch);
      await tester.pump();
      expect(appState.gpsTracker.isSimulated, isTrue);

      // Tap Start
      await tester.tap(find.text('Start Walk'));
      await tester.pump();
      expect(appState.gpsTracker.isTracking, isTrue);
      expect(find.text('Pause Tracking'), findsOneWidget);

      // Tap Pause
      await tester.tap(find.text('Pause Tracking'));
      await tester.pump();
      expect(appState.gpsTracker.isPaused, isTrue);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Finish & Save'), findsOneWidget);
    });
  });
}
