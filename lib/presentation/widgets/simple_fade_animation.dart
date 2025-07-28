import 'package:flutter/material.dart';

class SimpleFadeAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const SimpleFadeAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
  });

  @override
  State<SimpleFadeAnimation> createState() => _SimpleFadeAnimationState();
}

class _SimpleFadeAnimationState extends State<SimpleFadeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
