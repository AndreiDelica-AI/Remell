import 'package:flutter/foundation.dart';

enum SmartNotificationType {
  quickTask,
  unfinishedTask,
  missedTask,
  consolidatedEvening,
}

class NotificationEvaluationResult {
  final bool shouldSend;
  final String? suppressionReason;
  final SmartNotificationType? type;
  final String? title;
  final String? body;
  final Map<String, dynamic>? payload;

  const NotificationEvaluationResult({
    required this.shouldSend,
    this.suppressionReason,
    this.type,
    this.title,
    this.body,
    this.payload,
  });

  @override
  String toString() =>
      'NotificationEvaluationResult(shouldSend: $shouldSend, type: $type, title: $title, reason: $suppressionReason)';
}

/// Abstract storage interface so logic runs identically in Flutter Web, Mobile, and VM unit tests
abstract class NotificationStorage {
  String? getString(String key);
  void setString(String key, String value);
  void remove(String key);
}

class InMemoryNotificationStorage implements NotificationStorage {
  final Map<String, String> _map = {};

  @override
  String? getString(String key) => _map[key];

  @override
  void setString(String key, String value) => _map[key] = value;

  @override
  void remove(String key) => _map.remove(key);
}

class SmartNotificationScheduler {
  SmartNotificationScheduler._();

  static NotificationStorage storage = InMemoryNotificationStorage();

  /// Mandatory minimum interval between any two system push notifications (4 hours)
  static const Duration minSpacing = Duration(hours: 4);

  /// Hard block between 09:00 PM (21:00) and 08:00 AM (08:00) local time
  static bool isQuietHours(DateTime time) {
    final hour = time.hour;
    return hour >= 21 || hour < 8;
  }

  /// Delivery window 1: 08:15 AM - 08:45 AM
  static bool isWithinMorningQuickTaskWindow(DateTime time) {
    if (time.hour == 8 && time.minute >= 15 && time.minute <= 45) {
      return true;
    }
    return false;
  }

  /// Delivery window 2: 05:30 PM - 06:15 PM (17:30 - 18:15)
  static bool isWithinUnfinishedTaskWindow(DateTime time) {
    if (time.hour == 17 && time.minute >= 30) return true;
    if (time.hour == 18 && time.minute <= 15) return true;
    return false;
  }

  /// Delivery window 3: 07:30 PM - 08:15 PM (19:30 - 20:15)
  static bool isWithinMissedTaskWindow(DateTime time) {
    if (time.hour == 19 && time.minute >= 30) return true;
    if (time.hour == 20 && time.minute <= 15) return true;
    return false;
  }

  /// General evening review window before quiet hours: 05:30 PM - 08:59 PM (17:30 - 20:59)
  static bool isWithinEveningWindow(DateTime time) {
    if (time.hour >= 17 && time.hour <= 20) {
      if (time.hour == 17 && time.minute < 30) return false;
      return true;
    }
    return false;
  }

  /// Evaluates spacing rule: enforces at least 4 hours between any two system notifications
  static bool isSpacingViolated(DateTime now, DateTime? lastPushTime) {
    if (lastPushTime == null) return false;
    return now.difference(lastPushTime) < minSpacing;
  }

  /// Generates the non-guilt, supportive notification copy
  static Map<String, String> generateCopy({
    required SmartNotificationType type,
    int quickCount = 0,
    int unfinishedCount = 0,
    int missedCount = 0,
  }) {
    switch (type) {
      case SmartNotificationType.quickTask:
        final plural = quickCount == 1 ? 'quick item' : 'quick items';
        return {
          'title': "Today's Quick Notes",
          'body': 'You have $quickCount $plural ready for today.',
        };
      case SmartNotificationType.unfinishedTask:
        final plural = unfinishedCount == 1 ? 'task' : 'tasks';
        return {
          'title': 'Daily Progress',
          'body': '$unfinishedCount $plural remaining for today. Ready to wrap up?',
        };
      case SmartNotificationType.missedTask:
        final plural = missedCount == 1 ? 'item' : 'items';
        return {
          'title': 'Catch-up',
          'body': 'You have $missedCount unresolved $plural from previous days.',
        };
      case SmartNotificationType.consolidatedEvening:
        final unfPlural = unfinishedCount == 1 ? 'task' : 'tasks';
        final missPlural = missedCount == 1 ? 'item' : 'items';
        if (unfinishedCount > 0 && missedCount > 0) {
          return {
            'title': 'Daily Progress & Catch-up',
            'body':
                '$unfinishedCount $unfPlural remaining today and $missedCount unresolved $missPlural from previous days.',
          };
        } else if (unfinishedCount > 0) {
          return {
            'title': 'Daily Progress',
            'body': '$unfinishedCount $unfPlural remaining for today. Ready to wrap up?',
          };
        } else {
          return {
            'title': 'Catch-up',
            'body': 'You have $missedCount unresolved $missPlural from previous days.',
          };
        }
    }
  }

  /// Pure deterministic evaluation function for notification triggers, suppression, and spacing
  static NotificationEvaluationResult evaluateNotification({
    required DateTime now,
    required int todayQuickCount,
    required int todayUnfinishedCount,
    required int pastMissedCount,
    DateTime? lastPushTime,
    bool morningSentToday = false,
    bool eveningSentToday = false,
    DateTime? snoozeUntil,
  }) {
    // 1. Hard Quiet Hours Guardrail (09:00 PM - 08:00 AM)
    if (isQuietHours(now)) {
      return const NotificationEvaluationResult(
        shouldSend: false,
        suppressionReason: 'Quiet hours active (09:00 PM - 08:00 AM)',
      );
    }

    // 2. Active Snooze Guardrail
    if (snoozeUntil != null && now.isBefore(snoozeUntil)) {
      return NotificationEvaluationResult(
        shouldSend: false,
        suppressionReason: 'Notifications snoozed until ${snoozeUntil.toIso8601String()}',
      );
    }

    // 3. Morning Quick Task Window (08:15 AM - 08:45 AM)
    if (isWithinMorningQuickTaskWindow(now)) {
      if (morningSentToday) {
        return const NotificationEvaluationResult(
          shouldSend: false,
          suppressionReason: 'Morning quick task notification already sent today',
        );
      }
      if (isSpacingViolated(now, lastPushTime)) {
        return const NotificationEvaluationResult(
          shouldSend: false,
          suppressionReason: '4-hour minimum spacing buffer active',
        );
      }
      // Smart Suppression: suppress if no quick items
      if (todayQuickCount <= 0) {
        return const NotificationEvaluationResult(
          shouldSend: false,
          suppressionReason: 'Zero quick notes for today (Smart Suppression)',
        );
      }

      final copy = generateCopy(
        type: SmartNotificationType.quickTask,
        quickCount: todayQuickCount,
      );
      return NotificationEvaluationResult(
        shouldSend: true,
        type: SmartNotificationType.quickTask,
        title: copy['title'],
        body: copy['body'],
        payload: {'actionType': 'quickTask', 'count': todayQuickCount},
      );
    }

    // 4. Evening Reflection & Workday Wrap-Up Windows (17:30 - 20:59)
    if (isWithinEveningWindow(now)) {
      if (eveningSentToday) {
        return const NotificationEvaluationResult(
          shouldSend: false,
          suppressionReason: 'Evening notification already delivered today',
        );
      }

      if (isSpacingViolated(now, lastPushTime)) {
        return const NotificationEvaluationResult(
          shouldSend: false,
          suppressionReason: '4-hour minimum spacing buffer active',
        );
      }

      // Smart Suppression: if everything completed and no missed tasks from prior days
      if (todayUnfinishedCount <= 0 && pastMissedCount <= 0) {
        return const NotificationEvaluationResult(
          shouldSend: false,
          suppressionReason:
              'All tasks completed today and zero missed tasks from previous days (Smart Suppression)',
        );
      }

      // 4-Hour Spacing Enforcement & Merged Consolidated Notification:
      // If both unfinished and missed tasks exist, or if evaluated in the evening window,
      // deliver a single consolidated ping to prevent multiple notifications.
      final SmartNotificationType selectedType;
      if (todayUnfinishedCount > 0 && pastMissedCount > 0) {
        selectedType = SmartNotificationType.consolidatedEvening;
      } else if (todayUnfinishedCount > 0) {
        selectedType = SmartNotificationType.unfinishedTask;
      } else {
        selectedType = SmartNotificationType.missedTask;
      }

      final copy = generateCopy(
        type: selectedType,
        unfinishedCount: todayUnfinishedCount,
        missedCount: pastMissedCount,
      );

      return NotificationEvaluationResult(
        shouldSend: true,
        type: selectedType,
        title: copy['title'],
        body: copy['body'],
        payload: {
          'actionType': selectedType.name,
          'unfinishedCount': todayUnfinishedCount,
          'missedCount': pastMissedCount,
        },
      );
    }

    // Outside designated delivery windows
    return const NotificationEvaluationResult(
      shouldSend: false,
      suppressionReason: 'Current time is outside designated delivery windows',
    );
  }

  // --- Persistence & State Helpers ---

  static String _getKey(String suffix) => 'remell_smart_notif_$suffix';

  static DateTime? getLastPushTime() {
    try {
      final raw = storage.getString(_getKey('last_push'));
      if (raw != null && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
    } catch (_) {}
    return null;
  }

  static void recordPushSent(DateTime time) {
    try {
      storage.setString(_getKey('last_push'), time.toIso8601String());
      final dateStr = '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
      if (isWithinMorningQuickTaskWindow(time)) {
        storage.setString(_getKey('morning_sent_$dateStr'), 'true');
      } else if (isWithinEveningWindow(time)) {
        storage.setString(_getKey('evening_sent_$dateStr'), 'true');
      }
    } catch (_) {}
  }

  static bool hasSentMorningToday(DateTime now) {
    try {
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      return storage.getString(_getKey('morning_sent_$dateStr')) == 'true';
    } catch (_) {}
    return false;
  }

  static bool hasSentEveningToday(DateTime now) {
    try {
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      return storage.getString(_getKey('evening_sent_$dateStr')) == 'true';
    } catch (_) {}
    return false;
  }

  static DateTime? getSnoozeUntil() {
    try {
      final raw = storage.getString(_getKey('snooze_until'));
      if (raw != null && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
    } catch (_) {}
    return null;
  }

  static void setSnooze(Duration duration) {
    try {
      final until = DateTime.now().add(duration);
      storage.setString(_getKey('snooze_until'), until.toIso8601String());
    } catch (_) {}
  }

  static void clearSnooze() {
    try {
      storage.remove(_getKey('snooze_until'));
    } catch (_) {}
  }
}
