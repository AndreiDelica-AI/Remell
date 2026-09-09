import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreakState {
  final int currentStreak;
  final String? lastCompletionDate; // yyyy-MM-dd
  final List<String> completionHistory; // list of yyyy-MM-dd
  final bool showCelebration; // flag to trigger overlay dialog

  StreakState({
    required this.currentStreak,
    this.lastCompletionDate,
    required this.completionHistory,
    this.showCelebration = false,
  });

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'lastCompletionDate': lastCompletionDate,
        'completionHistory': completionHistory,
      };

  factory StreakState.fromJson(Map<String, dynamic> json) => StreakState(
        currentStreak: json['currentStreak'] ?? 0,
        lastCompletionDate: json['lastCompletionDate'],
        completionHistory: List<String>.from(json['completionHistory'] ?? []),
        showCelebration: false,
      );
}

class StreakNotifier extends StateNotifier<StreakState> {
  StreakNotifier() : super(StreakState(currentStreak: 0, completionHistory: [])) {
    _loadStreak();
  }

  static const String _keyStreak = 'remell_streak_state';

  void _loadStreak() {
    try {
      final jsonStr = html.window.localStorage[_keyStreak];
      if (jsonStr != null) {
        final loaded = StreakState.fromJson(jsonDecode(jsonStr));
        // Validate: if the last completion was more than 1 day ago, the streak is broken.
        final now = DateTime.now();
        final todayStr = _formatDate(now);
        final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));
        final lastDate = loaded.lastCompletionDate;
        final isStreakValid = lastDate == null ||
            lastDate == todayStr ||
            lastDate == yesterdayStr;

        if (isStreakValid) {
          state = loaded;
        } else {
          // Streak is broken — reset count but keep completion history
          state = StreakState(
            currentStreak: 0,
            lastCompletionDate: loaded.lastCompletionDate,
            completionHistory: loaded.completionHistory,
            showCelebration: false,
          );
          _saveStreak();
        }
      }
    } catch (_) {}
  }

  void _saveStreak() {
    try {
      final jsonStr = jsonEncode(state.toJson());
      html.window.localStorage[_keyStreak] = jsonStr;
    } catch (_) {}
  }

  void clearStreakHistory() {
    state = StreakState(currentStreak: 0, completionHistory: []);
    _saveStreak();
  }

  /// Called when a task (focus or quick note) is completed.
  /// Returns true if it extended the streak and should trigger a celebration!
  bool recordCompletion() {
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    
    // Check if already completed today
    if (state.completionHistory.contains(todayStr)) {
      // Already recorded today, no streak extension celebration needed
      return false;
    }

    final newHistory = List<String>.from(state.completionHistory)..add(todayStr);

    int newStreak = state.currentStreak;
    bool extended = false;

    if (state.lastCompletionDate == null) {
      // First task completed ever
      newStreak = 1;
      extended = true;
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = _formatDate(yesterday);

      if (state.lastCompletionDate == yesterdayStr) {
        // Extended yesterday's streak
        newStreak = state.currentStreak + 1;
        extended = true;
      } else if (state.lastCompletionDate == todayStr) {
        // Already completed today, no change
      } else {
        // Missed at least one day — reset streak back to 1
        newStreak = 1;
        extended = true;
      }
    }

    state = StreakState(
      currentStreak: newStreak,
      lastCompletionDate: todayStr,
      completionHistory: newHistory,
      showCelebration: extended,
    );
    
    _saveStreak();
    return extended;
  }

  /// Streak is strictly for daily tasks (FocusTaskItem).
  /// It is only awarded if the user completes at least 50% (half) of their total daily tasks.
  bool evaluateDailyTasksStreak({
    required int totalDailyTasks,
    required int completedDailyTasks,
  }) {
    if (totalDailyTasks == 0) return false;
    final double ratio = completedDailyTasks / totalDailyTasks;
    if (ratio >= 0.5) {
      return recordCompletion();
    }
    return false;
  }

  void dismissCelebration() {
    state = StreakState(
      currentStreak: state.currentStreak,
      lastCompletionDate: state.lastCompletionDate,
      completionHistory: state.completionHistory,
      showCelebration: false,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

final streakProvider = StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  return StreakNotifier();
});
