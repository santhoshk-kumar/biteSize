import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/fasting_model.dart';
import '../models/notification_settings.dart';

/// Central service managing Android & iOS system local push notifications,
/// scheduled meal reminders, hydration nudges, and fasting metabolic alarms.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Notifier triggered when the user taps on a notification payload.
  final ValueNotifier<String?> notificationPayload = ValueNotifier<String?>(null);

  // Notification Channel IDs
  static const String channelMeals = 'bitesize_meals';
  static const String channelFasting = 'bitesize_fasting';
  static const String channelFastingLive = 'bitesize_fasting_live';
  static const String channelHydration = 'bitesize_hydration';
  static const String channelHabits = 'bitesize_habits';
  static const String channelActivity = 'bitesize_activity';

  // Fixed Notification IDs
  static const int idBreakfast = 101;
  static const int idLunch = 102;
  static const int idDinner = 103;
  static const int idDebrief = 104;
  static const int idStreakProtector = 105;
  static const int idActivityReminder = 106;
  static const int idOngoingFasting = 200;
  static const int idFastingKetosis = 201;
  static const int idFastingAutophagy = 202;
  static const int idFastingTargetReached = 203;
  static const int idFastingGlycogen = 204;
  static const int idFastingHalfway = 205;
  static const int idFastingWindowClosing = 206;
  static const int idWorkoutCelebration = 210;
  static const int idHydrationBase = 300;
  static const int idHydrationGoal = 320;

  /// Initializes the local notification plugin and sets up timezone & channels.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _ensureTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('NotificationService: User tapped notification payload: ${response.payload}');
          if (response.payload != null) {
            notificationPayload.value = response.payload;
          }
        },
      );

      _isInitialized = true;

      // Register system notification channels on Android (API 26+)
      await _createNotificationChannels();

      await requestPermissions();
    } catch (e) {
      debugPrint('NotificationService: Platform native notifications unavailable ($e)');
    }
  }

  /// Creates and registers all app notification channels explicitly on Android.
  Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl == null) return;

        // 1. Meal Reminders Channel
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelMeals,
            'Meal Reminders',
            description: 'Daily breakfast, lunch, and dinner meal logging reminders',
            importance: Importance.high,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // 2. Intermittent Fasting Alerts Channel
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelFasting,
            'Intermittent Fasting',
            description: 'Goal reached alerts, metabolic milestones, and window closing alerts',
            importance: Importance.high,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // 3. Persistent Fasting Live Status Bar Channel (Silent, Ongoing)
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelFastingLive,
            'Live Fasting Status',
            description: 'Persistent status bar timer and metabolic stage during active fasts',
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
            showBadge: false,
          ),
        );

        // 4. Hydration Reminders Channel
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelHydration,
            'Hydration Reminders',
            description: 'Periodic water intake reminders throughout the day',
            importance: Importance.defaultImportance,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // 5. Habits & Coaching Channel
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelHabits,
            'Habits & Coaching',
            description: 'Daily habit streaks, evening debriefs, and coach alerts',
            importance: Importance.high,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // 6. Activity & Movement Channel
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelActivity,
            'Activity & Movement',
            description: 'Movement reminders and workout celebration alerts',
            importance: Importance.high,
            enableVibration: true,
            showBadge: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationService._createNotificationChannels failed ($e)');
    }
  }

  /// Requests runtime notification permission on Android 13+ (API 33+) and iOS.
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidImplementation = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        final notifGranted = await androidImplementation?.requestNotificationsPermission() ?? false;
        try {
          await androidImplementation?.requestExactAlarmsPermission();
        } catch (_) {}
        return notifGranted;
      } else if (Platform.isIOS) {
        final iosImplementation = _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await iosImplementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('NotificationService: Permission request skipped ($e)');
    }
    return false;
  }

  /// Shows an instant notification alert immediately.
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String channelId = channelMeals,
    String channelName = 'Reminders',
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService.showImmediateNotification failed ($e)');
    }
  }

  /// Displays an immediate celebration alert when a physical activity or GPS route is completed.
  Future<void> showWorkoutCompletedAlert({
    required String title,
    required int caloriesBurned,
    required int durationMinutes,
    double? distanceKm,
  }) async {
    final distStr = distanceKm != null && distanceKm > 0
        ? ' • ${distanceKm.toStringAsFixed(2)} km'
        : '';
    await showImmediateNotification(
      id: idWorkoutCelebration,
      title: '🔥 Workout Logged: $title',
      body: 'Crushed -$caloriesBurned kcal in $durationMinutes min$distStr! Great job keeping your metabolic rhythm active.',
      channelId: channelActivity,
      channelName: 'Activity & Movement',
    );
  }

  /// Displays an immediate celebration alert when the user meets their daily hydration target.
  Future<void> showHydrationGoalReachedAlert({
    required int targetMl,
  }) async {
    await showImmediateNotification(
      id: idHydrationGoal,
      title: 'Hydration Goal Reached! 🌊🎉',
      body: 'You crushed your daily target of ${targetMl}ml! Outstanding job keeping your body hydrated today.',
      channelId: channelHydration,
      channelName: 'Hydration Reminders',
    );
  }

  /// Schedules a repeating daily notification at the specified hour and minute.
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String channelId = channelMeals,
    String channelName = 'Meal Reminders',
    String? payload,
  }) async {
    try {
      final scheduledDate = _nextInstanceOfTime(hour, minute);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails();
      final details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } catch (exactErr) {
        debugPrint(
            'NotificationService.scheduleDailyReminder exact failed for id=$id, falling back to inexact: $exactErr');
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.scheduleDailyReminder failed for id=$id ($e)');
    }
  }

  /// Schedules a one-time notification for a future timestamp (e.g. fasting target).
  Future<void> scheduleOneTimeAlert({
    required int id,
    required String title,
    required String body,
    required DateTime targetTime,
    String channelId = channelFasting,
    String channelName = 'Intermittent Fasting',
    String? payload,
  }) async {
    try {
      if (targetTime.isBefore(DateTime.now())) return;

      final tzTarget = tz.TZDateTime.from(targetTime, tz.local);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails();
      final details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzTarget,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (exactErr) {
        debugPrint(
            'NotificationService.scheduleOneTimeAlert exact failed for id=$id, falling back to inexact: $exactErr');
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzTarget,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.scheduleOneTimeAlert failed for id=$id ($e)');
    }
  }

  /// Calculates a stable notification ID for custom habits.
  static int habitNotificationId(String habitId) {
    return 10000 + (habitId.hashCode.abs() % 89999);
  }

  /// Schedules a daily local push notification for a specific habit.
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String title,
    required int hour,
    required int minute,
    String? body,
  }) async {
    final notifId = habitNotificationId(habitId);
    await scheduleDailyReminder(
      id: notifId,
      title: 'Habit Reminder: $title',
      body: body ?? 'Time to complete your habit and keep your consistency streak going! 🔥',
      hour: hour,
      minute: minute,
      channelId: channelHabits,
      channelName: 'Habits & Coaching',
    );
  }

  /// Cancels any scheduled reminder for the given habit.
  Future<void> cancelHabitReminder(String habitId) async {
    final notifId = habitNotificationId(habitId);
    await cancel(notifId);
  }

  /// Displays or updates a persistent glanceable ongoing notification in the Android status bar
  /// showing the live chronometer elapsed timer, metabolic stage, and remaining time.
  Future<void> updateOngoingFastingNotification({
    required FastingState fasting,
  }) async {
    if (!fasting.isActive || fasting.startTime == null) {
      await cancelOngoingFastingNotification();
      return;
    }

    try {
      final stage = fasting.currentStage;
      final targetHours = fasting.protocol.fastHours;
      final elapsedH = fasting.elapsedHours;
      final isTargetReached = fasting.targetReached;
      final progressPercent = (fasting.progress * 100).clamp(0, 100).toInt();

      final title = isTargetReached
          ? 'Fast Goal Reached! 🎉 (${elapsedH.toStringAsFixed(1)}h)'
          : '🔥 Fasting: ${stage.name} (${elapsedH.toStringAsFixed(1)}h / ${targetHours}h)';

      final body = isTargetReached
          ? 'Completed ${fasting.protocol.label} fast. Your eating window is now open!'
          : '${stage.description.split(".").first}. ${fasting.remaining.inHours}h ${fasting.remaining.inMinutes % 60}m remaining ($progressPercent%)';

      final androidDetails = AndroidNotificationDetails(
        channelFastingLive,
        'Live Fasting Status',
        channelDescription: 'Persistent status bar timer and metabolic stage during active fasts',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        usesChronometer: true,
        chronometerCountDown: false,
        when: fasting.startTime!.millisecondsSinceEpoch,
        showWhen: true,
        onlyAlertOnce: true,
        subText: '${fasting.protocol.label} Fast',
        icon: '@mipmap/ic_launcher',
        showProgress: true,
        maxProgress: 100,
        progress: progressPercent,
        color: const Color(0xFF10B981),
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        actions: const [
          AndroidNotificationAction(
            'open_fasting',
            'View Fasting Tracker',
            showsUserInterface: true,
          ),
        ],
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: idOngoingFasting,
        title: title,
        body: body,
        notificationDetails: details,
        payload: 'fasting_screen',
      );
    } catch (e) {
      debugPrint('NotificationService.updateOngoingFastingNotification failed ($e)');
    }
  }

  /// Sends a simulated ongoing fasting notification to the status bar for instant verification.
  Future<void> showTestFastingNotification() async {
    final simulatedStart = DateTime.now().subtract(const Duration(hours: 14, minutes: 20));
    final testFast = FastingState(
      isActive: true,
      startTime: simulatedStart,
      protocol: FastingProtocol.sixteenEight,
    );
    await updateOngoingFastingNotification(fasting: testFast);
  }

  /// Cancels the ongoing persistent fasting status notification.
  Future<void> cancelOngoingFastingNotification() async {
    await cancel(idOngoingFasting);
  }

  /// Cancels a specific scheduled or active notification.
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('NotificationService.cancel failed ($e)');
    }
  }

  /// Cancels all notifications.
  Future<void> cancelAll() async {
    try {
      await cancelOngoingFastingNotification();
      await cancel(idFastingTargetReached);
      await cancel(idFastingGlycogen);
      await cancel(idFastingHalfway);
      await cancel(idFastingKetosis);
      await cancel(idFastingAutophagy);
      await cancel(idFastingWindowClosing);
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.cancelAll failed ($e)');
    }
  }

  /// Comprehensive sync of all user notification settings and active fasts.
  Future<void> syncAllReminders({
    required NotificationSettings settings,
    required FastingState fasting,
  }) async {
    if (!settings.enabled) {
      await cancelAll();
      return;
    }

    // 1. Breakfast Reminder
    if (settings.breakfastReminder) {
      await scheduleDailyReminder(
        id: idBreakfast,
        title: 'Morning Fuel Time 🍳',
        body: 'Start your day with high-protein energy! Log breakfast to kickstart your metabolism.',
        hour: settings.breakfastHour,
        minute: settings.breakfastMinute,
        channelId: channelMeals,
        channelName: 'Meal Reminders',
      );
    } else {
      await cancel(idBreakfast);
    }

    // 2. Lunch Reminder
    if (settings.lunchReminder) {
      await scheduleDailyReminder(
        id: idLunch,
        title: 'Midday Refuel 🥗',
        body: 'Keep your energy steady for the afternoon. Check your remaining macros and log lunch.',
        hour: settings.lunchHour,
        minute: settings.lunchMinute,
        channelId: channelMeals,
        channelName: 'Meal Reminders',
      );
    } else {
      await cancel(idLunch);
    }

    // 3. Dinner Reminder
    if (settings.dinnerReminder) {
      await scheduleDailyReminder(
        id: idDinner,
        title: 'Dinner & Recovery 🍲',
        body: 'Hit your final calorie and micronutrient targets today before winding down.',
        hour: settings.dinnerHour,
        minute: settings.dinnerMinute,
        channelId: channelMeals,
        channelName: 'Meal Reminders',
      );
    } else {
      await cancel(idDinner);
    }

    // 4. Evening Debrief Reminder
    if (settings.eveningDebriefReminder) {
      await scheduleDailyReminder(
        id: idDebrief,
        title: 'Your Daily Nutrition Debrief is Ready ✨',
        body: 'Check out your AI coach summary of today\'s calorie adherence and habit wins.',
        hour: settings.eveningDebriefHour,
        minute: settings.eveningDebriefMinute,
        channelId: channelHabits,
        channelName: 'Habits & Coaching',
      );
    } else {
      await cancel(idDebrief);
    }

    // 5. Streak Protector (9:30 PM)
    if (settings.streakProtection) {
      await scheduleDailyReminder(
        id: idStreakProtector,
        title: 'Protect Your Streak! 🔥',
        body: 'Don\'t break your habit streak! Log today\'s meals or a quick bite before midnight.',
        hour: 21,
        minute: 30,
        channelId: channelHabits,
        channelName: 'Habits & Coaching',
      );
    } else {
      await cancel(idStreakProtector);
    }

    // 6. Daily Activity & Movement Reminder (e.g. 5:30 PM)
    if (settings.activityReminder) {
      await scheduleDailyReminder(
        id: idActivityReminder,
        title: 'Time to Move! 🚶🪢',
        body: 'Step out for a brisk walk, run, or grab your jump rope to ignite 150+ active kcal and clear your mind!',
        hour: settings.activityReminderHour,
        minute: settings.activityReminderMinute,
        channelId: channelActivity,
        channelName: 'Activity & Movement',
      );
    } else {
      await cancel(idActivityReminder);
    }

    // 7. Periodic Hydration Reminders (every N hours between 9:00 AM and 9:00 PM)
    if (settings.hydrationReminder) {
      final interval = settings.hydrationIntervalHours.clamp(1, 6);
      int slot = 0;
      for (int h = 9; h <= 21; h += interval) {
        await scheduleDailyReminder(
          id: idHydrationBase + slot,
          title: 'Hydration Check 💧',
          body: 'Drink a glass of water (250ml) to keep your energy and metabolism sharp!',
          hour: h,
          minute: 0,
          channelId: channelHydration,
          channelName: 'Hydration Reminders',
        );
        slot++;
      }
      for (int leftover = slot; leftover < 15; leftover++) {
        await cancel(idHydrationBase + leftover);
      }
    } else {
      for (int slot = 0; slot < 15; slot++) {
        await cancel(idHydrationBase + slot);
      }
    }

    // 8. Active Fasting Alarms
    if (fasting.isActive && fasting.startTime != null) {
      final start = fasting.startTime!;
      final targetHours = fasting.protocol.fastHours;
      final targetTime = start.add(Duration(hours: targetHours));
      final now = DateTime.now();

      // Goal Reached Alert
      if (settings.fastingTargetReachedAlert) {
        if (targetTime.isAfter(now)) {
          await scheduleOneTimeAlert(
            id: idFastingTargetReached,
            title: 'Fasting Goal Reached! 🎉',
            body: 'Congratulations! You completed your ${fasting.protocol.label} fast (${targetHours}h). Your eating window is now open.',
            targetTime: targetTime,
            channelId: channelFasting,
            channelName: 'Intermittent Fasting',
          );
        }
      } else {
        await cancel(idFastingTargetReached);
      }

      // Metabolic Stage Transitions
      if (settings.fastingStageTransitionAlert) {
        // Stage 1: Glycogen Depletion (4h)
        final glycogenTime = start.add(const Duration(hours: 4));
        if (glycogenTime.isAfter(now) && glycogenTime.isBefore(targetTime)) {
          await scheduleOneTimeAlert(
            id: idFastingGlycogen,
            title: 'Metabolic Shift: Glycogen Depletion ⚡',
            body: '4h fasted: Insulin levels have fallen. Blood glucose has normalized and your liver is tapping stored glycogen.',
            targetTime: glycogenTime,
            channelId: channelFasting,
            channelName: 'Intermittent Fasting',
          );
        } else {
          await cancel(idFastingGlycogen);
        }

        // Halfway Milestone (e.g. 8h for 16h fast)
        final halfwayHours = targetHours / 2.0;
        final halfwayTime = start.add(Duration(minutes: (halfwayHours * 60).round()));
        if (halfwayTime.isAfter(now) && halfwayTime.isBefore(targetTime) && halfwayHours >= 5.0) {
          await scheduleOneTimeAlert(
            id: idFastingHalfway,
            title: 'Halfway Fasting Milestone 🌟',
            body: 'You are 50% through your ${fasting.protocol.label} fast (${halfwayHours.toStringAsFixed(1)}h done)! Digestion is fully resting. Stay hydrated.',
            targetTime: halfwayTime,
            channelId: channelFasting,
            channelName: 'Intermittent Fasting',
          );
        } else {
          await cancel(idFastingHalfway);
        }

        // Stage 2: Fat Burning & Ketosis (12h)
        final ketosisTime = start.add(const Duration(hours: 12));
        if (ketosisTime.isAfter(now) && ketosisTime.isBefore(targetTime)) {
          await scheduleOneTimeAlert(
            id: idFastingKetosis,
            title: 'Metabolic State: Fat Burning & Ketosis 🔥',
            body: 'Glycogen is depleted (12h fasted)! Lipolysis is active: your body is converting stored fat into clean ketone energy.',
            targetTime: ketosisTime,
            channelId: channelFasting,
            channelName: 'Intermittent Fasting',
          );
        } else {
          await cancel(idFastingKetosis);
        }

        // Stage 3: Deep Autophagy & Cellular Repair (18h)
        final autophagyTime = start.add(const Duration(hours: 18));
        if (autophagyTime.isAfter(now)) {
          await scheduleOneTimeAlert(
            id: idFastingAutophagy,
            title: 'Metabolic State: Deep Autophagy ✨',
            body: 'Peak cellular renewal active (18h fasted)! Damaged mitochondria and misfolded proteins are being recycled.',
            targetTime: autophagyTime,
            channelId: channelFasting,
            channelName: 'Intermittent Fasting',
          );
        } else {
          await cancel(idFastingAutophagy);
        }
      } else {
        await cancel(idFastingGlycogen);
        await cancel(idFastingHalfway);
        await cancel(idFastingKetosis);
        await cancel(idFastingAutophagy);
      }

      // Eating Window Closing Alert (30 min before eating window closes)
      if (settings.fastingWindowClosingAlert) {
        final eatHours = fasting.protocol.eatHours;
        final windowClosingTime = targetTime.add(Duration(hours: eatHours)).subtract(const Duration(minutes: 30));
        if (windowClosingTime.isAfter(now)) {
          await scheduleOneTimeAlert(
            id: idFastingWindowClosing,
            title: 'Eating Window Closing in 30m ⏳',
            body: 'Finish your final meal and hydration before your next ${fasting.protocol.label} fast begins.',
            targetTime: windowClosingTime,
            channelId: channelFasting,
            channelName: 'Intermittent Fasting',
          );
        } else {
          await cancel(idFastingWindowClosing);
        }
      } else {
        await cancel(idFastingWindowClosing);
      }
    } else {
      await cancel(idFastingTargetReached);
      await cancel(idFastingGlycogen);
      await cancel(idFastingHalfway);
      await cancel(idFastingKetosis);
      await cancel(idFastingAutophagy);
      await cancel(idFastingWindowClosing);
    }

    // 7. Persistent Glanceable Status Bar Fasting Notification
    if (settings.fastingOngoingNotification &&
        fasting.isActive &&
        fasting.startTime != null) {
      await updateOngoingFastingNotification(fasting: fasting);
    } else {
      await cancelOngoingFastingNotification();
    }
  }

  static bool _timeZonesReady = false;

  void _ensureTimeZones() {
    if (_timeZonesReady) return;
    try {
      tz.initializeTimeZones();
      final now = DateTime.now();
      final timeZoneName = now.timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        final currentOffset = now.timeZoneOffset;
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == currentOffset) {
            tz.setLocalLocation(loc);
            break;
          }
        }
      }
      _timeZonesReady = true;
    } catch (_) {}
  }

  /// Calculates next TZDateTime for the given hour and minute.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    _ensureTimeZones();
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
