import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ModernDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Color? accentColor;
  final String title;
  final String subtitle;

  const ModernDatePickerDialog({
    super.key,
    required this.initialDate,
    this.firstDate,
    this.lastDate,
    this.accentColor,
    this.title = 'Select End Date',
    this.subtitle = 'Choose when repeat should stop',
  });

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    Color? accentColor,
    String title = 'Select End Date',
    String subtitle = 'Choose when repeat should stop',
  }) {
    return showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => ModernDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        accentColor: accentColor,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<ModernDatePickerDialog> createState() => _ModernDatePickerDialogState();
}

class _ModernDatePickerDialogState extends State<ModernDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  final DateTime _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _applyPreset(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _displayedMonth = DateTime(date.year, date.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final primaryText = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);
    final accent = widget.accentColor ?? const Color(0xFF1E3A8A);
    final subtlePillBg = isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9);

    final minDate = widget.firstDate ?? _today;
    final maxDate = widget.lastDate ?? DateTime(_today.year + 5);

    // Calculate presets
    final preset1Week = _today.add(const Duration(days: 7));
    final preset2Weeks = _today.add(const Duration(days: 14));
    final presetEndOfThisMonth = DateTime(_today.year, _today.month + 1, 0);
    final preset1Month = DateTime(_today.year, _today.month + 1, _today.day);
    final preset3Months = DateTime(_today.year, _today.month + 3, _today.day);
    final presetEndOfYear = DateTime(_today.year, 12, 31);

    // Days in current displayed month
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
    final leadingBlanks = firstWeekday - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(isDark ? 0.95 : 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.40 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Icon & Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withOpacity(0.25), width: 1.2),
                      ),
                      child: Icon(LucideIcons.calendar, size: 18, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_months[_selectedDate.month - 1].substring(0, 3)} ${_selectedDate.day}, ${_selectedDate.year}',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x, size: 18, color: secondaryText.withOpacity(0.7)),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // 2. Smart Quick Preset Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildPresetChip('1 Week', preset1Week, accent, subtlePillBg, primaryText),
                      const SizedBox(width: 6),
                      _buildPresetChip('2 Weeks', preset2Weeks, accent, subtlePillBg, primaryText),
                      const SizedBox(width: 6),
                      _buildPresetChip('End of Mo', presetEndOfThisMonth, accent, subtlePillBg, primaryText),
                      const SizedBox(width: 6),
                      _buildPresetChip('1 Month', preset1Month, accent, subtlePillBg, primaryText),
                      const SizedBox(width: 6),
                      _buildPresetChip('3 Months', preset3Months, accent, subtlePillBg, primaryText),
                      const SizedBox(width: 6),
                      _buildPresetChip('End of Year', presetEndOfYear, accent, subtlePillBg, primaryText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Subtle Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: borderColor,
              ),
              const SizedBox(height: 10),

              // 3. Month & Year Navigation Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_months[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    Row(
                      children: [
                        _buildNavButton(LucideIcons.chevronLeft, _previousMonth, subtlePillBg, primaryText),
                        const SizedBox(width: 6),
                        _buildNavButton(LucideIcons.chevronRight, _nextMonth, subtlePillBg, primaryText),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 4. Weekday Header Row (M T W T F S S)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _weekdays.map((w) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: secondaryText.withOpacity(0.6),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),

              // 5. Calendar Days Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: leadingBlanks + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < leadingBlanks) {
                      return const SizedBox.shrink();
                    }
                    final dayNum = index - leadingBlanks + 1;
                    final cellDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
                    final isSelected = _isSameDay(cellDate, _selectedDate);
                    final isToday = _isSameDay(cellDate, _today);
                    final isDisabled = cellDate.isBefore(minDate) || cellDate.isAfter(maxDate);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isDisabled
                          ? null
                          : () {
                              setState(() {
                                _selectedDate = cellDate;
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? accent
                              : (isToday
                                  ? accent.withOpacity(0.12)
                                  : Colors.transparent),
                          border: isToday && !isSelected
                              ? Border.all(color: accent.withOpacity(0.5), width: 1.2)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: accent.withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDisabled
                                      ? secondaryText.withOpacity(0.25)
                                      : primaryText),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 6. Action Footer Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: secondaryText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(_selectedDate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Set End Date',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildPresetChip(String label, DateTime date, Color accent, Color bg, Color text) {
    final isSelected = _isSameDay(_selectedDate, date);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _applyPreset(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accent : bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : bg,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : text.withOpacity(0.75),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, Color bg, Color text) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: text.withOpacity(0.8)),
      ),
    );
  }
}
