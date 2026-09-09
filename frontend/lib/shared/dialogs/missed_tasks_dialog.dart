import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/notification_provider.dart';

String _formatMissedDuration(String rawDuration) {
  // Parse raw duration string (e.g. "30 mins", "1 hour 30 min", "45") → "30m", "1h 30m"
  int total = 0;
  final hrMatch = RegExp(r'(\d+)\s*(?:hr|hrs|hour|hours|h)\b', caseSensitive: false).firstMatch(rawDuration);
  if (hrMatch != null) total += (int.tryParse(hrMatch.group(1)!) ?? 0) * 60;
  final minMatch = RegExp(r'(\d+)\s*(?:min|mins|minute|minutes|m)\b', caseSensitive: false).firstMatch(rawDuration);
  if (minMatch != null) total += (int.tryParse(minMatch.group(1)!) ?? 0);
  if (total == 0) {
    final digits = int.tryParse(rawDuration.replaceAll(RegExp(r'[^0-9]'), ''));
    if (digits != null) total = digits;
  }
  if (total <= 0) return rawDuration;
  final h = total ~/ 60;
  final m = total % 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

String _formatMissedDate(String isoDate) {
  try {
    final parts = isoDate.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysDiff = today.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (daysDiff == 1) return 'Yesterday';
    if (daysDiff <= 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dt.weekday - 1]}, ${daysDiff}d ago';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  } catch (_) {
    return isoDate;
  }
}

String _formatDueTime(String? dueTime) {
  if (dueTime == null || dueTime.isEmpty) return '';
  try {
    final parts = dueTime.split(':');
    int h = int.parse(parts[0]);
    final m = int.tryParse(parts[1]) ?? 0;
    final ampm = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    else if (h > 12) h -= 12;
    return '$h:${m.toString().padLeft(2, '0')} $ampm';
  } catch (_) {
    return dueTime;
  }
}

class MissedTasksDialog extends StatefulWidget {
  final List<MissedTaskInfo> missedTasks;
  final void Function(MissedTaskInfo info) onTaskTap;

  const MissedTasksDialog({
    super.key,
    required this.missedTasks,
    required this.onTaskTap,
  });

  @override
  State<MissedTasksDialog> createState() => _MissedTasksDialogState();
}

class _MissedTasksDialogState extends State<MissedTasksDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
    const redAccent = Color(0xFFDC2626);

    final count = widget.missedTasks.length;

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
                  color: Colors.black.withOpacity(isThemeDark ? 0.65 : 0.15),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: redAccent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(LucideIcons.alertTriangle, size: 17, color: redAccent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MISSED TASKS',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: secondaryText.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$count unresolved task${count > 1 ? "s" : ""} from previous days.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap a task to work on it now.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, size: 17, color: secondaryText.withOpacity(0.6)),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: borderColor),

                // Task list
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    child: Column(
                      children: widget.missedTasks.map((info) {
                        return _MissedTaskRow(
                          info: info,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          itemBg: itemBg,
                          borderColor: borderColor,
                          onTap: () => widget.onTaskTap(info),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Footer
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

class _MissedTaskRow extends StatefulWidget {
  final MissedTaskInfo info;
  final Color primaryText;
  final Color secondaryText;
  final Color itemBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _MissedTaskRow({
    required this.info,
    required this.primaryText,
    required this.secondaryText,
    required this.itemBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_MissedTaskRow> createState() => _MissedTaskRowState();
}

class _MissedTaskRowState extends State<_MissedTaskRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final hoverBg = isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
    final dueLabel = _formatDueTime(widget.info.dueTime);
    final dateLabel = _formatMissedDate(widget.info.missedDate);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _isHovered ? hoverBg : widget.itemBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFFDC2626).withOpacity(0.40)
                  : widget.borderColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.info.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          dateLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: widget.secondaryText.withOpacity(0.8),
                          ),
                        ),
                        if (dueLabel.isNotEmpty) ...[
                          Text(
                            ' · ',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: widget.secondaryText.withOpacity(0.5),
                            ),
                          ),
                          Text(
                            dueLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: widget.secondaryText.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatMissedDuration(widget.info.duration),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: widget.secondaryText.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: widget.secondaryText.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
