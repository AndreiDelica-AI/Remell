import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import 'dart:js' as js;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'core/router/app_router.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'shared/bottom_sheets/create_task_sheet.dart';
import 'shared/providers/tasks_provider.dart';
import 'shared/providers/energy_provider.dart';
import 'shared/widgets/time_background.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/streak_provider.dart';
import 'shared/widgets/streak_celebration_dialog.dart';
import 'package:go_router/go_router.dart';
import 'shared/services/notification_service.dart';
import 'shared/providers/notification_provider.dart';
import 'shared/services/day_plan_service.dart';
import 'shared/bottom_sheets/plan_tomorrow_sheet.dart';
import 'shared/dialogs/missed_tasks_dialog.dart';
import 'shared/services/smart_notification_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    debugPrint('[Initialization] Initializing NotificationService...');
    await NotificationService.initialize();
    debugPrint('[Initialization] NotificationService initialized successfully');
  } catch (e, stack) {
    debugPrint('[Initialization] NotificationService initialization failed: $e');
    debugPrint(stack.toString());
  }
  
  // Isar database and other core services initializations would go here in production
  
  runApp(
    const ProviderScope(
      child: RemellApp(),
    ),
  );
}

class RemellApp extends ConsumerWidget {
  const RemellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inter font from Google Fonts as required by typography PRD settings
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Remell',
      debugShowCheckedModeBanner: false,
      
      // Light Mode Color System (#FAFAFA Background, #FFFFFF Cards, #111827 Text, #2563EB Accent)
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
          primary: const Color(0xFF2563EB),
          surface: const Color(0xFFFFFFFF),
          background: const Color(0xFFFAFAFA),
        ),
        textTheme: textTheme.apply(
          bodyColor: const Color(0xFF111827),
          displayColor: const Color(0xFF111827),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF),
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF2563EB),
          unselectedItemColor: Color(0xFF6B7280),
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
      ),

      // Dark Mode Color System (#0F172A Background, #1E293B Cards, #F8FAFC Text, #2563EB Accent)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
          primary: const Color(0xFF2563EB),
          surface: const Color(0xFF1E293B),
          background: const Color(0xFF0F172A),
        ),
        textTheme: textTheme.apply(
          bodyColor: const Color(0xFFF8FAFC),
          displayColor: const Color(0xFFF8FAFC),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 0,
          margin: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E293B),
          selectedItemColor: Colors.white,
          unselectedItemColor: Color(0xFF94A3B8),
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
      ),

      themeMode: themeMode, // Supports System Theme by default
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _activeTimer;
  Timer? _startTimeTimer;
  Timer? _backgroundTimer;
  final Map<String, Set<int>> _notifiedThresholds = {};

  final List<Widget> _screens = [
    const QuickNotesScreen(),
    const ProgressScreen(),
    const DailyTasksScreen(),
    const SettingsScreen(),
  ];

  StreamSubscription? _notifClickSub;

  late AnimationController _fabAnimController;
  late Animation<double> _fabRotateAnim;
  late Animation<double> _fabExpandAnim;
  bool _isFabOpen = false;

  InAppNotificationData? _currentNotification;
  Timer? _notifDismissTimer;
  late AnimationController _notifAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fabRotateAnim = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
    _fabExpandAnim = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeOutBack,
    );

    _notifAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _notifClickSub = NotificationService.onNotificationClick.stream.listen((payload) {
      if (payload != null && payload.isNotEmpty) {
        if (mounted) {
          ref.read(activeFocusTaskIdProvider.notifier).state = payload;
          GoRouter.of(context).go('/focus');
        }
      }
    });

    // Check startTimes every 30 seconds for alerts
    _startTimeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkStartTimes();
        _checkDayPlanningWindows();
      }
    });

    // Schedule daily planning reminders once on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DayPlanService.scheduleDailyPlanningReminders();
      // Also trigger night check right away in case app opened during night window
      if (mounted) _checkDayPlanningWindows();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifClickSub?.cancel();
    _activeTimer?.cancel();
    _startTimeTimer?.cancel();
    _backgroundTimer?.cancel();
    _notifDismissTimer?.cancel();
    _notifAnimController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    if (_fabAnimController.isAnimating) return;
    if (_isFabOpen) {
      _closeFab();
    } else {
      _dismissInAppNotification();
      setState(() {
        _isFabOpen = true;
      });
      _fabAnimController.forward();
    }
  }

  void _closeFab() {
    if (_isFabOpen) {
      setState(() {
        _isFabOpen = false;
      });
      _fabAnimController.reverse();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _backgroundTimer?.cancel();
      // Start continuous notifications check every 10 seconds
      _backgroundTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        // 1. Active Task Reminder
        final active = ref.read(activeTaskTimerProvider);
        if (active.isRunning && active.activeTask != null) {
          final dueTime = active.activeTask!.dueTime;
          final durationMinutes = active.activeTask!.durationMinutes;
          final remainingMinutes = (active.secondsRemaining / 60).ceil();
          final minsLeft = remainingMinutes > 0 ? remainingMinutes : durationMinutes;
          _triggerGlobalNotification(
            'Unfinished Task',
            '${active.activeTask!.title} - $minsLeft mins left',
            isUnfinished: true,
            taskId: active.activeTask!.id,
          );
        }

        // 2. Doom Scroll Intercept
        final doom = ref.read(doomScrollProvider);
        if (doom.isActive && doom.startTime != null && doom.budget != null) {
          final elapsed = DateTime.now().difference(doom.startTime!);
          if (elapsed >= doom.budget!) {
            ref.read(doomScrollProvider.notifier).setLimitReached();
            _triggerGlobalNotification(
              'Focus Intercept',
              'Time limit reached (${elapsed.inMinutes}m). Tap to refocus.',
              isUnfinished: true,
            );
          }
        }

        // Cancel the periodic timer if neither is active
        final activeNow = ref.read(activeTaskTimerProvider);
        final doomNow = ref.read(doomScrollProvider);
        if (!activeNow.isRunning && !doomNow.isActive) {
          timer.cancel();
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _backgroundTimer?.cancel();
    }
  }

  String _getDayShortName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  /// Format minutes as "Xh Ym" or "Ym" or "Xh"
  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  void _checkSmartNotificationSchedule() {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final todayDayShort = _getDayShortName(now.weekday);
    final focusTasks = ref.read(focusTasksProvider);
    final quickTasks = ref.read(quickTasksProvider);
    final streakState = ref.read(streakProvider);

    // 1. Calculate today's quick tasks count
    final int todayQuickCount = quickTasks.length;

    // 2. Calculate today's unfinished focus tasks count
    final todayTasks = focusTasks.where((t) {
      if (t.repeatDays.isNotEmpty) {
        return t.repeatDays.any((d) => d.trim().toLowerCase() == todayDayShort.trim().toLowerCase());
      }
      return true;
    }).toList();
    final int todayUnfinishedCount = todayTasks.where((t) => !t.isDone).length;

    // 3. Calculate past missed tasks from prior days
    final List<MissedTaskInfo> missedList = [];
    for (int i = 1; i <= 14; i++) {
      final pastDate = todayDate.subtract(Duration(days: i));
      final pastDateStr = '${pastDate.year}-${pastDate.month.toString().padLeft(2, '0')}-${pastDate.day.toString().padLeft(2, '0')}';
      if (streakState.completionHistory.contains(pastDateStr)) continue;

      final dayShort = _getDayShortName(pastDate.weekday);
      final tasksForDay = focusTasks.where((t) {
        if (t.skippedDates.contains(pastDateStr)) return false;
        if (t.repeatUntil != null) {
          final until = DateTime(t.repeatUntil!.year, t.repeatUntil!.month, t.repeatUntil!.day);
          if (pastDate.isAfter(until)) return false;
        }
        if (t.repeatDays.isNotEmpty) {
          return t.repeatDays.any((d) => d.trim().toLowerCase() == dayShort.trim().toLowerCase());
        }
        return false;
      }).toList();

      for (final t in tasksForDay.where((t) => !t.isDone)) {
        missedList.add(MissedTaskInfo(
          id: t.id,
          title: t.title,
          duration: t.duration,
          dueTime: t.dueTime,
          timeSegment: t.timeSegment,
          missedDate: pastDateStr,
        ));
      }
    }
    final int pastMissedCount = missedList.length;

    final lastPush = SmartNotificationScheduler.getLastPushTime();
    final morningSent = SmartNotificationScheduler.hasSentMorningToday(now);
    final eveningSent = SmartNotificationScheduler.hasSentEveningToday(now);
    final snoozeUntil = SmartNotificationScheduler.getSnoozeUntil();

    final result = SmartNotificationScheduler.evaluateNotification(
      now: now,
      todayQuickCount: todayQuickCount,
      todayUnfinishedCount: todayUnfinishedCount,
      pastMissedCount: pastMissedCount,
      lastPushTime: lastPush,
      morningSentToday: morningSent,
      eveningSentToday: eveningSent,
      snoozeUntil: snoozeUntil,
    );

    if (result.shouldSend && result.title != null && result.body != null) {
      SmartNotificationScheduler.recordPushSent(now);
      _triggerGlobalNotification(
        result.title!,
        result.body!,
        isUnfinished: result.type == SmartNotificationType.unfinishedTask,
        isMissedTask: result.type == SmartNotificationType.missedTask ||
            result.type == SmartNotificationType.consolidatedEvening,
        missedTasks: missedList,
      );
    }
  }

  void _checkStartTimes() {
    final now = DateTime.now();
    final quickTasks = ref.read(quickTasksProvider);
    final focusTasks = ref.read(focusTasksProvider);
    final currentDayShort = _getDayShortName(now.weekday);

    void checkTask(String id, String title, String? dueTime, int estimateMinutes, {List<String> repeatDays = const []}) {
      if (dueTime == null) return;
      // If task is recurring and does not repeat today, skip today's timing check
      if (repeatDays.isNotEmpty && !repeatDays.any((d) => d.trim().toLowerCase() == currentDayShort.trim().toLowerCase())) {
        return;
      }
      final parts = dueTime.split(':');
      if (parts.length != 2) return;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return;

      final startTime = DateTime(now.year, now.month, now.day, hour, minute);

      // Calculate latest start time
      final latestStart = startTime.subtract(Duration(minutes: estimateMinutes));
      
      final diffSeconds = latestStart.difference(now).inSeconds;

      if (diffSeconds > 0) {
        final thresholds = [10, 5, 3, 1];
        for (final t in thresholds) {
          final targetSeconds = t * 60;
          if (diffSeconds >= (targetSeconds - 30) && diffSeconds < (targetSeconds + 30)) {
            final key = '$id-${latestStart.millisecondsSinceEpoch}';
            final notifiedSet = _notifiedThresholds.putIfAbsent(key, () => <int>{});
            if (!notifiedSet.contains(t)) {
              notifiedSet.add(t);

              final timeFormatted = NotificationService.formatTimeOfDay(hour, minute);
              _triggerGlobalNotification(
                'Starting soon',
                '$title · ${_formatDuration(estimateMinutes)} (Starts at $timeFormatted)',
                taskId: id,
              );
            }
          }
        }
      } else {
        // Task is overdue / unfinished for TODAY ONLY (within 2 hours of due start)
        final overdueMinutes = now.difference(latestStart).inMinutes;
        if (overdueMinutes >= 0 && overdueMinutes <= 120 && overdueMinutes % 5 == 0) {
          final key = '$id-${latestStart.millisecondsSinceEpoch}-overdue-$overdueMinutes';
          final notifiedSet = _notifiedThresholds.putIfAbsent(key, () => <int>{});
          if (!notifiedSet.contains(overdueMinutes)) {
            notifiedSet.add(overdueMinutes);

            _triggerGlobalNotification(
              'Unfinished Task',
              '$title · ${_formatDuration(estimateMinutes)}',
              isUnfinished: true,
              taskId: id,
            );
          }
        }
      }
    }

    for (var task in quickTasks) {
      checkTask(task.id, task.title, task.dueTime, task.durationMinutes);
    }

    for (var task in focusTasks) {
      if (task.isDone) continue;
      int est = 15;
      final numStr = task.duration.split(' ').first;
      final parsed = int.tryParse(numStr);
      if (parsed != null) est = parsed;

      checkTask(task.id, task.title, task.dueTime, est, repeatDays: task.repeatDays);
    }

    // Evaluate smart notification schedule (Morning quick tasks, Workday wrap-up, Evening catch-up, Quiet hours, 4-hr spacing)
    _checkSmartNotificationSchedule();
  }

  void _checkDayPlanningWindows() {
    if (!mounted) return;

    // Night window: remind user to plan tomorrow
    if (DayPlanService.isNight() && !DayPlanService.hasShownNightPlanTonight()) {
      DayPlanService.markNightPlanShownTonight();
      // Show an in-app notification banner for the night planning reminder
      ref.read(inAppNotificationProvider.notifier).state = const InAppNotificationData(
        title: '🌙 Plan tomorrow',
        body: 'Tap to list what you want to accomplish tomorrow.',
        duration: Duration(seconds: 12),
      );
    }
  }

  void _triggerGlobalNotification(String title, String body, {bool isUnfinished = false, bool isMissedTask = false, String? taskId, List<MissedTaskInfo> missedTasks = const []}) {
    // Clean up title and body so "Unfinished Task" is never mentioned twice
    String cleanTitle = title;
    if (isUnfinished && (cleanTitle.toLowerCase().contains('unfinished task') || cleanTitle.isEmpty)) {
      cleanTitle = cleanTitle
          .replaceAll(RegExp(r'(Unfinished Task Alert:?|Unfinished Task Reminder:?|Unfinished Task:?|Task Reminder:?|Overdue:?)', caseSensitive: false), '')
          .trim();
      if (cleanTitle.isEmpty) cleanTitle = 'Unfinished Task';
    }

    String cleanBody = body;
    if (isUnfinished && cleanTitle == 'Unfinished Task') {
      // Remove any due time or deadline mentions if present
      cleanBody = cleanBody.replaceAll(RegExp(r'\s*\(Due at [^)]+\)', caseSensitive: false), '');
      cleanBody = cleanBody.replaceAll(RegExp(r'\s*Due at [^,.-]+', caseSensitive: false), '');
      cleanBody = cleanBody
          .replaceAll(RegExp(r'Unfinished task', caseSensitive: false), 'Task')
          .trim();
    }

    unawaited(NotificationService.show(title: cleanTitle, body: cleanBody, isUnfinished: isUnfinished, taskId: taskId));

    // Synthesize audio chime on browser Web Audio API
    try {
      if (isUnfinished) {
        js.context.callMethod('playUnfinishedTaskChime');
      } else {
        js.context.callMethod('playNotificationChime');
      }
    } catch (_) {}

    // Show in-app notification banner beside the plus sign
    if (mounted) {
      final isPersistentNotif = NotificationService.isPersistent;
      final duration = isPersistentNotif
          ? const Duration(minutes: 30)
          : Duration(seconds: isMissedTask ? 12 : isUnfinished ? 8 : 6);

      _showInAppNotification(
        title: cleanTitle,
        body: cleanBody.isNotEmpty ? cleanBody : null,
        isUnfinished: isUnfinished,
        isMissedTask: isMissedTask,
        taskId: taskId,
        customDuration: duration,
        missedTasks: missedTasks,
      );
    }
  }

  void _showInAppNotification({
    required String title,
    String? body,
    bool isUnfinished = false,
    bool isMissedTask = false,
    String? taskId,
    Duration? customDuration,
    List<MissedTaskInfo> missedTasks = const [],
  }) {
    _notifDismissTimer?.cancel();

    setState(() {
      _currentNotification = InAppNotificationData(
        title: title,
        body: body,
        isUnfinished: isUnfinished,
        isMissedTask: isMissedTask,
        taskId: taskId,
        duration: customDuration,
        missedTasks: missedTasks,
      );
    });

    _notifAnimController.forward(from: 0.0);

    final isPersistentNotif = NotificationService.isPersistent;
    final duration = customDuration ??
        (isPersistentNotif
            ? const Duration(minutes: 30)
            : Duration(seconds: isUnfinished ? 8 : 6));

    _notifDismissTimer = Timer(duration, () {
      _dismissInAppNotification();
    });
  }

  void _dismissInAppNotification() {
    _notifDismissTimer?.cancel();
    if (_notifAnimController.status != AnimationStatus.dismissed) {
      _notifAnimController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _currentNotification = null;
          });
          ref.read(inAppNotificationProvider.notifier).state = null;
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _currentNotification = null;
        });
        ref.read(inAppNotificationProvider.notifier).state = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StreakState>(streakProvider, (previous, next) {
      if (next.showCelebration) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => StreakCelebrationDialog(
            streakDays: next.currentStreak,
            completionHistory: next.completionHistory,
            onDismiss: () {
              ref.read(streakProvider.notifier).dismissCelebration();
            },
          ),
        );
      }
    });

    ref.listen<InAppNotificationData?>(inAppNotificationProvider, (previous, next) {
      if (next != null) {
        _showInAppNotification(
          title: next.title,
          body: next.body,
          isUnfinished: next.isUnfinished,
          isMissedTask: next.isMissedTask,
          taskId: next.taskId,
          customDuration: next.duration,
          missedTasks: next.missedTasks,
        );
      }
    });



    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final navSelectedColor = isDark ? Colors.white : const Color(0xFF2563EB);
    final navUnselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      body: Stack(
        children: [
          TimeOfDayBackground(
            child: SafeArea(
              child: _screens[_currentIndex],
            ),
          ),
          AnimatedBuilder(
            animation: _fabAnimController,
            builder: (context, child) {
              if (_fabAnimController.value <= 0.001) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: GestureDetector(
                  onTap: _closeFab,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withOpacity(0.45 * _fabAnimController.value.clamp(0.0, 1.0)),
                  ),
                ),
              );
            },
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Option 1: Quick Task
          _buildFabActionItem(
            label: 'Quick Task',
            icon: LucideIcons.stickyNote,
            slideOffset: 24,
            onTap: () => openCreateTaskSheet(context, ref, isQuickNote: true),
          ),
          // Option 2: Scheduled Tasks
          _buildFabActionItem(
            label: 'Scheduled Tasks',
            icon: LucideIcons.listTodo,
            slideOffset: 12,
            onTap: () => openCreateTaskSheet(context, ref, isQuickNote: false),
          ),
          // Bottom row containing notification banner beside the Plus Button
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildInAppNotificationBanner(isDark),
              // Main Rotating FAB (+ to x)
              GestureDetector(
                onTap: _toggleFab,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12, right: 6),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.14) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: RotationTransition(
                      turns: _fabRotateAnim,
                      child: Icon(
                        LucideIcons.plus,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: navBgColor.withOpacity(0.85),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, LucideIcons.stickyNote, 'Quick Notes', navSelectedColor, navUnselectedColor),
                    _buildNavItem(1, LucideIcons.trendingUp, 'Progress', navSelectedColor, navUnselectedColor),
                    _buildNavItem(2, LucideIcons.listTodo, 'Daily Tasks', navSelectedColor, navUnselectedColor),
                    _buildNavItem(3, LucideIcons.user, 'My Account', navSelectedColor, navUnselectedColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFabActionItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    double slideOffset = 20.0,
  }) {
    return AnimatedBuilder(
      animation: _fabExpandAnim,
      builder: (context, child) {
        final val = _fabExpandAnim.value;
        if (val <= 0.001) {
          return const SizedBox.shrink();
        }
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - val) * slideOffset),
            child: Transform.scale(
              scale: 0.85 + (0.15 * val),
              alignment: Alignment.bottomRight,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _closeFab();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 7, bottom: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Circular button matching Remell theme
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.14)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInAppNotificationBanner(bool isDark) {
    return AnimatedBuilder(
      animation: _notifAnimController,
      builder: (context, child) {
        final val = _notifAnimController.value;
        if (val <= 0.001 || _currentNotification == null) {
          return const SizedBox.shrink();
        }
        final notif = _currentNotification!;
        final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);
        const primaryTextColor = Color(0xFFF8FAFC);
        final accentColor = notif.isMissedTask
            ? const Color(0xFF6366F1)  // calm Indigo for missed tasks / catch-up
            : notif.isUnfinished
                ? const Color(0xFFF59E0B)  // warm Amber for unfinished
                : const Color(0xFF10B981);  // soothing Emerald for quick tasks

        final screenWidth = MediaQuery.of(context).size.width;
        final maxBannerWidth = math.min(380.0, screenWidth - 90.0);

        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1.0 - val) * 20.0, 0),
            child: Material(
              color: Colors.transparent,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12, right: 8),
                  constraints: BoxConstraints(maxWidth: maxBannerWidth),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.14) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.40 : 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Type icon badge
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              notif.isMissedTask
                                  ? LucideIcons.calendarClock
                                  : notif.isUnfinished
                                      ? LucideIcons.listTodo
                                      : LucideIcons.stickyNote,
                              size: 14,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Title & Subtitle
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (notif.body != null && notif.body!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    notif.body!,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w400,
                                      color: primaryTextColor.withOpacity(0.75),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Dismiss X button
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _dismissInAppNotification,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                LucideIcons.x,
                                size: 13,
                                color: primaryTextColor.withOpacity(0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Interactive Action Pills: [Snooze 2h] & [Review / View]
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              SmartNotificationScheduler.setSnooze(const Duration(hours: 2));
                              _dismissInAppNotification();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.bellOff, size: 10, color: primaryTextColor.withOpacity(0.75)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Snooze 2h',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextColor.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              _dismissInAppNotification();
                              if (notif.isMissedTask) {
                                setState(() => _currentIndex = 2);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black.withOpacity(0.85),
                                      builder: (ctx) => MissedTasksDialog(
                                        missedTasks: notif.missedTasks,
                                        onTaskTap: (info) {
                                          Navigator.of(ctx).pop();
                                          ref.read(activeFocusTaskIdProvider.notifier).state = info.id;
                                          GoRouter.of(context).go('/focus');
                                        },
                                      ),
                                    );
                                  }
                                });
                              } else if (notif.taskId != null) {
                                ref.read(activeFocusTaskIdProvider.notifier).state = notif.taskId;
                                GoRouter.of(context).go('/focus');
                              } else {
                                setState(() => _currentIndex = 2);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: accentColor.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.externalLink, size: 10, color: accentColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    notif.isMissedTask ? 'Review' : 'View',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

      },
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color selectedColor,
    Color unselectedColor,
  ) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? selectedColor : unselectedColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _closeFab();
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

