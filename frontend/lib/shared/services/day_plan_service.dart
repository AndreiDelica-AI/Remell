import 'dart:convert';
import 'dart:math' as math;
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class DayPlanData {
  final String date; // yyyy-MM-dd
  final DateTime createdAt;
  final String notes;
  final List<String> items;
  bool addedToQuickTasks;

  DayPlanData({
    required this.date,
    required this.createdAt,
    required this.notes,
    required this.items,
    this.addedToQuickTasks = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
        'items': items,
        'addedToQuickTasks': addedToQuickTasks,
      };

  factory DayPlanData.fromJson(Map<String, dynamic> json) => DayPlanData(
        date: json['date'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        notes: json['notes'] as String? ?? '',
        items: (json['items'] as List? ?? []).map((e) => e.toString()).toList(),
        addedToQuickTasks: json['addedToQuickTasks'] as bool? ?? false,
      );
}

class DayPlanService {
  DayPlanService._();

  static String formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String get todayString => formatDate(DateTime.now());
  static String get tomorrowString => formatDate(DateTime.now().add(const Duration(days: 1)));
  static String get yesterdayString => formatDate(DateTime.now().subtract(const Duration(days: 1)));

  static TimeOfDay getWakeTime() {
    if (kIsWeb) {
      try {
        final w = html.window.localStorage['remell_settings_wake_time'];
        if (w != null && w.isNotEmpty) {
          return parseTimeString(w, fallback: const TimeOfDay(hour: 7, minute: 0));
        }
      } catch (_) {}
    }
    return const TimeOfDay(hour: 7, minute: 0);
  }

  static TimeOfDay getSleepTime() {
    if (kIsWeb) {
      try {
        final s = html.window.localStorage['remell_settings_sleep_time'];
        if (s != null && s.isNotEmpty) {
          return parseTimeString(s, fallback: const TimeOfDay(hour: 22, minute: 0));
        }
      } catch (_) {}
    }
    return const TimeOfDay(hour: 22, minute: 0);
  }

  static TimeOfDay parseTimeString(String timeStr, {required TimeOfDay fallback}) {
    try {
      final clean = timeStr.trim();
      final parts = clean.split(' ');
      final hm = parts[0].split(':');
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      if (parts.length > 1) {
        final period = parts[1].toLowerCase();
        if (period == 'pm' && hour < 12) hour += 12;
        if (period == 'am' && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return fallback;
    }
  }

  static String formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour % 12 == 0 ? 12 : tod.hour % 12;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Checks if current time is within the user's morning window (from wakeTime to noon / wakeTime + 4 hrs)
  static bool isMorning([DateTime? nowTime]) {
    final now = nowTime ?? DateTime.now();
    final wake = getWakeTime();
    final wakeMinutes = wake.hour * 60 + wake.minute;
    final nowMinutes = now.hour * 60 + now.minute;
    final morningEndMinutes = math.max(12 * 60, wakeMinutes + 4 * 60);

    return nowMinutes >= wakeMinutes && nowMinutes < morningEndMinutes;
  }

  /// Checks if current time is in the night window (from 90 mins before sleepTime until sleepTime / midnight)
  static bool isNight([DateTime? nowTime]) {
    final now = nowTime ?? DateTime.now();
    final sleep = getSleepTime();
    final sleepMinutes = sleep.hour * 60 + sleep.minute;
    final nowMinutes = now.hour * 60 + now.minute;

    final nightStartMinutes = math.max(18 * 60, sleepMinutes - 90);
    if (sleepMinutes >= 18 * 60) {
      return nowMinutes >= nightStartMinutes;
    } else {
      // Sleep time past midnight
      return nowMinutes >= nightStartMinutes || nowMinutes < sleepMinutes;
    }
  }

  static DayPlanData? getPlanForDate(String dateStr) {
    if (!kIsWeb) return null;
    try {
      final raw = html.window.localStorage['remell_day_plan_$dateStr'];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return DayPlanData.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[DayPlanService] Error reading plan for $dateStr: $e');
    }
    return null;
  }

  static DayPlanData? getTodayPlan() => getPlanForDate(todayString);

  static DayPlanData? getTomorrowPlan() => getPlanForDate(tomorrowString);

  static void savePlan(DayPlanData plan) {
    if (!kIsWeb) return;
    try {
      final jsonStr = jsonEncode(plan.toJson());
      html.window.localStorage['remell_day_plan_${plan.date}'] = jsonStr;
    } catch (e) {
      debugPrint('[DayPlanService] Error saving plan: $e');
    }
  }

  static void markTodayPlanAddedToTasks() {
    final plan = getTodayPlan();
    if (plan != null) {
      plan.addedToQuickTasks = true;
      savePlan(plan);
    }
  }

  static void recordCompletedTask(String title, {String type = 'Task'}) {
    if (!kIsWeb || title.trim().isEmpty) return;
    try {
      final dateStr = todayString;
      final key = 'remell_completed_tasks_$dateStr';
      final existingRaw = html.window.localStorage[key];
      List<dynamic> list = [];
      if (existingRaw != null && existingRaw.isNotEmpty) {
        list = jsonDecode(existingRaw) as List<dynamic>;
      }
      final alreadyExists = list.any((item) => (item is Map && item['title'] == title.trim()));
      if (!alreadyExists) {
        list.add({
          'title': title.trim(),
          'type': type,
          'completedAt': DateTime.now().toIso8601String(),
        });
        html.window.localStorage[key] = jsonEncode(list);
      }
    } catch (e) {
      debugPrint('[DayPlanService] Error recording completed task: $e');
    }
  }

  static List<Map<String, dynamic>> getTodayCompletedTasks() {
    if (!kIsWeb) return [];
    try {
      final dateStr = todayString;
      final key = 'remell_completed_tasks_$dateStr';
      final raw = html.window.localStorage[key];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[DayPlanService] Error reading completed tasks: $e');
    }
    return [];
  }

  static bool hasShownMorningPlanToday([DateTime? nowTime]) {
    if (!kIsWeb) return false;
    final dateStr = formatDate(nowTime ?? DateTime.now());
    return html.window.localStorage['remell_morning_plan_shown_$dateStr'] == 'true';
  }

  static void markMorningPlanShownToday([DateTime? nowTime]) {
    if (!kIsWeb) return;
    final dateStr = formatDate(nowTime ?? DateTime.now());
    html.window.localStorage['remell_morning_plan_shown_$dateStr'] = 'true';
  }

  static bool hasShownNightPlanTonight([DateTime? nowTime]) {
    if (!kIsWeb) return false;
    final dateStr = formatDate(nowTime ?? DateTime.now());
    return html.window.localStorage['remell_night_plan_shown_$dateStr'] == 'true';
  }

  static void markNightPlanShownTonight([DateTime? nowTime]) {
    if (!kIsWeb) return;
    final dateStr = formatDate(nowTime ?? DateTime.now());
    html.window.localStorage['remell_night_plan_shown_$dateStr'] = 'true';
  }

  /// Schedules daily morning & evening notification alarms based on wake & sleep times
  static Future<void> scheduleDailyPlanningReminders() async {
    if (!NotificationService.isNotificationAllowed) return;

    final wake = getWakeTime();
    final sleep = getSleepTime();

    final wakeTimeStr = '${wake.hour.toString().padLeft(2, '0')}:${wake.minute.toString().padLeft(2, '0')}';
    
    // Evening notification 60 mins before sleep time
    int eveningHour = sleep.hour;
    int eveningMinute = sleep.minute - 60;
    if (eveningMinute < 0) {
      eveningMinute += 60;
      eveningHour = (eveningHour - 1) % 24;
    }
    final eveningTimeStr = '${eveningHour.toString().padLeft(2, '0')}:${eveningMinute.toString().padLeft(2, '0')}';

    await NotificationService.scheduleTaskReminders(
      taskId: 'remell_daily_morning_plan',
      title: 'Time to plan your day ☀️',
      dueTime: wakeTimeStr,
      durationMinutes: 10,
    );

    await NotificationService.scheduleTaskReminders(
      taskId: 'remell_daily_evening_plan',
      title: 'List down tomorrow\'s plans 🌙',
      dueTime: eveningTimeStr,
      durationMinutes: 10,
    );
  }
}
