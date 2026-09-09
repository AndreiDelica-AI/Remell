import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../providers/tasks_provider.dart';

class MorningTasksSummaryDialog extends ConsumerStatefulWidget {
  final String userName;

  const MorningTasksSummaryDialog({
    super.key,
    required this.userName,
  });

  @override
  ConsumerState<MorningTasksSummaryDialog> createState() => _MorningTasksSummaryDialogState();
}

class _MorningTasksSummaryDialogState extends ConsumerState<MorningTasksSummaryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isThemeDark ? const Color(0xFF090D16) : Colors.white;
    final primaryText = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final itemBg = isThemeDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final borderColor = isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final quickTasks = ref.watch(quickTasksProvider);
    final focusTasks = ref.watch(focusTasksProvider);

    final waitingFocusTasks = focusTasks.where((t) => !t.isDone).toList();
    final waitingQuickTasks = quickTasks;
    final totalWaitingCount = waitingFocusTasks.length + waitingQuickTasks.length;

    int totalMinutes = 0;
    for (final t in waitingFocusTasks) {
      final numMatch = RegExp(r'\d+').firstMatch(t.duration);
      if (numMatch != null) {
        totalMinutes += int.tryParse(numMatch.group(0) ?? '20') ?? 20;
      } else {
        totalMinutes += 20;
      }
    }
    for (final q in waitingQuickTasks) {
      totalMinutes += q.durationMinutes;
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isThemeDark ? 0.50 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — sun icon upper right, greeting text left
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good morning, ${widget.userName}.',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              totalWaitingCount == 0
                                  ? 'Your schedule is clear for today.'
                                  : '$totalWaitingCount tasks waiting today (~$totalMinutes min total).',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sun icon in upper right
                      Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withOpacity(0.40),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFBBF24).withOpacity(0.20),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.sun,
                                size: 20,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          IconButton(
                            icon: Icon(LucideIcons.x, size: 16, color: secondaryText.withOpacity(0.5)),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFF1E293B)),

                // Task List or Empty State
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  child: totalWaitingCount == 0
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            color: itemBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Center(
                            child: Text(
                              'No pending tasks. Start your day fresh.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: secondaryText,
                              ),
                            ),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                ...waitingFocusTasks.map((task) => _buildMinimalTaskRow(
                                      title: task.title,
                                      duration: formatDurationString(task.duration),
                                      tag: task.dueTime != null ? '${task.timeSegment} • ${formatTimeAmPm(task.dueTime)}' : task.timeSegment,
                                      primaryText: primaryText,
                                      secondaryText: secondaryText,
                                      itemBg: itemBg,
                                      borderColor: borderColor,
                                    )),
                                ...waitingQuickTasks.map((qTask) => _buildMinimalTaskRow(
                                      title: qTask.title,
                                      duration: formatDuration(qTask.durationMinutes),
                                      tag: qTask.dueTime != null ? 'Quick Note • ${formatTimeAmPm(qTask.dueTime)}' : 'Quick Note',
                                      primaryText: primaryText,
                                      secondaryText: secondaryText,
                                      itemBg: itemBg,
                                      borderColor: borderColor,
                                    )),
                              ],
                            ),
                          ),
                        ),
                ),

                // Compact Minimalist Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Smaller Dismiss Button
                      SizedBox(
                        height: 36,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            foregroundColor: secondaryText,
                          ),
                          child: Text(
                            'Dismiss',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Smaller Start Focus Button
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (waitingFocusTasks.isNotEmpty || waitingQuickTasks.isNotEmpty) {
                              context.go('/focus');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                            foregroundColor: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isThemeDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                                width: 1,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            totalWaitingCount > 0 ? 'Start Focus' : 'Go to Tasks',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: const Color(0xFFF8FAFC),
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
        ),
      ),
    );
  }

  Widget _buildMinimalTaskRow({
    required String title,
    required String duration,
    required String tag,
    required Color primaryText,
    required Color secondaryText,
    required Color itemBg,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            duration,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: secondaryText.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
