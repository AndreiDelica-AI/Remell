import 'package:flutter_test/flutter_test.dart';
import 'package:remell/shared/services/smart_notification_scheduler.dart';

void main() {
  group('SmartNotificationScheduler Rules & Guardrails', () {
    test('Strict Quiet Hours enforcement (09:00 PM - 08:00 AM)', () {
      // 09:00 PM (21:00) -> should be quiet hours
      expect(SmartNotificationScheduler.isQuietHours(DateTime(2026, 9, 9, 21, 0)), isTrue);
      // 11:30 PM (23:30) -> should be quiet hours
      expect(SmartNotificationScheduler.isQuietHours(DateTime(2026, 9, 9, 23, 30)), isTrue);
      // 03:00 AM (03:00) -> should be quiet hours
      expect(SmartNotificationScheduler.isQuietHours(DateTime(2026, 9, 9, 3, 0)), isTrue);
      // 07:59 AM (07:59) -> should be quiet hours
      expect(SmartNotificationScheduler.isQuietHours(DateTime(2026, 9, 9, 7, 59)), isTrue);

      // 08:00 AM (08:00) -> active hours
      expect(SmartNotificationScheduler.isQuietHours(DateTime(2026, 9, 9, 8, 0)), isFalse);
      // 02:00 PM (14:00) -> active hours
      expect(SmartNotificationScheduler.isQuietHours(DateTime(2026, 9, 9, 14, 0)), isFalse);
      // 08:59 PM (20:59) -> active hours
      expect(SmartNotificationScheduler.isQuietHours(DateTime(2026, 9, 9, 20, 59)), isFalse);

      // Evaluation in quiet hours should suppress notification
      final result = SmartNotificationScheduler.evaluateNotification(
        now: DateTime(2026, 9, 9, 22, 0),
        todayQuickCount: 5,
        todayUnfinishedCount: 3,
        pastMissedCount: 2,
      );
      expect(result.shouldSend, isFalse);
      expect(result.suppressionReason, contains('Quiet hours active'));
    });

    test('4-Hour Minimum Spacing Buffer enforcement', () {
      final lastPush = DateTime(2026, 9, 9, 14, 0); // 2:00 PM

      // 2 hours later (4:00 PM) -> spacing violated (< 4 hours)
      expect(
        SmartNotificationScheduler.isSpacingViolated(DateTime(2026, 9, 9, 16, 0), lastPush),
        isTrue,
      );

      // 3 hours 59 mins later -> spacing violated (< 4 hours)
      expect(
        SmartNotificationScheduler.isSpacingViolated(DateTime(2026, 9, 9, 17, 59), lastPush),
        isTrue,
      );

      // 4 hours later (6:00 PM) -> spacing satisfied
      expect(
        SmartNotificationScheduler.isSpacingViolated(DateTime(2026, 9, 9, 18, 0), lastPush),
        isFalse,
      );
    });

    test('Morning Quick Task delivery (08:15 AM - 08:45 AM) & smart suppression', () {
      final morningTime = DateTime(2026, 9, 9, 8, 30);

      // Successful trigger when quick items exist
      final resSuccess = SmartNotificationScheduler.evaluateNotification(
        now: morningTime,
        todayQuickCount: 3,
        todayUnfinishedCount: 0,
        pastMissedCount: 0,
      );
      expect(resSuccess.shouldSend, isTrue);
      expect(resSuccess.type, SmartNotificationType.quickTask);
      expect(resSuccess.title, "Today's Quick Notes");
      expect(resSuccess.body, "You have 3 quick items ready for today.");

      // Smart suppression when zero quick items
      final resEmpty = SmartNotificationScheduler.evaluateNotification(
        now: morningTime,
        todayQuickCount: 0,
        todayUnfinishedCount: 0,
        pastMissedCount: 0,
      );
      expect(resEmpty.shouldSend, isFalse);
      expect(resEmpty.suppressionReason, contains('Smart Suppression'));

      // Suppression if already sent morning notification today
      final resAlreadySent = SmartNotificationScheduler.evaluateNotification(
        now: morningTime,
        todayQuickCount: 3,
        todayUnfinishedCount: 0,
        pastMissedCount: 0,
        morningSentToday: true,
      );
      expect(resAlreadySent.shouldSend, isFalse);
      expect(resAlreadySent.suppressionReason, contains('already sent today'));
    });

    test('Workday Wrap-Up Unfinished Task (05:30 PM - 06:15 PM) & Smart Suppression', () {
      final wrapUpTime = DateTime(2026, 9, 9, 17, 45);

      // Triggers if active tasks scheduled for today remain incomplete
      final res = SmartNotificationScheduler.evaluateNotification(
        now: wrapUpTime,
        todayQuickCount: 0,
        todayUnfinishedCount: 4,
        pastMissedCount: 0,
      );
      expect(res.shouldSend, isTrue);
      expect(res.type, SmartNotificationType.unfinishedTask);
      expect(res.title, "Daily Progress");
      expect(res.body, "4 tasks remaining for today. Ready to wrap up?");

      // Smart suppression if all tasks are completed
      final resCompleted = SmartNotificationScheduler.evaluateNotification(
        now: wrapUpTime,
        todayQuickCount: 0,
        todayUnfinishedCount: 0,
        pastMissedCount: 0,
      );
      expect(resCompleted.shouldSend, isFalse);
      expect(resCompleted.suppressionReason, contains('Smart Suppression'));
    });

    test('Evening Reflection Missed Task (07:30 PM - 08:15 PM) & Smart Suppression', () {
      final reflectionTime = DateTime(2026, 9, 9, 19, 45);

      // Triggers if tasks from prior days were left unresolved
      final res = SmartNotificationScheduler.evaluateNotification(
        now: reflectionTime,
        todayQuickCount: 0,
        todayUnfinishedCount: 0,
        pastMissedCount: 2,
      );
      expect(res.shouldSend, isTrue);
      expect(res.type, SmartNotificationType.missedTask);
      expect(res.title, "Catch-up");
      expect(res.body, "You have 2 unresolved items from previous days.");

      // Smart suppression if zero missed tasks from previous days
      final resZeroMissed = SmartNotificationScheduler.evaluateNotification(
        now: reflectionTime,
        todayQuickCount: 0,
        todayUnfinishedCount: 0,
        pastMissedCount: 0,
      );
      expect(resZeroMissed.shouldSend, isFalse);
      expect(resZeroMissed.suppressionReason, contains('Smart Suppression'));
    });

    test('Merged Consolidated Evening Notification when both today and past tasks exist', () {
      final eveningTime = DateTime(2026, 9, 9, 18, 0);

      // Both unfinished tasks from today AND missed tasks from past days exist
      final res = SmartNotificationScheduler.evaluateNotification(
        now: eveningTime,
        todayQuickCount: 0,
        todayUnfinishedCount: 3,
        pastMissedCount: 2,
      );
      expect(res.shouldSend, isTrue);
      expect(res.type, SmartNotificationType.consolidatedEvening);
      expect(res.title, "Daily Progress & Catch-up");
      expect(
        res.body,
        "3 tasks remaining today and 2 unresolved items from previous days.",
      );
    });

    test('Non-Guilt Copy & Tone Verification', () {
      // Ensure no alarm emojis or aggressive warning copy
      final types = [
        SmartNotificationType.quickTask,
        SmartNotificationType.unfinishedTask,
        SmartNotificationType.missedTask,
        SmartNotificationType.consolidatedEvening,
      ];

      for (final t in types) {
        final copy = SmartNotificationScheduler.generateCopy(
          type: t,
          quickCount: 1,
          unfinishedCount: 1,
          missedCount: 1,
        );
        final title = copy['title']!;
        final body = copy['body']!;

        expect(title.contains('🚨'), isFalse, reason: 'Title should not contain 🚨');
        expect(title.contains('⚠️'), isFalse, reason: 'Title should not contain ⚠️');
        expect(body.contains('🚨'), isFalse, reason: 'Body should not contain 🚨');
        expect(body.contains('⚠️'), isFalse, reason: 'Body should not contain ⚠️');
        expect(title.toLowerCase().contains('urgent'), isFalse);
        expect(body.toLowerCase().contains('failed'), isFalse);
      }
    });
  });
}
