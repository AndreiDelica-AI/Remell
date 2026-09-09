import 'dart:async';
import 'dart:math' as math;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/streak_provider.dart';
import '../../../shared/providers/tasks_provider.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/dialogs/note_for_later_dialog.dart';

Color getTaskTimeBasedColor(FocusTaskItem task) {
  if (task.colorHex != null && task.colorHex!.isNotEmpty) {
    try {
      final clean = task.colorHex!.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      } else if (clean.length == 8) {
        return Color(int.parse('0x$clean'));
      }
    } catch (_) {}
  }
  switch (task.timeSegment.toLowerCase()) {
    case 'morning':
      return const Color(0xFFF59E0B); // Amber / Gold
    case 'afternoon':
      return const Color(0xFFEA580C); // Warm Orange
    case 'night':
      return const Color(0xFF7C3AED); // Deep Violet
    default:
      return const Color(0xFF1E3A8A); // Dark Royal Navy
  }
}

class FocusNowScreen extends ConsumerStatefulWidget {
  const FocusNowScreen({super.key});

  @override
  ConsumerState<FocusNowScreen> createState() => _FocusNowScreenState();
}

class _FocusNowScreenState extends ConsumerState<FocusNowScreen> with TickerProviderStateMixin {
  bool _isRunning = false;
  Timer? _timer;
  int _totalSeconds = 25 * 60;
  int _secondsRemaining = 25 * 60;
  bool _isInitialized = false;
  bool _congratsShown = false;



  // Strategy 3: Initiation Booster (2-Minute Rule)
  bool _isTrialMode = false;
  int _secondsFocused = 0;

  // Quick Break State & Dynamic Limits
  bool _isBreakActive = false;
  int _breakSecondsRemaining = 0;
  int _breakTotalSeconds = 0;
  Timer? _breakTimer;
  int _breaksTakenInSession = 0;
  final ValueNotifier<int> _breakSecondsNotifier = ValueNotifier<int>(0);
  BuildContext? _breakModalContext;

  // Fallback subtasks for direct Deep Focus sessions
  final List<SubTaskItem> _fallbackSubtasks = [
    SubTaskItem(title: 'Objective 1: Core planning & setup', isCompleted: false),
    SubTaskItem(title: 'Objective 2: Deep execution & review', isCompleted: false),
  ];

  int _getMaxBreaksAllowed(int durationMinutes) {
    if (durationMinutes <= 60) return 1;
    if (durationMinutes <= 120) return 2;
    return math.max(1, (durationMinutes / 60).ceil());
  }

  void _startQuickBreak(int minutes, String taskName) {
    _pauseTimer();
    _breakTimer?.cancel();
    _triggerHaptic(HapticType.medium);
    _playAppleTick();

    final totalSecs = minutes * 60;
    _breakTotalSeconds = totalSecs;
    _breakSecondsRemaining = totalSecs;
    _breakSecondsNotifier.value = totalSecs;

    setState(() {
      _isBreakActive = true;
    });

    ref.read(doomScrollProvider.notifier).startSession(Duration(minutes: minutes));

    ref.read(inAppNotificationProvider.notifier).state = InAppNotificationData(
      title: '$minutes-Min Quick Break Started',
      body: 'Focus timer paused on $taskName. Take time to recharge.',
      duration: const Duration(seconds: 5),
    );

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_breakSecondsRemaining > 0) {
        _breakSecondsRemaining--;
        _breakSecondsNotifier.value = _breakSecondsRemaining;
        if (mounted) {
          setState(() {});
        }
      } else {
        _endQuickBreak(taskName, showCompletionDialog: true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showQuickBreakActiveModal(context, taskName);
      }
    });
  }

  void _showQuickBreakActiveModal(BuildContext context, String taskName) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardColor = isThemeDark ? const Color(0xFF161B26) : const Color(0xFFFFFFFF);
    final borderColor = isThemeDark ? const Color(0xFF2A324B) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        _breakModalContext = ctx;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.coffee, color: Color(0xFF9333EA), size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quick Break in Progress',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Focus timer is paused on "$taskName". Take a mindful breath.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: secondaryTextColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<int>(
                  valueListenable: _breakSecondsNotifier,
                  builder: (context, secondsLeft, _) {
                    final progress = _breakTotalSeconds > 0
                        ? (secondsLeft / _breakTotalSeconds).clamp(0.0, 1.0)
                        : 0.0;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF7C3AED).withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _formatTime(secondsLeft),
                            style: GoogleFonts.inter(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF9333EA),
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: isThemeDark ? const Color(0xFF1E1B4B) : const Color(0xFFEDE9FE),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9333EA)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _breakModalContext = null;
                      _endQuickBreak(taskName, showCompletionDialog: false);
                    },
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: const Text('End Break & Resume Focus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (_breakModalContext != null) {
        _breakModalContext = null;
      }
    });
  }

  void _endQuickBreak(String taskName, {bool showCompletionDialog = false}) {
    _breakTimer?.cancel();
    _triggerHaptic(HapticType.medium);
    _playAppleTick();

    if (_breakModalContext != null) {
      try {
        Navigator.of(_breakModalContext!).pop();
      } catch (_) {}
      _breakModalContext = null;
    }

    setState(() {
      _isBreakActive = false;
      _breakSecondsRemaining = 0;
      _breakSecondsNotifier.value = 0;
    });

    ref.read(doomScrollProvider.notifier).endSession();

    if (showCompletionDialog) {
      _playCelebrationChime();
      _showBreakFinishedDialog(context, taskName);
    } else {
      _startTimer();
      ref.read(inAppNotificationProvider.notifier).state = InAppNotificationData(
        title: 'Resuming Focus Session',
        body: 'Continuing session for $taskName.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _showBreakFinishedDialog(BuildContext context, String taskName) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final cardColor = isThemeDark ? const Color(0xFF161B26) : const Color(0xFFFFFFFF);
    final borderColor = isThemeDark ? const Color(0xFF2A324B) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.coffee, size: 32, color: Color(0xFF9333EA)),
                ),
                const SizedBox(height: 14),
                Text(
                  'Quick Break Complete',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hope that gave you a nice recharge! Ready to jump back into "$taskName"?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: primaryTextColor.withOpacity(0.75),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startTimer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Resume Focus Session',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
  }

  void _initializeTimer(int durationMinutes) {
    if (!_isInitialized) {
      _totalSeconds = durationMinutes * 60;
      _secondsRemaining = _totalSeconds;
      _isInitialized = true;
    }
  }

  void _startTimer() {
    _triggerHaptic(HapticType.light);
    _playAppleTick();
    _timer?.cancel();
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
          _secondsFocused++;
          if (_secondsFocused > 0 && _secondsFocused % 900 == 0) {
            ref.read(streakProvider.notifier).recordCompletion();
          }
        });

        // 2-minute trial prompt check
        if (_isTrialMode && (_totalSeconds - _secondsRemaining >= 120)) {
          _timer?.cancel();
          setState(() {
            _isRunning = false;
          });
          _playCelebrationChime();
          int defaultDur = 25;
          try {
            final activeTaskId = ref.read(activeFocusTaskIdProvider);
            final tasks = ref.read(focusTasksProvider);
            final activeTask = tasks.firstWhere((t) => t.id == activeTaskId);
            defaultDur = activeTask.durationMinutes > 0 ? activeTask.durationMinutes : 25;
          } catch (_) {}
          _showTrialFinishedPrompt(context, defaultDur);
        }
      } else {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
        });
        _triggerHaptic(HapticType.heavy);
        _playCelebrationChime();
      }
    });
  }

  void _pauseTimer() {
    _triggerHaptic(HapticType.light);
    _playAppleTick();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _addOneMinute() {
    _triggerHaptic(HapticType.selection);
    _playAppleTick();
    setState(() {
      _secondsRemaining += 60;
      _totalSeconds += 60;
    });
  }

  void _addFiveMinutes() {
    _triggerHaptic(HapticType.selection);
    _playAppleTick();
    setState(() {
      _secondsRemaining += 300;
      _totalSeconds += 300;
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _triggerHaptic(HapticType type) {
    try {
      switch (type) {
        case HapticType.selection:
          HapticFeedback.selectionClick();
          break;
        case HapticType.light:
          HapticFeedback.lightImpact();
          break;
        case HapticType.medium:
          HapticFeedback.mediumImpact();
          break;
        case HapticType.heavy:
          HapticFeedback.heavyImpact();
          break;
      }
    } catch (_) {}
  }

  void _playAppleTick() {
    try {
      js.context.callMethod('eval', [
        '''
        var ctx = new (window.AudioContext || window.webkitAudioContext)();
        var osc = ctx.createOscillator();
        var gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(880, ctx.currentTime);
        gain.gain.setValueAtTime(0.08, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.04);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start();
        osc.stop(ctx.currentTime + 0.04);
        '''
      ]);
    } catch (_) {}
  }

  void _playSubtaskCompleteSound() {
    try {
      js.context.callMethod('eval', [
        '''
        var ctx = new (window.AudioContext || window.webkitAudioContext)();
        var osc1 = ctx.createOscillator();
        var osc2 = ctx.createOscillator();
        var gain = ctx.createGain();
        osc1.type = 'sine';
        osc2.type = 'triangle';
        osc1.frequency.setValueAtTime(587.33, ctx.currentTime); // D5
        osc1.frequency.exponentialRampToValueAtTime(880, ctx.currentTime + 0.12); // A5
        osc2.frequency.setValueAtTime(1174.66, ctx.currentTime + 0.05); // D6
        gain.gain.setValueAtTime(0.10, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.22);
        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(ctx.destination);
        osc1.start();
        osc2.start(ctx.currentTime + 0.05);
        osc1.stop(ctx.currentTime + 0.22);
        osc2.stop(ctx.currentTime + 0.22);
        '''
      ]);
    } catch (_) {}
  }

  void _playCelebrationChime() {
    try {
      js.context.callMethod('eval', [
        '''
        var ctx = new (window.AudioContext || window.webkitAudioContext)();
        [523.25, 659.25, 783.99, 1046.50].forEach(function(freq, i) {
          var osc = ctx.createOscillator();
          var gain = ctx.createGain();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(freq, ctx.currentTime + (i * 0.07));
          gain.gain.setValueAtTime(0.12, ctx.currentTime + (i * 0.07));
          gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + (i * 0.07) + 0.4);
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(ctx.currentTime + (i * 0.07));
          osc.stop(ctx.currentTime + (i * 0.07) + 0.4);
        });
        '''
      ]);
    } catch (_) {}
  }

  void _triggerConfetti() {
    try {
      js.context.callMethod('eval', [
        '''
        if (typeof confetti === 'function') {
          confetti({
            particleCount: 70,
            spread: 60,
            origin: { y: 0.7 }
          });
        }
        '''
      ]);
    } catch (_) {}
  }

  void _showCongratsDialog(BuildContext context, FocusTaskItem activeTask, int streak) {
    if (_congratsShown) return;
    _congratsShown = true;
    _timer?.cancel();
    _triggerHaptic(HapticType.heavy);
    _triggerConfetti();
    _playCelebrationChime();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isThemeDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
        final cardColor = isThemeDark ? const Color(0xFF161B26) : const Color(0xFFFFFFFF);
        final borderColor = isThemeDark ? const Color(0xFF2A324B) : const Color(0xFFE2E8F0);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 2),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.partyPopper, size: 32, color: Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Session Completed!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You conquered all objectives for "${activeTask.title}".',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: primaryColor.withOpacity(0.75),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.flame, size: 20, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Text(
                        '$streak Day Streak Active!',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    _playAppleTick();
                    ref.read(activeFocusTaskIdProvider.notifier).state = null;
                    Navigator.of(context).pop();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Awesome, Keep Momentum',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breakTimer?.cancel();
    _breakSecondsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgDark = const Color(0xFF0B0E14);
    final bgLight = const Color(0xFFF6F8FA);
    final scaffoldBg = isThemeDark ? bgDark : bgLight;

    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isThemeDark ? const Color(0xFF161B26) : Colors.white;
    final cardBorder = isThemeDark ? const Color(0xFF2A324B).withOpacity(0.5) : const Color(0xFFE2E8F0);

    final activeTaskId = ref.watch(activeFocusTaskIdProvider);
    final focusTasks = ref.watch(focusTasksProvider);
    final quickTasks = ref.watch(quickTasksProvider);
    
    FocusTaskItem? matchedTask;
    try {
      matchedTask = focusTasks.firstWhere((task) => task.id == activeTaskId);
    } catch (_) {}

    if (matchedTask == null && activeTaskId != null) {
      try {
        final qTask = quickTasks.firstWhere((task) => task.id == activeTaskId);
        matchedTask = FocusTaskItem(
          id: qTask.id,
          title: qTask.title,
          duration: '${qTask.durationMinutes} min',
          timeSegment: 'Morning',
          notes: qTask.notes,
          subtasks: qTask.subtasks.map((s) => SubTaskItem(id: s.id, title: s.title, isCompleted: s.isCompleted)).toList(),
          difficulty: qTask.difficulty,
          dueTime: qTask.dueTime,
          isCompleted: qTask.isCompleted,
        );
      } catch (_) {}
    }

    final FocusTaskItem activeTask = matchedTask ?? FocusTaskItem(
      id: 'fallback',
      title: 'Deep Focus Session',
      duration: '25 min',
      timeSegment: 'Morning',
      notes: 'Keep focusing on your goals.',
      subtasks: _fallbackSubtasks,
    );

    int defaultDuration = activeTask.durationMinutes > 0 ? activeTask.durationMinutes : 25;
    _initializeTimer(defaultDuration);

    final List<SubTaskItem> effectiveSubtasks = activeTask.id == 'fallback'
        ? _fallbackSubtasks
        : (activeTask.subtasks.isNotEmpty
            ? activeTask.subtasks
            : parseSubtasksFromNotes(activeTask.notes));

    final int totalSubtasks = effectiveSubtasks.length;
    final int completedSubtasks = effectiveSubtasks.where((st) => st.isCompleted).length;
    final int remainingSubtasks = totalSubtasks - completedSubtasks;
    final double subtaskProgress = totalSubtasks > 0 ? (completedSubtasks / totalSubtasks) : 0.0;
    final bool allSubtasksDone = totalSubtasks > 0 && completedSubtasks == totalSubtasks;

    // Trigger auto congrats if all subtasks done
    if (activeTask.id != 'fallback' && allSubtasksDone && !_congratsShown) {
      int streak = 5;
      if (activeTask.timeSegment == 'Morning') streak = 5;
      else if (activeTask.timeSegment == 'Afternoon') streak = 3;
      else streak = 8;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCongratsDialog(context, activeTask, streak);
      });
    }

    // Dynamic color logic: Shifts to celebratory Emerald / Warm Amber when >= 80% or done
    final Color baseTaskColor = getTaskTimeBasedColor(activeTask);
    final Color activeAccentColor = allSubtasksDone
        ? const Color(0xFF10B981) // Emerald
        : (subtaskProgress >= 0.75
            ? const Color(0xFFF59E0B) // Golden final stretch
            : baseTaskColor);

    // Timer gauge progress (1.0 down to 0.0)
    final double timerProgress = _totalSeconds > 0
        ? (_secondsRemaining / _totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: IconButton(
              icon: Icon(LucideIcons.chevronLeft, color: primaryTextColor, size: 24),
              onPressed: () {
                _triggerHaptic(HapticType.selection);
                _playAppleTick();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
          ),
          centerTitle: true,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isThemeDark ? const Color(0xFF161B26) : const Color(0xFFE2E8F0).withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activeTask.timeSegment == 'Morning'
                      ? LucideIcons.sun
                      : (activeTask.timeSegment == 'Afternoon' ? LucideIcons.cloudSun : LucideIcons.moon),
                  size: 13,
                  color: activeTask.timeSegment == 'Morning'
                      ? const Color(0xFFF59E0B)
                      : (activeTask.timeSegment == 'Afternoon' ? const Color(0xFFEA580C) : const Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 6),
                Text(
                  '${activeTask.timeSegment} Session',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Task Title Header
                Text(
                  activeTask.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Concentric Ring Gauge Hero
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric Fluid Ring Gauge
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: timerProgress),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, progressVal, child) {
                            return CustomPaint(
                              size: const Size(250, 250),
                              painter: AppleFocusRingPainter(
                                progress: progressVal,
                                accentColor: activeAccentColor,
                                isDark: isThemeDark,
                              ),
                            );
                          },
                        ),

                          // Inner Digital Time Readout & Status Dot
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Status pill (Focusing / Paused / Ready / Quick Break)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isBreakActive
                                      ? const Color(0xFF7C3AED).withOpacity(0.18)
                                      : activeAccentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _isBreakActive
                                            ? const Color(0xFF9333EA)
                                            : (_isRunning ? const Color(0xFF10B981) : secondaryTextColor),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _isBreakActive
                                          ? 'QUICK BREAK'
                                          : (_isRunning
                                              ? 'FOCUSING'
                                              : (_secondsRemaining == _totalSeconds ? 'READY' : 'PAUSED')),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: _isBreakActive
                                            ? const Color(0xFF9333EA)
                                            : (_isRunning ? activeAccentColor : secondaryTextColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Large Digital Timer Readout
                              Text(
                                _formatTime(_secondsRemaining),
                                style: GoogleFonts.inter(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -2.0,
                                  color: primaryTextColor,
                                ),
                              ),

                              // Quick Adjustment Steppers (+1m / +5m)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: _addOneMinute,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.plus, size: 11, color: secondaryTextColor),
                                          const SizedBox(width: 2),
                                          Text(
                                            '1m',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _addFiveMinutes,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.plus, size: 11, color: secondaryTextColor),
                                          const SizedBox(width: 2),
                                          Text(
                                            '5m',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: secondaryTextColor,
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
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // 3. Floating Cohesive Glassmorphic Card (Task Details & Subtasks)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cardBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isThemeDark ? 0.35 : 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtask Header & Visual Momentum Progress Text
                      if (totalSubtasks > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'OBJECTIVES',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: secondaryTextColor.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              allSubtasksDone
                                  ? 'All objectives completed'
                                  : (remainingSubtasks == 1
                                      ? '1 objective left - Final stretch'
                                      : '$completedSubtasks of $totalSubtasks done'),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: allSubtasksDone
                                    ? const Color(0xFF10B981)
                                    : (remainingSubtasks == 1
                                        ? const Color(0xFFF59E0B)
                                        : activeAccentColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Spring-Animated Velocity Progress Bar
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: subtaskProgress),
                              duration: const Duration(milliseconds: 550),
                              curve: Curves.easeOutBack,
                              builder: (context, fillVal, child) {
                                return FractionallySizedBox(
                                  widthFactor: fillVal.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          activeAccentColor,
                                          activeAccentColor.withOpacity(0.85),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: activeAccentColor.withOpacity(0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Interactive Tactile Checklist
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: effectiveSubtasks.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: cardBorder.withOpacity(0.4),
                          ),
                          itemBuilder: (context, index) {
                            final subtask = effectiveSubtasks[index];
                            return AppleSubtaskRow(
                              key: ValueKey('${activeTask.id}_subtask_${index}_${subtask.title}_${subtask.isCompleted}'),
                              subtask: subtask,
                              index: index,
                              accentColor: activeAccentColor,
                              primaryTextColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                              onToggle: () {
                                _triggerHaptic(HapticType.light);
                                if (!subtask.isCompleted) {
                                  _playSubtaskCompleteSound();
                                  if (remainingSubtasks == 1) {
                                    _triggerConfetti();
                                    _playCelebrationChime();
                                  }
                                } else {
                                  _playAppleTick();
                                }
                                if (activeTask.id == 'fallback') {
                                  setState(() {
                                    _fallbackSubtasks[index].isCompleted = !_fallbackSubtasks[index].isCompleted;
                                  });
                                  return;
                                }
                                final isFocusTask = ref.read(focusTasksProvider).any((t) => t.id == activeTask.id);
                                if (isFocusTask) {
                                  ref.read(focusTasksProvider.notifier).toggleSubTask(activeTask.id, index);
                                } else {
                                  ref.read(quickTasksProvider.notifier).toggleSubtask(activeTask.id, index);
                                }
                              },
                            );
                          },
                        ),
                      ] else ...[
                        // Fallback when no subtasks
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(LucideIcons.target, size: 16, color: activeAccentColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Single deep focus session. Stay in the zone!',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Optional Topic Notes inside card
                      if (activeTask.notes.isNotEmpty && activeTask.notes != 'No notes added.') ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SESSION NOTES',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeTask.notes,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: primaryTextColor.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 4. Initiation Booster (2-Minute Rule Switch)
                if (!_isRunning && _secondsRemaining == _totalSeconds) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.timer, size: 16, color: activeAccentColor),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '120s Initiation Booster',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                Text(
                                  'Overcome friction with the 2-min rule',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _isTrialMode,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) {
                            _triggerHaptic(HapticType.selection);
                            _playAppleTick();
                            setState(() {
                              _isTrialMode = val;
                              if (_isTrialMode) {
                                _secondsRemaining = 120;
                              } else {
                                _secondsRemaining = defaultDuration * 60;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Action Zone: Apple-Grade Primary Action Button
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (allSubtasksDone) {
                            _showCongratsDialog(context, activeTask, 5);
                          } else if (_isBreakActive) {
                            _endQuickBreak(activeTask.title, showCompletionDialog: false);
                          } else if (_isRunning) {
                            _pauseTimer();
                          } else {
                            _startTimer();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: allSubtasksDone
                              ? const Color(0xFF10B981)
                              : (_isBreakActive
                                  ? const Color(0xFF7C3AED)
                                  : (_isRunning
                                      ? (isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
                                      : (isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)))),
                          foregroundColor: allSubtasksDone
                              ? Colors.white
                              : (_isBreakActive
                                  ? Colors.white
                                  : (_isRunning
                                      ? primaryTextColor
                                      : (isThemeDark ? const Color(0xFF0F172A) : Colors.white))),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: (_isRunning && !_isBreakActive)
                                ? BorderSide(color: cardBorder, width: 1.5)
                                : BorderSide.none,
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              allSubtasksDone
                                  ? LucideIcons.partyPopper
                                  : (_isBreakActive
                                      ? LucideIcons.play
                                      : (_isRunning ? LucideIcons.pause : LucideIcons.play)),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              allSubtasksDone
                                  ? 'Complete Session'
                                  : (_isBreakActive
                                      ? 'End Break & Resume'
                                      : (_isRunning ? 'Pause Focus' : 'Start Focus')),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // 6. Floating Action Button: Glassmorphic Row [ Quick Break ] + [ Note for Later ]
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Break Button
            FloatingActionButton.extended(
              heroTag: 'quick_break_btn',
              onPressed: () {
                if (_isBreakActive) {
                  _showQuickBreakActiveModal(context, activeTask.title);
                } else {
                  _showQuickBreakDialog(context, defaultDuration);
                }
              },
              backgroundColor: isThemeDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE),
              foregroundColor: isThemeDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isThemeDark ? const Color(0xFF581C87) : const Color(0xFFDDD6FE),
                  width: 1,
                ),
              ),
              icon: const Icon(LucideIcons.coffee, size: 16),
              label: Text(
                _isBreakActive ? 'Break (${_formatTime(_breakSecondsRemaining)})' : 'Quick Break',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            // Note for Later Button
            FloatingActionButton.extended(
              heroTag: 'note_for_later_btn',
              onPressed: () => _showNoteForLaterDialog(context),
              backgroundColor: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isThemeDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1,
                ),
              ),
              icon: const Icon(LucideIcons.pencil, size: 16),
              label: Text(
                'Note for Later',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickBreakDialog(BuildContext context, int defaultDuration) {
    _triggerHaptic(HapticType.selection);
    _playAppleTick();
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardColor = isThemeDark ? const Color(0xFF161B26) : const Color(0xFFFFFFFF);
    final borderColor = isThemeDark ? const Color(0xFF2A324B) : const Color(0xFFE2E8F0);

    final tasks = ref.read(focusTasksProvider);
    final activeTaskId = ref.read(activeFocusTaskIdProvider);
    String activeTaskName = 'Current Task';
    try {
      if (activeTaskId != null) {
        final t = tasks.firstWhere((item) => item.id == activeTaskId);
        activeTaskName = t.title;
      }
    } catch (_) {}

    final maxBreaks = _getMaxBreaksAllowed(defaultDuration);
    final remainingBreaks = math.max(0, maxBreaks - _breaksTakenInSession);
    final isLimitReached = remainingBreaks <= 0;

    int selectedMinutes = 5;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.coffee, color: Color(0xFF9333EA), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Break',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: primaryTextColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mindful check-in without losing task momentum',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Limit / Allowance indicator chip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLimitReached
                            ? (isThemeDark ? const Color(0xFF3B1219) : const Color(0xFFFEF2F2))
                            : (isThemeDark ? const Color(0xFF1E1435) : const Color(0xFFF3E8FF)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isLimitReached
                              ? (isThemeDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA))
                              : (isThemeDark ? const Color(0xFF6B21A8) : const Color(0xFFDDD6FE)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLimitReached ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
                            size: 14,
                            color: isLimitReached ? const Color(0xFFEF4444) : const Color(0xFF9333EA),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isLimitReached
                                  ? 'Break limit reached ($_breaksTakenInSession of $maxBreaks used for this session)'
                                  : '$remainingBreaks of $maxBreaks break${maxBreaks > 1 ? "s" : ""} available (${defaultDuration >= 120 ? "${(defaultDuration / 60).round()}h task: 1 per hour" : "1 per hour"})',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isLimitReached ? const Color(0xFFEF4444) : const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isLimitReached
                          ? 'You have used all planned breaks for this session. Complete your current focus block to maintain peak deep-work momentum.'
                          : 'Take a timed pause to satisfy curiosity or step away. We\'ll hold your exact place on "$activeTaskName" and prompt you when time is up.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: primaryTextColor.withOpacity(0.8),
                        height: 1.45,
                      ),
                    ),
                    if (!isLimitReached) ...[
                      const SizedBox(height: 16),
                      // Break duration selector (5m vs 7m)
                      Row(
                        children: [5, 7].map((mins) {
                          final isSelected = selectedMinutes == mins;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedMinutes = mins),
                              child: Container(
                                margin: EdgeInsets.only(right: mins == 5 ? 8 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF7C3AED).withOpacity(0.18)
                                      : (isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF9333EA) : borderColor,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$mins Minutes',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: isSelected ? const Color(0xFF9333EA) : primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      mins == 5 ? 'Quick Recharge' : 'Optimal Reset',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected ? const Color(0xFF9333EA) : secondaryTextColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Stay Focused',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: primaryTextColor.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isLimitReached
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _breaksTakenInSession++;
                                    });
                                    _startQuickBreak(selectedMinutes, activeTaskName);
                                  },
                            icon: Icon(isLimitReached ? LucideIcons.lock : LucideIcons.play, size: 14),
                            label: Text(
                              isLimitReached ? 'Limit Reached' : 'Start $selectedMinutes-Min Break',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLimitReached
                                  ? (isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
                                  : const Color(0xFF7C3AED),
                              foregroundColor: isLimitReached ? secondaryTextColor : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
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
      },
    );
  }

  void _showNoteForLaterDialog(BuildContext context) {
    _triggerHaptic(HapticType.selection);
    _playAppleTick();

    NoteForLaterDialog.show(
      context: context,
      onSave: (thought) {
        ref.read(quickTasksProvider.notifier).add(
          thought,
          15,
          'Note captured during focus session.',
          isUrgent: false,
        );
        _triggerHaptic(HapticType.medium);
        _playCelebrationChime();
        ref.read(inAppNotificationProvider.notifier).state = InAppNotificationData(
          title: 'Saved to Quick Notes',
          body: '"$thought" is safely saved. Keep your focus momentum!',
          duration: const Duration(seconds: 4),
        );
      },
    );
  }

  void _showTrialFinishedPrompt(BuildContext context, int defaultDuration) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final cardColor = isThemeDark ? const Color(0xFF161B26) : const Color(0xFFFFFFFF);
    final borderColor = isThemeDark ? const Color(0xFF2A324B) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.flame, size: 42, color: Color(0xFFF59E0B)),
                const SizedBox(height: 12),
                Text(
                  '2-Minute Booster Complete',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You overcame the hardest part: starting. Keep going for the full session or stop now?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: primaryTextColor.withOpacity(0.75),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Stop Here',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _isTrialMode = false;
                            _secondsRemaining = (defaultDuration * 60) - 120;
                            if (_secondsRemaining < 60) _secondsRemaining = 60;
                          });
                          _startTimer();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Keep Going',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
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
}

enum HapticType { selection, light, medium, heavy }

/// Apple-Style Circular Checkbox & Interactive Subtask Row with Elastic Bounce & Strikethrough
class AppleSubtaskRow extends StatefulWidget {
  final SubTaskItem subtask;
  final VoidCallback onToggle;
  final int index;
  final Color accentColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  const AppleSubtaskRow({
    super.key,
    required this.subtask,
    required this.onToggle,
    required this.index,
    required this.accentColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  @override
  State<AppleSubtaskRow> createState() => _AppleSubtaskRowState();
}

class _AppleSubtaskRowState extends State<AppleSubtaskRow> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    if (widget.subtask.isCompleted) {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AppleSubtaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subtask.isCompleted != oldWidget.subtask.isCompleted) {
      if (widget.subtask.isCompleted) {
        _animController.forward(from: 0.0);
      } else {
        _animController.reverse(from: 1.0);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.subtask.isCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
          child: Row(
            children: [
              // Apple-Style Elastic Checkbox
              ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? const Color(0xFF10B981) : Colors.transparent,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : widget.secondaryTextColor.withOpacity(0.4),
                      width: 1.8,
                    ),
                    boxShadow: isDone
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isDone ? 1.0 : 0.0,
                      child: const Icon(
                        LucideIcons.check,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Objective Title with smooth strike-through, opacity, and scheduled time badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isDone ? FontWeight.w400 : FontWeight.w500,
                        decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationColor: widget.secondaryTextColor.withOpacity(0.7),
                        decorationThickness: 1.8,
                        color: isDone
                            ? widget.secondaryTextColor.withOpacity(0.40)
                            : widget.primaryTextColor,
                      ),
                      child: Text(widget.subtask.title),
                    ),
                    if (widget.subtask.scheduledTime != null && widget.subtask.scheduledTime!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.bellRing, size: 10, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.subtask.scheduledTime} alert',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Concentric Fluid Ring Gauge Painter with smooth sweep gradient and rounded cap
class AppleFocusRingPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool isDark;

  AppleFocusRingPainter({
    required this.progress,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 8.0;

    // 1. Background Track Ring
    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // 2. Active Gradient Arc
    final sweepAngle = 2 * math.pi * progress;
    final startAngle = -math.pi / 2; // Start from top 12 o'clock

    final sweepGradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      colors: [
        accentColor.withOpacity(0.7),
        accentColor,
      ],
      transform: const GradientRotation(-math.pi / 2),
    );

    final activePaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );

    // 3. Glowing Round Tip
    final tipAngle = startAngle + sweepAngle;
    final tipOffset = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );

    final tipGlow = Paint()
      ..color = accentColor.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tipOffset, 7.0, tipGlow);

    final tipDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tipOffset, 3.5, tipDot);
  }

  @override
  bool shouldRepaint(covariant AppleFocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
