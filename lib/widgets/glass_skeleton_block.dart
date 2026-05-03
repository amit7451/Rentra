import 'dart:ui';
import 'package:flutter/material.dart';

class GlassSkeletonBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const GlassSkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16.0,
  });

  @override
  State<GlassSkeletonBlock> createState() => _GlassSkeletonBlockState();
}

class _GlassSkeletonBlockState extends State<GlassSkeletonBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _anim = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = _anim.value;

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                /// 🌫️ glass blur base
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(),
                ),

                /// 🧊 glass surface
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(
                                0xFF224E58,
                              ).withValues(alpha: 0.75 * opacity),
                              const Color(
                                0xFF14363F,
                              ).withValues(alpha: 0.75 * opacity),
                            ]
                          : [
                              const Color(0xFF14B8A6).withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.4 * opacity),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25 * opacity)
                          : Colors.white.withValues(alpha: 0.6 * opacity),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
