import '../../../shared/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;
import '../../../shared/providers/energy_provider.dart';
import '../../../shared/services/notification_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Answers State
  final Map<int, dynamic> _answers = {};
  final int _totalSteps = 5;
  bool _testNotificationSent = false;
  bool _permissionEnabled = false;

  @override
  void initState() {
    super.initState();
    // Default selections
    _answers[0] = 'It takes me a while to get started';
    _answers[1] = 'I open my phone and start doom-scrolling';
  }

  void _saveSetting(String key, String value) {
    if (!kIsWeb) return;
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  Future<void> _nextPage() async {
    if (_currentStep == 3 && !_permissionEnabled) {
      try {
        final granted = await NotificationService.requestPermissions();
        setState(() => _permissionEnabled = true);
      } catch (_) {
        setState(() => _permissionEnabled = true);
      }
    }

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Finalize and Save
      final user = ref.read(authUserProvider);
      final userEmail = user?['email'] ?? user?['id'] ?? 'guest';
      if (kIsWeb) {
        try {
          html.window.localStorage['remell_onboarding_completed_$userEmail'] = 'true';
        } catch (_) {}
      }

      if (user != null) {
        final updatedUser = Map<String, dynamic>.from(user);
        updatedUser['isNewUser'] = false;
        if (updatedUser['preferences'] is Map) {
          updatedUser['preferences']['hasCompletedOnboarding'] = true;
        } else {
          updatedUser['preferences'] = {'hasCompletedOnboarding': true};
        }
        ref.read(authUserProvider.notifier).state = updatedUser;
        saveAuthSession(ref.read(authTokenProvider), updatedUser);
      }

      if (mounted) context.go('/home');
    }
  }

  void _triggerTestNotification() {
    setState(() => _testNotificationSent = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.bellRing, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remell Safety Net Alert',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Text(
                    'Time to return to your tasks! (Test Notification)',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEA580C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getCtaButtonText() {
    switch (_currentStep) {
      case 0:
      case 1:
      case 2:
        return 'Continue';
      case 3:
        return _permissionEnabled ? 'Continue' : 'Enable Notifications & Continue';
      case 4:
        return "It works! Let's start";
      default:
        return 'Continue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA);
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final orangeCtaColor = const Color(0xFFEA580C);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: primaryTextColor),
                onPressed: _prevPage,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              )
            : null,
        title: Text(
          'Personalize (${_currentStep + 1}/$_totalSteps)',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primaryTextColor.withOpacity(0.5),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  backgroundColor: isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(orangeCtaColor),
                  minHeight: 3,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentStep = page;
                  });
                },
                children: [
                  _buildScreen1(),
                  _buildScreen2(),
                  _buildScreen3(),
                  _buildScreen4(),
                  _buildScreen5(),
                ],
              ),
            ),

            // Prominent Dark Orange Bottom CTA with Arrow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: orangeCtaColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  splashFactory: NoSplash.splashFactory,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getCtaButtonText(),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowRight, size: 20, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContainer({required String title, String? subtitle, required Widget child}) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: primaryTextColor,
              height: 1.25,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  // Card Option Widget with Yellow/Amber Active State
  Widget _buildAmberOptionCard({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);

    final cardBg = isSelected
        ? (isThemeDark ? const Color(0xFF78350F).withOpacity(0.4) : const Color(0xFFFEF3C7))
        : (isThemeDark ? const Color(0xFF1E293B) : Colors.white);

    final borderColor = isSelected
        ? const Color(0xFFF59E0B)
        : (isThemeDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: primaryTextColor,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFFF59E0B) : (isThemeDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  // Screen 1: The Initial Reality Check (Establishing Empathy)
  Widget _buildScreen1() {
    final options = [
      "I'm usually on top of my tasks",
      'It takes me a while to get started',
      'My mind is a constant blur of clutter',
    ];

    return _buildStepContainer(
      title: 'First, how well do days usually go for you?',
      subtitle: 'Select the option that best describes your daily flow.',
      child: Column(
        children: options.map((opt) {
          final isSelected = _answers[0] == opt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: _buildAmberOptionCard(
              text: opt,
              isSelected: isSelected,
              onTap: () => setState(() => _answers[0] = opt),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Screen 2: Diagnosing the Root Cause (Doom-Scrolling & Friction)
  Widget _buildScreen2() {
    final options = [
      'I open my phone and start doom-scrolling',
      'I write notes down and completely forget where they are',
      'I get overwhelmed by a cluttered mind and give up',
    ];

    return _buildStepContainer(
      title: 'What usually keeps you from finishing your tasks?',
      subtitle: 'Identify your main distraction trigger so we can build your safety net.',
      child: Column(
        children: options.map((opt) {
          final isSelected = _answers[1] == opt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: _buildAmberOptionCard(
              text: opt,
              isSelected: isSelected,
              onTap: () => setState(() => _answers[1] = opt),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Screen 3: The Educational Pivot (Biology over Laziness)
  Widget _buildScreen3() {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563);

    return _buildStepContainer(
      title: "It’s biology, not laziness.",
      subtitle: 'Your digital feeds move faster than your focus does.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: isThemeDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isThemeDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.shieldCheck, color: Color(0xFFF59E0B), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Remell Core Philosophy',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "When you open your phone for a quick break, a 5-minute distraction turns into an hour of scrolling. Your tasks get buried under mental clutter. You can't out-scroll your memory, but you can out-system it. That's where Remell comes in.",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Screen 4: Notification Permission & Setup
  Widget _buildScreen4() {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563);

    return _buildStepContainer(
      title: 'Never miss a task again.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Remell works by sending persistent alerts so your notes don't get buried under mental clutter. Let's make sure notifications are turned on.",
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 24),

          // Permission Prompt Container
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isThemeDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _permissionEnabled ? const Color(0xFF10B981) : (isThemeDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                width: _permissionEnabled ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _permissionEnabled ? LucideIcons.checkCircle2 : LucideIcons.bell,
                      color: _permissionEnabled ? const Color(0xFF10B981) : const Color(0xFFEA580C),
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _permissionEnabled ? 'Notifications Enabled' : 'Notification Safety Net',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _permissionEnabled ? 'Your persistent reminders are active.' : 'Allows Remell to surface urgent notes.',
                            style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Secondary Action Button: Test a notification now
                OutlinedButton.icon(
                  onPressed: _triggerTestNotification,
                  icon: const Icon(LucideIcons.bellRing, size: 16, color: Color(0xFFEA580C)),
                  label: Text(
                    'Test a notification now',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFEA580C)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEA580C)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Screen 5: Notification Tester & Live Proof
  Widget _buildScreen5() {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563);

    return _buildStepContainer(
      title: "Let's test your safety net.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap the button below to send a live test notification. This is how Remell will cut through the noise when you get distracted.',
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 28),

          // Interactive Prominent Card
          GestureDetector(
            onTap: _triggerTestNotification,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: _testNotificationSent
                    ? (isThemeDark ? const Color(0xFF065F46).withOpacity(0.3) : const Color(0xFFD1FAE5))
                    : (isThemeDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _testNotificationSent ? const Color(0xFF10B981) : const Color(0xFFEA580C),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _testNotificationSent ? LucideIcons.checkCircle2 : LucideIcons.sparkles,
                    size: 36,
                    color: _testNotificationSent ? const Color(0xFF10B981) : const Color(0xFFEA580C),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _testNotificationSent ? 'Test Notification Sent!' : 'Send Test Notification',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _testNotificationSent
                        ? 'Check your alert banner above!'
                        : 'Tap here to trigger a live Remell alert',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
