import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../shared/services/day_plan_service.dart';

class PlanTomorrowSheet extends StatefulWidget {
  const PlanTomorrowSheet({super.key});

  @override
  State<PlanTomorrowSheet> createState() => _PlanTomorrowSheetState();
}

class _PlanTomorrowSheetState extends State<PlanTomorrowSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _saving = false;
  late AnimationController _entryController;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();

    // Pre-fill with existing tomorrow plan if it exists
    final existingPlan = DayPlanService.getTomorrowPlan();
    if (existingPlan != null && existingPlan.notes.isNotEmpty) {
      _controller.text = existingPlan.notes;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _entryController.dispose();
    super.dispose();
  }

  List<String> _parseItems(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) {
          var l = line.trim();
          if (l.startsWith('-') || l.startsWith('•') || l.startsWith('*')) {
            l = l.substring(1).trim();
          }
          final numMatch = RegExp(r'^\d+[\.\)]\s*').firstMatch(l);
          if (numMatch != null) l = l.substring(numMatch.end).trim();
          return l;
        })
        .where((l) => l.isNotEmpty)
        .toList();
  }

  Future<void> _savePlan() async {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    final items = _parseItems(rawText);
    final plan = DayPlanData(
      date: DayPlanService.tomorrowString,
      createdAt: DateTime.now(),
      notes: rawText,
      items: items,
    );

    DayPlanService.savePlan(plan);
    DayPlanService.markNightPlanShownTonight();

    // Schedule morning reminder
    await DayPlanService.scheduleDailyPlanningReminders();

    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop('saved');
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isThemeDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryText = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isThemeDark
        ? const Color(0xFF0F172A).withOpacity(0.65)
        : const Color(0xFFF1F5F9);

    final sleepFormatted = DayPlanService.formatTimeOfDay(DayPlanService.getSleepTime());
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideAnim.value),
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isThemeDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.04),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isThemeDark ? 0.5 : 0.12),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: EdgeInsets.only(bottom: keyboardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: secondaryText.withOpacity(0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E3A8A).withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Text('🌙', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan Tomorrow',
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'What do you want to accomplish tomorrow?',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Text input area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220, minHeight: 120),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isThemeDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.55,
                    color: primaryText,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText:
                        'e.g.\n- Review morning emails\n- Team sync at 10 AM\n- Finish project proposal',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.55,
                      color: secondaryText.withOpacity(0.5),
                    ),
                  ),
                  cursorColor: const Color(0xFF1E3A8A),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Hint text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 11, color: secondaryText.withOpacity(0.4)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'You\'ll be reminded in the morning at your wake time. Sleep time: $sleepFormatted',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: secondaryText.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _savePlan,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(LucideIcons.moon, size: 16),
                  label: Text(
                    _saving ? 'Saving...' : 'Save Plan for Tomorrow',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the "Plan Tomorrow" bottom sheet
Future<String?> showPlanTomorrowSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const PlanTomorrowSheet(),
  );
}
