import 'package:flutter_riverpod/flutter_riverpod.dart';

class MissedTaskInfo {
  final String id;
  final String title;
  final String duration;
  final String? dueTime;
  final String timeSegment;
  // ISO date the task was missed (e.g. '2026-09-08')
  final String missedDate;

  const MissedTaskInfo({
    required this.id,
    required this.title,
    required this.duration,
    this.dueTime,
    required this.timeSegment,
    required this.missedDate,
  });
}

class InAppNotificationData {
  final String title;
  final String? body;
  final bool isUnfinished;
  final bool isMissedTask;
  final String? taskId;
  final Duration? duration;
  final List<MissedTaskInfo> missedTasks;

  const InAppNotificationData({
    required this.title,
    this.body,
    this.isUnfinished = false,
    this.isMissedTask = false,
    this.taskId,
    this.duration,
    this.missedTasks = const [],
  });
}

final inAppNotificationProvider = StateProvider<InAppNotificationData?>((ref) => null);
