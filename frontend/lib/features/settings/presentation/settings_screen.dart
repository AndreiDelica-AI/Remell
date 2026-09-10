import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/tasks_provider.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/day_plan_service.dart';
import '../../../shared/dialogs/modern_clock_picker_dialog.dart';
import '../../../shared/dialogs/legal_dialogs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _allowNotifications = true;
  bool _persistentNotifs = true;
  bool _smartAI = true;
  bool _autoSubtasks = true;

  String _wakeTime = '07:00 AM';
  String _sleepTime = '10:00 PM';
  String _theme = 'Dark';
  String _accentColor = 'Default Blue';

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  void _loadLocalSettings() {
    if (!kIsWeb) return;
    try {
      {
        final allowNotif = html.window.localStorage['remell_settings_allow_notifs'];
        if (allowNotif != null) _allowNotifications = (allowNotif == 'true');
        final w = html.window.localStorage['remell_settings_wake_time'];
        if (w != null) _wakeTime = w;
        final s = html.window.localStorage['remell_settings_sleep_time'];
        if (s != null) _sleepTime = s;
        final t = html.window.localStorage['remell_settings_theme'];
        if (t != null) {
          _theme = t;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (t == 'Dark') {
                ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
              } else if (t == 'Light') {
                ref.read(themeModeProvider.notifier).state = ThemeMode.light;
              } else {
                ref.read(themeModeProvider.notifier).state = ThemeMode.system;
              }
            }
          });
        }
        final a = html.window.localStorage['remell_settings_accent'];
        if (a != null) _accentColor = a;
        
        final tm = html.window.localStorage['remell_settings_trial_mode'];
        if (tm != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(isTrialModeProvider.notifier).state = (tm == 'true');
            }
          });
        }

        final pn = html.window.localStorage['remell_settings_pn'];
        if (pn != null) _persistentNotifs = (pn == 'true');
        final sa = html.window.localStorage['remell_settings_sa'];
        if (sa != null) _smartAI = (sa == 'true');
        final asSub = html.window.localStorage['remell_settings_asub'];
        if (asSub != null) _autoSubtasks = (asSub == 'true');
      }
    } catch (_) {}
  }

  void _saveSetting(String key, String value) {
    if (!kIsWeb) return;
    try {
      {
        html.window.localStorage[key] = value;
      }
    } catch (_) {}
  }

  Future<void> _selectWakeTime() async {
    final timeParts = _wakeTime.split(' ');
    final hm = timeParts[0].split(':');
    int hour = int.tryParse(hm[0]) ?? 7;
    final int minute = int.tryParse(hm[1]) ?? 0;
    if (timeParts.length > 1 && timeParts[1].toLowerCase() == 'pm' && hour < 12) {
      hour += 12;
    } else if (timeParts.length > 1 && timeParts[1].toLowerCase() == 'am' && hour == 12) {
      hour = 0;
    }

    final TimeOfDay? picked = await ModernClockPickerDialog.show(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      title: 'Wake Up Time',
      subtitle: 'Schedule your morning task summary',
      isWakeTime: true,
    );

    if (picked != null) {
      setState(() {
        _wakeTime = picked.format(context);
      });
      _saveSetting('remell_settings_wake_time', _wakeTime);
      DayPlanService.scheduleDailyPlanningReminders();
    }
  }

  Future<void> _selectSleepTime() async {
    final timeParts = _sleepTime.split(' ');
    final hm = timeParts[0].split(':');
    int hour = int.tryParse(hm[0]) ?? 22;
    final int minute = int.tryParse(hm[1]) ?? 0;
    if (timeParts.length > 1 && timeParts[1].toLowerCase() == 'pm' && hour < 12) {
      hour += 12;
    } else if (timeParts.length > 1 && timeParts[1].toLowerCase() == 'am' && hour == 12) {
      hour = 0;
    }

    final TimeOfDay? picked = await ModernClockPickerDialog.show(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      title: 'Bedtime / Sleep Time',
      subtitle: 'Schedule your evening accomplishment review',
      isWakeTime: false,
    );

    if (picked != null) {
      setState(() {
        _sleepTime = picked.format(context);
      });
      _saveSetting('remell_settings_sleep_time', _sleepTime);
      DayPlanService.scheduleDailyPlanningReminders();
    }
  }

  void _selectTheme() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Select Theme', 
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['System', 'Dark', 'Light'].map((t) {
              return ListTile(
                title: Text(t, style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black)),
                onTap: () {
                  setState(() {
                    _theme = t;
                  });
                  _saveSetting('remell_settings_theme', t);
                  
                  if (t == 'Dark') {
                    ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
                  } else if (t == 'Light') {
                    ref.read(themeModeProvider.notifier).state = ThemeMode.light;
                  } else {
                    ref.read(themeModeProvider.notifier).state = ThemeMode.system;
                  }
                  
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _selectAccentColor() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Select Accent Color', 
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Default Blue', 'Emerald Green', 'Violet Purple', 'Sunset Amber'].map((a) {
              return ListTile(
                title: Text(a, style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black)),
                onTap: () {
                  setState(() {
                    _accentColor = a;
                  });
                  _saveSetting('remell_settings_accent', a);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final cardBg = isThemeDark ? const Color(0xFF131B2E) : const Color(0xFFFFFFFF);
    final borderColor = isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final authUser = ref.watch(authUserProvider);
    String displayName = authUser?['nickname'] ?? authUser?['displayName'] ?? authUser?['name'] ?? '';
    if (displayName.isEmpty && authUser?['email'] != null) { displayName = authUser!['email'].toString().split('@').first; }
    if (displayName.isEmpty) displayName = 'Drei';
    if (displayName.length > 7) displayName = displayName.substring(0, 7);
    final email = authUser?['email'] ?? '';
    final avatarUrl = authUser?['avatarUrl'] as String?;
    final initials = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'D';
    return Scaffold(
      backgroundColor: isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'My Account.',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 20),

              // Premium Account Profile Card - Tappable to edit
              GestureDetector(
                onTap: () => _showEditProfileSheet(context, displayName, avatarUrl),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: cardBg.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      // Avatar: shows Google photo if available, else initials
                      Stack(
                        children: [
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: (avatarUrl == null || avatarUrl.isEmpty) ? const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ) : null,
                            ),
                            child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? ClipOval(
                                    child: Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(initials, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(initials, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBg, width: 2),
                              ),
                              child: const Icon(LucideIcons.pencil, size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: secondaryTextColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.pencil, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              'Edit Profile',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildCategoryHeader('Profile details', secondaryTextColor),
                    _buildListTile('Edit Display Name & Photo', trailing: 'Edit', onTap: () => _showEditProfileSheet(context, displayName, avatarUrl)),
                    
                    const SizedBox(height: 20),
                    _buildCategoryHeader('Sleep & wake schedule', secondaryTextColor),
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          // Wake Time Row
                          InkWell(
                            onTap: _selectWakeTime,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(LucideIcons.sun, size: 18, color: Color(0xFFF59E0B)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Wake Up',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: primaryTextColor,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Morning plan and alarms',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _wakeTime,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: primaryTextColor,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          LucideIcons.chevronRight,
                                          size: 14,
                                          color: secondaryTextColor.withOpacity(0.6),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            indent: 66,
                            endIndent: 16,
                            color: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                          // Sleep Time Row
                          InkWell(
                            onTap: _selectSleepTime,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF818CF8).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(LucideIcons.moon, size: 18, color: Color(0xFF818CF8)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bedtime',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: primaryTextColor,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Evening review and wind-down',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _sleepTime,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: primaryTextColor,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          LucideIcons.chevronRight,
                                          size: 14,
                                          color: secondaryTextColor.withOpacity(0.6),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    _buildCategoryHeader('Reminders & alerts', secondaryTextColor),
                    _buildSwitchTile('Allow task notifications', _allowNotifications, (val) async {
                      if (val) {
                        final granted = await NotificationService.requestPermissions();
                        setState(() => _allowNotifications = granted);
                        _saveSetting('remell_settings_allow_notifs', granted.toString());
                      } else {
                        setState(() => _allowNotifications = false);
                        _saveSetting('remell_settings_allow_notifs', 'false');
                      }
                    }),
                    _buildSwitchTile('Persistent notifications', _persistentNotifs, (val) {
                      setState(() => _persistentNotifs = val);
                      _saveSetting('remell_settings_pn', val.toString());
                    }),
                    _buildSwitchTile('Automatic subtasks', _autoSubtasks, (val) {
                      setState(() => _autoSubtasks = val);
                      _saveSetting('remell_settings_asub', val.toString());
                    }),

                    const SizedBox(height: 24),
                    _buildCategoryHeader('Legal & privacy', secondaryTextColor),
                    _buildListTile('Privacy Policy', trailing: '', onTap: () {
                      LegalModalDialog.showPrivacy(context);
                    }),
                    _buildListTile('Terms of Service', trailing: '', onTap: () {
                      LegalModalDialog.showTerms(context);
                    }),

                    const SizedBox(height: 24),
                    _buildCategoryHeader('Storage & device cache', secondaryTextColor),
                    _buildListTile('Clear Local Cache', trailing: '', onTap: _showClearCacheDialog),

                    const SizedBox(height: 24),
                    _buildCategoryHeader('Security & access', secondaryTextColor),
                    _buildListTile('Sign Out', trailing: '', onTap: _showSignOutWarningDialog, isDestructive: true),
                    _buildListTile('Delete Account', trailing: '', onTap: _showDeleteAccountDialog, isDestructive: true),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isThemeDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.trash2, color: Colors.amber, size: 22),
            const SizedBox(width: 10),
            Text(
              'Clear Local Cache',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Text(
          'This will clear local offline data cache and re-synchronize clean state on next reload. Your account will remain active.',
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.4,
            color: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (kIsWeb) {
                clearLocalCachePreservingAuth();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local cache cleared successfully.'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }


  void _showEditProfileSheet(BuildContext context, String currentName, String? currentAvatarUrl) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: currentName);
    String? selectedPhotoData = currentAvatarUrl;
    bool isSaving = false;

    void pickPhotoFromDevice(StateSetter setModalState) {
      if (!kIsWeb) return;
      try {
        final uploadInput = html.FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        uploadInput.onChange.listen((e) {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            final file = files[0];
            final reader = html.FileReader();
            reader.readAsDataUrl(file);
            reader.onLoadEnd.listen((e) {
              final result = reader.result as String?;
              if (result != null && result.isNotEmpty) {
                setModalState(() {
                  selectedPhotoData = result;
                });
              }
            });
          }
        });
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final liveAvatar = selectedPhotoData ?? '';
          final liveName = nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'D';
          final liveInitial = liveName.substring(0, 1).toUpperCase();

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: isThemeDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isThemeDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Profile',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isThemeDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(LucideIcons.x, size: 20, color: isThemeDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                  Text(
                    'Update your display name and profile photo.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar Photo Upload Section with Interactive Tappable Circle
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => pickPhotoFromDevice(setModalState),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 90,
                                width: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF2563EB), width: 3),
                                  gradient: liveAvatar.isEmpty
                                      ? const LinearGradient(
                                          colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withOpacity(0.3),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: liveAvatar.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          liveAvatar,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(liveInitial, style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(liveInitial, style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isThemeDark ? const Color(0xFF0F172A) : Colors.white, width: 2),
                                  ),
                                  child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons: Upload Photo & Remove Photo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => pickPhotoFromDevice(setModalState),
                              icon: const Icon(LucideIcons.image, size: 16, color: Color(0xFF2563EB)),
                              label: Text(
                                'Upload Photo',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                            if (liveAvatar.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    selectedPhotoData = null;
                                  });
                                },
                                icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
                                label: Text(
                                  'Remove',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.redAccent),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Display Name field
                  Text(
                    'Display Name / Nickname',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    maxLength: 7,
                    onChanged: (_) => setModalState(() {}),
                    style: GoogleFonts.inter(
                      color: isThemeDark ? Colors.white : const Color(0xFF111827),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Your name or nickname',
                      hintStyle: GoogleFonts.inter(color: isThemeDark ? const Color(0xFF475569) : const Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(LucideIcons.user, size: 16, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                final dio = ref.read(apiClientProvider).client;
                                final rawName = nameController.text.trim();
final firstWord = rawName.split(RegExp(r'\s+')).first;
final cleaned = firstWord.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
final newName = cleaned.length > 7 ? cleaned.substring(0, 7) : cleaned;
                                final response = await dio.patch('/auth/profile', data: {
                                  'displayName': newName.isNotEmpty ? newName : null,
                                  'avatarUrl': selectedPhotoData,
                                });
                                if (response.statusCode == 200) {
                                  final updated = response.data['data'] as Map<String, dynamic>?;
                                  final current = Map<String, dynamic>.from(ref.read(authUserProvider) ?? {});
                                  if (updated != null) {
                                    current['displayName'] = updated['displayName'] ?? newName;
                                    current['avatarUrl'] = updated['avatarUrl'] ?? selectedPhotoData;
                                    current['nickname'] = updated['displayName'] ?? newName;
                                  } else {
                                    current['displayName'] = newName;
                                    current['avatarUrl'] = selectedPhotoData;
                                    current['nickname'] = newName;
                                  }
                                  ref.read(authUserProvider.notifier).state = current;
                                  saveAuthSession(ref.read(authTokenProvider), current);
                                  
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Profile photo & name updated!'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() => isSaving = false);
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update profile: ${e.toString()}'),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Save Changes', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildCategoryHeader(String title, Color secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title.toLowerCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: secondaryTextColor.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildListTile(
    String title, {
    required String trailing,
    Widget? customTrailing,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: isDestructive ? Colors.redAccent : primaryTextColor,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customTrailing != null)
            customTrailing
          else if (trailing.isNotEmpty)
            Text(
              trailing,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: secondaryTextColor.withOpacity(0.6),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight, 
              size: 14, 
              color: primaryTextColor.withOpacity(0.2),
            ),
          ]
        ],
      ),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: primaryTextColor,
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF2563EB),
            inactiveThumbColor: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
            inactiveTrackColor: isThemeDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  void _showResetLearningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset AI Learning?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        content: Text(
          'This will erase all behavioral weight models. Remell will fallback to default smart schedules.',
          style: GoogleFonts.inter(height: 1.4, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI memory cleared.')),
              );
            },
            child: Text(
              'Reset',
              style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutWarningDialog() {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isThemeDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.logOut, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              'Sign Out Warning',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out? Your offline session will be ended and you will need to sign in again to access your account.',
          style: GoogleFonts.inter(
            height: 1.4,
            color: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    saveAuthSession(null, null);
    ref.read(quickTasksProvider.notifier).resetForAccountChange();
    ref.read(focusTasksProvider.notifier).resetForAccountChange();
    ref.read(authTokenProvider.notifier).state = null;
    ref.read(authUserProvider.notifier).state = null;
  }

  void _showDeleteAccountDialog() {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isThemeDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              'Delete Account Warning',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CAUTION: This action cannot be easily undone.',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account and all synchronized tasks, notes, and preferences will be permanently purged after 30 days. You will be immediately signed out.',
              style: GoogleFonts.inter(
                height: 1.4,
                color: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final token = ref.read(authTokenProvider);
    if (token == null) return;

    final dio = Dio(BaseOptions(
      baseUrl: ApiClient.resolvedBaseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'x-request-id': 'flutter-${DateTime.now().millisecondsSinceEpoch}',
      },
    ));

    try {
      final response = await dio.delete('/auth/delete-account');
      if (response.statusCode == 200) {
        ref.read(authTokenProvider.notifier).state = null;
        ref.read(authUserProvider.notifier).state = null;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account scheduled for deletion. You have been signed out.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go('/login');
        }
      } else {
        throw Exception('Failed to delete account.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete account. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
