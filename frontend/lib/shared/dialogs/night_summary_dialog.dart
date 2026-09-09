import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/tasks_provider.dart';
import '../services/day_plan_service.dart';
import '../bottom_sheets/plan_tomorrow_sheet.dart';

class NightSummaryDialog extends ConsumerStatefulWidget {
  final String userName;

  const NightSummaryDialog({
    super.key,
    required this.userName,
  });

  @override
  ConsumerState<NightSummaryDialog> createState() => _NightSummaryDialogState();
}

class _NightSummaryDialogState extends ConsumerState<NightSummaryDialog>
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

    final focusTasks = ref.watch(focusTasksProvider);
    final quickTasks = ref.watch(quickTasksProvider);

    // Completed tasks: logged in DayPlanService + completed focus tasks
    final loggedDone = DayPlanService.getTodayCompletedTasks();
    final doneFocusTasks = focusTasks.where((t) => t.isDone).toList();

    final List<Map<String, String>> allCompleted = [];
    final Set<String> addedTitles = {};

    for (final item in loggedDone) {
      final title = item['title']?.toString() ?? '';
      if (title.isNotEmpty && !addedTitles.contains(title)) {
        addedTitles.add(title);
        allCompleted.add({
          'title': title,
          'type': item['type']?.toString() ?? 'Task',
        });
      }
    }

    for (final f in doneFocusTasks) {
      if (!addedTitles.contains(f.title)) {
        addedTitles.add(f.title);
        allCompleted.add({
          'title': f.title,
          'type': 'Focus Task',
        });
      }
    }

    final totalCompletedCount = allCompleted.length;
    final remainingCount = focusTasks.where((t) => !t.isDone).length + quickTasks.length;

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
                  color: Colors.black.withOpacity(isThemeDark ? 0.60 : 0.15),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — moon icon upper right, greeting text left
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good evening, ${widget.userName}.',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              totalCompletedCount == 0
                                  ? 'No tasks completed today. Rest well tonight.'
                                  : '$totalCompletedCount task${totalCompletedCount > 1 ? "s" : ""} accomplished today.',
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
                      // Moon icon in upper right
                      Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF8B5CF6).withOpacity(0.35),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFA78BFA).withOpacity(0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.moon,
                                size: 20,
                                color: Color(0xFFA78BFA),
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

                Divider(height: 1, color: borderColor),

                // Accomplished list or empty state
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  child: totalCompletedCount == 0
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
                              'No tasks finished today. Tomorrow is a brand new start.',
                              textAlign: TextAlign.center,
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
                              children: allCompleted.map((item) {
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
                                      Icon(
                                        LucideIcons.check,
                                        size: 14,
                                        color: secondaryText,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item['title'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: primaryText,
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: secondaryText.withOpacity(0.6),
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
                ),

                if (remainingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 22, right: 22, bottom: 12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock, size: 12, color: secondaryText.withOpacity(0.8)),
                        const SizedBox(width: 6),
                        Text(
                          '$remainingCount task${remainingCount > 1 ? "s" : ""} waiting for tomorrow',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: secondaryText.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Footer Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            showPlanTomorrowSheet(context);
                          },
                          icon: const Icon(LucideIcons.pencil, size: 13),
                          label: Text(
                            'Plan Tomorrow',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
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
}
