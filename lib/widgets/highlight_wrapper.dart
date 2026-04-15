import 'package:flutter/material.dart';

class HighlightWrapper extends StatefulWidget {
  final Widget child;
  final bool shouldHighlight;
  final double borderRadius;

  const HighlightWrapper({
    super.key,
    required this.child,
    required this.shouldHighlight,
    this.borderRadius = 18.0,
  });

  @override
  State<HighlightWrapper> createState() => _HighlightWrapperState();
}

class _HighlightWrapperState extends State<HighlightWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _colorAnimation =
        ColorTween(
          begin: Colors.transparent,
          end: Colors.grey.withOpacity(0.4),
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
          ),
        );

    if (widget.shouldHighlight) {
      _startAnimation();
    }
  }

  Future<void> _startAnimation() async {
    // Scroll into view if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.5, // Center it
        );
      }
    });

    await _controller.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    await _controller.reverse();
  }

  @override
  void didUpdateWidget(HighlightWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldHighlight && !oldWidget.shouldHighlight) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          foregroundDecoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}


