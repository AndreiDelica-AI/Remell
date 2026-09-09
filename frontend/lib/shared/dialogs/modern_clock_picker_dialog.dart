import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ModernClockPickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;
  final String subtitle;
  final bool isWakeTime;

  const ModernClockPickerDialog({
    super.key,
    required this.initialTime,
    required this.title,
    required this.subtitle,
    this.isWakeTime = true,
  });

  static Future<TimeOfDay?> show({
    required BuildContext context,
    required TimeOfDay initialTime,
    required String title,
    required String subtitle,
    bool isWakeTime = true,
  }) {
    return showDialog<TimeOfDay>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => ModernClockPickerDialog(
        initialTime: initialTime,
        title: title,
        subtitle: subtitle,
        isWakeTime: isWakeTime,
      ),
    );
  }

  @override
  State<ModernClockPickerDialog> createState() => _ModernClockPickerDialogState();
}

class _ModernClockPickerDialogState extends State<ModernClockPickerDialog> {
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
  }

  void _applyPreset(int hour24, int minute) {
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        hour24,
        minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isThemeDark ? const Color(0xFF161B26) : Colors.white;
    final primaryText = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isThemeDark ? const Color(0xFF2A324B) : const Color(0xFFE2E8F0);
    final accentColor = widget.isWakeTime ? const Color(0xFFF59E0B) : const Color(0xFF818CF8);

    final List<Map<String, dynamic>> presets = widget.isWakeTime
        ? [
            {'label': '6:00 AM', 'hour': 6, 'minute': 0},
            {'label': '6:30 AM', 'hour': 6, 'minute': 30},
            {'label': '7:00 AM', 'hour': 7, 'minute': 0},
            {'label': '7:30 AM', 'hour': 7, 'minute': 30},
            {'label': '8:00 AM', 'hour': 8, 'minute': 0},
          ]
        : [
            {'label': '9:30 PM', 'hour': 21, 'minute': 30},
            {'label': '10:00 PM', 'hour': 22, 'minute': 0},
            {'label': '10:30 PM', 'hour': 22, 'minute': 30},
            {'label': '11:00 PM', 'hour': 23, 'minute': 0},
            {'label': '11:30 PM', 'hour': 23, 'minute': 30},
          ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isThemeDark ? 0.5 : 0.08),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Apple Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isWakeTime ? LucideIcons.sun : LucideIcons.moon,
                      size: 18,
                      color: accentColor,
                    ),
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
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
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
                    icon: Icon(LucideIcons.x, size: 18, color: secondaryText),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: borderColor),

            // Apple Native Cupertino Time Wheel
            SizedBox(
              height: 180,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isThemeDark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.inter(
                      color: primaryText,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  key: ValueKey(_selectedDateTime),
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: _selectedDateTime,
                  use24hFormat: false,
                  onDateTimeChanged: (DateTime newDateTime) {
                    _selectedDateTime = newDateTime;
                  },
                ),
              ),
            ),

            Divider(height: 1, color: borderColor),

            // Quick Presets
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: presets.map((preset) {
                    final h = preset['hour'] as int;
                    final m = preset['minute'] as int;
                    final isSelected = _selectedDateTime.hour == h && _selectedDateTime.minute == m;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _applyPreset(h, m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor.withOpacity(0.18)
                                : (isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? accentColor : borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            preset['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? accentColor : secondaryText,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Bottom Actions (Cancel / Done)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryText,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          TimeOfDay(
                            hour: _selectedDateTime.hour,
                            minute: _selectedDateTime.minute,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(
                          fontSize: 14,
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
    );
  }
}
