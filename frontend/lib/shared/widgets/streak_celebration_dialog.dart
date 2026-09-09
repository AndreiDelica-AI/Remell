import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StreakCelebrationDialog extends StatefulWidget {
  final int streakDays;
  final List<String> completionHistory;
  final VoidCallback onDismiss;

  const StreakCelebrationDialog({
    super.key,
    required this.streakDays,
    required this.completionHistory,
    required this.onDismiss,
  });

  @override
  State<StreakCelebrationDialog> createState() => _StreakCelebrationDialogState();
}

class _StreakCelebrationDialogState extends State<StreakCelebrationDialog> with TickerProviderStateMixin {
  late AnimationController _flameController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  late AnimationController _confettiController;
  final List<ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    // Flame entry scale animation
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _flameController,
      curve: Curves.elasticOut,
    );
    _rotationAnimation = Tween<double>(begin: -0.10, end: 0.0).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.elasticOut),
    );
    _flameController.forward();

    // Confetti particles generator
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        setState(() {
          for (var p in _particles) {
            p.update();
          }
          _particles.removeWhere((p) => p.y > 600 || p.alpha <= 0.0);
        });
      });
    _confettiController.repeat();

    _spawnConfetti();
  }

  void _spawnConfetti() {
    final random = math.Random();
    // Spawn 100 particles initially
    for (int i = 0; i < 80; i++) {
      _particles.add(
        ConfettiParticle(
          x: 140.0 + random.nextDouble() * 80.0, // center it
          y: 180.0 + random.nextDouble() * 40.0,
          vx: (random.nextDouble() - 0.5) * 14.0,
          vy: -6.0 - random.nextDouble() * 10.0,
          color: HSLColor.fromAHSL(
            1.0,
            random.nextDouble() * 360.0,
            0.85,
            0.65,
          ).toColor(),
          size: 6.0 + random.nextDouble() * 8.0,
          gravity: 0.28,
        ),
      );
    }
  }

  @override
  void dispose() {
    _flameController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    // Prepare 7 days calendar row ending with today
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (idx) => now.subtract(Duration(days: 6 - idx)));

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Confetti painter
          CustomPaint(
            painter: ConfettiPainter(particles: _particles),
            size: const Size(400, 600),
          ),

          // Main Dialog Card
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dialogBg.withOpacity(0.95),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Scaled Animating Flame Icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Back fire light glow
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5722).withOpacity(0.3),
                                blurRadius: 35,
                                spreadRadius: 8,
                              )
                            ],
                          ),
                        ),
                        // Animated Realistic Fire Flame
                        AnimatedFireFlameWidget(
                          width: 130,
                          height: 150,
                          streakDays: widget.streakDays,
                        ),
                        // Flame number text
                        Positioned(
                          bottom: 18,
                          child: Text(
                            '${widget.streakDays}',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Streak Title
                Text(
                  '${widget.streakDays} day streak!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtext
                Text(
                  'Amazing work! Come back tomorrow to keep your streak alive.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // 7 Days Connected Timeline Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Connected line behind
                          Positioned(
                            left: 18,
                            right: 18,
                            child: Container(
                              height: 3,
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          // Row of nodes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: last7Days.map((date) {
                              final String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                              final bool hasCompleted = widget.completionHistory.contains(dateStr);
                              final String weekdayName = _getWeekdayLabel(date.weekday);

                              return Column(
                                children: [
                                  Text(
                                    weekdayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: hasCompleted
                                          ? const Color(0xFFFF5722)
                                          : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: hasCompleted ? const Color(0xFFFF5722) : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                      border: Border.all(
                                        color: hasCompleted
                                            ? const Color(0xFFFF7A45)
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                        width: 2.0,
                                      ),
                                      boxShadow: hasCompleted
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFFF5722).withOpacity(0.4),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: hasCompleted
                                        ? const Center(
                                            child: Icon(Icons.check, size: 12, color: Colors.white),
                                          )
                                        : null,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Button to continue
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDismiss();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: const Color(0xFFFF5722).withOpacity(0.4),
                  ),
                  child: Text(
                    'Awesome!',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

  String _getWeekdayLabel(int weekday) {
    switch (weekday) {
      case 1: return 'MON';
      case 2: return 'TUE';
      case 3: return 'WED';
      case 4: return 'THU';
      case 5: return 'FRI';
      case 6: return 'SAT';
      case 7: return 'SUN';
      default: return '';
    }
  }
}

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double gravity;
  double alpha = 1.0;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.gravity,
  });

  void update() {
    x += vx;
    y += vy;
    vy += gravity;
    vx *= 0.98;
    alpha -= 0.015;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      if (p.alpha <= 0.0) continue;
      final paint = Paint()..color = p.color.withOpacity(p.alpha);
      canvas.drawRect(
        Rect.fromLTWH(p.x, p.y, p.size, p.size * 0.6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}

class AnimatedFireFlameWidget extends StatefulWidget {
  final double width;
  final double height;
  final int streakDays;

  const AnimatedFireFlameWidget({
    super.key,
    this.width = 130,
    this.height = 150,
    required this.streakDays,
  });

  @override
  State<AnimatedFireFlameWidget> createState() => _AnimatedFireFlameWidgetState();
}

class _AnimatedFireFlameWidgetState extends State<AnimatedFireFlameWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: RealisticFireFlamePainter(animValue: _controller.value),
        );
      },
    );
  }
}

class RealisticFireFlamePainter extends CustomPainter {
  final double animValue;

  RealisticFireFlamePainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = animValue * 2 * math.pi;

    // 1. Outer Flame Aura / Glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFF4500).withOpacity(0.35 + 0.1 * math.sin(phase))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(w * 0.5, h * 0.6), w * 0.45, glowPaint);

    // 2. Outer Flame Body (Crimson -> Deep Amber)
    final outerPath = Path();
    final outerTipX = w * 0.5 + math.sin(phase) * 6;
    final outerTipY = h * 0.05 + math.cos(phase * 1.5) * 4;

    outerPath.moveTo(outerTipX, outerTipY);
    outerPath.quadraticBezierTo(
      w * 0.88 + math.sin(phase * 2) * 5,
      h * 0.45,
      w * 0.85,
      h * 0.72,
    );
    outerPath.cubicTo(
      w * 0.85,
      h * 0.98,
      w * 0.15,
      h * 0.98,
      w * 0.15,
      h * 0.72,
    );
    outerPath.quadraticBezierTo(
      w * 0.12 - math.cos(phase * 2) * 5,
      h * 0.45,
      outerTipX,
      outerTipY,
    );
    outerPath.close();

    final outerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, outerTipY),
        Offset(w * 0.5, h),
        [
          const Color(0xFFFF5722),
          const Color(0xFFFF1744),
          const Color(0xFFD50000),
        ],
      );
    canvas.drawPath(outerPath, outerPaint);

    // 3. Middle Flame Body (Vibrant Orange -> Warm Gold)
    final midPath = Path();
    final midTipX = w * 0.5 - math.sin(phase * 1.3) * 5;
    final midTipY = h * 0.22 + math.sin(phase * 2) * 4;

    midPath.moveTo(midTipX, midTipY);
    midPath.quadraticBezierTo(
      w * 0.78 + math.cos(phase * 1.5) * 4,
      h * 0.5,
      w * 0.75,
      h * 0.74,
    );
    midPath.cubicTo(
      w * 0.75,
      h * 0.93,
      w * 0.25,
      h * 0.93,
      w * 0.25,
      h * 0.74,
    );
    midPath.quadraticBezierTo(
      w * 0.22 + math.sin(phase * 1.5) * 4,
      h * 0.5,
      midTipX,
      midTipY,
    );
    midPath.close();

    final midPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, midTipY),
        Offset(w * 0.5, h * 0.9),
        [
          const Color(0xFFFFC107),
          const Color(0xFFFF9800),
          const Color(0xFFFF5722),
        ],
      );
    canvas.drawPath(midPath, midPaint);

    // 4. Inner Hot Flame Core (Bright Yellow -> White Hot Glow)
    final innerPath = Path();
    final innerTipX = w * 0.5 + math.cos(phase * 2) * 3;
    final innerTipY = h * 0.38 + math.sin(phase * 3) * 3;

    innerPath.moveTo(innerTipX, innerTipY);
    innerPath.quadraticBezierTo(
      w * 0.66,
      h * 0.58,
      w * 0.64,
      h * 0.78,
    );
    innerPath.cubicTo(
      w * 0.64,
      h * 0.90,
      w * 0.36,
      h * 0.90,
      w * 0.36,
      h * 0.78,
    );
    innerPath.quadraticBezierTo(
      w * 0.34,
      h * 0.58,
      innerTipX,
      innerTipY,
    );
    innerPath.close();

    final innerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, innerTipY),
        Offset(w * 0.5, h * 0.85),
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFFFEB3B),
          const Color(0xFFFFC107),
        ],
      );
    canvas.drawPath(innerPath, innerPaint);

    // 5. Rising Fire Ember Particles
    final emberPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final baseProgress = (animValue + i / 8.0) % 1.0;
      final emberY = h * (0.85 - baseProgress * 0.75);
      final emberX = w * 0.5 + math.sin(baseProgress * math.pi * 4 + i) * (12.0 + i * 2.0);
      final emberRadius = (1.5 + (1.0 - baseProgress) * 2.5);
      final alpha = ((1.0 - baseProgress) * 0.9).clamp(0.0, 1.0);

      emberPaint.color = (i % 2 == 0 ? const Color(0xFFFFEB3B) : const Color(0xFFFF5722)).withOpacity(alpha);
      canvas.drawCircle(Offset(emberX, emberY), emberRadius, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RealisticFireFlamePainter oldDelegate) {
    return oldDelegate.animValue != animValue;
  }
}
