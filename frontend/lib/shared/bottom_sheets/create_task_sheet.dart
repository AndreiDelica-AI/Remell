import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:remell/shared/services/voice_service.dart';
import 'package:remell/shared/providers/tasks_provider.dart';
import 'dart:html' as html;
import 'package:remell/core/network/api_client.dart';
import 'package:remell/shared/providers/auth_provider.dart';
import 'package:remell/shared/utils/nlp_parser.dart';
import 'package:remell/shared/services/notification_service.dart';
import 'package:remell/shared/dialogs/modern_date_picker_dialog.dart';
import 'package:remell/shared/utils/time_highlighting_controller.dart';

class CreateTaskSheet extends ConsumerStatefulWidget {
  final QuickTaskItem? taskToEdit;
  final FocusTaskItem? focusTaskToEdit;
  final bool initialIsQuickNote;

  const CreateTaskSheet({
    super.key,
    this.taskToEdit,
    this.focusTaskToEdit,
    this.initialIsQuickNote = true,
  });

  @override
  ConsumerState<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<CreateTaskSheet> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final _taskController = TimeHighlightingTextEditingController();
  final _notesController = TimeHighlightingTextEditingController();

  final List<String> _subTasks = [];
  final List<TimeHighlightingTextEditingController> _subTaskControllers = [];

  bool _showDetails = false;
  bool _isAiParsing = false;
  String? _validationError;

  bool _isQuickNote = true;
  bool _showManualSettings = false;

  static const List<int> _minuteOptions = [0, 5, 10, 15, 30, 60];
  int _durationHours = 0;
  int _durationMinutes = 2; // Index in _minuteOptions (2 => 10 min)

  late FixedExtentScrollController _quickHoursController;
  late FixedExtentScrollController _quickMinutesController;
  late FixedExtentScrollController _focusHoursController;
  late FixedExtentScrollController _focusMinutesController;

  String _selectedSegment = 'Morning';
  bool _isUrgent = false;
  String _selectedColorHex = '#1E3A8A';
  String _selectedIcon = 'target';

  final List<Map<String, String>> _colorOptions = const [
    {'name': 'Dark Gold Yellow', 'hex': '#CA8A04'},
    {'name': 'Dark Amber Copper', 'hex': '#78350F'},
    {'name': 'Dark Burnt Orange', 'hex': '#C2410C'},
    {'name': 'Dark Ruby Red', 'hex': '#B91C1C'},
    {'name': 'Dark Crimson Maroon', 'hex': '#881337'},
    {'name': 'Dark Wine Rose', 'hex': '#9D174D'},
    {'name': 'Dark Plum Violet', 'hex': '#581C87'},
    {'name': 'Dark Royal Purple', 'hex': '#6B21A8'},
    {'name': 'Dark Indigo Night', 'hex': '#312E81'},
    {'name': 'Dark Cobalt Blue', 'hex': '#1E40AF'},
    {'name': 'Dark Royal Navy', 'hex': '#1E3A8A'},
    {'name': 'Dark Ocean Cyan', 'hex': '#075985'},
    {'name': 'Dark Deep Teal', 'hex': '#0F766E'},
    {'name': 'Dark Emerald Green', 'hex': '#064E3B'},
    {'name': 'Dark Forest Green', 'hex': '#15803D'},
    {'name': 'Dark Bronze Olive', 'hex': '#3F6212'},
  ];

  static final Map<String, List<String>> _iconKeywords = const {
    'dumbbell': ['gym', 'fitness', 'workout', 'dumbbell', 'exercise', 'weights', 'bicep', 'health', 'train', 'sport', 'lift', 'bodybuilding', 'muscle'],
    'target': ['target', 'focus', 'goal', 'aim', 'bullseye', 'task', 'priority', 'objective'],
    'briefcase': ['briefcase', 'work', 'job', 'office', 'business', 'company', 'career', 'employment', 'meeting'],
    'book': ['book', 'read', 'study', 'education', 'learn', 'course', 'reading', 'school', 'homework', 'library', 'textbook'],
    'code': ['code', 'dev', 'developer', 'programming', 'software', 'script', 'coding', 'html', 'python', 'css', 'bug', 'git', 'web'],
    'coffee': ['coffee', 'break', 'drink', 'cafe', 'espresso', 'tea', 'morning', 'rest', 'pause', 'energy', 'latte', 'beverage'],
    'zap': ['zap', 'energy', 'lightning', 'bolt', 'fast', 'quick', 'power', 'urgent', 'priority', 'high'],
    'compass': ['compass', 'explore', 'navigation', 'direction', 'travel', 'guide', 'route', 'map'],
    'sparkles': ['sparkles', 'star', 'magic', 'clean', 'new', 'shine', 'ai', 'feature', 'special', 'create'],
    'trophy': ['trophy', 'win', 'award', 'victory', 'champion', 'achievement', 'reward', 'first', 'success', 'cup', 'prize'],
    'heart': ['heart', 'love', 'health', 'care', 'cardio', 'family', 'favorite', 'like', 'relationship', 'selfcare', 'wellness'],
    'music': ['music', 'song', 'audio', 'sound', 'listen', 'headphone', 'play', 'track', 'album', 'sing', 'tune'],
    'camera': ['camera', 'photo', 'picture', 'video', 'shoot', 'media', 'image', 'snapshot', 'film', 'record', 'photography'],
    'utensils': ['utensils', 'food', 'eat', 'meal', 'cook', 'cooking', 'dinner', 'lunch', 'breakfast', 'restaurant', 'recipe', 'kitchen', 'diet', 'snack'],
    'shoppingCart': ['shoppingcart', 'shopping', 'cart', 'buy', 'store', 'groceries', 'market', 'purchase', 'shop'],
    'wallet': ['wallet', 'money', 'finance', 'pay', 'cash', 'budget', 'card', 'bank', 'coins', 'expense', 'bill'],
    'laptop': ['laptop', 'computer', 'pc', 'tech', 'work', 'screen', 'online', 'remote', 'desk'],
    'headphones': ['headphones', 'headset', 'music', 'listen', 'podcast', 'audio', 'call', 'audiobook'],
    'plane': ['plane', 'flight', 'travel', 'trip', 'vacation', 'airport', 'holiday', 'fly', 'tour'],
    'car': ['car', 'drive', 'auto', 'commute', 'travel', 'vehicle', 'ride', 'road', 'trip'],
    'bike': ['bike', 'bicycle', 'cycling', 'ride', 'exercise', 'outdoor', 'commute', 'sport'],
    'home': ['home', 'house', 'cleaning', 'chores', 'family', 'stay', 'indoor', 'residence', 'room'],
    'brush': ['brush', 'paint', 'art', 'design', 'draw', 'sketch', 'clean', 'teeth', 'hygiene', 'sweep'],
  };

  /// Categorized Icon Map for building the Task Creation Icon Picker
  static final Map<String, List<String>> categories = {
    'Time of Day': [
      'sun',
      'sunrise',
      'sun-medium',
      'sun-max',
      'cloud-sun',
      'compass',
      'moon',
      'moon-stars',
      'bed',
    ],
    'Work & Career': [
      'briefcase',
      'laptop',
      'code',
      'file-text',
      'mail',
      'presentation',
      'terminal',
      'folder',
      'archive',
      'clipboard-list',
    ],
    'Health & Fitness': [
      'dumbbell',
      'heart-pulse',
      'apple',
      'footprints',
      'pill',
      'bike',
      'activity',
      'trophy',
      'flame',
      'timer',
    ],
    'Personal & Home': [
      'home',
      'shopping-bag',
      'utensils',
      'car',
      'sparkles',
      'wrench',
      'coffee',
      'scissors',
      'trash-2',
      'bath',
    ],
    'Learning & Mind': [
      'book-open',
      'pencil',
      'graduation-cap',
      'brain',
      'headphones',
      'lightbulb',
      'bookmark',
      'palette',
      'music',
      'microscope',
    ],
    'Finance & Bills': [
      'credit-card',
      'dollar-sign',
      'receipt',
      'wallet',
      'piggy-bank',
      'coins',
      'trending-up',
      'percent',
    ],
    'Social & Life': [
      'users',
      'calendar',
      'gift',
      'phone-call',
      'party-popper',
      'message-square',
      'smile',
      'plane',
    ],
    'Status & Controls': [
      'check-circle',
      'circle',
      'flag',
      'alert-circle',
      'star',
      'bell',
      'tag',
      'lock',
    ],
  };

  /// Complete String Key -> IconData lookup table for runtime rendering
  static final Map<String, IconData> allIcons = {
    // Time of Day
    'sun': LucideIcons.sun,
    'sunrise': LucideIcons.sunrise,
    'sun-medium': LucideIcons.sunMedium,
    'sun-max': LucideIcons.sunDim,
    'cloud-sun': LucideIcons.cloudSun,
    'compass': LucideIcons.compass,
    'moon': LucideIcons.moon,
    'moon-stars': LucideIcons.moonStar,
    'bed': LucideIcons.bed,

    // Work & Career
    'briefcase': LucideIcons.briefcase,
    'laptop': LucideIcons.laptop,
    'code': LucideIcons.code,
    'file-text': LucideIcons.fileText,
    'mail': LucideIcons.mail,
    'presentation': LucideIcons.presentation,
    'terminal': LucideIcons.terminal,
    'folder': LucideIcons.folder,
    'archive': LucideIcons.archive,
    'clipboard-list': LucideIcons.clipboardList,

    // Health & Fitness
    'dumbbell': LucideIcons.dumbbell,
    'heart-pulse': LucideIcons.heartPulse,
    'apple': LucideIcons.apple,
    'footprints': LucideIcons.footprints,
    'pill': LucideIcons.pill,
    'bike': LucideIcons.bike,
    'activity': LucideIcons.activity,
    'trophy': LucideIcons.trophy,
    'flame': LucideIcons.flame,
    'timer': LucideIcons.timer,

    // Personal & Home
    'home': LucideIcons.home,
    'shopping-bag': LucideIcons.shoppingBag,
    'utensils': LucideIcons.utensils,
    'car': LucideIcons.car,
    'sparkles': LucideIcons.sparkles,
    'wrench': LucideIcons.wrench,
    'coffee': LucideIcons.coffee,
    'scissors': LucideIcons.scissors,
    'trash-2': LucideIcons.trash2,
    'bath': LucideIcons.bath,

    // Learning & Mind
    'book-open': LucideIcons.bookOpen,
    'pencil': LucideIcons.pencil,
    'graduation-cap': LucideIcons.graduationCap,
    'brain': LucideIcons.brain,
    'headphones': LucideIcons.headphones,
    'lightbulb': LucideIcons.lightbulb,
    'bookmark': LucideIcons.bookmark,
    'palette': LucideIcons.palette,
    'music': LucideIcons.music,
    'microscope': LucideIcons.microscope,

    // Finance & Bills
    'credit-card': LucideIcons.creditCard,
    'dollar-sign': LucideIcons.dollarSign,
    'receipt': LucideIcons.receipt,
    'wallet': LucideIcons.wallet,
    'piggy-bank': LucideIcons.piggyBank,
    'coins': LucideIcons.coins,
    'trending-up': LucideIcons.trendingUp,
    'percent': LucideIcons.percent,

    // Social & Life
    'users': LucideIcons.users,
    'calendar': LucideIcons.calendar,
    'gift': LucideIcons.gift,
    'phone-call': LucideIcons.phoneCall,
    'party-popper': LucideIcons.partyPopper,
    'message-square': LucideIcons.messageSquare,
    'smile': LucideIcons.smile,
    'plane': LucideIcons.plane,

    // Status & Controls
    'check-circle': LucideIcons.checkCircle,
    'circle': LucideIcons.circle,
    'flag': LucideIcons.flag,
    'alert-circle': LucideIcons.alertCircle,
    'star': LucideIcons.star,
    'bell': LucideIcons.bell,
    'tag': LucideIcons.tag,
    'lock': LucideIcons.lock,
  };

  static List<String> get _allIcons => allIcons.keys.toList();

  static IconData _getIconData(String name) {
    final lower = name.toLowerCase().trim();
    if (allIcons.containsKey(lower)) {
      return allIcons[lower]!;
    }
    for (var entry in allIcons.entries) {
      if (entry.key.replaceAll('-', '').toLowerCase() == lower.replaceAll('-', '').toLowerCase()) {
        return entry.value;
      }
    }
    return LucideIcons.target;
  }

  String _difficulty = 'medium';
  TimeOfDay? _selectedTime;

  final List<String> _allWeekdays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _selectedDays = [];
  DateTime? _repeatUntil;        // end date for recurring task series
  int _repeatTabMode = 0;        // 0: Ongoing, 1: Duration, 2: Target Month / Specific Date
  bool _isSubtasksCollapsed = false;

  bool _isListening = false;
  String _voiceBaseText = '';
  String? _derivedTitle;

  int _findClosestMinuteIndex(int remMin) {
    int closestIdx = 0;
    int minDiff = 999;
    for (int i = 0; i < _minuteOptions.length; i++) {
      int diff = (_minuteOptions[i] - remMin).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  @override
  void initState() {
    super.initState();

    _isQuickNote = widget.initialIsQuickNote;

    if (widget.focusTaskToEdit != null) {
      _isQuickNote = false;
      final t = widget.focusTaskToEdit!;
      _taskController.text = t.title;
      _notesController.text = (t.notes.isNotEmpty && t.notes != 'No notes added.') ? t.notes : '';
      _selectedSegment = t.timeSegment;
      _difficulty = t.difficulty;
      if (t.colorHex != null && t.colorHex!.isNotEmpty) {
        _selectedColorHex = t.colorHex!;
      } else {
        _selectedColorHex = '#1E3A8A';
      }
      if (t.iconName != null && t.iconName!.isNotEmpty) {
        _selectedIcon = t.iconName!;
      } else {
        _selectedIcon = 'target';
      }
      if (t.repeatDays.isNotEmpty) {
        _selectedDays.clear();
        _selectedDays.addAll(t.repeatDays);
      }
      _repeatUntil = t.repeatUntil;
      if (t.dueTime != null && t.dueTime!.contains(':')) {
        try {
          final parts = t.dueTime!.split(':');
          _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        } catch (_) {}
      }
      final durDigits = t.duration.replaceAll(RegExp(r'[^0-9]'), '');
      final durMin = int.tryParse(durDigits) ?? 15;
      _durationHours = durMin ~/ 60;
      _durationMinutes = _findClosestMinuteIndex(durMin % 60);

      if (t.subtasks.isNotEmpty) {
        _subTasks.clear();
        _subTaskControllers.clear();
        for (final st in t.subtasks) {
          _subTasks.add(st.title);
          _subTaskControllers.add(TimeHighlightingTextEditingController(text: st.title));
        }
      }

      if (_notesController.text.isNotEmpty || _subTasks.isNotEmpty) {
        _showDetails = true;
      }
    } else if (widget.taskToEdit != null) {
      _isQuickNote = true;
      final t = widget.taskToEdit!;
      _taskController.text = t.title;
      _notesController.text = (t.notes.isNotEmpty && t.notes != 'No notes added.') ? t.notes : '';
      _durationHours = t.durationMinutes ~/ 60;
      _durationMinutes = _findClosestMinuteIndex(t.durationMinutes % 60);
      _isUrgent = t.isUrgent;
      _difficulty = t.difficulty;
      if (t.dueTime != null && t.dueTime!.contains(':')) {
        final parts = t.dueTime!.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            _selectedTime = TimeOfDay(hour: h, minute: m);
          }
        }
      }
      if (t.subtasks.isNotEmpty) {
        _subTasks.clear();
        _subTaskControllers.clear();
        for (final st in t.subtasks) {
          _subTasks.add(st.title);
          _subTaskControllers.add(TimeHighlightingTextEditingController(text: st.title));
        }
      }
      if (t.notes.isNotEmpty && t.notes != 'No notes added.' || _subTasks.isNotEmpty) {
        _showDetails = true;
      }
    } else {
      _selectedSegment = 'Morning';
      _selectedColorHex = '#1E3A8A';
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    VoiceService.ensureMicrophonePermission();

    _quickHoursController = FixedExtentScrollController(initialItem: _durationHours);
    _quickMinutesController = FixedExtentScrollController(initialItem: _durationMinutes);
    _focusHoursController = FixedExtentScrollController(initialItem: _durationHours);
    _focusMinutesController = FixedExtentScrollController(initialItem: _durationMinutes);

    _notesController.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    VoiceService.stopListening();
    _pulseController.dispose();
    _notesController.removeListener(_onNotesChanged);
    _taskController.dispose();
    _notesController.dispose();
    for (var controller in _subTaskControllers) {
      controller.dispose();
    }
    _quickHoursController.dispose();
    _quickMinutesController.dispose();
    _focusHoursController.dispose();
    _focusMinutesController.dispose();
    super.dispose();
  }

  void _updateSubtaskControllers(List<String> steps) {
    final existingText = _subTaskControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    // Only update if steps contain new items or differ
    if (steps.isNotEmpty && steps.join('|') != existingText.join('|')) {
      for (var controller in _subTaskControllers) {
        controller.dispose();
      }
      _subTaskControllers.clear();
      for (var step in steps) {
        _subTaskControllers.add(TimeHighlightingTextEditingController(text: step));
      }
      if (mounted) setState(() {});
    }
  }

  bool get isAutoSubtasksEnabled {
    try {
      final val = html.window.localStorage['remell_settings_asub'];
      return val != 'false';
    } catch (_) {
      return true;
    }
  }

  void _onNotesChanged() {
    final text = _notesController.text;
    if (_isListening) {
      if (_voiceBaseText.isEmpty) {
        _notesController.text = text;
      } else {
        _notesController.text = '$_voiceBaseText $text';
      }
      _notesController.selection = TextSelection.fromPosition(
        TextPosition(offset: _notesController.text.length),
      );
    }

    if (text.trim().isNotEmpty) {
      // 1. Auto-extract Subtasks
      if (isAutoSubtasksEnabled) {
        final List<String> parsedSteps = NlpParser.parseSubtasks(text);
        if (parsedSteps.isNotEmpty) {
          _updateSubtaskControllers(parsedSteps);
        }
      }

      // 2. Auto-extract Duration (e.g. 6 hours -> 360 min)
      final parsedDur = NlpParser.parseDuration(text);
      if (parsedDur != null && parsedDur > 0) {
        final hours = parsedDur ~/ 60;
        final mins = _findClosestMinuteIndex(parsedDur % 60);
        if (_durationHours != hours || _durationMinutes != mins) {
          setState(() {
            _durationHours = hours;
            _durationMinutes = mins;
          });
          if (_quickHoursController.hasClients) {
            _quickHoursController.jumpToItem(hours);
          }
          if (_quickMinutesController.hasClients) {
            _quickMinutesController.jumpToItem(mins);
          }
          if (_focusHoursController.hasClients) {
            _focusHoursController.jumpToItem(hours);
          }
          if (_focusMinutesController.hasClients) {
            _focusMinutesController.jumpToItem(mins);
          }
        }
      }

      // 3. Auto-extract Start / Due Time (e.g. start around 5:30 -> 17:30)
      final parsedTimeStr = NlpParser.parseDeadline(text);
      if (parsedTimeStr != null && parsedTimeStr.contains(':')) {
        try {
          final parts = parsedTimeStr.split(':');
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final newTime = TimeOfDay(hour: h, minute: m);
          if (_selectedTime != newTime) {
            setState(() {
              _selectedTime = newTime;
            });
          }
        } catch (_) {}
      }

      // 4. Auto-extract repeat days (e.g. "every monday" → ['Mon'])
      final parsedDays = NlpParser.parseRepeatDays(text);
      if (parsedDays.isNotEmpty && _selectedDays.isEmpty) {
        setState(() {
          _selectedDays.clear();
          _selectedDays.addAll(parsedDays);
        });
      }

      // 5. Auto-extract repeat until date (e.g. "until Sept 30", "for 4 weeks")
      if (_selectedDays.isNotEmpty || parsedDays.isNotEmpty) {
        final parsedUntil = NlpParser.parseRepeatUntil(text);
        if (parsedUntil != null && _repeatUntil == null) {
          setState(() => _repeatUntil = parsedUntil);
        }
      }
    }

    _refreshDerivedTitle();
  }

  void _refreshDerivedTitle() {
    final title = NlpParser.deriveTitleFromNote(_notesController.text);
    if (mounted) {
      setState(() {
        _derivedTitle = title.isEmpty ? null : title;
      });
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await VoiceService.stopListening();
      setState(() {
        _isListening = false;
      });
      _pulseController.stop();
    } else {
      _voiceBaseText = _notesController.text.trim();
      setState(() {
        _isListening = true;
        _validationError = null;
      });
      _pulseController.repeat(reverse: true);

      await VoiceService.startListening(
        onInterim: (text) {
          if (mounted) {
            setState(() {
              if (_voiceBaseText.isEmpty) {
                _notesController.text = text;
              } else {
                _notesController.text = '$_voiceBaseText $text';
              }
              _notesController.selection = TextSelection.fromPosition(
                TextPosition(offset: _notesController.text.length),
              );
            });
            _onNotesChanged();
          }
        },
        onFinal: (text) {
          if (mounted) {
            setState(() {
              if (_voiceBaseText.isEmpty) {
                _notesController.text = text;
              } else {
                _notesController.text = '$_voiceBaseText $text';
              }
              _notesController.selection = TextSelection.fromPosition(
                TextPosition(offset: _notesController.text.length),
              );
            });
            _onNotesChanged();
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _validationError = 'Voice error: $err';
            });
            _pulseController.stop();
          }
        },
      );
    }
  }

  Widget _buildVoiceRow(Color fieldColor, Color primaryTextColor, Color secondaryTextColor, bool isDark) {
    final isSupported = VoiceService.isSupported;
    final curColor = Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF')));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isQuickNote) ...[
          // ICON SELECTOR BUTTON
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Choose Task Icon',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showIconPickerModal(context, isDark, primaryTextColor, secondaryTextColor, fieldColor),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: curColor.withOpacity(0.5), width: 1.5),
                      ),
                      child: Center(
                        child: Icon(
                          _getIconData(_selectedIcon),
                          size: 22,
                          color: curColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Icon',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
        ],

        // VOICE MICROPHONE BUTTON
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: isSupported ? _toggleListening : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isListening ? 60 : 54,
                height: _isListening ? 60 : 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.redAccent
                      : (isSupported ? primaryTextColor : primaryTextColor.withOpacity(0.1)),
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  _isListening ? LucideIcons.micOff : LucideIcons.mic,
                  color: _isListening
                      ? Colors.white
                      : (isSupported
                          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                          : secondaryTextColor),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isSupported ? (_isListening ? 'Listening...' : 'Tap mic') : 'Unavailable',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isListening ? Colors.redAccent : secondaryTextColor,
              ),
            ),
          ],
        ),

        if (!_isQuickNote) ...[
          const SizedBox(width: 24),

          // COLOR SELECTOR BUTTON
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Choose Color',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showColorPickerModal(context, isDark, primaryTextColor, secondaryTextColor, fieldColor),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: curColor, width: 2.0),
                      ),
                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: curColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: curColor.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Color',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNoteEditor({
    required Color fieldColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isDark,
    required String hint,
    int maxLines = 6,
  }) {
    final curColor = Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF')));
    final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = _isListening
        ? Colors.redAccent.withOpacity(0.6)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final boxBorderWidth = _isListening ? 2.0 : 1.0;
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final boxShadow = [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 180,
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: boxBorderWidth,
            ),
            boxShadow: boxShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isListening) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withOpacity(0.4 + 0.6 * (1.0 - _pulseController.value)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LISTENING',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              Row(
                children: [
                  if (!_isQuickNote) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: curColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: curColor.withOpacity(0.5), width: 1),
                      ),
                      child: Icon(
                        _getIconData(_selectedIcon),
                        size: 20,
                        color: curColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _taskController,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Task Title',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor.withOpacity(0.4),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                height: 1,
                color: dividerColor,
              ),

              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _isListening
                      ? (_notesController.text.isEmpty
                          ? Text(
                              'Listening...',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                height: 1.5,
                                color: primaryTextColor.withOpacity(0.4),
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : buildTimeHighlightedText(
                              _notesController.text,
                              baseStyle: GoogleFonts.inter(
                                fontSize: 15,
                                height: 1.5,
                                color: primaryTextColor.withOpacity(0.9),
                              ),
                              highlightColor: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
                            ))
                      : TextField(
                          controller: _notesController,
                          maxLines: null,
                          autofocus: widget.taskToEdit == null && widget.focusTaskToEdit == null,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: primaryTextColor.withOpacity(0.9),
                          ),
                          onChanged: (_) {
                            if (_validationError != null) {
                              setState(() => _validationError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: GoogleFonts.inter(
                              color: secondaryTextColor.withOpacity(0.4),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedRepeatCard(Color fieldColor, Color primaryTextColor, Color secondaryTextColor, bool isDark) {
    final curColor = Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF')));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    // Determine current repeat frequency mode
    final isEveryDay = _selectedDays.length == 7;
    final isWeekdaysOnly = _selectedDays.length == 5 &&
        _selectedDays.contains('Mon') &&
        _selectedDays.contains('Tue') &&
        _selectedDays.contains('Wed') &&
        _selectedDays.contains('Thu') &&
        _selectedDays.contains('Fri');
    final isNever = _selectedDays.isEmpty;

    String currentMode;
    if (isNever) {
      currentMode = 'Never';
    } else if (isEveryDay) {
      currentMode = 'Daily';
    } else if (isWeekdaysOnly) {
      currentMode = 'Weekdays';
    } else {
      currentMode = 'Custom';
    }

    const dayShortLetters = {
      'Mon': 'M',
      'Tue': 'T',
      'Wed': 'W',
      'Thu': 'T',
      'Fri': 'F',
      'Sat': 'S',
      'Sun': 'S',
    };

    Widget buildSegment(String title, String modeKey) {
      final isSelected = currentMode == modeKey;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              if (modeKey == 'Never') {
                _selectedDays.clear();
                _repeatUntil = null;
              } else if (modeKey == 'Daily') {
                _selectedDays.clear();
                _selectedDays.addAll(_allWeekdays);
              } else if (modeKey == 'Weekdays') {
                _selectedDays.clear();
                _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
              } else if (modeKey == 'Custom') {
                if (_selectedDays.isEmpty) {
                  final today = DateTime.now();
                  final todayWeekdayName = _allWeekdays[(today.weekday - 1) % 7];
                  _selectedDays.add(todayWeekdayName);
                }
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF334155) : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? primaryTextColor
                      : secondaryTextColor.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Repeat frequency switcher
          Row(
            children: [
              Icon(LucideIcons.repeat, size: 15, color: primaryTextColor.withOpacity(0.85)),
              const SizedBox(width: 7),
              Text(
                'Repeat',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Segmented Track: Never • Daily • Weekdays • Custom
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.35) : const Color(0xFFE2E8F0).withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                buildSegment('Never', 'Never'),
                buildSegment('Daily', 'Daily'),
                buildSegment('Weekdays', 'Weekdays'),
                buildSegment('Custom', 'Custom'),
              ],
            ),
          ),

          // Custom Weekday Circular Badges (Only shown when Custom is selected)
          if (currentMode == 'Custom') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _allWeekdays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? curColor
                          : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9)),
                      border: Border.all(
                        color: isSelected
                            ? curColor
                            : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: curColor.withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        dayShortLetters[day] ?? day[0],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : primaryTextColor.withOpacity(0.75),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // End Date Row (Only relevant when repeat is active)
          if (_selectedDays.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(LucideIcons.calendar, size: 15, color: primaryTextColor.withOpacity(0.85)),
                const SizedBox(width: 7),
                Text(
                  'End Repeat',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final picked = await ModernDatePickerDialog.show(
                      context: context,
                      initialDate: _repeatUntil ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(DateTime.now().year + 5),
                      accentColor: curColor,
                      title: 'Select End Date',
                      subtitle: 'Repeat will end after this date',
                    );
                    if (picked != null) {
                      setState(() => _repeatUntil = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _repeatUntil != null
                              ? 'Ends ${months[_repeatUntil!.month - 1]} ${_repeatUntil!.day}'
                              : 'Never',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _repeatUntil != null ? primaryTextColor : secondaryTextColor,
                          ),
                        ),
                        if (_repeatUntil != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _repeatUntil = null),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(LucideIcons.x, size: 12, color: secondaryTextColor),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 4),
                          Icon(LucideIcons.chevronRight, size: 12, color: secondaryTextColor),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtasksSection(Color fieldColor, Color primaryTextColor, Color secondaryTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isSubtasksCollapsed = !_isSubtasksCollapsed;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isSubtasksCollapsed ? LucideIcons.chevronRight : LucideIcons.chevronDown,
                    size: 16,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'subtasks & checklist:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (_isSubtasksCollapsed) _isSubtasksCollapsed = false;
                    _subTaskControllers.add(TimeHighlightingTextEditingController());
                  });
                },
                icon: Icon(LucideIcons.plus, size: 14, color: primaryTextColor),
                label: Text(
                  'Add step',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_isSubtasksCollapsed) ...[
          const SizedBox(height: 8),
          if (_subTaskControllers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No subtasks created. Tap + Add step or speak to generate.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: secondaryTextColor.withOpacity(0.5),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _subTaskControllers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final curColor = Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF')));
                final textValue = _subTaskControllers[index].text;

                return Container(
                  decoration: BoxDecoration(
                    color: fieldColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showSubtaskEditSheet(index, primaryTextColor, secondaryTextColor, fieldColor),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                LucideIcons.checkCircle2,
                                size: 16,
                                color: curColor.withOpacity(0.85),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: textValue.isNotEmpty
                                  ? buildTimeHighlightedText(
                                      textValue,
                                      baseStyle: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: primaryTextColor,
                                        height: 1.35,
                                      ),
                                      highlightColor: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
                                    )
                                  : Text(
                                      'Action step ${index + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: secondaryTextColor.withOpacity(0.4),
                                        height: 1.35,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            // Delete Step Button
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _subTaskControllers[index].dispose();
                                  _subTaskControllers.removeAt(index);
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(LucideIcons.x, size: 16, color: secondaryTextColor.withOpacity(0.6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            ),
        ],
      ],
    );
  }

  void _showSubtaskEditSheet(int index, Color primaryTextColor, Color secondaryTextColor, Color fieldColor) {
    if (index >= _subTaskControllers.length) return;
    final curColor = Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF')));
    final editController = TimeHighlightingTextEditingController(text: _subTaskControllers[index].text);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2230) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: secondaryTextColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step ${index + 1} Details',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent.withOpacity(0.85)),
                          onPressed: () {
                            setState(() {
                              _subTaskControllers[index].dispose();
                              _subTaskControllers.removeAt(index);
                            });
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: TextField(
                        controller: editController,
                        autofocus: true,
                        maxLines: 6,
                        minLines: 3,
                        onChanged: (val) {
                          setSheetState(() {});
                        },
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryTextColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Describe this step in full detail...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: secondaryTextColor.withOpacity(0.4),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: secondaryTextColor.withOpacity(0.25)),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _subTaskControllers[index].text = editController.text.trim();
                              });
                              Navigator.of(sheetContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: curColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Save Step',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
      },
    );
  }

  void _showIconPickerModal(BuildContext context, bool isDark, Color primaryTextColor, Color secondaryTextColor, Color fieldColor) {
    String searchQuery = '';
    final curColor = Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF')));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchQuery.trim().toLowerCase();
            final filteredIcons = query.isEmpty
                ? _allIcons
                : _allIcons.where((iconKey) {
                    if (iconKey.toLowerCase().contains(query)) return true;
                    final keywords = _iconKeywords[iconKey] ?? [];
                    return keywords.any((k) => k.toLowerCase().contains(query));
                  }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    'Choose Task Icon',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.search, size: 16, color: secondaryTextColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setModalState(() {
                                searchQuery = val;
                              });
                            },
                            style: GoogleFonts.inter(fontSize: 14, color: primaryTextColor),
                            decoration: InputDecoration(
                              hintText: 'Search icon (e.g. gym, work, food...)',
                              hintStyle: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor.withOpacity(0.5)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setModalState(() {
                                searchQuery = '';
                              });
                            },
                            child: Icon(LucideIcons.x, size: 16, color: secondaryTextColor),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredIcons.isEmpty
                        ? Center(
                            child: Text(
                              'No matching icons found',
                              style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: filteredIcons.length,
                            itemBuilder: (context, index) {
                              final iconKey = filteredIcons[index];
                              final isSelected = _selectedIcon == iconKey;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedIcon = iconKey;
                                  });
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? curColor.withOpacity(0.18) : fieldColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? curColor : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _getIconData(iconKey),
                                        size: 24,
                                        color: isSelected ? curColor : primaryTextColor,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        iconKey,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? curColor : secondaryTextColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
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
      },
    );
  }

  void _showColorPickerModal(BuildContext context, bool isDark, Color primaryTextColor, Color secondaryTextColor, Color fieldColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.70,
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  'Choose Task Accent Color',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colorOptions.map((opt) {
                    final hex = opt['hex']!;
                    final optColor = Color(int.parse(hex.replaceAll('#', '0xFF')));
                    final isSelected = _selectedColorHex == hex;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColorHex = hex;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: optColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? primaryTextColor : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: optColor.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(LucideIcons.check, color: Colors.white, size: 22)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submit() {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      setState(() {
        _validationError = 'Say or type something to remember.';
      });
      return;
    }

    String title = _taskController.text.trim();
    if (title.isEmpty) {
      title = NlpParser.deriveTitleFromNote(notes);
    }
    if (title.isEmpty) {
      title = _isQuickNote ? 'Quick Note' : 'Daily Task';
    }

    final List<String> steps = [];
    for (var controller in _subTaskControllers) {
      final text = controller.text.trim();
      if (text.isNotEmpty && !steps.contains(text)) {
        steps.add(text);
      }
    }

    final List<String> parsedFromNotes = NlpParser.parseSubtasks(notes);
    for (var s in parsedFromNotes) {
      final cleanStep = s.trim();
      if (cleanStep.isNotEmpty && !steps.contains(cleanStep)) {
        steps.add(cleanStep);
      }
    }

    String? dueTimeStr;
    if (_selectedTime != null) {
      dueTimeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    } else {
      dueTimeStr = NlpParser.parseDeadline(notes);
    }

    String computedSegment = 'Morning';
    if (_selectedTime != null) {
      final hour = _selectedTime!.hour;
      if (hour >= 5 && hour < 12) {
        computedSegment = 'Morning';
      } else if (hour >= 12 && hour < 18) {
        computedSegment = 'Afternoon';
      } else {
        computedSegment = 'Night';
      }
    } else {
      final currentHour = DateTime.now().hour;
      if (currentHour >= 5 && currentHour < 12) {
        computedSegment = 'Morning';
      } else if (currentHour >= 12 && currentHour < 18) {
        computedSegment = 'Afternoon';
      } else {
        computedSegment = 'Night';
      }
    }

    final selectedMinVal = _minuteOptions[_durationMinutes.clamp(0, _minuteOptions.length - 1)];
    var totalDuration = (_durationHours * 60) + selectedMinVal;
    // If not open (0), check if still at default 10 min and try NLP parse
    if (_durationHours == 0 && totalDuration == 10) {
      final parsedDur = NlpParser.parseDuration(notes);
      if (parsedDur != null && parsedDur > 0) {
        totalDuration = parsedDur;
      }
    }
    // totalDuration == 0 means "Open" / unknown — keep as 0

    if (!_isQuickNote) {
      if (dueTimeStr == null || dueTimeStr.isEmpty) {
        setState(() {
          _validationError = '⚠️ Daily tasks must have a startTime! Please select a due time.';
        });
        return;
      }
    }

    Navigator.pop(context, {
      'title': title,
      'notes': _notesController.text.trim(),
      'type': _isQuickNote ? 'quick_note' : 'daily_task',
      'duration': totalDuration,
      'time': computedSegment,
      'steps': steps,
      'isUrgent': _isUrgent,
      'difficulty': _difficulty,
      'dueTime': dueTimeStr,
      'repeatDays': _selectedDays,
      'repeatUntil': _repeatUntil?.toIso8601String(),
      'colorHex': _selectedColorHex,
      'iconName': _selectedIcon,
    });
  }

  Future<void> _pickTime() async {
    final initialTime = _selectedTime ?? TimeOfDay.now();
    DateTime tempDateTime = DateTime(
      2020,
      1,
      1,
      initialTime.hour,
      initialTime.minute,
    );

    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBgColor = isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final fieldColor = isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6);
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);

    await showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Container(
          height: 280,
          color: sheetBgColor,
          child: Column(
            children: [
              Container(
                color: fieldColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: Text('Cancel', style: GoogleFonts.inter(color: Colors.redAccent)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoButton(
                      child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: primaryTextColor)),
                      onPressed: () {
                        setState(() {
                          _selectedTime = TimeOfDay(
                            hour: tempDateTime.hour,
                            minute: tempDateTime.minute,
                          );
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: isThemeDark ? Brightness.dark : Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: tempDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime newDateTime) {
                      tempDateTime = newDateTime;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(
    Color fieldColor,
    Color primaryTextColor,
    Color secondaryTextColor,
    bool isThemeDark,
    FixedExtentScrollController hoursController,
    FixedExtentScrollController minutesController,
  ) {
    final curColor = Color(int.parse(_selectedColorHex.replaceAll('#', '0xFF')));
    final selectedMin = _minuteOptions[_durationMinutes.clamp(0, _minuteOptions.length - 1)];

    return Container(
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isThemeDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Time you want to start
          Row(
            children: [
              Icon(LucideIcons.clock, size: 15, color: primaryTextColor.withOpacity(0.85)),
              const SizedBox(width: 7),
              Text(
                'Start Time',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isThemeDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isThemeDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.clock, size: 13, color: primaryTextColor.withOpacity(0.8)),
                      const SizedBox(width: 5),
                      _selectedTime != null
                          ? () {
                              final h = _selectedTime!.hour;
                              final m = _selectedTime!.minute.toString().padLeft(2, '0');
                              final period = h >= 12 ? 'PM' : 'AM';
                              final displayH = h % 12 == 0 ? 12 : h % 12;
                              return Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$displayH:$m ',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    TextSpan(
                                      text: period,
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor.withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }()
                          : Text(
                              'Set Time',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isThemeDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Row 2: Task duration
          Row(
            children: [
              Icon(LucideIcons.timer, size: 15, color: primaryTextColor.withOpacity(0.85)),
              const SizedBox(width: 7),
              Text(
                'Task duration',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isThemeDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isThemeDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_durationHours > 0 ? "${_durationHours}h " : ""}${selectedMin == 0 && _durationHours == 0 ? "Open" : "${selectedMin}m"}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(brightness: isThemeDark ? Brightness.dark : Brightness.light),
                    child: CupertinoPicker(
                      scrollController: hoursController,
                      itemExtent: 32,
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _durationHours = index;
                        });
                      },
                      children: List<Widget>.generate(24, (int index) {
                        return Center(
                          child: Text(
                            '$index hr',
                            style: GoogleFonts.inter(fontSize: 14, color: primaryTextColor, fontWeight: FontWeight.w600),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(brightness: isThemeDark ? Brightness.dark : Brightness.light),
                    child: CupertinoPicker(
                      scrollController: minutesController,
                      itemExtent: 32,
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _durationMinutes = index;
                        });
                      },
                       children: List<Widget>.generate(_minuteOptions.length, (int index) {
                        return Center(
                          child: Text(
                            _minuteOptions[index] == 0 ? '0 min  (open)' : '${_minuteOptions[index]} min',
                            style: GoogleFonts.inter(fontSize: 14, color: primaryTextColor, fontWeight: FontWeight.w600),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final sheetBgColor = isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
    final fieldColor = isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _isListening ? (isThemeDark ? const Color(0xFF020617) : const Color(0xFFE2E8F0)) : sheetBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.70,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primaryTextColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_validationError != null) ...[
                AnimatedOpacity(
                  opacity: _isListening ? 0.15 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _validationError!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_isQuickNote) ...[
                AnimatedOpacity(
                  opacity: _isListening ? 0.15 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    'create a quick note.',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildNoteEditor(
                  fieldColor: fieldColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  isDark: isThemeDark,
                  hint: 'List it down',
                ),
                const SizedBox(height: 20),
                _buildVoiceRow(fieldColor, primaryTextColor, secondaryTextColor, isThemeDark),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  opacity: _isListening ? 0.15 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: _isListening,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTextColor,
                            foregroundColor: sheetBgColor,
                            minimumSize: const Size(140, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            splashFactory: NoSplash.splashFactory,
                          ),
                          child: Text(
                            (widget.taskToEdit != null || widget.focusTaskToEdit != null) ? 'Save Note' : 'Save Quick Note',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                AnimatedOpacity(
                  opacity: _isListening ? 0.15 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    'Plan a Daily Focus Task',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildNoteEditor(
                  fieldColor: fieldColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  isDark: isThemeDark,
                  hint: 'List it down',
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                _buildVoiceRow(fieldColor, primaryTextColor, secondaryTextColor, isThemeDark),
                const SizedBox(height: 20),
                _buildSubtasksSection(fieldColor, primaryTextColor, secondaryTextColor),
                const SizedBox(height: 24),
                _buildScheduleCard(fieldColor, primaryTextColor, secondaryTextColor, isThemeDark, _focusHoursController, _focusMinutesController),
                const SizedBox(height: 18),
                _buildUnifiedRepeatCard(fieldColor, primaryTextColor, secondaryTextColor, isThemeDark),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTextColor,
                        foregroundColor: sheetBgColor,
                        minimumSize: const Size(140, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        splashFactory: NoSplash.splashFactory,
                      ),
                      child: Text(
                        (widget.taskToEdit != null || widget.focusTaskToEdit != null) ? 'Save Task' : 'Plan Focus Task',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
