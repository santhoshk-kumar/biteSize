import 'package:flutter_test/flutter_test.dart';
import 'package:zen_calorie/models/fasting_model.dart';
import 'package:zen_calorie/models/notification_settings.dart';
import 'package:zen_calorie/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Architecture & Channels Tests', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    test('Defines distinct notification channels and IDs', () {
      expect(NotificationService.channelMeals, 'bitesize_meals');
      expect(NotificationService.channelFasting, 'bitesize_fasting');
      expect(NotificationService.channelFastingLive, 'bitesize_fasting_live');
      expect(NotificationService.channelHydration, 'bitesize_hydration');
      expect(NotificationService.channelHabits, 'bitesize_habits');

      expect(NotificationService.idBreakfast, 101);
      expect(NotificationService.idLunch, 102);
      expect(NotificationService.idDinner, 103);
      expect(NotificationService.idDebrief, 104);
      expect(NotificationService.idStreakProtector, 105);
      expect(NotificationService.idOngoingFasting, 200);
      expect(NotificationService.idFastingKetosis, 201);
      expect(NotificationService.idFastingAutophagy, 202);
      expect(NotificationService.idFastingTargetReached, 203);
    });

    test('syncAllReminders handles enabled and disabled settings gracefully without errors', () async {
      const enabledSettings = NotificationSettings(
        enabled: true,
        breakfastReminder: true,
        lunchReminder: true,
        dinnerReminder: true,
        eveningDebriefReminder: true,
        streakProtection: true,
      );

      const fasting = FastingState(
        isActive: true,
        protocol: FastingProtocol.sixteenEight,
      );

      // In unit test environment, calls catch native missing channels safely
      await service.syncAllReminders(
        settings: enabledSettings,
        fasting: fasting,
      );

      const disabledSettings = NotificationSettings(enabled: false);
      await service.syncAllReminders(
        settings: disabledSettings,
        fasting: fasting,
      );
    });

    test('showImmediateNotification executes without uncaught exceptions', () async {
      await service.showImmediateNotification(
        id: 999,
        title: 'Test Notification',
        body: 'Testing body text',
      );
    });

    test('updateOngoingFastingNotification handles active and inactive fast safely', () async {
      final activeFast = FastingState(
        isActive: true,
        startTime: DateTime.now().subtract(const Duration(hours: 14)),
        protocol: FastingProtocol.sixteenEight,
      );

      await service.updateOngoingFastingNotification(fasting: activeFast);
      await service.cancelOngoingFastingNotification();

      const inactiveFast = FastingState(isActive: false);
      await service.updateOngoingFastingNotification(fasting: inactiveFast);
    });

    test('showTestFastingNotification executes cleanly without throwing', () async {
      await service.showTestFastingNotification();
      await service.cancelOngoingFastingNotification();
    });

    test('notificationPayload notifier initializes with null and notifies listeners', () {
      expect(service.notificationPayload.value, isNull);
      var received = false;
      service.notificationPayload.addListener(() {
        received = true;
      });
      service.notificationPayload.value = 'fasting_screen';
      expect(received, isTrue);
      expect(service.notificationPayload.value, 'fasting_screen');
    });
  });
}
