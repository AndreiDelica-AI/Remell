import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'streak_provider.dart';
import '../services/day_plan_service.dart';
import '../utils/nlp_parser.dart';

String removeEmojis(String input) {
  return input.replaceAll(RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true), '').trim();
}

List<SubTaskItem> parseSubtasksFromNotes(String notes) {
  if (notes.trim().isEmpty || notes == 'No notes added.') return [];
  final steps = NlpParser.parseSubtasks(notes);
  if (steps.isNotEmpty) {
    return steps.map((s) => SubTaskItem(title: s, scheduledTime: NlpParser.parseDeadline(s))).toList();
  }
  final lines = notes.split(RegExp(r'\r?\n'));
  final List<SubTaskItem> items = [];
  for (var line in lines) {
    var cleaned = removeEmojis(line.trim());
    if (cleaned.isEmpty) continue;
    if (cleaned.startsWith('-') || cleaned.startsWith('*') || cleaned.startsWith('•')) {
      cleaned = cleaned.substring(1).trim();
    } else {
      final match = RegExp(r'^\d+[\.\)]\s*').firstMatch(cleaned);
      if (match != null) {
        cleaned = cleaned.substring(match.end).trim();
      }
    }
    if (cleaned.isNotEmpty) {
      items.add(SubTaskItem(title: cleaned, scheduledTime: NlpParser.parseDeadline(cleaned)));
    }
  }
  return items;
}

class SubTaskItem {
  final String? id;
  final String title;
  bool isCompleted;
  final String? scheduledTime; // e.g. '09:00', '10:00', '11:00'

  SubTaskItem({this.id, required this.title, this.isCompleted = false, this.scheduledTime});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'scheduledTime': scheduledTime,
      };

  factory SubTaskItem.fromJson(Map<String, dynamic> json) => SubTaskItem(
        id: json['id']?.toString(),
        title: json['title'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
        scheduledTime: json['scheduledTime'] ?? json['time'] ?? NlpParser.parseDeadline(json['title'] ?? ''),
      );
}

class QuickTaskItem {
  final String id;
  final String title;
  final String time;
  final int durationMinutes;
  final String notes;
  final bool isUrgent;
  final String difficulty; // 'low', 'medium', 'high'
  final String? dueTime;   // e.g. '10:20'
  final List<SubTaskItem> subtasks;
  final String? colorHex;
  final String? iconName;

  QuickTaskItem({
    required this.id,
    required this.title,
    required this.time,
    required this.durationMinutes,
    required this.notes,
    this.isUrgent = false,
    this.difficulty = 'medium',
    this.dueTime,
    required this.subtasks,
    this.colorHex,
    this.iconName,
  });

  bool get isCompleted => subtasks.isNotEmpty && subtasks.every((st) => st.isCompleted);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': time,
        'durationMinutes': durationMinutes,
        'notes': notes,
        'isUrgent': isUrgent,
        'difficulty': difficulty,
        'dueTime': dueTime,
        'colorHex': colorHex,
        'iconName': iconName,
        'subtasks': subtasks.map((st) => st.toJson()).toList(),
      };

  factory QuickTaskItem.fromJson(Map<String, dynamic> json) => QuickTaskItem(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? '',
        time: json['time'] ?? 'Just now',
        durationMinutes: json['durationMinutes'] ?? 10,
        notes: json['notes'] ?? '',
        isUrgent: json['isUrgent'] ?? false,
        difficulty: json['difficulty'] ?? 'medium',
        dueTime: json['dueTime'],
        colorHex: json['colorHex'],
        iconName: json['iconName'],
        subtasks: (json['subtasks'] as List? ?? [])
            .map((st) => SubTaskItem.fromJson(st))
            .toList(),
      );
}

class FocusTaskItem {
  final String id;
  final String title;
  final String duration;
  final String timeSegment; // 'Morning', 'Afternoon', 'Night'
  final String notes;
  final List<SubTaskItem> subtasks;
  final String difficulty; // 'low', 'medium', 'high'
  final String? dueTime;   // e.g. '10:20'
  final List<String> repeatDays;
  final String? colorHex;
  final String? iconName;
  final bool isCompleted;
  final DateTime? repeatUntil;     // end date for recurring tasks
  final List<String> skippedDates; // ISO date strings skipped (e.g. '2026-09-08')

  FocusTaskItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.timeSegment,
    required this.notes,
    required this.subtasks,
    this.difficulty = 'medium',
    this.dueTime,
    this.repeatDays = const [],
    this.colorHex,
    this.iconName,
    this.isCompleted = false,
    this.repeatUntil,
    this.skippedDates = const [],
  });

  bool get isDone => isCompleted || (subtasks.isNotEmpty && subtasks.every((st) => st.isCompleted));

  int get durationMinutes {
    int total = 0;
    final hrMatch = RegExp(r'(\d+)\s*(?:hr|hrs|hour|hours|h)\b', caseSensitive: false).firstMatch(duration);
    if (hrMatch != null) {
      total += (int.tryParse(hrMatch.group(1)!) ?? 0) * 60;
    }
    final minMatch = RegExp(r'(\d+)\s*(?:min|mins|minute|minutes|m)\b', caseSensitive: false).firstMatch(duration);
    if (minMatch != null) {
      total += (int.tryParse(minMatch.group(1)!) ?? 0);
    }
    if (total == 0) {
      final digits = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), ''));
      if (digits != null) {
        total = digits;
      }
    }
    return total;
  }

  double get completionPercentage {
    if (isDone) return 1.0;
    if (subtasks.isEmpty) return 0.0;
    final completedCount = subtasks.where((st) => st.isCompleted).length;
    return completedCount / subtasks.length;
  }
}

class QuickTasksNotifier extends StateNotifier<List<QuickTaskItem>> {
  final Ref ref;

  QuickTasksNotifier(this.ref) : super([]) {
    _loadTasks();
  }

  int completedCount = 0;

  String _getUserKey() {
    final user = ref.read(authUserProvider);
    final userEmail = user?['email'] ?? user?['id'] ?? 'guest';
    return 'remell_quick_tasks_$userEmail';
  }

  Future<void> _loadTasks() async {
    try {
      final token = ref.read(authTokenProvider);
      if (token != null) {
        final dio = ref.read(apiClientProvider).client;
        final response = await dio.get('/quick-tasks');
        if (response.statusCode == 200 && response.data['data'] != null) {
          final List rawList = response.data['data'] is List ? response.data['data'] : [];
          state = rawList.map((item) {
            final String rawDesc = item['notes'] ?? '';
            return QuickTaskItem(
              id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              title: item['title'] ?? '',
              time: 'Just now',
              durationMinutes: 10,
              notes: rawDesc,
              isUrgent: item['priority'] == 'high',
              difficulty: item['priority'] ?? 'medium',
              dueTime: null,
              subtasks: parseSubtasksFromNotes(rawDesc),
            );
          }).toList();
          _saveLocalTasks();
          return;
        }
      }
    } catch (e) {
      debugPrint('[QuickTasks] Failed to fetch from backend API: $e');
    }
    _loadLocalTasks();
  }

  void _saveLocalTasks() {
    if (!kIsWeb) return;
    try {
      final key = _getUserKey();
      final list = state.map((item) => item.toJson()).toList();
      final jsonStr = jsonEncode(list);
      html.window.localStorage[key] = jsonStr;
    } catch (_) {}
  }

  void _loadLocalTasks() {
    if (!kIsWeb) {
      state = [];
      return;
    }
    try {
      final key = _getUserKey();
      final jsonStr = html.window.localStorage[key];
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        state = decoded.map((item) {
          final q = QuickTaskItem.fromJson(item);
          if (q.subtasks.isEmpty && q.notes.isNotEmpty) {
            return QuickTaskItem(
              id: q.id,
              title: q.title,
              time: q.time,
              durationMinutes: q.durationMinutes,
              notes: q.notes,
              isUrgent: q.isUrgent,
              difficulty: q.difficulty,
              dueTime: q.dueTime,
              subtasks: parseSubtasksFromNotes(q.notes),
              colorHex: q.colorHex,
              iconName: q.iconName,
            );
          }
          return q;
        }).toList();
        return;
      }
    } catch (_) {}
    state = [];
  }

  Future<void> add(String title, int duration, String notes,
      {bool isUrgent = false, String difficulty = 'medium', String? dueTime, List<String>? steps}) async {
    final cleanNotes = notes.isNotEmpty ? notes : 'No notes added.';
    final subtasks = (steps != null && steps.isNotEmpty)
        ? steps.map((s) => SubTaskItem(title: s, scheduledTime: NlpParser.parseDeadline(s))).toList()
        : parseSubtasksFromNotes(cleanNotes);

    String createdId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      final token = ref.read(authTokenProvider);
      if (token != null) {
        final dio = ref.read(apiClientProvider).client;
        final response = await dio.post('/quick-tasks', data: {
          'title': title,
          'notes': cleanNotes,
          'priority': isUrgent ? 'high' : difficulty,
        });
        if (response.statusCode == 201 && response.data['data'] != null) {
          createdId = response.data['data']['id']?.toString() ?? createdId;
        }
      }
    } catch (e) {
      debugPrint('[QuickTasks] Backend add failed: $e');
    }

    final newTask = QuickTaskItem(
      id: createdId,
      title: title,
      time: 'Just now',
      durationMinutes: duration,
      notes: cleanNotes,
      isUrgent: isUrgent,
      difficulty: difficulty,
      dueTime: dueTime,
      subtasks: subtasks,
    );

    state = [newTask, ...state];
    _saveLocalTasks();
  }

  Future<void> removeAt(int index, {bool isCompleted = true}) async {
    if (index >= state.length) return;
    final task = state[index];

    try {
      final token = ref.read(authTokenProvider);
      if (token != null) {
        final dio = ref.read(apiClientProvider).client;
        await dio.post('/quick-tasks/${task.id}/complete');
      }
    } catch (e) {
      debugPrint('[QuickTasks] Backend complete failed: $e');
    }

    if (isCompleted) {
      completedCount++;
      DayPlanService.recordCompletedTask(task.title, type: 'Quick Note');
      ref.read(streakProvider.notifier).recordCompletion();
      if (kIsWeb) {
        try {
          html.window.dispatchEvent(html.Event('triggerConfetti'));
        } catch (_) {}
      }
    }

    state = List.from(state)..removeAt(index);
    _saveLocalTasks();
  }

  void insert(int index, QuickTaskItem task) {
    state = List.from(state)..insert(index, task);
    if (completedCount > 0) completedCount--;
    _saveLocalTasks();
  }

  void toggleSubtask(String taskId, int index) {
    state = state.map((task) {
      if (task.id == taskId) {
        final existingSubtasks = task.subtasks.isNotEmpty
            ? task.subtasks
            : parseSubtasksFromNotes(task.notes);
        final updatedSubtasks = List<SubTaskItem>.from(
          existingSubtasks.map((st) => SubTaskItem(
            id: st.id,
            title: st.title,
            isCompleted: st.isCompleted,
            scheduledTime: st.scheduledTime ?? NlpParser.parseDeadline(st.title),
          )),
        );
        if (index < updatedSubtasks.length) {
          updatedSubtasks[index].isCompleted = !updatedSubtasks[index].isCompleted;
        }
        return QuickTaskItem(
          id: task.id,
          title: task.title,
          time: task.time,
          durationMinutes: task.durationMinutes,
          notes: task.notes,
          isUrgent: task.isUrgent,
          difficulty: task.difficulty,
          dueTime: task.dueTime,
          subtasks: updatedSubtasks,
          colorHex: task.colorHex,
          iconName: task.iconName,
        );
      }
      return task;
    }).toList();
    _saveLocalTasks();
  }

  Future<void> updateTask(String id, String title, int duration, String notes,
      {bool isUrgent = false, String difficulty = 'medium', String? dueTime, List<String>? steps}) async {
    state = state.map((task) {
      if (task.id == id) {
        final subtasks = (steps != null && steps.isNotEmpty)
            ? steps.map((s) => SubTaskItem(title: s, scheduledTime: NlpParser.parseDeadline(s))).toList()
            : parseSubtasksFromNotes(notes);
        return QuickTaskItem(
          id: id,
          title: title,
          time: task.time,
          durationMinutes: duration,
          notes: notes,
          isUrgent: isUrgent,
          difficulty: difficulty,
          dueTime: dueTime,
          subtasks: subtasks,
          colorHex: task.colorHex,
          iconName: task.iconName,
        );
      }
      return task;
    }).toList();
    _saveLocalTasks();
  }

  void clearAll() {
    state = [];
    completedCount = 0;
    _saveLocalTasks();
  }

  void resetForAccountChange() {
    state = [];
    completedCount = 0;
  }
}

final quickTasksProvider = StateNotifierProvider<QuickTasksNotifier, List<QuickTaskItem>>((ref) {
  ref.watch(authTokenProvider);
  ref.watch(authUserProvider);
  return QuickTasksNotifier(ref);
});

class ActiveTaskTimerState {
  final QuickTaskItem? activeTask;
  final bool isRunning;
  final int secondsRemaining;
  final int totalSeconds;

  int get timeLeftSeconds => secondsRemaining;
  int get totalDurationSeconds => totalSeconds;

  ActiveTaskTimerState({
    this.activeTask,
    this.isRunning = false,
    this.secondsRemaining = 0,
    this.totalSeconds = 0,
  });

  double get progress {
    if (totalSeconds <= 0) return 0.0;
    return (totalSeconds - secondsRemaining) / totalSeconds;
  }
}

class ActiveTaskTimerNotifier extends StateNotifier<ActiveTaskTimerState> {
  final Ref ref;
  Timer? _timer;

  ActiveTaskTimerNotifier(this.ref) : super(ActiveTaskTimerState());

  void start(QuickTaskItem task, {bool isTrialMode = false}) => startTask(task);
  void startTask(QuickTaskItem task) {
    _timer?.cancel();
    final totalSec = task.durationMinutes * 60;
    state = ActiveTaskTimerState(
      activeTask: task,
      isRunning: true,
      secondsRemaining: totalSec,
      totalSeconds: totalSec,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining > 0) {
        state = ActiveTaskTimerState(
          activeTask: state.activeTask,
          isRunning: true,
          secondsRemaining: state.secondsRemaining - 1,
          totalSeconds: state.totalSeconds,
        );
      } else {
        _timer?.cancel();
        completeEarly();
      }
    });
  }

  void pause() {
    _timer?.cancel();
    state = ActiveTaskTimerState(
      activeTask: state.activeTask,
      isRunning: false,
      secondsRemaining: state.secondsRemaining,
      totalSeconds: state.totalSeconds,
    );
  }

  void resume() {
    if (state.activeTask == null || state.secondsRemaining <= 0) return;
    _timer?.cancel();
    state = ActiveTaskTimerState(
      activeTask: state.activeTask,
      isRunning: true,
      secondsRemaining: state.secondsRemaining,
      totalSeconds: state.totalSeconds,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining > 0) {
        state = ActiveTaskTimerState(
          activeTask: state.activeTask,
          isRunning: true,
          secondsRemaining: state.secondsRemaining - 1,
          totalSeconds: state.totalSeconds,
        );
      } else {
        _timer?.cancel();
        completeEarly();
      }
    });
  }

  void completeEarly() {
    _timer?.cancel();
    if (state.activeTask != null) {
      final tasksNotifier = ref.read(quickTasksProvider.notifier);
      final tasks = ref.read(quickTasksProvider);
      final idx = tasks.indexWhere((t) => t.id == state.activeTask!.id);
      if (idx != -1) {
        tasksNotifier.removeAt(idx, isCompleted: true);
      }
    }
    state = ActiveTaskTimerState();
  }

  void convertTrialToTask(int durationMinutes) {
    if (state.activeTask != null) {
      final task = state.activeTask!;
      _timer?.cancel();
      ref.read(quickTasksProvider.notifier).add(
        task.title,
        durationMinutes,
        task.notes,
        isUrgent: task.isUrgent,
        difficulty: task.difficulty,
        dueTime: task.dueTime,
      );
      state = ActiveTaskTimerState();
    }
  }

  void skip() {
    _timer?.cancel();
    state = ActiveTaskTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final activeTaskTimerProvider = StateNotifierProvider<ActiveTaskTimerNotifier, ActiveTaskTimerState>((ref) {
  return ActiveTaskTimerNotifier(ref);
});

class FocusTasksNotifier extends StateNotifier<List<FocusTaskItem>> {
  final Ref ref;

  FocusTasksNotifier(this.ref) : super([]) {
    _loadTasks();
  }

  int completedCount = 0;

  final Map<String, List<bool>> segmentStreakHistory = {
    'Morning': [false, false, false, false, false, false, false],
    'Afternoon': [false, false, false, false, false, false, false],
    'Night': [false, false, false, false, false, false, false],
  };

  String _getUserKey() {
    final user = ref.read(authUserProvider);
    final userEmail = user?['email'] ?? user?['id'] ?? 'guest';
    return 'remell_focus_tasks_$userEmail';
  }

  Future<void> _loadTasks() async {
    try {
      final token = ref.read(authTokenProvider);
      if (token != null) {
        final dio = ref.read(apiClientProvider).client;
        final response = await dio.get('/focus');
        if (response.statusCode == 200) {
          final List data = response.data['data'] is List ? response.data['data'] : (response.data['data'] != null ? [response.data['data']] : []);

          state = data.map((taskData) {
            final List subtasksList = taskData['subtasks'] ?? [];
            final rawDesc = taskData['description'] ?? '';
            String? dueTime;
            List<String> repeatDays = [];
            String? colorHex;
            String? iconName;

            String notes = rawDesc;
            String parseStr = rawDesc;
            if (parseStr.contains('[colorHex: ')) {
              final start = parseStr.indexOf('[colorHex: ');
              final end = parseStr.indexOf(']', start);
              if (end != -1) {
                colorHex = parseStr.substring(start + 11, end);
                parseStr = (parseStr.substring(0, start) + parseStr.substring(end + 1)).trim();
              }
            }
            if (parseStr.contains('[iconName: ')) {
              final start = parseStr.indexOf('[iconName: ');
              final end = parseStr.indexOf(']', start);
              if (end != -1) {
                iconName = parseStr.substring(start + 11, end);
                parseStr = (parseStr.substring(0, start) + parseStr.substring(end + 1)).trim();
              }
            }
            if (parseStr.startsWith('[repeatDays: ')) {
              final idx = parseStr.indexOf(']');
              if (idx != -1) {
                final daysStr = parseStr.substring(13, idx);
                if (daysStr.isNotEmpty) {
                  repeatDays = daysStr.split(',');
                }
                parseStr = parseStr.substring(idx + 1).trim();
              }
            }
            if (parseStr.startsWith('[dueTime: ')) {
              final idx = parseStr.indexOf(']');
              if (idx != -1) {
                dueTime = parseStr.substring(10, idx);
                notes = parseStr.substring(idx + 1).trim();
              }
            } else {
              notes = parseStr;
            }

            final List<SubTaskItem> loadedSubtasks = subtasksList.map((st) => SubTaskItem(
                  id: st['id']?.toString(),
                  title: st['title'] ?? '',
                  isCompleted: st['status'] == 'completed',
                )).toList();

            return FocusTaskItem(
              id: taskData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              title: taskData['title'] ?? '',
              duration: formatDuration(taskData['estimatedMinutes'] as int? ?? 0),
              timeSegment: taskData['priority'] == 'high' ? 'Night' : (taskData['priority'] == 'medium' ? 'Afternoon' : 'Morning'),
              notes: notes,
              difficulty: taskData['priority'] ?? 'medium',
              dueTime: dueTime,
              repeatDays: repeatDays,
              colorHex: colorHex,
              iconName: iconName,
              isCompleted: taskData['status'] == 'completed',
              subtasks: loadedSubtasks.isNotEmpty ? loadedSubtasks : parseSubtasksFromNotes(notes),
            );
          }).toList();
          _saveLocalTasks();
          return;
        }
      }
    } catch (e) {
      debugPrint('[FocusTasks] Backend load failed: $e');
    }
    _loadLocalTasks();
  }

  void _saveLocalTasks() {
    if (!kIsWeb) return;
    try {
      final key = _getUserKey();
      final list = state.map((item) => {
        'id': item.id,
        'title': item.title,
        'duration': item.duration,
        'timeSegment': item.timeSegment,
        'notes': item.notes,
        'difficulty': item.difficulty,
        'dueTime': item.dueTime,
        'repeatDays': item.repeatDays,
        'colorHex': item.colorHex,
        'iconName': item.iconName,
        'isCompleted': item.isCompleted,
        'subtasks': item.subtasks.map((st) => st.toJson()).toList(),
        'repeatUntil': item.repeatUntil?.toIso8601String(),
        'skippedDates': item.skippedDates,
      }).toList();
      final jsonStr = jsonEncode(list);
      html.window.localStorage[key] = jsonStr;
    } catch (_) {}
  }

  void _loadLocalTasks() {
    if (!kIsWeb) {
      state = [];
      return;
    }
    try {
      final key = _getUserKey();
      final jsonStr = html.window.localStorage[key];
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        state = decoded.map((item) {
          final String notes = item['notes'] ?? '';
          final List rawSubtasks = item['subtasks'] as List? ?? [];
          final List<SubTaskItem> subtasks = rawSubtasks.isNotEmpty
              ? rawSubtasks.map((st) => SubTaskItem.fromJson(st)).toList()
              : parseSubtasksFromNotes(notes);

          final String? untilStr = item['repeatUntil'] as String?;
          return FocusTaskItem(
            id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: item['title'] ?? '',
            duration: item['duration'] ?? '20 min',
            timeSegment: item['timeSegment'] ?? 'Morning',
            notes: notes,
            difficulty: item['difficulty'] ?? 'medium',
            dueTime: item['dueTime'],
            repeatDays: (item['repeatDays'] as List? ?? []).cast<String>(),
            colorHex: item['colorHex'],
            iconName: item['iconName'],
            isCompleted: item['isCompleted'] == true,
            subtasks: subtasks,
            repeatUntil: untilStr != null ? DateTime.tryParse(untilStr) : null,
            skippedDates: (item['skippedDates'] as List? ?? []).cast<String>(),
          );
        }).toList();
        return;
      }
    } catch (_) {}
    state = [];
  }

  String formatDuration(int minutes) {
    if (minutes <= 0) return '0 min';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours hr${hours > 1 ? "s" : ""}';
    }
    return '$hours hr $remainingMinutes min';
  }

  Future<void> add(String title, String timeSegment, String notes, List<String> steps,
      {String difficulty = 'medium', String? dueTime, int? durationMinutes, List<String> repeatDays = const [],
      String? colorHex, String? iconName, DateTime? repeatUntil}) async {
    try {
      final token = ref.read(authTokenProvider);
      final int estimatedMin = durationMinutes ?? (steps.isNotEmpty ? steps.length * 10 : 20);

      if (token == null) {
        _localAdd(title, timeSegment, notes, steps, difficulty: difficulty, dueTime: dueTime,
            durationMinutes: estimatedMin, repeatDays: repeatDays, colorHex: colorHex,
            iconName: iconName, repeatUntil: repeatUntil);
        return;
      }

      final dio = ref.read(apiClientProvider).client;
      String backendDesc = notes;
      if (colorHex != null && colorHex.isNotEmpty) {
        backendDesc = '[colorHex: $colorHex] $backendDesc';
      }
      if (iconName != null && iconName.isNotEmpty) {
        backendDesc = '[iconName: $iconName] $backendDesc';
      }
      if (dueTime != null) {
        backendDesc = '[dueTime: $dueTime] $backendDesc';
      }
      if (repeatDays.isNotEmpty) {
        backendDesc = '[repeatDays: ${repeatDays.join(",")}] $backendDesc';
      }
      if (repeatUntil != null) {
        backendDesc = '[repeatUntil: ${repeatUntil.toIso8601String()}] $backendDesc';
      }

      await dio.post('/focus', data: {
        'title': title,
        'description': backendDesc,
        'estimatedMinutes': estimatedMin,
        'priority': difficulty,
      });
      await _loadTasks();
    } catch (e) {
      final int estimatedMin = durationMinutes ?? (steps.isNotEmpty ? steps.length * 10 : 20);
      _localAdd(title, timeSegment, notes, steps, difficulty: difficulty, dueTime: dueTime,
          durationMinutes: estimatedMin, repeatDays: repeatDays, colorHex: colorHex,
          iconName: iconName, repeatUntil: repeatUntil);
    }
  }

  void _localAdd(String title, String timeSegment, String notes, List<String> steps,
      {String difficulty = 'medium', String? dueTime, int? durationMinutes,
      List<String> repeatDays = const [], String? colorHex, String? iconName, DateTime? repeatUntil}) {
    final subtasks = steps.isNotEmpty
        ? steps.map((s) => SubTaskItem(title: s, scheduledTime: NlpParser.parseDeadline(s))).toList()
        : parseSubtasksFromNotes(notes);

    final int estimatedMin = durationMinutes ?? (steps.isNotEmpty ? steps.length * 10 : 20);

    state = [
      ...state,
      FocusTaskItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        duration: formatDuration(estimatedMin),
        timeSegment: timeSegment,
        notes: notes,
        difficulty: difficulty,
        dueTime: dueTime,
        repeatDays: repeatDays,
        colorHex: colorHex,
        iconName: iconName,
        subtasks: subtasks,
        repeatUntil: repeatUntil,
      )
    ];
    _saveLocalTasks();
  }

  /// Skip a single occurrence of a recurring task on a given date.
  /// Adds the ISO date string (yyyy-MM-dd) to the task's skippedDates list.
  void skipOccurrence(String taskId, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    state = state.map((task) {
      if (task.id != taskId) return task;
      final newSkipped = [...task.skippedDates, dateStr];
      return FocusTaskItem(
        id: task.id, title: task.title, duration: task.duration,
        timeSegment: task.timeSegment, notes: task.notes, difficulty: task.difficulty,
        dueTime: task.dueTime, repeatDays: task.repeatDays, colorHex: task.colorHex,
        iconName: task.iconName, subtasks: task.subtasks, isCompleted: task.isCompleted,
        repeatUntil: task.repeatUntil, skippedDates: newSkipped,
      );
    }).toList();
    _saveLocalTasks();
  }

  void toggleSubTask(String focusTaskId, int subtaskIndex) {
    toggleSubtask(focusTaskId, subtaskIndex);
  }

  void _checkDailyStreakThreshold() {
    final totalDailyTasks = state.length;
    if (totalDailyTasks == 0) return;
    final completedDailyTasks = state.where((t) => t.isDone).length;
    final streakExtended = ref.read(streakProvider.notifier).evaluateDailyTasksStreak(
      totalDailyTasks: totalDailyTasks,
      completedDailyTasks: completedDailyTasks,
    );

    if (streakExtended && kIsWeb) {
      try {
        html.window.dispatchEvent(html.Event('triggerConfetti'));
      } catch (_) {}
    }
  }

  void toggleSubtask(String focusTaskId, int subtaskIndex) {
    state = state.map((task) {
      if (task.id == focusTaskId) {
        final existingSubtasks = task.subtasks.isNotEmpty
            ? task.subtasks
            : parseSubtasksFromNotes(task.notes);
        final newSubtasks = List<SubTaskItem>.from(
          existingSubtasks.map((st) => SubTaskItem(
            id: st.id,
            title: st.title,
            isCompleted: st.isCompleted,
            scheduledTime: st.scheduledTime ?? NlpParser.parseDeadline(st.title),
          )),
        );
        if (subtaskIndex < newSubtasks.length) {
          newSubtasks[subtaskIndex].isCompleted = !newSubtasks[subtaskIndex].isCompleted;
        }

        final bool allDone = newSubtasks.isNotEmpty && newSubtasks.every((st) => st.isCompleted);
        if (allDone) {
          DayPlanService.recordCompletedTask(task.title, type: 'Focus Task');
          if (segmentStreakHistory.containsKey(task.timeSegment)) {
            segmentStreakHistory[task.timeSegment]![6] = true;
          }
        }

        return FocusTaskItem(
          id: task.id,
          title: task.title,
          duration: task.duration,
          timeSegment: task.timeSegment,
          notes: task.notes,
          difficulty: task.difficulty,
          dueTime: task.dueTime,
          repeatDays: task.repeatDays,
          colorHex: task.colorHex,
          iconName: task.iconName,
          subtasks: newSubtasks,
          repeatUntil: task.repeatUntil,
          skippedDates: task.skippedDates,
        );
      }
      return task;
    }).toList();
    _saveLocalTasks();
    _checkDailyStreakThreshold();
  }

  void toggleTaskCompletion(String focusTaskId) {
    state = state.map((task) {
      if (task.id == focusTaskId) {
        final newDoneState = !task.isDone;
        final updatedSubtasks = task.subtasks.map((st) => SubTaskItem(
          id: st.id,
          title: st.title,
          isCompleted: newDoneState,
          scheduledTime: st.scheduledTime ?? NlpParser.parseDeadline(st.title),
        )).toList();

        if (newDoneState) {
          DayPlanService.recordCompletedTask(task.title, type: 'Focus Task');
          if (segmentStreakHistory.containsKey(task.timeSegment)) {
            segmentStreakHistory[task.timeSegment]![6] = true;
          }
        }

        return FocusTaskItem(
          id: task.id,
          title: task.title,
          duration: task.duration,
          timeSegment: task.timeSegment,
          notes: task.notes,
          difficulty: task.difficulty,
          dueTime: task.dueTime,
          repeatDays: task.repeatDays,
          colorHex: task.colorHex,
          iconName: task.iconName,
          subtasks: updatedSubtasks,
          isCompleted: newDoneState,
          repeatUntil: task.repeatUntil,
          skippedDates: task.skippedDates,
        );
      }
      return task;
    }).toList();
    _saveLocalTasks();
    _checkDailyStreakThreshold();
  }


  void updateTaskNotes(String id, String newNotes) {
    state = state.map((task) {
      if (task.id == id) {
        final newSubtasks = parseSubtasksFromNotes(newNotes);
        return FocusTaskItem(
          id: task.id,
          title: task.title,
          duration: task.duration,
          timeSegment: task.timeSegment,
          notes: newNotes,
          difficulty: task.difficulty,
          dueTime: task.dueTime,
          repeatDays: task.repeatDays,
          colorHex: task.colorHex,
          iconName: task.iconName,
          subtasks: newSubtasks,
          repeatUntil: task.repeatUntil,
          skippedDates: task.skippedDates,
        );
      }
      return task;
    }).toList();
    _saveLocalTasks();
  }

  void updateTask(String id, String title, String timeSegment, String notes, List<String> steps,
      {String difficulty = 'medium', String? dueTime, int? durationMinutes,
      List<String> repeatDays = const [], String? colorHex, String? iconName,
      DateTime? repeatUntil, bool clearRepeatUntil = false}) {
    state = state.map((task) {
      if (task.id == id) {
        List<SubTaskItem> subtasks;
        if (steps.isNotEmpty) {
          subtasks = steps.map((s) {
            final existing = task.subtasks.firstWhere(
              (st) => st.title.toLowerCase().trim() == s.toLowerCase().trim(),
              orElse: () => SubTaskItem(title: s, scheduledTime: NlpParser.parseDeadline(s)),
            );
            return SubTaskItem(
              id: existing.id,
              title: s,
              isCompleted: existing.isCompleted,
              scheduledTime: existing.scheduledTime ?? NlpParser.parseDeadline(s),
            );
          }).toList();
        } else {
          subtasks = task.subtasks.isNotEmpty ? task.subtasks : parseSubtasksFromNotes(notes);
        }

        final int estimatedMin = durationMinutes ?? (steps.isNotEmpty ? steps.length * 10 : 20);

        return FocusTaskItem(
          id: id,
          title: title,
          duration: formatDuration(estimatedMin),
          timeSegment: timeSegment,
          notes: notes,
          difficulty: difficulty,
          dueTime: dueTime ?? task.dueTime,
          repeatDays: repeatDays.isNotEmpty ? repeatDays : task.repeatDays,
          colorHex: colorHex ?? task.colorHex,
          iconName: iconName ?? task.iconName,
          subtasks: subtasks,
          isCompleted: task.isCompleted,
          repeatUntil: clearRepeatUntil ? null : (repeatUntil ?? task.repeatUntil),
          skippedDates: task.skippedDates,
        );
      }
      return task;
    }).toList();
    _saveLocalTasks();
  }

  Future<void> removeTaskById(String id) async {
    try {
      final token = ref.read(authTokenProvider);
      if (token == null) {
        _localRemove(id);
        return;
      }
      final dio = ref.read(apiClientProvider).client;
      await dio.post('/focus/$id/complete');
      _localRemove(id);
    } catch (e) {
      _localRemove(id);
    }
  }

  void _localRemove(String id) {
    final index = state.indexWhere((task) => task.id == id);
    if (index != -1) {
      state = List.from(state)..removeAt(index);
      completedCount++;
      _saveLocalTasks();
    }
  }

  Future<void> clearAll() async {
    try {
      final token = ref.read(authTokenProvider);
      if (token != null) {
        final dio = ref.read(apiClientProvider).client;
        for (var task in state) {
          try {
            await dio.delete('/focus/${task.id}');
          } catch (_) {}
        }
      }
    } catch (_) {}
    state = [];
    completedCount = 0;
    _saveLocalTasks();
  }

  void resetForAccountChange() {
    state = [];
    completedCount = 0;
  }
}

final focusTasksProvider = StateNotifierProvider<FocusTasksNotifier, List<FocusTaskItem>>((ref) {
  ref.watch(authTokenProvider);
  ref.watch(authUserProvider);
  return FocusTasksNotifier(ref);
});

final activeFocusTaskIdProvider = StateProvider<String?>((ref) => null);
final isTrialModeProvider = StateProvider<bool>((ref) => false);

class DoomScrollState {
  final bool isActive;
  final DateTime? startTime;
  final Duration? budget;
  final bool limitReached;

  DoomScrollState({
    this.isActive = false,
    this.startTime,
    this.budget,
    this.limitReached = false,
  });
}

class DoomScrollNotifier extends StateNotifier<DoomScrollState> {
  Timer? _timer;

  DoomScrollNotifier() : super(DoomScrollState());

  void startSession(Duration budget) {
    _timer?.cancel();
    state = DoomScrollState(
      isActive: true,
      startTime: DateTime.now(),
      budget: budget,
      limitReached: false,
    );

    _timer = Timer(budget, () {
      state = DoomScrollState(
        isActive: true,
        startTime: state.startTime,
        budget: state.budget,
        limitReached: true,
      );
    });
  }

  void startIntercept(Duration budget) {
    startSession(budget);
  }

  void reset() {
    endSession();
  }

  void setLimitReached() {
    state = DoomScrollState(
      isActive: state.isActive,
      startTime: state.startTime,
      budget: state.budget,
      limitReached: true,
    );
  }

  void endSession() {
    _timer?.cancel();
    state = DoomScrollState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final doomScrollProvider = StateNotifierProvider<DoomScrollNotifier, DoomScrollState>((ref) {
  return DoomScrollNotifier();
});

String formatDuration(int minutes) {
  if (minutes <= 0) return '0 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) {
    return '$hours hr${hours > 1 ? "s" : ""}';
  }
  return '$hours hr $remainingMinutes min';
}

String formatDurationShort(int minutes) {
  if (minutes <= 0) return '0m';
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) return '${hours}h';
  return '${hours}h ${remainingMinutes}m';
}

String formatTimeAmPm(String? dueTime) {
  if (dueTime == null || dueTime.trim().isEmpty) return '';
  final trimmed = dueTime.trim();
  if (trimmed.contains(':')) {
    final parts = trimmed.split(':');
    int? h = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
    if (h == null) return trimmed;
    final mStr = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '00';
    final m = int.tryParse(mStr) ?? 0;

    final lower = trimmed.toLowerCase();
    final isAlreadyPm = lower.contains('pm') || lower.contains('p.m.');
    final isAlreadyAm = lower.contains('am') || lower.contains('a.m.');

    String period;
    if (isAlreadyPm) {
      period = 'PM';
      if (h == 0) h = 12;
      if (h > 12) h -= 12;
    } else if (isAlreadyAm) {
      period = 'AM';
      if (h == 0) h = 12;
      if (h > 12) h -= 12;
    } else {
      period = h >= 12 ? 'PM' : 'AM';
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
    }
    final formattedM = m < 10 ? '0$m' : '$m';
    return '$h:$formattedM $period';
  }
  return trimmed;
}

String formatDurationString(String? duration) {
  if (duration == null || duration.trim().isEmpty) return '0 min';
  if (duration.contains('hr') || duration.contains('hour') || RegExp(r'\d+h\b').hasMatch(duration)) {
    return duration;
  }
  final digits = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), ''));
  if (digits != null) {
    return formatDuration(digits);
  }
  return duration;
}


