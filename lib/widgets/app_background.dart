import 'dart:math';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      // Light mode: soft warm-white gradient so transparent scaffolds look great
      return Material(
        color: const Color(0xFFF0FAF9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE6F7F6), // soft teal tint at top
                    Color(0xFFF5FFFE), // near-white mid
                    Color(0xFFFFFFFF), // pure white bottom
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Subtle teal bloom at top
            Positioned(
              top: -60,
              left: size.width * 0.5 - 160,
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x2014B8A6),
                      Color(0x0814B8A6),
                      Color(0x0014B8A6),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      );
    }

    return Material(
      color: const Color(0xFF0A2530), // Base darkest teal
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Base deep teal gradient ─────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A2530), // darkest top
                  Color(0xFF0D2B36), // mid
                  Color(0xFF0F2E38), // lower mid
                  Color(0xFF0C2B35), // bottom
                ],
                stops: [0.0, 0.40, 0.70, 1.0],
              ),
            ),
          ),

          // ── 2. PREMIUM GLOW — hero center bloom ────────────────────
          //    The large teal orb glow behind where your 3D asset sits
          Positioned(
            top: size.height * 0.07,
            left: size.width * 0.5 - 180,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x3018A89A), // bright teal core
                    Color(0x18108070), // mid falloff
                    Color(0x00000000), // transparent edge
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // ── 3. PREMIUM GLOW — upper ambient wash ──────────────────
          //    Soft top-down light that gives the screen depth
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * 0.55,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x1520A090), // teal shimmer at very top
                    Color(0x0810706A),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // ── 4. PREMIUM GLOW — bottom card halo ────────────────────
          //    The glowing edge along the top of the bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * 0.50,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x0A1A9080), // faint teal bleed
                    Color(0x151E3540), // card base tint
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── 5. PREMIUM GLOW — left edge accent ────────────────────
          Positioned(
            top: size.height * 0.15,
            left: -40,
            child: Container(
              width: 180,
              height: 300,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x150E8070), Color(0x00000000)],
                ),
              ),
            ),
          ),

          // ── 6. Decorative arc rings — top right ───────────────────
          const Positioned(
            top: -80,
            right: -80,
            child: _ArcRing(size: 380, color: Color(0xFF1E5560), stroke: 1.0),
          ),
          const Positioned(
            top: -10,
            right: -15,
            child: _ArcRing(size: 255, color: Color(0xFF1B4D5A), stroke: 0.7),
          ),
          const Positioned(
            top: 55,
            right: 40,
            child: _ArcRing(size: 160, color: Color(0xFF184858), stroke: 0.5),
          ),

          // ── 7. Decorative arc rings — bottom left ─────────────────
          const Positioned(
            bottom: -90,
            left: -70,
            child: _ArcRing(size: 340, color: Color(0xFF1B4D5A), stroke: 0.5),
          ),
          const Positioned(
            bottom: -20,
            left: -15,
            child: _ArcRing(size: 195, color: Color(0xFF184858), stroke: 0.3),
          ),

          // ── 8. Your screen content ─────────────────────────────────
          child,
        ],
      ),
    );
  }
}

// ── Arc ring widget ───────────────────────────────────────────────────
class _ArcRing extends StatelessWidget {
  final double size;
  final Color color;
  final double stroke;
  const _ArcRing({
    required this.size,
    required this.color,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ArcPainter(color: color, strokeWidth: stroke),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const _ArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -pi / 2,
      pi * 1.55,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
