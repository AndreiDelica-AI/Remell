import 'package:flutter/material.dart';
import 'dart:math' as math;

class TimeOfDayBackground extends StatefulWidget {
  final Widget child;

  const TimeOfDayBackground({super.key, required this.child});

  @override
  State<TimeOfDayBackground> createState() => _TimeOfDayBackgroundState();
}

class _TimeOfDayBackgroundState extends State<TimeOfDayBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_StarParticle> _stars = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    // Animation controller for star pulsing & slow movement
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Night stars (minimalistic background particles)
    for (int i = 0; i < 20; i++) {
      _stars.add(_StarParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2.0 + 1.0,
        speed: _random.nextDouble() * 0.01 + 0.003,
        opacity: _random.nextDouble() * 0.35 + 0.15,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final now = DateTime.now();
        final double timeAsDouble = now.hour + now.minute / 60.0;

        final isNight = timeAsDouble < 5.0 || timeAsDouble >= 18.0;

        return Stack(
          children: [
            // Solid Base Background (Bringing back the original clean background)
            Positioned.fill(
              child: Container(
                color: backgroundColor,
              ),
            ),

            // Serene Nature Landscape Background Image
            Positioned.fill(
              child: Opacity(
                opacity: isThemeDark ? 0.35 : 0.08,
                child: Image.asset(
                  'assets/images/nature_bg.png',
                  fit: BoxFit.cover,
                  color: isThemeDark ? const Color(0xFF0F172A).withOpacity(0.85) : null,
                  colorBlendMode: isThemeDark ? BlendMode.darken : null,
                ),
              ),
            ),




            // Night Twilight / Midnight Deepening Overlay (Deep navy to charcoal, active 6PM - 5AM)
            if (timeAsDouble >= 18.0 || timeAsDouble < 5.0)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0B1329).withOpacity(isThemeDark ? 0.35 : 0.02),
                        const Color(0xFF020617).withOpacity(isThemeDark ? 0.65 : 0.04),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),

            // Drifting Glowing Dust for Night Mode (only active in dark theme)
            if (isNight && isThemeDark)
              Positioned.fill(
                child: CustomPaint(
                  painter: _SpaceDustPainter(
                    stars: _stars,
                    animationValue: _controller.value,
                  ),
                ),
              ),

            // Render child content over background
            Positioned.fill(child: widget.child),
          ],
        );
      },
    );
  }
}

class _StarParticle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  _StarParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });

  void update() {
    // Drifts slowly upwards and slightly leftwards
    y -= speed * 0.005;
    x -= speed * 0.002;
    if (y < 0) y = 1.0;
    if (x < 0) x = 1.0;
  }
}

class _SpaceDustPainter extends CustomPainter {
  final List<_StarParticle> stars;
  final double animationValue;

  _SpaceDustPainter({required this.stars, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint starPaint = Paint()..style = PaintingStyle.fill;

    for (var star in stars) {
      star.update();

      // Compute pixel coordinates
      final double px = star.x * size.width;
      final double py = star.y * size.height;

      // Pulse the opacity slightly
      final double pulse = 0.7 + 0.3 * math.sin(animationValue * 2 * math.pi + star.size);
      starPaint.color = Colors.white.withOpacity((star.opacity * pulse).clamp(0.0, 1.0));

      // Draw glowing space dust
      canvas.drawCircle(Offset(px, py), star.size, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpaceDustPainter oldDelegate) => true;
}


