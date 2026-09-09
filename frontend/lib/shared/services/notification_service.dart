import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'dart:async';
import 'dart:math' as math;
import 'dart:html' as html;

import 'smart_notification_scheduler.dart';

class WebNotificationStorage implements NotificationStorage {
  @override
  String? getString(String key) {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  void setString(String key, String value) {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  @override
  void remove(String key) {
    try {
      html.window.localStorage.remove(key);
    } catch (_) {}
  }
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static final StreamController<String?> onNotificationClick =
      StreamController<String?>.broadcast();

  static bool get isNotificationAllowed {
    try {
      if (kIsWeb) {
        final val = html.window.localStorage['remell_settings_allow_notifs'];
        return val != 'false';
      }
    } catch (_) {}
    return true;
  }

  static bool get isPersistent {
    try {
      if (kIsWeb) {
        final val = html.window.localStorage['remell_settings_pn'];
        return val == 'true';
      }
    } catch (_) {}
    return false;
  }

  static NotificationDetails getDetails({required bool isUnfinished}) {
    final persistent = isPersistent;
    const actions = <AndroidNotificationAction>[
      AndroidNotificationAction('mark_complete', 'Mark Complete', showsUserInterface: true),
      AndroidNotificationAction('snooze_2h', 'Snooze 2 Hours'),
      AndroidNotificationAction('view_tasks', 'View Tasks', showsUserInterface: true),
    ];

    if (isUnfinished) {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'remell_unfinished_tasks',
          'Unfinished Task Alerts',
          channelDescription: 'Alerts for previous unfinished and overdue tasks',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          ongoing: persistent,
          autoCancel: !persistent,
          actions: actions,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      );
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'remell_reminders',
        'Remell reminders',
        channelDescription: 'Task start times, deadlines, and active reminders',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        ongoing: persistent,
        autoCancel: !persistent,
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      SmartNotificationScheduler.storage = WebNotificationStorage();
    }

    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // timezone defaults to UTC when the platform cannot report an IANA zone.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: apple,
      macOS: apple,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          onNotificationClick.add(details.payload);
        }
      },
    );
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    return _requestPermissionsImpl().timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  }

  static Future<bool> _requestPermissionsImpl() async {
    try {
      await initialize();

      if (kIsWeb) {
        final web = _plugin.resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin>();
        if (web == null) return false;
        if (web.permissionStatus == WebNotificationPermission.granted) return true;
        try {
          return await web.requestNotificationsPermission() ?? false;
        } catch (_) {
          return false;
        }
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          final notifications =
              await android?.requestNotificationsPermission() ?? true;
          await android?.requestExactAlarmsPermission();
          return notifications;
        case TargetPlatform.iOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin>()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
        case TargetPlatform.macOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                      MacOSFlutterLocalNotificationsPlugin>()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
        default:
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> show({required String title, required String body, bool isUnfinished = false, String? taskId}) async {
    if (!isNotificationAllowed) return;
    if (SmartNotificationScheduler.isQuietHours(DateTime.now())) {
      debugPrint('[NotificationService] Suppressed due to Quiet Hours (09:00 PM - 08:00 AM)');
      return;
    }
    await initialize();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails: getDetails(isUnfinished: isUnfinished),
      payload: taskId,
    );
  }

  static final Map<String, List<Timer>> _activeWebTimers = {};

  static Future<void> scheduleSubtaskReminders({
    required String taskId,
    required String subtaskTitle,
    required String? scheduledTime,
  }) async {
    if (!isNotificationAllowed) return;
    if (scheduledTime == null || scheduledTime.trim().isEmpty) return;
    final parts = scheduledTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var targetTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!targetTime.isAfter(now)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    final formattedTime = formatTimeOfDay(hour, minute);
    final subtaskId = '$taskId-$subtaskTitle-$scheduledTime';
    final baseId = subtaskId.hashCode.abs().remainder(1000000000);

    // Cancel existing native notifications
    try {
      await _plugin.cancel(id: baseId);
      await _plugin.cancel(id: baseId + 1);
    } catch (_) {}

    // Cancel existing web timers
    if (_activeWebTimers.containsKey(subtaskId)) {
      for (final t in _activeWebTimers[subtaskId]!) {
        t.cancel();
      }
      _activeWebTimers.remove(subtaskId);
    }
    final List<Timer> webTimers = [];

    // 1. Notification 10 minutes before (e.g. 9:50 AM for 10:00 AM)
    final leadTime = targetTime.subtract(const Duration(minutes: 10));
    if (leadTime.isAfter(now)) {
      try {
        await _plugin.zonedSchedule(
          id: baseId,
          title: '10 min left: $subtaskTitle',
          body: '$subtaskTitle is scheduled at $formattedTime',
          scheduledDate: leadTime,
          notificationDetails: getDetails(isUnfinished: false),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: taskId,
        );
      } catch (_) {}

      final diff = leadTime.difference(now);
      webTimers.add(Timer(diff, () {
        show(
          title: '10 min left: $subtaskTitle',
          body: '$subtaskTitle is scheduled at $formattedTime',
          taskId: taskId,
        );
      }));
    }

    // 2. Notification at exact time (e.g. 10:00 AM)
    if (targetTime.isAfter(now)) {
      try {
        await _plugin.zonedSchedule(
          id: baseId + 1,
          title: 'Time for: $subtaskTitle',
          body: '$subtaskTitle ($formattedTime)',
          scheduledDate: targetTime,
          notificationDetails: getDetails(isUnfinished: false),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: taskId,
        );
      } catch (_) {}

      final diff = targetTime.difference(now);
      webTimers.add(Timer(diff, () {
        show(
          title: 'Time for: $subtaskTitle',
          body: '$subtaskTitle ($formattedTime)',
          taskId: taskId,
        );
      }));
    }

    if (webTimers.isNotEmpty) {
      _activeWebTimers[subtaskId] = webTimers;
    }
  }

  static Future<void> scheduleAllSubtasksReminders({
    required String taskId,
    required List<dynamic> subtasks,
  }) async {
    for (final st in subtasks) {
      final isCompleted = st.isCompleted == true;
      final String? time = st.scheduledTime as String?;
      final String title = st.title as String? ?? '';
      if (!isCompleted && time != null && time.isNotEmpty) {
        await scheduleSubtaskReminders(
          taskId: taskId,
          subtaskTitle: title,
          scheduledTime: time,
        );
      }
    }
  }

  static Future<void> scheduleTaskReminders({
    required String taskId,
    required String title,
    required String? dueTime,
    required int durationMinutes,
  }) async {
    if (!isNotificationAllowed) return;
    if (dueTime == null) return;
    final parts = dueTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduledTime.isAfter(now)) scheduledTime = scheduledTime.add(const Duration(days: 1));

    final baseId = taskId.hashCode.abs().remainder(1000000000);
    await _plugin.cancel(id: baseId);
    await _plugin.cancel(id: baseId + 1);

    // Smart Ergonomic Preparation Timing: lead time before start time
    final int prepLeadMinutes = math.min(15, math.max(5, durationMinutes));
    final prepTime = scheduledTime.subtract(Duration(minutes: prepLeadMinutes));

    final durText = formatDurationFriendly(durationMinutes);
    if (prepTime.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: baseId,
        title: 'Starting soon',
        body: '$title - $durText (Starts at ${_formatTime(scheduledTime)})',
        scheduledDate: prepTime,
        notificationDetails: getDetails(isUnfinished: false),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: taskId,
      );
    }

    // Overdue / Unfinished Check: 10 minutes after scheduled start time if missed
    final overdueTime = scheduledTime.add(const Duration(minutes: 10));
    if (overdueTime.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: baseId + 1,
        title: 'Unfinished Task',
        body: '$title - $durText',
        scheduledDate: overdueTime,
        notificationDetails: getDetails(isUnfinished: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: taskId,
      );
    }
  }

  static String formatDurationFriendly(int minutes) {
    if (minutes <= 0) return 'Flexible duration';
    if (minutes < 60) return '$minutes mins';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h hr${h > 1 ? "s" : ""}';
    return '$h hr $m min';
  }

  static String formatTimeOfDay(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  static String _formatTime(tz.TZDateTime value) {
    return formatTimeOfDay(value.hour, value.minute);
  }
}
