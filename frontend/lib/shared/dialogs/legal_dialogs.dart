import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LegalModalDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget content;

  const LegalModalDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
  });

  static void showTerms(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => LegalModalDialog(
        title: 'Terms of Service',
        subtitle: 'Last updated: September 2026',
        icon: LucideIcons.fileText,
        content: const _TermsOfServiceContent(),
      ),
    );
  }

  static void showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => LegalModalDialog(
        title: 'Privacy Policy',
        subtitle: 'GDPR, CCPA & DPA 10173 Compliant',
        icon: LucideIcons.shieldCheck,
        content: const _PrivacyPolicyContent(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A26) : Colors.white;
    final primaryText = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.6 : 0.16),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Column(
                children: [
                  // Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Center(
                            child: Icon(icon, color: primaryText, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: primaryText,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(LucideIcons.x, size: 16, color: secondaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: borderColor),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      physics: const BouncingScrollPhysics(),
                      child: content,
                    ),
                  ),

                  Divider(height: 1, color: borderColor),
                  // Footer Close Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          'I Understand & Accept',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsOfServiceContent extends StatelessWidget {
  const _TermsOfServiceContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('1. Acceptance of Terms', primaryText),
        _buildParagraph(
          'By accessing or using Remell ("the Service"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the application.',
          secondaryText,
        ),
        _buildSectionHeader('2. "As-Is" Warranty & Notification Disclaimer', primaryText),
        _buildParagraph(
          'THE SERVICE IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS. REMELL DOES NOT GUARANTEE UNINTERRUPTED OR ERROR-FREE OPERATION. TIMERS, ALERTS, AND NOTIFICATIONS MAY BE SUBJECT TO MOBILE OS BATTERY POLICIES, BROWSER SUSPENSION, OR NETWORK DISRUPTIONS. REMELL DISCLAIMS ALL LIABILITY FOR MISSED DEADLINES, SCHEDULING DELAYS, OR PRODUCTIVITY LOSSES.',
          secondaryText,
          isBold: true,
        ),
        _buildSectionHeader('3. Productivity & Non-Medical Advice Disclaimer', primaryText),
        _buildParagraph(
          'Remell is a self-management and focus organization tool. It is NOT a medical, psychiatric, or therapeutic service. Nothing in Remell constitutes professional medical diagnosis or clinical treatment for ADHD, sleep disorders, or mental health conditions.',
          secondaryText,
        ),
        _buildSectionHeader('4. User Responsibilities & Conduct', primaryText),
        _buildParagraph(
          'You are solely responsible for maintaining the security of your account and device. You agree not to reverse-engineer, exploit, or inject malicious scripts into the service.',
          secondaryText,
        ),
        _buildSectionHeader('5. Limitation of Liability', primaryText),
        _buildParagraph(
          'TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT SHALL REMELL OR ITS CREATORS BE LIABLE FOR ANY CONSEQUENTIAL, INCIDENTAL, INDIRECT, OR SPECIAL DAMAGES. TOTAL LIABILITY SHALL NOT EXCEED THE TOTAL AMOUNT PAID BY YOU IN THE PRECEDING 12 MONTHS OR \$50.00 USD.',
          secondaryText,
          isBold: true,
        ),
        _buildSectionHeader('6. Governing Law & Dispute Resolution', primaryText),
        _buildParagraph(
          'These Terms shall be governed by and construed in accordance with applicable laws. Any claims shall be resolved through individual binding arbitration rather than class action litigation.',
          secondaryText,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }
}

class _PrivacyPolicyContent extends StatelessWidget {
  const _PrivacyPolicyContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('1. Information We Collect', primaryText),
        _buildParagraph(
          'We collect information you directly provide: task titles, notes, focus preferences, and email address (if using authenticated sync). We do NOT sell your data to third-party advertisers.',
          secondaryText,
        ),
        _buildSectionHeader('2. Data Storage & Local Caching', primaryText),
        _buildParagraph(
          'Remell uses browser LocalStorage and secure cloud synchronization to maintain offline capability. Local data remains on your device until cleared or synchronized.',
          secondaryText,
        ),
        _buildSectionHeader('3. GDPR, CCPA & DPA 10173 Compliance', primaryText),
        _buildParagraph(
          'Under international data protection laws (GDPR, CCPA, and the Philippine Data Privacy Act of 2012 / RA 10173), you have the right to:\n'
          '• Access and export your personal data at any time ("Data Portability").\n'
          '• Request immediate and permanent deletion of your account and task history ("Right to Erasure").\n'
          '• Restrict or opt out of non-essential analytics tracking.',
          secondaryText,
        ),
        _buildSectionHeader('4. Data Retention & Erasure', primaryText),
        _buildParagraph(
          'When an account deletion is initiated, data is permanently erased from active databases and fully purged from backup archives within 30 days.',
          secondaryText,
        ),
        _buildSectionHeader('5. Contact Data Protection Officer', primaryText),
        _buildParagraph(
          'For privacy requests, inquiries, or data protection concerns, contact our team at privacy@remell.app.',
          secondaryText,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }
}
