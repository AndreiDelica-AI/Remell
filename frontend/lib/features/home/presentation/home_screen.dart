import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:js' as js;
import '../../../shared/providers/tasks_provider.dart';
import '../../../shared/bottom_sheets/create_task_sheet.dart';
import '../../../shared/providers/streak_provider.dart';
import '../../../shared/providers/energy_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/services/day_plan_service.dart';
import '../../../shared/utils/nlp_parser.dart';
import '../../../shared/dialogs/morning_tasks_dialog.dart';
import '../../../shared/dialogs/night_summary_dialog.dart';
import '../../../shared/bottom_sheets/plan_tomorrow_sheet.dart';

// Live Clock Widget - Typography-based clock widget without background card
class LiveClockWidget extends StatefulWidget {
  const LiveClockWidget({super.key});

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  late Timer _timer;
  String _timeStr = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    if (mounted) {
      setState(() {
        _timeStr = '${hour.toString().padLeft(2, '0')}:$minute:$second $amPm';
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      _timeStr,
      style: GoogleFonts.shareTechMono(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isThemeDark ? Colors.white : const Color(0xFF1E293B),
        letterSpacing: 0.5,
      ),
    );
  }
}

class SunMoonSummaryOrb extends StatefulWidget {
  final String userName;

  const SunMoonSummaryOrb({
    super.key,
    required this.userName,
  });

  @override
  State<SunMoonSummaryOrb> createState() => _SunMoonSummaryOrbState();
}

class _SunMoonSummaryOrbState extends State<SunMoonSummaryOrb> {
  bool _isHovered = false;
  Timer? _periodicCheckTimer;

  @override
  void initState() {
    super.initState();
    // Periodically re-check whether morning / night window changed
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMorning = DayPlanService.isMorning();
    final isNight = DayPlanService.isNight();

    if (!isMorning && !isNight) {
      return const SizedBox.shrink();
    }

    final isThemeDark = Theme.of(context).brightness == Brightness.dark;

    // Sun (morning) vs Moon (night) styling
    final Color primaryColor = isMorning ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);
    final Color secondaryColor = isMorning ? const Color(0xFFD97706) : const Color(0xFF6366F1);
    final Color glowColor = isMorning ? const Color(0xFFFBBF24) : const Color(0xFFA78BFA);
    final IconData icon = isMorning ? LucideIcons.sun : LucideIcons.moon;
    final String label = isMorning ? 'Morning Summary' : 'Night Summary';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () async {
          if (isMorning) {
            await showDialog(
              context: context,
              barrierColor: Colors.black.withOpacity(0.85),
              builder: (ctx) => MorningTasksSummaryDialog(
                userName: widget.userName,
              ),
            );
          } else {
            await showDialog(
              context: context,
              barrierColor: Colors.black.withOpacity(0.85),
              builder: (ctx) => NightSummaryDialog(
                userName: widget.userName,
              ),
            );
          }
          if (mounted) setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                primaryColor.withOpacity(_isHovered ? 0.30 : 0.18),
                secondaryColor.withOpacity(_isHovered ? 0.22 : 0.10),
              ],
              radius: 0.9,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: glowColor.withOpacity(isThemeDark ? 0.55 : 0.40),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(_isHovered ? 0.40 : 0.22),
                blurRadius: _isHovered ? 16 : 9,
                spreadRadius: _isHovered ? 1.5 : 0.5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}

void _requestNotificationPermission() {
  unawaited(NotificationService.requestPermissions());
}

void _triggerBackgroundNotification(String title, String body) {
  unawaited(NotificationService.show(title: title, body: body));
}

// Global helper to open create task bottom sheet
void openCreateTaskSheet(BuildContext context, WidgetRef ref, {bool isQuickNote = true, FocusTaskItem? taskToEdit}) async {
  _requestNotificationPermission();
  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CreateTaskSheet(initialIsQuickNote: taskToEdit != null ? false : isQuickNote, focusTaskToEdit: taskToEdit),
  );

  if (result != null) {
    final title = result['title'] as String;
    final type = result['type'] as String;
    final notes = result['notes'] as String;
    final duration = result['duration'] as int;
    final dueTime = result['dueTime'] as String?;

    if (type == 'quick_note') {
      final bool isUrgent = result['isUrgent'] as bool? ?? false;
      final steps = result['steps'] as List<String>?;
      ref.read(quickTasksProvider.notifier).add(
        title,
        duration,
        notes,
        isUrgent: isUrgent,
        difficulty: result['difficulty'] as String? ?? 'medium',
        dueTime: dueTime,
        steps: steps,
      );
    } else {
      final steps = result['steps'] as List<String>;
      final repeatDays = result['repeatDays'] as List<String>? ?? const [];
      final colorHex = result['colorHex'] as String?;
      final iconName = result['iconName'] as String?;
      final repeatUntilStr = result['repeatUntil'] as String?;
      final repeatUntil = repeatUntilStr != null ? DateTime.tryParse(repeatUntilStr) : null;
      if (taskToEdit != null) {
        ref.read(focusTasksProvider.notifier).updateTask(
          taskToEdit.id,
          title,
          result['time'] as String? ?? taskToEdit.timeSegment,
          notes,
          steps,
          difficulty: result['difficulty'] as String? ?? taskToEdit.difficulty,
          dueTime: dueTime,
          durationMinutes: duration,
          repeatDays: repeatDays,
          colorHex: colorHex,
          iconName: iconName,
          repeatUntil: repeatUntil,
          clearRepeatUntil: repeatUntil == null && repeatDays.isNotEmpty,
        );
      } else {
        ref.read(focusTasksProvider.notifier).add(
          title,
          result['time'] as String,
          notes,
          steps,
          difficulty: result['difficulty'] as String? ?? 'medium',
          dueTime: dueTime,
          durationMinutes: duration,
          repeatDays: repeatDays,
          colorHex: colorHex,
          iconName: iconName,
          repeatUntil: repeatUntil,
        );
      }
    }

    final taskId = taskToEdit?.id ?? '${DateTime.now().millisecondsSinceEpoch}-$title';
    await NotificationService.scheduleTaskReminders(
      taskId: taskId,
      title: title,
      dueTime: dueTime,
      durationMinutes: duration,
    );

    final rawSteps = (result['steps'] as List<String>?) ?? const [];
    final generatedSubtasks = rawSteps.map((s) => SubTaskItem(title: s, scheduledTime: NlpParser.parseDeadline(s))).toList();
    await NotificationService.scheduleAllSubtasksReminders(
      taskId: taskId,
      subtasks: generatedSubtasks,
    );

    ref.read(inAppNotificationProvider.notifier).state = InAppNotificationData(
      title: 'Saved: $title',
      duration: const Duration(seconds: 4),
    );
  }
}

// Global helper to open edit task bottom sheet
void openEditTaskSheet(BuildContext context, WidgetRef ref, QuickTaskItem task) async {
  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CreateTaskSheet(taskToEdit: task),
  );

  if (result != null) {
    final title = result['title'] as String;
    final notes = result['notes'] as String;
    final isUrgent = result['isUrgent'] as bool? ?? false;
    final difficulty = result['difficulty'] as String? ?? 'medium';
    final dueTime = result['dueTime'] as String?;
    final duration = result['duration'] as int;

    ref.read(quickTasksProvider.notifier).updateTask(
      task.id,
      title,
      duration,
      notes,
      isUrgent: isUrgent,
      difficulty: difficulty,
      dueTime: dueTime,
      steps: result['steps'] as List<String>?,
    );

    await NotificationService.scheduleTaskReminders(
      taskId: task.id,
      title: title,
      dueTime: dueTime,
      durationMinutes: duration,
    );

    final rawSteps = (result['steps'] as List<String>?) ?? const [];
    final generatedSubtasks = rawSteps.map((s) => SubTaskItem(title: s, scheduledTime: NlpParser.parseDeadline(s))).toList();
    await NotificationService.scheduleAllSubtasksReminders(
      taskId: task.id,
      subtasks: generatedSubtasks,
    );

    ref.read(inAppNotificationProvider.notifier).state = InAppNotificationData(
      title: 'Updated: $title',
      duration: const Duration(seconds: 4),
    );
  }
}

// ==========================================
// 1. QUICK NOTES SCREEN (TAB 1)
// ==========================================
class QuickNotesScreen extends ConsumerStatefulWidget {
  const QuickNotesScreen({super.key});

  @override
  ConsumerState<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

  void _showFocusStartedDialog(BuildContext context, QuickTaskItem task) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final cardColor = isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.play, color: Color(0xFFEA580C), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Focus Session Started!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${task.durationMinutes} min focus timer is running.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: primaryTextColor.withOpacity(0.7),
                ),
              ),
              if (task.notes.isNotEmpty && task.notes != 'No notes added.') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryTextColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.notes,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: primaryTextColor.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Dismiss', style: GoogleFonts.inter(color: primaryTextColor.withOpacity(0.6))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/focus');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Open Focus Screen', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

class _QuickNotesScreenState extends ConsumerState<QuickNotesScreen> with TickerProviderStateMixin {
  double _swipeOffset = 0.0;
  bool _isSwiping = false;
  late AnimationController _swipeAnimController;
  late AnimationController _arrowController;
  late Animation<double> _arrowAnim;
  late AnimationController _plusController;
  late Animation<double> _plusAnim;
  double _guideOpacity = 0.50;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _guideOpacity > 0.0) {
        setState(() {
          _guideOpacity = 0.0;
        });
      }
    });
    _requestNotificationPermission();
    // Check morning / night summary after a short delay so dialog appears after the screen is visible
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkMorningSummary();
        _checkNightSummary();
      }
    });
    _swipeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _arrowAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
    _arrowController.repeat(reverse: true);
    _plusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _plusAnim = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _plusController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _swipeAnimController.dispose();
    _arrowController.dispose();
    _plusController.dispose();
    super.dispose();
  }



  void _animateSwipeTo(double targetValue, {required VoidCallback onComplete}) {
    _swipeAnimController.stop();
    _swipeAnimController.reset();

    final Animation<double> animation = Tween<double>(
      begin: _swipeOffset,
      end: targetValue,
    ).animate(CurvedAnimation(
      parent: _swipeAnimController,
      curve: Curves.easeOutQuad,
    ));

    animation.addListener(() {
      setState(() {
        _swipeOffset = animation.value;
      });
    });

    late void Function(AnimationStatus) listener;
    listener = (status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(listener);
        onComplete();
      }
    };
    animation.addStatusListener(listener);

    _swipeAnimController.forward();
  }

  String _getGreetingSub(List<QuickTaskItem> quickTasks) {
    final pendingCount = quickTasks.length;
    if (pendingCount == 0) {
      return 'your mind is completely clear.';
    } else if (pendingCount == 1) {
      return '1 thought waiting.';
    } else {
      return 'you have $pendingCount thoughts waiting.';
    }
  }

  String _getUserDisplayName() {
    final authUser = ref.read(authUserProvider);
    String rawName = authUser?['nickname'] ?? authUser?['displayName'] ?? authUser?['name'] ?? '';
    if (rawName.isEmpty && authUser?['email'] != null) {
      rawName = authUser!['email'].toString().split('@').first;
    }
    final firstWord = rawName.trim().split(RegExp(r'\s+')).first;
    final cleanedWord = firstWord.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final finalWord = cleanedWord.length > 7 ? cleanedWord.substring(0, 7) : cleanedWord;
    return finalWord.isEmpty ? 'there' : finalWord;
  }

  void _checkMorningSummary() {
    if (!mounted) return;
    if (!DayPlanService.isMorning()) return;
    if (DayPlanService.hasShownMorningPlanToday()) return;

    DayPlanService.markMorningPlanShownToday();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => MorningTasksSummaryDialog(
        userName: _getUserDisplayName(),
      ),
    );
  }

  void _checkNightSummary() {
    if (!mounted) return;
    if (!DayPlanService.isNight()) return;
    if (DayPlanService.hasShownNightPlanTonight()) return;

    DayPlanService.markNightPlanShownTonight();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => NightSummaryDialog(
        userName: _getUserDisplayName(),
      ),
    );
  }

  void _skipActiveTask() {
    final quickTasks = ref.read(quickTasksProvider);
    if (quickTasks.isNotEmpty) {
      final task = quickTasks.first;
      setState(() {
        _swipeOffset = 0.0;
      });

      ref.read(quickTasksProvider.notifier).removeAt(0, isCompleted: false);
      ref.read(quickTasksProvider.notifier).insert(quickTasks.length - 1, task);

      ref.read(inAppNotificationProvider.notifier).state = InAppNotificationData(
        title: 'Skipped: "${task.title}"',
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final cardColor = isThemeDark ? const Color(0xFF1E293B).withOpacity(0.85) : const Color(0xFFFFFFFF).withOpacity(0.85);
    final dividerColor = isThemeDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

    final quickTasks = ref.watch(quickTasksProvider);
    final focusTasks = ref.watch(focusTasksProvider);
    final authUser = ref.watch(authUserProvider);
    String rawName = authUser?['nickname'] ?? authUser?['displayName'] ?? authUser?['name'] ?? '';
    if (rawName.isEmpty && authUser?['email'] != null) {
      final emailStr = authUser!['email'].toString();
      rawName = emailStr.split('@').first;
    }
    // Strictly 1-word, maximum of 7 letters rule
    final firstWord = rawName.trim().split(RegExp(r'\s+')).first;
    final cleanedWord = firstWord.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final finalWord = cleanedWord.length > 7 ? cleanedWord.substring(0, 7) : cleanedWord;
    final validName = finalWord.isEmpty ? 'drei' : finalWord;
    final nameGreeting = "${validName.toLowerCase()}.";

    return Listener(
      onPointerDown: (_) {
        if (_guideOpacity > 0.0) {
          setState(() {
            _guideOpacity = 0.0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: name+subtitle left, clock+orb right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  nameGreeting,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getGreetingSub(quickTasks),
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                              color: secondaryTextColor.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Right side: clock aligned with name, sun/moon orb below
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Clock sits at same visual level as the name text
                        const LiveClockWidget(),
                        const SizedBox(height: 10),
                        SunMoonSummaryOrb(
                          userName: _getUserDisplayName(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'QUICK NOTES',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: secondaryTextColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 14),
                if (quickTasks.isEmpty)
                  _buildEmptyState()
                else
                  _buildSwipeableFlippableCard(quickTasks, cardColor, primaryTextColor, secondaryTextColor, dividerColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeableFlippableCard(List<QuickTaskItem> quickTasks, Color cardColor, Color primaryTextColor, Color secondaryTextColor, Color dividerColor) {
    final mainTask = quickTasks.first;
    final remainingTasks = quickTasks.sublist(1);
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Minimalist Visual Swipe Indicator Prompt (‹ skip   start focus ›)
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.chevronLeft,
                    size: 13,
                    color: secondaryTextColor.withOpacity(0.45),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'skip',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                      color: secondaryTextColor.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'start focus',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: secondaryTextColor.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 13,
                    color: secondaryTextColor.withOpacity(0.45),
                  ),
                ],
              ),
            ],
          ),
        ),

        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onDoubleTap: () {
                final isTrial = ref.read(isTrialModeProvider);
                ref.read(activeTaskTimerProvider.notifier).start(mainTask, isTrialMode: isTrial);
              },
              onTap: () {
                _showTaskDetailPopup(context, mainTask, cardColor, primaryTextColor, secondaryTextColor);
              },
              onPanStart: (details) {
                if (_guideOpacity > 0.0) {
                  setState(() {
                    _guideOpacity = 0.0;
                  });
                }
                setState(() {
                  _isSwiping = true;
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _swipeOffset += details.delta.dx;
                });
              },
              onPanEnd: (details) {
                setState(() {
                  _isSwiping = false;
                });
                if (_swipeOffset > 120) {
                  _animateSwipeTo(480.0, onComplete: () {
                    final isTrial = ref.read(isTrialModeProvider);
                    ref.read(activeTaskTimerProvider.notifier).start(mainTask, isTrialMode: isTrial);
                    _showFocusStartedDialog(context, mainTask);
                    setState(() {
                      _swipeOffset = 0.0;
                    });
                  });
                } else if (_swipeOffset < -120) {
                  _animateSwipeTo(-480.0, onComplete: () {
                    _skipActiveTask();
                  });
                } else {
                  _animateSwipeTo(0.0, onComplete: () {});
                }
              },
              child: Transform.translate(
                offset: Offset(_swipeOffset, 0),
                child: Transform.rotate(
                  angle: (_swipeOffset / 300) * (math.pi / 180) * 12,
                  child: _buildSimpleTaskCard(mainTask, cardColor, primaryTextColor, secondaryTextColor),
                ),
              ),
            ),

          ],
        ),
        const SizedBox(height: 36),

        if (remainingTasks.isNotEmpty) ...[
          Text(
            'Quick tasks:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: secondaryTextColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 18),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: remainingTasks.length,
            itemBuilder: (context, index) {
              final task = remainingTasks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? (task.isUrgent ? const Color(0xFF2C1B1B) : const Color(0xFF0F172A))
                        : (task.isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: task.isUrgent
                          ? Colors.redAccent.withOpacity(0.5)
                          : primaryTextColor.withOpacity(0.06),
                      width: 1.2,
                    ),
                    boxShadow: task.isUrgent
                        ? [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.16),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${formatDuration(task.durationMinutes)}${task.dueTime != null ? ' • ${formatTimeAmPm(task.dueTime)}' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(LucideIcons.edit3, size: 16, color: secondaryTextColor),
                            onPressed: () => openEditTaskSheet(context, ref, task),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent.withOpacity(0.8)),
                            onPressed: () {
                              ref.read(quickTasksProvider.notifier).removeAt(index + 1, isCompleted: false);
                            },
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }


  Widget _buildSimpleTaskCard(QuickTaskItem task, Color cardColor, Color primaryTextColor, Color secondaryTextColor) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: task.isUrgent
            ? (isThemeDark ? Colors.redAccent.withOpacity(0.12) : Colors.redAccent.withOpacity(0.06))
            : const Color(0xFF0F172A),
        gradient: task.isUrgent
            ? LinearGradient(
                colors: [
                  const Color(0xFFEF4444).withOpacity(0.22),
                  const Color(0xFF7F1D1D).withOpacity(0.07),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: task.isUrgent
            ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.55), width: 2.0)
            : Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1.0,
              ),
        boxShadow: task.isUrgent
            ? [BoxShadow(color: Colors.redAccent.withOpacity(0.18), blurRadius: 20, spreadRadius: 2)]
            : [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: duration chip + timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isThemeDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clock, size: 11.5,
                          color: task.isUrgent ? Colors.white.withOpacity(0.9) : secondaryTextColor.withOpacity(0.85)),
                        const SizedBox(width: 5),
                        Text(
                          formatDuration(task.durationMinutes),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: task.isUrgent ? Colors.white.withOpacity(0.95) : secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.isUrgent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 1),
                      ),
                      child: Text(
                        'URGENT',
                        style: GoogleFonts.inter(
                          fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                          color: isThemeDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          // Task title — centered, bold, clean — NO notes
          Expanded(
            child: Center(
              child: Text(
                task.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.25,
                  color: task.isUrgent ? Colors.white : primaryTextColor,
                ),
              ),
            ),
          ),
          // Subtle tap hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.info, size: 10,
                color: task.isUrgent ? Colors.white.withOpacity(0.35) : secondaryTextColor.withOpacity(0.3)),
              const SizedBox(width: 4),
              Text(
                'tap for details',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: task.isUrgent ? Colors.white.withOpacity(0.4) : secondaryTextColor.withOpacity(0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTaskDetailPopup(BuildContext context, QuickTaskItem task, Color cardColor, Color primaryTextColor, Color secondaryTextColor) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    // Deep dark background and sleek aesthetic matching Remell
    const sheetBg = Color(0xFF0F172A);
    const surfaceBg = Color(0xFF0B1120); // Darker tone suitable for notes & subtasks
    const borderCol = Color(0xFF1E293B);
    const labelCol = Color(0xFF94A3B8);
    const bodyCol = Color(0xFFCBD5E1);
    const titleCol = Color(0xFFF8FAFC);
    const mutedCol = Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final hasNotes = task.notes.isNotEmpty && task.notes != 'No notes added.';
        final hasSubtasks = task.subtasks.isNotEmpty;
        return Container(
          decoration: const BoxDecoration(
            color: sheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: borderCol, width: 1),
              left: BorderSide(color: borderCol, width: 1),
              right: BorderSide(color: borderCol, width: 1),
            ),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 32, height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title block
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: GoogleFonts.inter(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.2,
                            color: titleCol,
                          ),
                        ),
                      ),
                      if (task.isUrgent) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F1D1D).withOpacity(0.55),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                          ),
                          child: Text('URGENT',
                            style: GoogleFonts.inter(
                              fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8,
                              color: const Color(0xFFFCA5A5))),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Meta chips row (Duration & Due Time — NO 'Just now')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Wrap(
                    spacing: 7, runSpacing: 7,
                    children: [
                      _detailChip(LucideIcons.clock, formatDuration(task.durationMinutes)),
                      if (task.dueTime != null && task.dueTime!.isNotEmpty)
                        _detailChip(LucideIcons.alarmCheck, formatTimeAmPm(task.dueTime!)),
                    ],
                  ),
                ),

                // ── NOTES (Larger spacious area with dark theme) ────────────────────────────────
                if (hasNotes) ...[
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Container(
                          width: 3, height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Notes',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: labelCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: surfaceBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol, width: 1),
                      ),
                      child: Text(
                        task.notes,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.6,
                          color: bodyCol,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── SUBTASKS (Darker aesthetic) ─────────────────────────────
                if (hasSubtasks) ...[
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Container(
                          width: 3, height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Subtasks',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: labelCol,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: mutedCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol, width: 1),
                      ),
                      child: Column(
                        children: task.subtasks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final st = entry.value;
                          final isLast = idx == task.subtasks.length - 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              border: isLast ? null : const Border(
                                bottom: BorderSide(color: borderCol, width: 1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 18, height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: st.isCompleted
                                        ? const Color(0xFF064E3B)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: st.isCompleted
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF334155),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: st.isCompleted
                                      ? const Icon(LucideIcons.check, size: 10, color: Color(0xFF10B981))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    st.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      height: 1.4,
                                      color: st.isCompleted ? mutedCol : bodyCol,
                                      decoration: st.isCompleted ? TextDecoration.lineThrough : null,
                                      decorationColor: mutedCol,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── ACTION BUTTONS ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      // Edit — subtle outlined
                      SizedBox(
                        width: 80,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            openEditTaskSheet(context, ref, task);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF1E2D45), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: mutedCol,
                          ),
                          child: Text(
                            'Edit',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: mutedCol,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Start Focus — dark solid, no icon
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            final isTrial = ref.read(isTrialModeProvider);
                            ref.read(activeTaskTimerProvider.notifier).start(task, isTrialMode: isTrial);
                            _showFocusStartedDialog(context, task);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF334155), width: 1),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Start Focus',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: const Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 100.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              LucideIcons.stickyNote,
              size: 32,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.18),
            ),
            const SizedBox(height: 16),
            Text(
              'Your mind is completely clear.',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3D Flippable Quick Task Card Widget
class QuickFlipCardWidget extends ConsumerStatefulWidget {
  final QuickTaskItem task;
  final Color cardColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final bool isTimerRunning;
  final int timeLeftSeconds;
  final int totalDurationSeconds;
  final VoidCallback onComplete;

  const QuickFlipCardWidget({
    super.key,
    required this.task,
    required this.cardColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.isTimerRunning,
    required this.timeLeftSeconds,
    required this.totalDurationSeconds,
    required this.onComplete,
  });

  @override
  ConsumerState<QuickFlipCardWidget> createState() => _QuickFlipCardWidgetState();
}

class _QuickFlipCardWidgetState extends ConsumerState<QuickFlipCardWidget> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(_flipController)
      ..addListener(() {
        setState(() {});
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 6.0, end: 28.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() {});
      });
    _pulseController.repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isTimerRunning) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(QuickFlipCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTimerRunning != oldWidget.isTimerRunning) {
      if (widget.isTimerRunning) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    final double scale = 1.0 + (math.sin(_flipAnimation.value) * 0.06);

    return GestureDetector(
      onTap: _toggleCard,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(_flipAnimation.value)
          ..scale(scale, scale),
        alignment: Alignment.center,
        child: _flipAnimation.value <= math.pi / 2
            ? _buildFrontCard()
            : Transform(
                transform: Matrix4.identity()..rotateY(math.pi),
                alignment: Alignment.center,
                child: _buildBackCard(),
              ),
      ),
    );
  }

  Widget _buildFrontCard() {
    final double pulseOpacity = 0.35 + ((_pulseAnimation.value - 6.0) / 22.0) * 0.55;
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasNotes = widget.task.notes.isNotEmpty && widget.task.notes != 'No notes added.';

    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: widget.task.isUrgent
            ? (isThemeDark ? Colors.redAccent.withOpacity(0.12) : Colors.redAccent.withOpacity(0.06))
            : widget.cardColor,
        gradient: widget.task.isUrgent
            ? LinearGradient(
                colors: [
                  const Color(0xFFEF4444).withOpacity(0.24),
                  const Color(0xFF7F1D1D).withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: widget.task.isUrgent
            ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.55), width: 2.0)
            : Border.all(
                color: isThemeDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
                width: 1.0,
              ),
        boxShadow: widget.task.isUrgent
            ? [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(pulseOpacity * 0.45),
                  blurRadius: _pulseAnimation.value / 1.5,
                  spreadRadius: 2.0,
                ),
                BoxShadow(
                  color: Colors.red.withOpacity(pulseOpacity * 0.28),
                  blurRadius: _pulseAnimation.value * 1.8,
                  spreadRadius: _pulseAnimation.value / 2.0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isThemeDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 11.5,
                          color: widget.task.isUrgent
                              ? Colors.white.withOpacity(0.9)
                              : widget.secondaryTextColor.withOpacity(0.85),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formatDuration(widget.task.durationMinutes),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.task.isUrgent
                                ? Colors.white.withOpacity(0.95)
                                : widget.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.task.isUrgent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'URGENT',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isThemeDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                widget.task.time,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: widget.task.isUrgent
                      ? Colors.white.withOpacity(0.8)
                      : widget.secondaryTextColor.withOpacity(0.75),
                ),
              ),
            ],
          ),
          if (widget.isTimerRunning) ...[
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  widget.task.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: widget.task.isUrgent ? Colors.white : widget.primaryTextColor,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: _buildLiquidCircularTimer(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: widget.onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.task.isUrgent ? Colors.white : const Color(0xFF1E3A8A),
                foregroundColor: widget.task.isUrgent ? const Color(0xFF991B1B) : Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Complete', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.task.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          height: 1.3,
                          color: widget.task.isUrgent ? Colors.white : widget.primaryTextColor,
                        ),
                      ),
                      if (hasNotes) ...[
                        const SizedBox(height: 10),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isThemeDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isThemeDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.04),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.fileText,
                                size: 11.5,
                                color: widget.task.isUrgent
                                    ? Colors.white.withOpacity(0.8)
                                    : const Color(0xFF1E3A8A).withOpacity(0.85),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  widget.task.notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: widget.task.isUrgent
                                        ? Colors.white.withOpacity(0.85)
                                        : widget.secondaryTextColor.withOpacity(0.85),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.rotateCcw,
                  size: 11,
                  color: widget.task.isUrgent
                      ? Colors.white.withOpacity(0.5)
                      : widget.secondaryTextColor.withOpacity(0.45),
                ),
                const SizedBox(width: 5),
                Text(
                  hasNotes ? 'Tap to view notes' : 'Tap card for details',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: widget.task.isUrgent
                        ? Colors.white.withOpacity(0.6)
                        : widget.secondaryTextColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiquidCircularTimer() {
    final double progress = widget.totalDurationSeconds > 0 
        ? 1.0 - (widget.timeLeftSeconds / widget.totalDurationSeconds) 
        : 0.0;
    
    final bool isUrgent = widget.task.isUrgent;
    final Color waveColor = isUrgent ? Colors.white : const Color(0xFF1E3A8A);
    final Color waveAccentColor = isUrgent ? Colors.white.withOpacity(0.4) : const Color(0xFF3B82F6);
    final Color outlineColor = isUrgent ? Colors.white.withOpacity(0.8) : const Color(0xFF1E3A8A).withOpacity(0.8);

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: waveColor.withOpacity(isUrgent ? 0.3 : 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: CustomPaint(
            painter: LiquidCircularProgressPainter(
              percentage: progress,
              animValue: _waveController.value,
              color: waveColor,
              outlineColor: outlineColor,
            ),
            child: Center(
              child: Text(
                '${(widget.timeLeftSeconds ~/ 60)}:${(widget.timeLeftSeconds % 60).toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isUrgent 
                      ? Colors.white 
                      : (progress >= 0.5 ? Colors.white : widget.primaryTextColor),
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackCard() {
    final double pulseOpacity = 0.35 + ((_pulseAnimation.value - 6.0) / 22.0) * 0.55;
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check if this task is running globally
    final activeTimer = ref.watch(activeTaskTimerProvider);
    final bool isTimerForThisTaskRunning = activeTimer.isRunning && activeTimer.activeTask?.id == widget.task.id;
    final displayTimeLeft = isTimerForThisTaskRunning ? activeTimer.timeLeftSeconds : widget.timeLeftSeconds;
    final displayTotalDuration = isTimerForThisTaskRunning ? activeTimer.totalDurationSeconds : widget.totalDurationSeconds;
    final displayIsTimerRunning = isTimerForThisTaskRunning || widget.isTimerRunning;

    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: widget.task.isUrgent
            ? (isThemeDark ? Colors.redAccent.withOpacity(0.12) : Colors.redAccent.withOpacity(0.06))
            : widget.cardColor,
        gradient: widget.task.isUrgent
            ? LinearGradient(
                colors: [
                  const Color(0xFFEF4444).withOpacity(0.24),
                  const Color(0xFF7F1D1D).withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: widget.task.isUrgent
            ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.55), width: 2.0)
            : Border.all(
                color: isThemeDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
                width: 1.0,
              ),
        boxShadow: widget.task.isUrgent
            ? [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(pulseOpacity * 0.45),
                  blurRadius: _pulseAnimation.value / 1.5,
                  spreadRadius: 2.0,
                ),
                BoxShadow(
                  color: Colors.red.withOpacity(pulseOpacity * 0.28),
                  blurRadius: _pulseAnimation.value * 1.8,
                  spreadRadius: _pulseAnimation.value / 2.0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.task.isUrgent
                          ? Colors.white.withOpacity(0.12)
                          : (isThemeDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.fileText,
                          size: 11.5,
                          color: widget.task.isUrgent
                              ? Colors.white.withOpacity(0.9)
                              : const Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Notes',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: widget.task.isUrgent
                                ? Colors.white.withOpacity(0.95)
                                : widget.primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.task.isUrgent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'URGENT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isThemeDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (displayIsTimerRunning) ...[
                    _buildBackTimer(displayTimeLeft, displayTotalDuration),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: widget.task.isUrgent
                          ? Colors.white.withOpacity(0.1)
                          : (isThemeDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.task.isUrgent
                            ? Colors.white.withOpacity(0.15)
                            : (isThemeDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.undo2,
                          size: 11,
                          color: widget.task.isUrgent
                              ? Colors.white.withOpacity(0.8)
                              : widget.secondaryTextColor.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Card',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: widget.task.isUrgent
                                ? Colors.white.withOpacity(0.85)
                                : widget.secondaryTextColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.task.isUrgent
                    ? Colors.black.withOpacity(0.18)
                    : (isThemeDark ? const Color(0xFF0F172A).withOpacity(0.55) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.task.isUrgent
                      ? Colors.white.withOpacity(0.1)
                      : (isThemeDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: _buildSubtasksList(widget.task),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.rotateCcw,
                size: 11,
                color: widget.task.isUrgent
                    ? Colors.white.withOpacity(0.5)
                    : widget.secondaryTextColor.withOpacity(0.45),
              ),
              const SizedBox(width: 5),
              Text(
                'Tap anywhere to flip card',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: widget.task.isUrgent
                      ? Colors.white.withOpacity(0.6)
                      : widget.secondaryTextColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackTimer(int timeLeftSeconds, int totalDurationSeconds) {
    final double progress = totalDurationSeconds > 0 
        ? 1.0 - (timeLeftSeconds / totalDurationSeconds) 
        : 0.0;
    
    final bool isUrgent = widget.task.isUrgent;
    final Color waveColor = isUrgent ? Colors.white : const Color(0xFF1E3A8A);
    final Color outlineColor = isUrgent ? Colors.white.withOpacity(0.8) : const Color(0xFF1E3A8A).withOpacity(0.8);

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: waveColor.withOpacity(isUrgent ? 0.3 : 0.2),
                blurRadius: 6,
                spreadRadius: 0.5,
              )
            ],
          ),
          child: CustomPaint(
            painter: LiquidCircularProgressPainter(
              percentage: progress,
              animValue: _waveController.value,
              color: waveColor,
              outlineColor: outlineColor,
            ),
            child: Center(
              child: Text(
                '${(timeLeftSeconds ~/ 60)}:${(timeLeftSeconds % 60).toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isUrgent 
                      ? Colors.white 
                      : (progress >= 0.5 ? Colors.white : widget.primaryTextColor),
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 1,
                      offset: const Offset(0, 0.5),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtasksList(QuickTaskItem task) {
    final hasNotes = task.notes.isNotEmpty && task.notes != 'No notes added.';
    if (!hasNotes) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.fileText,
              size: 22,
              color: task.isUrgent
                  ? Colors.white.withOpacity(0.35)
                  : widget.secondaryTextColor.withOpacity(0.35),
            ),
            const SizedBox(height: 6),
            Text(
              'No notes attached to this task',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: task.isUrgent
                    ? Colors.white.withOpacity(0.6)
                    : widget.secondaryTextColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    final lines = task.notes
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final cleanLine = line.replaceFirst(RegExp(r'^[•\-\*]\s*'), '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 4.5,
                  height: 4.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isUrgent
                        ? Colors.white.withOpacity(0.85)
                        : const Color(0xFF1E3A8A).withOpacity(0.85),
                  ),
                ),
                Expanded(
                  child: Text(
                    cleanLine,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.1,
                      color: task.isUrgent
                          ? Colors.white.withOpacity(0.95)
                          : widget.primaryTextColor.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}



class LiquidCircularProgressPainter extends CustomPainter {
  final double percentage;
  final double animValue;
  final Color color;
  final Color outlineColor;

  LiquidCircularProgressPainter({
    required this.percentage,
    required this.animValue,
    required this.color,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);

    final Paint bgPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final Paint borderPaint = Paint()
      ..color = outlineColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 1.25, borderPaint);

    final Paint progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    final double sweepAngle = 2 * math.pi * percentage.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1.5),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LiquidCircularProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.color != color;
  }
}

class ProgressDisplayTask {
  final String id;
  final String title;
  final String durationText;
  final String? dueTime;
  final String segment; // 'Morning', 'Afternoon', 'Night'
  final bool isDone;
  final String typeLabel;

  const ProgressDisplayTask({
    required this.id,
    required this.title,
    required this.durationText,
    this.dueTime,
    required this.segment,
    required this.isDone,
    required this.typeLabel,
  });
}

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedTab = 0; // 0: Overview, 1: Activity Timeline
  String _statusFilter = 'ALL'; // ALL, COMPLETED, UNFINISHED, DELAYED
  String _selectedTimeframe = 'Today'; // Today, This Week, This Month
  String? _expandedTimeSegment; // 'Morning', 'Afternoon', 'Night', or null

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;

    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final fieldColor = isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6);
    final cardBg = isThemeDark ? const Color(0xFF1E293B).withOpacity(0.75) : Colors.white;
    final cardBorder = isThemeDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    final streakState = ref.watch(streakProvider);
    final energyState = ref.watch(userEnergyProvider);
    final focusTasks = ref.watch(focusTasksProvider);
    final quickTasks = ref.watch(quickTasksProvider);
    final focusTasksNotifier = ref.watch(focusTasksProvider.notifier);
    final quickTasksNotifier = ref.watch(quickTasksProvider.notifier);

    final authUser = ref.watch(authUserProvider);
    final String rawName = authUser?['nickname'] ?? authUser?['displayName'] ?? authUser?['name'] ?? 'User';

    final int completedFocus = focusTasksNotifier.completedCount;
    final int completedQuick = quickTasksNotifier.completedCount;
    final int totalCompletedTasks = completedFocus + completedQuick;

    final int completedMinutes = (completedQuick * 10) + (completedFocus * 25);
    final String focusTimeText = formatDuration(completedMinutes);

    final displayTasks = _getDisplayTasksForTimeframe(_selectedTimeframe, focusTasks);


    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress.',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analytics & Progress Overview',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // WEEKLY ACTIVITY HEATMAP & STREAK INTEGRATION (CLICKABLE FOR MONTHLY CALENDAR & BACKTRACKING)
              GestureDetector(
                onTap: () => _showMonthlyStreakCalendarModal(context, isThemeDark, primaryTextColor, secondaryTextColor, fieldColor, cardBg, cardBorder),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'WEEKLY ACTIVITY',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: secondaryTextColor.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                LucideIcons.calendarDays,
                                size: 13,
                                color: secondaryTextColor.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Builder(builder: (ctx) {
                          final hasStreak = streakState.currentStreak > 0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: hasStreak
                                  ? const LinearGradient(
                                      colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
                                    )
                                  : null,
                              color: hasStreak ? null : (isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(12),
                              border: hasStreak ? null : Border.all(color: isThemeDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasStreak ? LucideIcons.flame : LucideIcons.minus,
                                  size: 13,
                                  color: hasStreak ? Colors.white : (isThemeDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasStreak ? '${streakState.currentStreak} Streak' : 'No streak',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: hasStreak ? Colors.white : (isThemeDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final now = DateTime.now();
                      final monday = now.subtract(Duration(days: now.weekday - 1));
                      final List<DateTime> weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: weekDays.map((date) {
                                final String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                final bool hasCompleted = streakState.completionHistory.contains(dateStr);
                                final bool isToday = date.day == now.day && date.month == now.month && date.year == now.year;
                                final bool isPartial = isToday && !hasCompleted && (completedFocus > 0 || completedQuick > 0);

                                String dayLabel = 'MON';
                                switch (date.weekday) {
                                  case 1: dayLabel = 'MON'; break;
                                  case 2: dayLabel = 'TUE'; break;
                                  case 3: dayLabel = 'WED'; break;
                                  case 4: dayLabel = 'THU'; break;
                                  case 5: dayLabel = 'FRI'; break;
                                  case 6: dayLabel = 'SAT'; break;
                                  case 7: dayLabel = 'SUN'; break;
                                }

                                return Expanded(
                                  child: Center(
                                    child: _buildHeatmapDay(dayLabel, isFull: hasCompleted, isPartial: isPartial, isDark: isThemeDark),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 4),
                                Text('No Tasks  ', style: GoogleFonts.inter(fontSize: 10, color: secondaryTextColor)),
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.35), borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 4),
                                Text('Partial  ', style: GoogleFonts.inter(fontSize: 10, color: secondaryTextColor)),
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 4),
                                Text('Completed (100%)', style: GoogleFonts.inter(fontSize: 10, color: secondaryTextColor)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Compact Aesthetic Period Segment Selector (Today | This Week | This Month)
              Container(
                height: 32,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: ['Today', 'This Week', 'This Month'].map((tf) {
                      final isSelected = _selectedTimeframe == tf;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTimeframe = tf),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isThemeDark ? const Color(0xFF1E40AF) : const Color(0xFF1D4ED8))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF1D4ED8).withOpacity(0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              tf,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : secondaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // 1. COMPLETION BAR & STATUS WIDGET
                Builder(builder: (context) {
                  final int realDone = displayTasks.where((t) => t.isDone).length;
                  final int realRemaining = displayTasks.where((t) => !t.isDone).length;
                  final int totalTasks = realDone + realRemaining;
                  final double completionRate = totalTasks > 0 ? (realDone / totalTasks) : 0.0;
                  final int percentage = (completionRate * 100).round();

                  String statusText;
                  Color statusColor;
                  IconData statusIcon;

                  if (totalTasks == 0) {
                    statusText = 'No tasks recorded for $_selectedTimeframe';
                    statusColor = secondaryTextColor;
                    statusIcon = LucideIcons.circle;
                  } else if (percentage == 100) {
                    statusText = '100% Completed • Outstanding Work!';
                    statusColor = const Color(0xFF10B981);
                    statusIcon = LucideIcons.checkCheck;
                  } else if (percentage >= 50) {
                    statusText = '$percentage% Done • Strong Momentum!';
                    statusColor = const Color(0xFF10B981);
                    statusIcon = LucideIcons.trendingUp;
                  } else {
                    statusText = '$percentage% Done • In Progress';
                    statusColor = const Color(0xFFF59E0B);
                    statusIcon = LucideIcons.clock;
                  }

                  return GestureDetector(
                    onTap: () => _showTasksBreakdownModal(
                      context,
                      isDoneList: false,
                      isDark: isThemeDark,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      fieldColor: fieldColor,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isThemeDark ? 0.25 : 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(statusIcon, size: 16, color: statusColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'COMPLETION & STATUS',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: secondaryTextColor.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  '$percentage%',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            statusText,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // High-level Dual Completion Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 10,
                              width: double.infinity,
                              color: isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              child: Row(
                                children: [
                                  if (completionRate > 0)
                                    Flexible(
                                      flex: (completionRate * 1000).toInt(),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF047857), // Dark green completed
                                        ),
                                      ),
                                    ),
                                  if (1.0 - completionRate > 0)
                                    Flexible(
                                      flex: ((1.0 - completionRate) * 1000).toInt(),
                                      child: Container(
                                        color: isThemeDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), // remaining
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Legend Breakdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Done: $realDone',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isThemeDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isThemeDark ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Remaining: $realRemaining',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(LucideIcons.listTodo, size: 12, color: secondaryTextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Total: $totalTasks',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Summary Cards Row - Wrapped in Horizontal Scroll View to guarantee ZERO right overflow on any screen
                Builder(builder: (context) {
                  final int realDone = displayTasks.where((t) => t.isDone).length;
                  final int realRemaining = displayTasks.where((t) => !t.isDone).length;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Current Streak Card (Clickable to open Monthly Progress Calendar)
                        GestureDetector(
                          onTap: () => _showMonthlyStreakCalendarModal(context, isThemeDark, primaryTextColor, secondaryTextColor, fieldColor, cardBg, cardBorder),
                          child: Builder(builder: (ctx) {
                            final hasStreak = streakState.currentStreak > 0;
                            final streakColor = hasStreak ? const Color(0xFFEA580C) : (isThemeDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
                            final streakTextColor = hasStreak ? const Color(0xFFEA580C) : secondaryTextColor;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 120,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: hasStreak
                                    ? const Color(0xFFEA580C).withOpacity(0.06)
                                    : cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasStreak
                                      ? const Color(0xFFEA580C).withOpacity(0.25)
                                      : cardBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Streak',
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: secondaryTextColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 350),
                                        child: hasStreak
                                            ? const Icon(LucideIcons.flame, size: 16, color: Color(0xFFEA580C), key: ValueKey('fire'))
                                            : Icon(LucideIcons.moonStar, size: 16, color: isThemeDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), key: const ValueKey('no-fire')),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 300),
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: hasStreak ? primaryTextColor : (isThemeDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      ),
                                      child: Text(
                                        hasStreak ? '${streakState.currentStreak} Days' : '— Days',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasStreak ? 'Tap for Calendar' : 'Start your streak!',
                                    style: GoogleFonts.inter(fontSize: 9, color: streakTextColor, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),

                        // Total Tasks Done Card (Clickable to show all tasks done!)
                        GestureDetector(
                          onTap: () => _showTasksBreakdownModal(
                            context,
                            isDoneList: true,
                            isDark: isThemeDark,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            fieldColor: fieldColor,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                          ),
                          child: Container(
                            width: 120,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Tasks Done',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: secondaryTextColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF047857)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  child: Text(
                                    '$realDone',
                                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: primaryTextColor),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to view done',
                                  style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF047857), fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // In Progress Card (Clickable to show tasks in progress / waiting!)
                        GestureDetector(
                          onTap: () => _showTasksBreakdownModal(
                            context,
                            isDoneList: false,
                            isDark: isThemeDark,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            fieldColor: fieldColor,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                          ),
                          child: Container(
                            width: 120,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'In Progress',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: secondaryTextColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(LucideIcons.clock, size: 16, color: Color(0xFFF59E0B)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  child: Text(
                                    '$realRemaining',
                                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: primaryTextColor),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to view pending',
                                  style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // 3. TIME-OF-DAY TASKS BREAKDOWN (Vertical Clickable Breakdown: Morning, Afternoon, Night)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TIME-OF-DAY TASKS BREAKDOWN',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: secondaryTextColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Morning Section
                _buildTimeSegmentAccordionItem(
                  segment: 'Morning',
                  icon: LucideIcons.sunrise,
                  accentColor: const Color(0xFFF59E0B),
                  displayTasks: displayTasks,
                  isDark: isThemeDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  fieldColor: fieldColor,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                ),

                // Afternoon Section
                _buildTimeSegmentAccordionItem(
                  segment: 'Afternoon',
                  icon: LucideIcons.sunMedium,
                  accentColor: const Color(0xFFEA580C),
                  displayTasks: displayTasks,
                  isDark: isThemeDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  fieldColor: fieldColor,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                ),

                // Night Section
                _buildTimeSegmentAccordionItem(
                  segment: 'Night',
                  icon: LucideIcons.moon,
                  accentColor: const Color(0xFF8B5CF6),
                  displayTasks: displayTasks,
                  isDark: isThemeDark,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  fieldColor: fieldColor,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                ),
                const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  void _showTasksBreakdownModal(
    BuildContext context, {
    required bool isDoneList,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color fieldColor,
    required Color cardBg,
    required Color cardBorder,
  }) {
    final focusTasks = ref.read(focusTasksProvider);
    final displayTasks = _getDisplayTasksForTimeframe(_selectedTimeframe, focusTasks);

    // Done items:
    final List<Map<String, String>> doneItems = displayTasks
        .where((t) => t.isDone)
        .map((dt) => {
              'title': dt.title,
              'type': dt.typeLabel,
              'duration': dt.durationText,
            })
        .toList();

    // In-progress items:
    final List<Map<String, String>> inProgressItems = displayTasks
        .where((t) => !t.isDone)
        .map((dt) => {
              'title': dt.title,
              'type': dt.typeLabel,
              'duration': dt.durationText,
            })
        .toList();

    final itemsToShow = isDoneList ? doneItems : inProgressItems;
    final titleText = isDoneList ? 'Completed Tasks ($_selectedTimeframe)' : 'In Progress & Waiting Tasks ($_selectedTimeframe)';
    final emptyText = isDoneList ? 'No completed tasks found for this period.' : 'No in-progress tasks waiting. You are all caught up!';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDoneList
                          ? const Color(0xFF064E3B).withOpacity(0.3)
                          : const Color(0xFFD97706).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDoneList ? LucideIcons.checkCircle2 : LucideIcons.clock,
                      size: 18,
                      color: isDoneList ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          '${itemsToShow.length} task${itemsToShow.length == 1 ? "" : "s"} total',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 18, color: secondaryTextColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (itemsToShow.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Center(
                    child: Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: itemsToShow.length,
                    itemBuilder: (context, idx) {
                      final item = itemsToShow[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDoneList
                                ? const Color(0xFF047857).withOpacity(0.3)
                                : cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDoneList ? LucideIcons.check : LucideIcons.circle,
                              size: 16,
                              color: isDoneList ? const Color(0xFF10B981) : secondaryTextColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item['title'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                  decoration: isDoneList ? TextDecoration.lineThrough : null,
                                  decorationColor: secondaryTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDoneList
                                    ? const Color(0xFF064E3B)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item['type'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDoneList ? const Color(0xFF6EE7B7) : secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showMonthlyStreakCalendarModal(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color fieldColor,
    Color cardBg,
    Color cardBorder,
  ) {
    DateTime displayedMonth = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final streakState = ref.watch(streakProvider);
            final history = streakState.completionHistory;

            const monthsList = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
            final monthYearStr = '${monthsList[displayedMonth.month - 1]} ${displayedMonth.year}';
            final int daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
            final firstWeekday = DateTime(displayedMonth.year, displayedMonth.month, 1).weekday; // 1 = Mon, 7 = Sun

            final prefixMonth = '${displayedMonth.year}-${displayedMonth.month.toString().padLeft(2, '0')}';
            final int completedDaysCount = history.where((d) => d.startsWith(prefixMonth)).length;
            final int monthlyRate = daysInMonth > 0 ? ((completedDaysCount / daysInMonth) * 100).round() : 0;

            final now = DateTime.now();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: primaryTextColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top Month Backtracking Bar (‹ Month Year ›)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.chevronLeft, color: primaryTextColor),
                          onPressed: () {
                            setModalState(() {
                              displayedMonth = DateTime(displayedMonth.year, displayedMonth.month - 1);
                            });
                          },
                        ),
                        Row(
                          children: [
                            const Icon(LucideIcons.flame, size: 18, color: Color(0xFFEA580C)),
                            const SizedBox(width: 6),
                            Text(
                              monthYearStr,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(LucideIcons.chevronRight, color: primaryTextColor),
                          onPressed: () {
                            setModalState(() {
                              displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Monthly Overview Metrics Cards (Completed Days, Monthly Rate, Streak Count)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: fieldColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COMPLETED',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: secondaryTextColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$completedDaysCount / $daysInMonth days',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: fieldColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MONTHLY RATE',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: secondaryTextColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$monthlyRate%',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFEA580C)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              displayedMonth = DateTime.now();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                'Today',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Calendar Weekday Header (MON TUE WED THU FRI SAT SUN)
                    Row(
                      children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((day) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: secondaryTextColor.withOpacity(0.6),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Days Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: (firstWeekday - 1) + daysInMonth,
                      itemBuilder: (context, index) {
                        if (index < firstWeekday - 1) {
                          return const SizedBox();
                        }
                        final dayNumber = index - (firstWeekday - 1) + 1;
                        final dateStr = '${displayedMonth.year}-${displayedMonth.month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
                        final isCompleted = history.contains(dateStr);
                        final isToday = displayedMonth.year == now.year && displayedMonth.month == now.month && dayNumber == now.day;
                        final isFuture = DateTime(displayedMonth.year, displayedMonth.month, dayNumber).isAfter(now);

                        return Container(
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFFEA580C)
                                : (isToday ? fieldColor : fieldColor.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(10),
                            border: isToday
                                ? Border.all(color: const Color(0xFFEA580C), width: 1.8)
                                : Border.all(color: cardBorder),
                            boxShadow: isCompleted
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFEA580C).withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNumber',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isCompleted || isToday ? FontWeight.w800 : FontWeight.w500,
                                  color: isCompleted
                                      ? Colors.white
                                      : (isFuture ? secondaryTextColor.withOpacity(0.35) : primaryTextColor),
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(height: 1),
                                const Icon(LucideIcons.flame, size: 10, color: Colors.white),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeOfDayLegend({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: secondaryTextColor),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          count,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildCategoryRow({
    required IconData icon,
    required String title,
    required String count,
    required double percentage,
    required Color color,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: primaryTextColor),
                      ),
                      Text(
                        count,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 6,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isTaskScheduledForDate(FocusTaskItem task, DateTime targetDate) {
    final normDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final normDateStr = '${normDate.year}-${normDate.month.toString().padLeft(2, '0')}-${normDate.day.toString().padLeft(2, '0')}';
    final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][normDate.weekday - 1];

    if (task.skippedDates.contains(normDateStr)) return false;
    if (task.repeatUntil != null) {
      final until = DateTime(task.repeatUntil!.year, task.repeatUntil!.month, task.repeatUntil!.day);
      if (normDate.isAfter(until)) return false;
    }
    if (task.repeatDays.isNotEmpty) {
      return task.repeatDays.any((d) => d.trim().toLowerCase() == dayName.trim().toLowerCase());
    }
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    return normDate == todayDate;
  }

  String _getSegmentForTask(String? dueTime, String defaultSegment) {
    if (dueTime != null && dueTime.isNotEmpty) {
      final clean = dueTime.trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? -1;
        if (h != -1) {
          if (clean.toLowerCase().contains('pm') && h < 12) h += 12;
          if (clean.toLowerCase().contains('am') && h == 12) h = 0;
          if (h >= 5 && h < 12) return 'Morning';
          if (h >= 12 && h < 17) return 'Afternoon';
          if (h >= 17 || (h >= 0 && h < 5)) return 'Night';
        }
      }
    }
    final cleanDef = defaultSegment.trim();
    if (cleanDef.toLowerCase() == 'morning') return 'Morning';
    if (cleanDef.toLowerCase() == 'afternoon') return 'Afternoon';
    if (cleanDef.toLowerCase() == 'night') return 'Night';
    return 'Morning';
  }

  List<ProgressDisplayTask> _getDisplayTasksForTimeframe(
    String timeframe,
    List<FocusTaskItem> focusTasks,
  ) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final Set<String> activeFocusIds = {};
    List<FocusTaskItem> activeFocus = [];

    if (timeframe == 'Today') {
      activeFocus = focusTasks.where((t) => _isTaskScheduledForDate(t, todayDate)).toList();
    } else if (timeframe == 'This Week') {
      final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
      final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
      for (final task in focusTasks) {
        for (final day in weekDays) {
          if (_isTaskScheduledForDate(task, day)) {
            if (!activeFocusIds.contains(task.id)) {
              activeFocusIds.add(task.id);
              activeFocus.add(task);
            }
            break;
          }
        }
      }
    } else if (timeframe == 'This Month') {
      final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
      final monthDays = List.generate(daysInMonth, (i) => DateTime(now.year, now.month, i + 1));
      for (final task in focusTasks) {
        for (final day in monthDays) {
          if (_isTaskScheduledForDate(task, day)) {
            if (!activeFocusIds.contains(task.id)) {
              activeFocusIds.add(task.id);
              activeFocus.add(task);
            }
            break;
          }
        }
      }
    } else {
      activeFocus = focusTasks;
    }

    final List<ProgressDisplayTask> list = [];
    for (final f in activeFocus) {
      list.add(ProgressDisplayTask(
        id: f.id,
        title: f.title,
        durationText: formatDurationString(f.duration),
        dueTime: f.dueTime,
        segment: _getSegmentForTask(f.dueTime, f.timeSegment),
        isDone: f.isDone,
        typeLabel: '${f.timeSegment} Focus',
      ));
    }

    return list;
  }

  Widget _buildTimeSegmentAccordionItem({
    required String segment,
    required IconData icon,
    required Color accentColor,
    required List<ProgressDisplayTask> displayTasks,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color fieldColor,
    required Color cardBg,
    required Color cardBorder,
  }) {
    final isExpanded = _expandedTimeSegment == segment;
    final tasks = displayTasks.where((t) => t.segment == segment).toList();
    tasks.sort((a, b) {
      if (!a.isDone && b.isDone) return -1;
      if (a.isDone && !b.isDone) return 1;
      return 0;
    });
    final int totalCount = tasks.length;
    final int doneCount = tasks.where((t) => t.isDone).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827).withOpacity(0.85) : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? accentColor.withOpacity(0.45) : cardBorder,
          width: isExpanded ? 1.4 : 1.0,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Clickable Header Row
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                if (_expandedTimeSegment == segment) {
                  _expandedTimeSegment = null;
                } else {
                  _expandedTimeSegment = segment;
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Segment Icon Box
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 17, color: accentColor),
                  ),
                  const SizedBox(width: 13),
                  // Segment Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          segment,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalCount == 0
                              ? 'No tasks'
                              : '$totalCount task${totalCount == 1 ? '' : 's'} • $doneCount done',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Stats badge (if totalCount > 0)
                  if (totalCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: (doneCount == totalCount && totalCount > 0)
                            ? const Color(0xFF047857).withOpacity(0.18)
                            : accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (doneCount == totalCount && totalCount > 0)
                              ? const Color(0xFF047857).withOpacity(0.4)
                              : accentColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        doneCount == totalCount ? '100% Done' : '$doneCount / $totalCount',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: (doneCount == totalCount && totalCount > 0)
                              ? const Color(0xFF10B981)
                              : accentColor,
                        ),
                      ),
                    ),
                  // Chevron with animated rotation
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 17,
                      color: isExpanded ? accentColor : secondaryTextColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Body (Task Breakdown)
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            child: isExpanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                        ),
                        const SizedBox(height: 12),
                        if (tasks.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: fieldColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'No ${segment.toLowerCase()} tasks recorded.',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: secondaryTextColor,
                              ),
                            ),
                          )
                        else
                          Column(
                            children: tasks.map<Widget>((ProgressDisplayTask t) {
                              final bool isDone = t.isDone;
                              final Color filledBg = isDone
                                  ? const Color(0xFF064E3B).withOpacity(0.35)
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC));

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: filledBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDone
                                        ? const Color(0xFF047857).withOpacity(0.35)
                                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isDone ? LucideIcons.checkCircle2 : LucideIcons.clock,
                                      size: 16,
                                      color: isDone ? const Color(0xFF10B981) : accentColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.title,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: primaryTextColor,
                                              decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                              decorationColor: secondaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${t.durationText}${t.dueTime != null && t.dueTime!.isNotEmpty ? ' • ${t.dueTime}' : ''}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? const Color(0xFF047857).withOpacity(0.2)
                                            : accentColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDone
                                              ? const Color(0xFF047857).withOpacity(0.4)
                                              : accentColor.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        isDone ? 'Finished' : 'Unfinished',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isDone ? const Color(0xFF6EE7B7) : accentColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapDay(String dayName, {bool isFull = false, bool isPartial = false, required bool isDark}) {
    final bgColor = isFull
        ? const Color(0xFFF59E0B)
        : (isPartial
            ? const Color(0xFFF59E0B).withOpacity(0.35)
            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)));

    final textColor = isFull
        ? Colors.black
        : (isPartial ? (isDark ? Colors.white : Colors.black87) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)));

    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isFull
                ? [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: isFull
              ? const Icon(Icons.check, size: 18, color: Colors.black)
              : (isPartial
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF59E0B)),
                    )
                  : null),
        ),
        const SizedBox(height: 6),
        Text(
          dayName,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
        ),
      ],
    );
  }


  Widget _buildSegmentBar({
    required String title,
    required int count,
    required int total,
    required Color color,
    required IconData icon,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final double pct = total > 0 ? (count / total).clamp(0.05, 1.0) : 0.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
            Text(
              '$count tasks',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(
    Color primaryTextColor,
    Color secondaryTextColor,
    Color cardBg,
    Color cardBorder,
  ) {
    final focusTasks = ref.watch(focusTasksProvider);
    final quickTasks = ref.watch(quickTasksProvider);
    final now = DateTime.now();

    final List<Map<String, dynamic>> items = [];

    for (final task in focusTasks) {
      bool isDelayed = false;
      if (!task.isDone && task.dueTime != null) {
        final parts = task.dueTime!.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final target = DateTime(now.year, now.month, now.day, h, m);
          if (now.isAfter(target)) {
            isDelayed = true;
          }
        }
      }

      String statusStr = task.isDone ? 'COMPLETED' : (isDelayed ? 'DELAYED' : 'UNFINISHED');
      Color statusColor = task.isDone
          ? const Color(0xFF10B981)
          : (isDelayed ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
      IconData icon = task.isDone
          ? LucideIcons.checkCheck
          : (isDelayed ? LucideIcons.clock8 : LucideIcons.alertTriangle);

      items.add({
        'id': task.id,
        'title': task.title,
        'time': task.dueTime != null ? 'Due ${formatTimeAmPm(task.dueTime)} (${task.timeSegment})' : task.timeSegment,
        'type': 'Focus Task',
        'status': statusStr,
        'color': statusColor,
        'icon': icon,
      });
    }

    for (final task in quickTasks) {
      bool isDelayed = false;
      if (!task.isCompleted && task.dueTime != null) {
        final parts = task.dueTime!.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final target = DateTime(now.year, now.month, now.day, h, m);
          if (now.isAfter(target)) {
            isDelayed = true;
          }
        }
      }

      String statusStr = task.isCompleted ? 'COMPLETED' : (isDelayed ? 'DELAYED' : 'UNFINISHED');
      Color statusColor = task.isCompleted
          ? const Color(0xFF10B981)
          : (isDelayed ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
      IconData icon = task.isCompleted
          ? LucideIcons.check
          : (isDelayed ? LucideIcons.clock : LucideIcons.listTodo);

      items.add({
        'id': task.id,
        'title': task.title,
        'time': task.dueTime != null ? 'Due ${formatTimeAmPm(task.dueTime)}' : 'Quick Note',
        'type': 'Quick Task',
        'status': statusStr,
        'color': statusColor,
        'icon': icon,
      });
    }

    final filtered = items.where((item) {
      final titleMatch = item['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final statusMatch = item['status'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final searchOk = titleMatch || statusMatch;

      final filterOk = (_statusFilter == 'ALL') || (item['status'] == _statusFilter);
      return searchOk && filterOk;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Text(
          'No activity found matching query.',
          style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: cardBorder),
        itemBuilder: (context, idx) {
          final item = filtered[idx];
          final Color statusColor = item['color'] as Color;
          final IconData statusIcon = item['icon'] as IconData;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                  ),
                  child: Icon(statusIcon, size: 16, color: statusColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              item['status'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item['type']} • ${item['time']}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: secondaryTextColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DailyTasksScreen extends ConsumerStatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  ConsumerState<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends ConsumerState<DailyTasksScreen> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _plusController;
  late Animation<double> _plusAnim;
  late final ScrollController _dateScrollController;
  late final List<DateTime> _scrollableDates;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 60));
    _scrollableDates = List.generate(150, (i) => startDay.add(Duration(days: i)));
    _dateScrollController = ScrollController();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _plusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _plusAnim = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _plusController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(_selectedDate, animate: false);
    });
  }

  void _scrollToDate(DateTime targetDate, {bool animate = true}) {
    if (!_dateScrollController.hasClients) return;
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final index = _scrollableDates.indexWhere((d) => d.year == target.year && d.month == target.month && d.day == target.day);
    if (index != -1) {
      const double itemWidth = 58.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
      final clampedOffset = targetOffset.clamp(0.0, _dateScrollController.position.maxScrollExtent);
      if (animate) {
        _dateScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _dateScrollController.jumpTo(clampedOffset);
      }
    }
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _waveController.dispose();
    _plusController.dispose();
    super.dispose();
  }

  List<DateTime> _getWeekDays(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _getShortDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _formatTaskTime(String? dueTime, String timeSegment) {
    if (dueTime != null && dueTime.isNotEmpty) {
      if (dueTime.contains(':')) {
        return formatTimeAmPm(dueTime);
      }
      return dueTime;
    }
    switch (timeSegment) {
      case 'Morning': return '8:00 AM';
      case 'Afternoon': return '1:00 PM';
      case 'Night': return '8:00 PM';
      default:
        final nowH = DateTime.now().hour;
        if (nowH >= 5 && nowH < 12) return '8:00 AM';
        if (nowH >= 12 && nowH < 18) return '1:00 PM';
        return '8:00 PM';
    }
  }

  int _timeToMinutes(String timeFormatted) {
    try {
      final parts = timeFormatted.split(' ');
      final hm = parts[0].split(':');
      int h = int.tryParse(hm[0]) ?? 8;
      final m = int.tryParse(hm[1]) ?? 0;
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && h < 12) h += 12;
      if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  String _calculateDurationGap(int currentMinutes, int prevMinutes) {
    final diff = (currentMinutes - prevMinutes).abs();
    if (diff == 0) return '';
    final hours = diff ~/ 60;
    final mins = diff % 60;
    if (hours > 0 && mins > 0) return '${hours}H ${mins}M';
    if (hours > 0) return '${hours}H';
    return '${mins}M';
  }

  Color _parseTaskColor(String? colorHex, String timeSegment, String? dueTime) {
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        final clean = colorHex.replaceAll('#', '').trim();
        if (clean.length == 6) {
          return Color(int.parse('0xFF$clean'));
        } else if (clean.length == 8) {
          return Color(int.parse('0x$clean'));
        }
      } catch (_) {}
    }

    return const Color(0xFF1E3A8A);
  }

  Color _getTimeOfDayColor(String timeSegment, String? dueTime) {
    // Determine hour from dueTime if available
    if (dueTime != null && dueTime.isNotEmpty && dueTime.contains(':')) {
      try {
        final lower = dueTime.toLowerCase().trim();
        final parts = lower.split(':');
        int hour = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim());
        final isPm = lower.contains('pm') || lower.contains('p.m.');
        final isAm = lower.contains('am') || lower.contains('a.m.');
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        if (hour >= 5 && hour < 12) return const Color(0xFFF59E0B); // morning amber
        if (hour >= 12 && hour < 18) return const Color(0xFFF97316); // afternoon orange
        return const Color(0xFF7C3AED); // night violet
      } catch (_) {}
    }
    // Fallback to timeSegment
    final seg = timeSegment.toLowerCase().trim();
    if (seg.contains('morning')) return const Color(0xFFF59E0B);
    if (seg.contains('afternoon')) return const Color(0xFFF97316);
    if (seg.contains('night') || seg.contains('evening')) return const Color(0xFF7C3AED);

    // Current hour fallback
    final nowH = DateTime.now().hour;
    if (nowH >= 5 && nowH < 12) return const Color(0xFFF59E0B);
    if (nowH >= 12 && nowH < 18) return const Color(0xFFF97316);
    return const Color(0xFF7C3AED); // night violet
  }

  IconData _getTimeOfDayIcon(String? dueTime, String timeSegment) {
    if (dueTime != null && dueTime.isNotEmpty) {
      final lower = dueTime.toLowerCase().trim();
      if (lower.contains(':')) {
        try {
          final parts = lower.split(':');
          int hour = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim());
          final isPm = lower.contains('pm') || lower.contains('p.m.');
          final isAm = lower.contains('am') || lower.contains('a.m.');
          if (isPm && hour < 12) hour += 12;
          if (isAm && hour == 12) hour = 0;

          if (hour >= 5 && hour < 12) {
            return LucideIcons.sunrise;
          } else if (hour >= 12 && hour < 18) {
            return LucideIcons.sunMedium;
          } else {
            return LucideIcons.moon;
          }
        } catch (_) {}
      }
    }

    final seg = timeSegment.toLowerCase().trim();
    if (seg.contains('morning')) {
      return LucideIcons.sunrise;
    } else if (seg.contains('afternoon')) {
      return LucideIcons.sunMedium;
    } else if (seg.contains('night') || seg.contains('evening')) {
      return LucideIcons.moon;
    }

    final nowH = DateTime.now().hour;
    if (nowH >= 5 && nowH < 12) return LucideIcons.sunrise;
    if (nowH >= 12 && nowH < 18) return LucideIcons.sunMedium;
    return LucideIcons.moon;
  }

  IconData _getTaskVectorIcon(String? iconName, String timeSegment, String? dueTime) {
    if (iconName != null && iconName.isNotEmpty) {
      final lower = iconName.toLowerCase().trim();
      if (lower.contains('briefcase') || lower.contains('work')) return LucideIcons.briefcase;
      if (lower.contains('book') || lower.contains('study') || lower.contains('read')) return LucideIcons.bookOpen;
      if (lower.contains('dumbbell') || lower.contains('gym') || lower.contains('health') || lower.contains('workout')) return LucideIcons.dumbbell;
      if (lower.contains('code') || lower.contains('dev')) return LucideIcons.code;
      if (lower.contains('coffee')) return LucideIcons.coffee;
      if (lower.contains('target') || lower.contains('focus')) return LucideIcons.target;
      if (lower.contains('zap') || lower.contains('energy') || lower.contains('bolt')) return LucideIcons.zap;
      if (lower.contains('compass')) return LucideIcons.compass;
      if (lower.contains('sparkles') || lower.contains('star')) return LucideIcons.sparkles;
      if (lower.contains('sunrise')) return LucideIcons.sunrise;
      if (lower.contains('sunset')) return LucideIcons.sunset;
      if (lower.contains('sun')) return LucideIcons.sunMedium;
      if (lower.contains('moon')) return LucideIcons.moon;
      if (lower.contains('flame') || lower.contains('fire')) return LucideIcons.flame;
      if (lower.contains('pencil') || lower.contains('edit')) return LucideIcons.pencil;
      if (lower.contains('calendar')) return LucideIcons.calendar;
      if (lower.contains('clock') || lower.contains('timer')) return LucideIcons.clock;
      if (lower.contains('search')) return LucideIcons.search;
      if (lower.contains('file') || lower.contains('doc')) return LucideIcons.fileText;
      if (lower.contains('list') || lower.contains('todo')) return LucideIcons.listTodo;
      if (lower.contains('music')) return LucideIcons.music;
      if (lower.contains('heart') || lower.contains('love')) return LucideIcons.heart;
      if (lower.contains('shopping') || lower.contains('cart')) return LucideIcons.shoppingCart;
      if (lower.contains('trophy')) return LucideIcons.trophy;
      if (lower.contains('user') || lower.contains('person')) return LucideIcons.user;
      if (lower.contains('home') || lower.contains('house')) return LucideIcons.home;
      if (lower.contains('settings') || lower.contains('gear')) return LucideIcons.settings;
      if (lower.contains('bell') || lower.contains('remind')) return LucideIcons.bell;
      if (lower.contains('check')) return LucideIcons.checkCircle2;
      if (lower.contains('flag')) return LucideIcons.flag;
      if (lower.contains('award')) return LucideIcons.award;
      if (lower.contains('bike')) return LucideIcons.bike;
      if (lower.contains('brush') || lower.contains('paint')) return LucideIcons.brush;
      if (lower.contains('camera')) return LucideIcons.camera;
      if (lower.contains('car')) return LucideIcons.car;
      if (lower.contains('gift')) return LucideIcons.gift;
      if (lower.contains('game') || lower.contains('play')) return LucideIcons.gamepad2;
      if (lower.contains('graduation') || lower.contains('school')) return LucideIcons.graduationCap;
      if (lower.contains('map') || lower.contains('pin')) return LucideIcons.mapPin;
      if (lower.contains('phone') || lower.contains('call')) return LucideIcons.phone;
      if (lower.contains('scissors')) return LucideIcons.scissors;
      if (lower.contains('smile') || lower.contains('happy')) return LucideIcons.smile;
      if (lower.contains('laptop') || lower.contains('computer')) return LucideIcons.laptop;
      if (lower.contains('headphones')) return LucideIcons.headphones;
      if (lower.contains('utensils') || lower.contains('food') || lower.contains('eat')) return LucideIcons.utensils;
      if (lower.contains('plane') || lower.contains('flight') || lower.contains('travel')) return LucideIcons.plane;
      if (lower.contains('shield')) return LucideIcons.shield;
      if (lower.contains('wallet') || lower.contains('money')) return LucideIcons.wallet;
      if (lower.contains('wrench') || lower.contains('fix')) return LucideIcons.wrench;
      if (lower.contains('leaf') || lower.contains('eco')) return LucideIcons.leaf;
      if (lower.contains('battery')) return LucideIcons.battery;
      if (lower.contains('box')) return LucideIcons.box;
      if (lower.contains('calculator')) return LucideIcons.calculator;
      if (lower.contains('creditcard') || lower.contains('card')) return LucideIcons.creditCard;
      if (lower.contains('dollarsign') || lower.contains('dollar')) return LucideIcons.dollarSign;
      if (lower.contains('mail') || lower.contains('email')) return LucideIcons.mail;
      if (lower.contains('message') || lower.contains('chat')) return LucideIcons.messageSquare;
      if (lower.contains('mic')) return LucideIcons.mic;
      if (lower.contains('film') || lower.contains('video') || lower.contains('movie')) return LucideIcons.film;
      if (lower.contains('image') || lower.contains('photo') || lower.contains('picture')) return LucideIcons.image;
      if (lower.contains('piechart')) return LucideIcons.pieChart;
      if (lower.contains('barchart') || lower.contains('chart')) return LucideIcons.barChart;
      if (lower.contains('sliders')) return LucideIcons.sliders;
      if (lower.contains('truck') || lower.contains('delivery')) return LucideIcons.truck;
      if (lower.contains('rocket') || lower.contains('launch')) return LucideIcons.rocket;
      if (lower.contains('package')) return LucideIcons.package;
      if (lower.contains('lifebuoy') || lower.contains('help')) return LucideIcons.lifeBuoy;
      if (lower.contains('printer')) return LucideIcons.printer;
      if (lower.contains('tag')) return LucideIcons.tag;
      if (lower.contains('thumbsup') || lower.contains('like')) return LucideIcons.thumbsUp;
      if (lower.contains('trash') || lower.contains('delete')) return LucideIcons.trash2;
      if (lower.contains('lightbulb') || lower.contains('idea')) return LucideIcons.lightbulb;
      if (lower.contains('alert')) return LucideIcons.alertCircle;
      if (lower.contains('archive')) return LucideIcons.archive;
      if (lower.contains('volume')) return LucideIcons.volume2;
      if (lower.contains('repeat')) return LucideIcons.repeat;
      if (lower.contains('star')) return LucideIcons.star;
    }
    return _getTimeOfDayIcon(dueTime, timeSegment);
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final cardBgColor = isThemeDark ? const Color(0xFF1E293B).withOpacity(0.85) : const Color(0xFFFFFFFF).withOpacity(0.92);

    final selectedDayName = _getShortDayName(_selectedDate.weekday);
    final rawFocusTasks = ref.watch(focusTasksProvider);
    final streakState = ref.watch(streakProvider);

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final selectedWeek = _getWeekDays(_selectedDate);
    final firstVisibleDate = DateTime(selectedWeek.first.year, selectedWeek.first.month, selectedWeek.first.day);
    final lastVisibleDate = DateTime(selectedWeek.last.year, selectedWeek.last.month, selectedWeek.last.day);

    bool checkDayHasUnfinished(DateTime day) {
      final dayDate = DateTime(day.year, day.month, day.day);
      if (dayDate.isAfter(todayDate)) return false;

      final dayShort = _getShortDayName(day.weekday);
      final dayDateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final bool isDayCompleted = streakState.completionHistory.contains(dayDateStr);
      if (isDayCompleted) return false;

      final tasksForDay = rawFocusTasks.where((t) {
        // Check if this date is skipped
        final skipStr = '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
        if (t.skippedDates.contains(skipStr)) return false;
        // Check repeatUntil
        if (t.repeatUntil != null) {
          final until = DateTime(t.repeatUntil!.year, t.repeatUntil!.month, t.repeatUntil!.day);
          if (dayDate.isAfter(until)) return false;
        }
        if (t.repeatDays.isNotEmpty) {
          return t.repeatDays.any((d) => d.trim().toLowerCase() == dayShort.trim().toLowerCase());
        }
        // No repeatDays = today-only task; only count it for today
        return dayDate == todayDate;
      }).toList();

      if (tasksForDay.isEmpty) return false;
      return tasksForDay.any((t) => !t.isDone);
    }

    final offscreenPastDates = _scrollableDates.where((d) {
      final dDate = DateTime(d.year, d.month, d.day);
      return dDate.isBefore(firstVisibleDate) && checkDayHasUnfinished(d);
    }).toList();

    final offscreenFutureDates = _scrollableDates.where((d) {
      final dDate = DateTime(d.year, d.month, d.day);
      return dDate.isAfter(lastVisibleDate) && checkDayHasUnfinished(d);
    }).toList();

    final selDateNorm = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final selDateStr = '${selDateNorm.year}-${selDateNorm.month.toString().padLeft(2, '0')}-${selDateNorm.day.toString().padLeft(2, '0')}';

    final filteredFocusTasks = rawFocusTasks.where((task) {
      // Skip if this date is explicitly skipped
      if (task.skippedDates.contains(selDateStr)) return false;
      // Respect repeatUntil end date
      if (task.repeatUntil != null) {
        final until = DateTime(task.repeatUntil!.year, task.repeatUntil!.month, task.repeatUntil!.day);
        if (selDateNorm.isAfter(until)) return false;
      }
      if (task.repeatDays.isNotEmpty) {
        return task.repeatDays.any((d) => d.trim().toLowerCase() == selectedDayName.trim().toLowerCase());
      }
      // No repeatDays = today-only task; only show for today
      return selDateNorm == todayDate;
    }).toList();

    final focusTasks = List<FocusTaskItem>.from(filteredFocusTasks)..sort((a, b) {
      final aMin = _timeToMinutes(_formatTaskTime(a.dueTime, a.timeSegment));
      final bMin = _timeToMinutes(_formatTaskTime(b.dueTime, b.timeSegment));
      return aMin.compareTo(bMin);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          children: [
            // 1. Month & Year Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _getMonthName(_selectedDate.month),
                              style: GoogleFonts.inter(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: primaryTextColor,
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: '${_selectedDate.year}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'daily schedule & focus goals.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                IconButton(
                  tooltip: 'Jump to Today',
                  icon: Icon(LucideIcons.calendar, size: 22, color: primaryTextColor),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() => _selectedDate = now);
                    _scrollToDate(now, animate: true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Interactive Scrollable Horizontal Calendar Strip (Scrollable left and right)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 84,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isThemeDark ? const Color(0xFF1E293B).withOpacity(0.7) : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isThemeDark ? const Color(0xFF334155).withOpacity(0.6) : Colors.grey[300]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    controller: _dateScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: offscreenPastDates.isNotEmpty ? 28 : 8,
                      right: offscreenFutureDates.isNotEmpty ? 28 : 8,
                    ),
                    itemCount: _scrollableDates.length,
                    itemBuilder: (context, index) {
                      final day = _scrollableDates[index];
                      final isSelected = day.day == _selectedDate.day && day.month == _selectedDate.month && day.year == _selectedDate.year;
                      final now = DateTime.now();
                      final isToday = day.day == now.day && day.month == now.month && day.year == now.year;
                      final dayShort = _getShortDayName(day.weekday);

                      final bool hasUnfinished = checkDayHasUnfinished(day);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedDate = day);
                            _scrollToDate(day, animate: true);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isThemeDark ? const Color(0xFF2563EB) : const Color(0xFF111827))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dayShort,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isToday ? const Color(0xFF2563EB) : secondaryTextColor),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.2)
                                        : (isToday ? const Color(0xFF2563EB).withOpacity(0.15) : Colors.transparent),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${day.day}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : (isToday ? const Color(0xFF2563EB) : primaryTextColor),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasUnfinished
                                        ? (isSelected ? const Color(0xFFFDE047) : const Color(0xFFEF4444))
                                        : Colors.transparent,
                                    boxShadow: hasUnfinished
                                        ? [
                                            BoxShadow(
                                              color: (isSelected ? const Color(0xFFFDE047) : const Color(0xFFEF4444)).withOpacity(0.6),
                                              blurRadius: 4,
                                              spreadRadius: 0.5,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (offscreenPastDates.isNotEmpty)
                  Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          final target = offscreenPastDates.last;
                          setState(() => _selectedDate = target);
                          _scrollToDate(target, animate: true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.chevronLeft, size: 12, color: Colors.white),
                              const SizedBox(height: 1),
                              Text(
                                '${offscreenPastDates.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (offscreenFutureDates.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          final target = offscreenFutureDates.first;
                          setState(() => _selectedDate = target);
                          _scrollToDate(target, animate: true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.chevronRight, size: 12, color: Colors.white),
                              const SizedBox(height: 1),
                              Text(
                                '${offscreenFutureDates.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 28),

            // 3. Smooth Vertical Timeline View
            if (focusTasks.isEmpty)
              _buildEmptyState()
            else
              ...focusTasks.asMap().entries.map((entry) {
                final index = entry.key;
                final task = entry.value;
                final bool isLast = index == focusTasks.length - 1;

                final formattedTime = _formatTaskTime(task.dueTime, task.timeSegment);
                final currentMinutes = _timeToMinutes(formattedTime);
                int prevMinutes = currentMinutes;
                if (index > 0) {
                  final prevTask = focusTasks[index - 1];
                  prevMinutes = _timeToMinutes(_formatTaskTime(prevTask.dueTime, prevTask.timeSegment));
                }

                final durationGap = index > 0 ? _calculateDurationGap(currentMinutes, prevMinutes) : '';
                final timeOfDayColor = _getTimeOfDayColor(task.timeSegment, task.dueTime);
                final taskColor = _parseTaskColor(task.colorHex, task.timeSegment, task.dueTime);
                final timeIcon = _getTimeOfDayIcon(task.dueTime, task.timeSegment);
                final taskVectorIcon = _getTaskVectorIcon(task.iconName, task.timeSegment, task.dueTime);

                return Column(
                  children: [
                    // Duration gap marker badge between tasks on the timeline
                    if (index > 0 && durationGap.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 36, bottom: 8, top: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: secondaryTextColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                durationGap,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryTextColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Timeline Axis: Timestamp Badge with Time-of-Day Vector Icon (Morning/Afternoon/Night Color)
                          SizedBox(
                            width: 68,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isThemeDark
                                        ? timeOfDayColor.withOpacity(0.18)
                                        : timeOfDayColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: timeOfDayColor.withOpacity(0.45),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: timeOfDayColor.withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        timeIcon,
                                        size: 16,
                                        color: timeOfDayColor,
                                      ),
                                      const SizedBox(height: 3),
                                      Builder(
                                        builder: (context) {
                                          final periodMatch = RegExp(r'^(.*?)\s*(AM|PM|am|pm)$').firstMatch(formattedTime.trim());
                                          if (periodMatch != null) {
                                            final timeDigits = periodMatch.group(1)!;
                                            final periodText = periodMatch.group(2)!.toUpperCase();
                                            return Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: timeDigits,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w900,
                                                      color: timeOfDayColor,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ' $periodText',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 7.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: timeOfDayColor.withOpacity(0.85),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              textAlign: TextAlign.center,
                                            );
                                          }
                                          return Text(
                                            formattedTime,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              color: timeOfDayColor,
                                              letterSpacing: -0.2,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: timeOfDayColor,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Right Side: Task Card styled with custom color & vector icon + swipe & tap handlers
                          Expanded(
                            child: TimelineTaskCardWidget(
                              task: task,
                              taskColor: taskColor,
                              taskVectorIcon: taskVectorIcon,
                              cardBgColor: cardBgColor,
                              primaryTextColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                              selectedDate: _selectedDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              LucideIcons.calendarCheck,
              size: 40,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks scheduled for this day.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to create a new daily focus task.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Streamlined Timeline Task Card Widget with Time Accent Colors, Vector Stroke Icons, Swipe & Editable Notes Modal
class TimelineTaskCardWidget extends ConsumerWidget {
  final FocusTaskItem task;
  final Color taskColor;
  final IconData taskVectorIcon;
  final Color cardBgColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final DateTime selectedDate; // The currently viewed date

  const TimelineTaskCardWidget({
    super.key,
    required this.task,
    required this.taskColor,
    required this.taskVectorIcon,
    required this.cardBgColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.selectedDate,
  });

  /// Shows a dialog asking whether to edit this occurrence or all occurrences.
  /// Returns true if user chose "all", false if "this only", null if cancelled.
  Future<bool?> _showEditScopeDialog(BuildContext context) async {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isThemeDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.pencil, size: 18, color: taskColor),
            const SizedBox(width: 10),
            Text('Edit recurring task',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700,
                color: isThemeDark ? Colors.white : const Color(0xFF111827))),
          ],
        ),
        content: Text(
          'How would you like to edit "${task.title}"?',
          style: GoogleFonts.inter(fontSize: 13, color: isThemeDark ? Colors.white70 : Colors.black54),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: taskColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Only this day',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: taskColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: taskColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('All occurrences',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog asking whether to delete this occurrence or all occurrences.
  Future<bool?> _showDeleteScopeDialog(BuildContext context) async {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isThemeDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text('Delete recurring task',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700,
                color: isThemeDark ? Colors.white : const Color(0xFF111827))),
          ],
        ),
        content: Text(
          'How would you like to delete "${task.title}"?',
          style: GoogleFonts.inter(fontSize: 13, color: isThemeDark ? Colors.white70 : Colors.black54),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Only this day',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('All occurrences',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTaskDetailsAndNotesModal(BuildContext context, WidgetRef ref) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final notesController = TextEditingController(text: task.notes == 'No notes added.' ? '' : task.notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isThemeDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: taskColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Drag Handle Indicator
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondaryTextColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Row: Icon, Title, Duration & Time Segment Badge
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: taskColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: taskColor.withOpacity(0.4), width: 1),
                      ),
                      child: Icon(taskVectorIcon, size: 22, color: taskColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: taskColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  formatDurationString(task.duration),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: taskColor,
                                  ),
                                ),
                              ),
                              if (task.dueTime != null && task.dueTime!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    formatTimeAmPm(task.dueTime),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber[300] ?? Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Text(
                                task.timeSegment,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Editable Notes Section
                Text(
                  'Task Notes & Focus Objectives',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  minLines: 2,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: primaryTextColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add details, goals, or notes for this task...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: secondaryTextColor.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: isThemeDark
                        ? const Color(0xFF0F172A).withOpacity(0.6)
                        : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: taskColor.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: taskColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Save Notes Action
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final updatedNotes = notesController.text.trim();
                      ref.read(focusTasksProvider.notifier).updateTaskNotes(
                        task.id,
                        updatedNotes.isEmpty ? 'No notes added.' : updatedNotes,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Notes updated for "${task.title}"'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: taskColor,
                        ),
                      );
                    },
                    icon: Icon(LucideIcons.check, size: 16, color: taskColor),
                    label: Text(
                      'Save Notes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: taskColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Subtasks Section (if any)
                if (task.subtasks.isNotEmpty) ...[
                  Text(
                    'Subtasks',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (ctx, setModalState) {
                      return Column(
                        children: task.subtasks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final sub = entry.value;
                          return GestureDetector(
                            onTap: () {
                              ref.read(focusTasksProvider.notifier).toggleSubTask(task.id, idx);
                              setModalState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: sub.isCompleted
                                    ? taskColor.withOpacity(0.08)
                                    : (isThemeDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: sub.isCompleted ? taskColor.withOpacity(0.4) : (isThemeDark ? Colors.white.withOpacity(0.08) : Colors.grey[300]!),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: sub.isCompleted ? taskColor : Colors.transparent,
                                      border: Border.all(
                                        color: sub.isCompleted ? taskColor : secondaryTextColor.withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: sub.isCompleted
                                        ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      sub.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: sub.isCompleted ? secondaryTextColor.withOpacity(0.6) : primaryTextColor,
                                        decoration: sub.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                                        decorationColor: secondaryTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                ],

                const SizedBox(height: 16),

                // Focus Mode & Task Done Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(modalContext);
                            ref.read(activeFocusTaskIdProvider.notifier).state = task.id;
                            context.go('/focus');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: taskColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(LucideIcons.play, size: 18, color: Colors.white),
                          label: Text(
                            'Focus Mode',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(focusTasksProvider.notifier).toggleTaskCompletion(task.id);
                            Navigator.pop(modalContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(task.isDone ? 'Marked active: "${task.title}"' : 'Completed: "${task.title}"!'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: task.isDone ? const Color(0xFF334155) : const Color(0xFF10B981),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: task.isDone
                                ? const Color(0xFF334155)
                                : const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            task.isDone ? LucideIcons.rotateCcw : LucideIcons.checkCircle2,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            task.isDone ? 'Mark Active' : 'Task Done',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final activeFocusTaskId = ref.watch(activeFocusTaskIdProvider);
    final isFocusActive = activeFocusTaskId == task.id;

    return Dismissible(
      key: Key('timeline_task_${task.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Edit Task
          if (task.repeatDays.isNotEmpty) {
            // Recurring task — ask scope
            final editAll = await _showEditScopeDialog(context);
            if (editAll == null) return false; // cancelled
            if (editAll) {
              // Edit all occurrences
              openCreateTaskSheet(context, ref, taskToEdit: task);
            } else {
              // Edit only this occurrence: skip this date on original, open sheet for a new one-time task
              ref.read(focusTasksProvider.notifier).skipOccurrence(task.id, selectedDate);
              // Open create sheet pre-filled as a one-time copy for this date
              final copyTask = FocusTaskItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: task.title,
                duration: task.duration,
                timeSegment: task.timeSegment,
                notes: task.notes,
                difficulty: task.difficulty,
                dueTime: task.dueTime,
                subtasks: task.subtasks,
                colorHex: task.colorHex,
                iconName: task.iconName,
                // No repeatDays — makes it a one-time task for today
              );
              openCreateTaskSheet(context, ref, taskToEdit: copyTask);
            }
          } else {
            openCreateTaskSheet(context, ref, taskToEdit: task);
          }
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Delete Task
          if (task.repeatDays.isNotEmpty) {
            // Recurring task — ask scope
            final deleteAll = await _showDeleteScopeDialog(context);
            if (deleteAll == null) return false; // cancelled
            if (deleteAll) {
              // Delete all occurrences
              await ref.read(focusTasksProvider.notifier).removeTaskById(task.id);
              return true;
            } else {
              // Skip only this date
              ref.read(focusTasksProvider.notifier).skipOccurrence(task.id, selectedDate);
              return false; // don't dismiss card; it's filtered from view by skippedDates
            }
          } else {
            await ref.read(focusTasksProvider.notifier).removeTaskById(task.id);
            return true;
          }
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isThemeDark ? const Color(0xFF064E3B) : const Color(0xFF065F46),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isThemeDark ? const Color(0xFF047857) : const Color(0xFF059669),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.pencil, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 9),
            Text(
              'Edit Task',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isThemeDark ? const Color(0xFF7F1D1D) : const Color(0xFF991B1B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isThemeDark ? const Color(0xFF991B1B) : const Color(0xFFB91C1C),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 9),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.trash2, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _showTaskDetailsAndNotesModal(context, ref),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: task.isDone
                ? (isThemeDark ? const Color(0xFF0F172A).withOpacity(0.92) : const Color(0xFF334155).withOpacity(0.14))
                : taskColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: task.isDone
                  ? (isThemeDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08))
                  : (isFocusActive ? Colors.white : taskColor),
              width: isFocusActive ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: task.isDone
                    ? Colors.transparent
                    : taskColor.withOpacity(0.4),
                blurRadius: isFocusActive ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Task Icon Container (Darkened when finished)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: task.isDone
                      ? (isThemeDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))
                      : Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: task.isDone
                        ? secondaryTextColor.withOpacity(0.2)
                        : Colors.white.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Icon(
                  task.isDone ? LucideIcons.checkCheck : taskVectorIcon,
                  size: 20,
                  color: task.isDone ? secondaryTextColor.withOpacity(0.5) : Colors.white,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Category / Notes Snippet Preview (Darkened, Blurred & Crossed Out when finished)
              Expanded(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: task.isDone ? 1.3 : 0.0,
                    sigmaY: task.isDone ? 1.3 : 0.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: task.isDone
                              ? primaryTextColor.withOpacity(0.38)
                              : Colors.white,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: Colors.white.withOpacity(0.7),
                          decorationThickness: 2.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Subtitle / Notes Snippet (Darkened & Crossed Out when finished)
                      Row(
                        children: [
                          Icon(
                            LucideIcons.fileText,
                            size: 12,
                            color: task.isDone
                                ? secondaryTextColor.withOpacity(0.35)
                                : Colors.white.withOpacity(0.85),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.notes.isNotEmpty && task.notes != 'No notes added.'
                                  ? task.notes
                                  : 'Tap card to view notes...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: task.isDone
                                    ? secondaryTextColor.withOpacity(0.35)
                                    : (task.notes.isNotEmpty && task.notes != 'No notes added.'
                                        ? Colors.white.withOpacity(0.88)
                                        : Colors.white.withOpacity(0.65)),
                                decoration: task.isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: Colors.white.withOpacity(0.5),
                                fontStyle: task.notes.isEmpty || task.notes == 'No notes added.'
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class FluidBackgroundPainter extends CustomPainter {
  final double percentage;
  final double animValue;
  final Color color;

  FluidBackgroundPainter({
    required this.percentage,
    required this.animValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (percentage <= 0) return;

    final double fillHeight = size.height * percentage.clamp(0.0, 1.0);
    final double surfaceY = size.height - fillHeight;

    final Paint liquidPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final Path wavePath = Path();
    wavePath.moveTo(0, size.height);
    wavePath.lineTo(0, surfaceY);

    final double phase = animValue * 2 * math.pi;
    for (double x = 0; x <= size.width; x += 4) {
      final double wave1 = math.sin(phase + (x / size.width) * 2 * math.pi) * 6.0;
      wavePath.lineTo(x, surfaceY + wave1);
    }

    wavePath.lineTo(size.width, size.height);
    wavePath.close();

    canvas.drawPath(wavePath, liquidPaint);
  }

  @override
  bool shouldRepaint(covariant FluidBackgroundPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.animValue != animValue ||
        oldDelegate.color != color;
  }
}
