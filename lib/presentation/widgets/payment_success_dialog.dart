import 'dart:math';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';

/// A beautiful animated payment success dialog with confetti-like particles
class PaymentSuccessDialog extends StatefulWidget {
  final double amount;
  final VoidCallback? onDone;

  const PaymentSuccessDialog({super.key, required this.amount, this.onDone});

  /// Show the payment success dialog
  static Future<void> show(
    BuildContext context, {
    required double amount,
    VoidCallback? onDone,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PaymentSuccessDialog(amount: amount, onDone: onDone);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  @override
  State<PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<PaymentSuccessDialog>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _particleController;
  late final AnimationController _pulseController;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _pulseAnimation;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    // Check mark draw animation
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutCirc,
    );

    // Particle burst animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Pulse glow animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Generate particles
    final rng = Random();
    _particles = List.generate(20, (_) => _Particle(rng));

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _checkController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _particleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: ColorManager.success.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated check mark with particles
                SizedBox(
                  height: 120,
                  width: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Particles
                      AnimatedBuilder(
                        animation: _particleController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(120, 120),
                            painter: _ParticlePainter(
                              particles: _particles,
                              progress: _particleController.value,
                            ),
                          );
                        },
                      ),
                      // Pulse glow circle
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    ColorManager.success.withValues(
                                      alpha: 0.15,
                                    ),
                                    ColorManager.success.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Check circle
                      AnimatedBuilder(
                        animation: _checkAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(72, 72),
                            painter: _CheckMarkPainter(
                              progress: _checkAnimation.value,
                              color: ColorManager.success,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Amount
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ColorManager.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ColorManager.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '\$${widget.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ColorManager.success,
                      letterSpacing: -1,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'has been added to your wallet',
                  style: TextStyle(
                    fontSize: 15,
                    color: ColorManager.textSecondary,
                  ),
                ),

                const SizedBox(height: 8),

                // Note about processing time
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColorManager.info.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: ColorManager.info,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your balance will update within a few moments.',
                          style: TextStyle(
                            fontSize: 13,
                            color: ColorManager.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Done button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDone?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the animated check mark
class _CheckMarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckMarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circle background
    final circlePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final circleProgress = (progress * 2).clamp(0.0, 1.0);
    canvas.drawCircle(center, radius * circleProgress, circlePaint);

    // Draw check mark
    if (progress > 0.5) {
      final checkProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);
      final checkPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

      final path = Path();
      // Check mark points (relative to center)
      final p1 = Offset(center.dx - radius * 0.3, center.dy);
      final p2 = Offset(center.dx - radius * 0.05, center.dy + radius * 0.25);
      final p3 = Offset(center.dx + radius * 0.3, center.dy - radius * 0.25);

      // First leg of check
      final firstLegProgress = (checkProgress * 2).clamp(0.0, 1.0);
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * firstLegProgress,
        p1.dy + (p2.dy - p1.dy) * firstLegProgress,
      );

      // Second leg of check
      if (checkProgress > 0.5) {
        final secondLegProgress = ((checkProgress - 0.5) * 2).clamp(0.0, 1.0);
        path.lineTo(
          p2.dx + (p3.dx - p2.dx) * secondLegProgress,
          p2.dy + (p3.dy - p2.dy) * secondLegProgress,
        );
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckMarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// A single confetti particle
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;

  static const _colors = [
    Color(0xFF27AE60), // Green
    Color(0xFF2ECC71), // Light Green
    Color(0xFFF78A30), // Orange (brand)
    Color(0xFF3498DB), // Blue
    Color(0xFFF39C12), // Yellow
    Color(0xFF9B59B6), // Purple
    Color(0xFFE74C3C), // Red
    Color(0xFF1ABC9C), // Teal
  ];

  _Particle(Random rng)
    : angle = rng.nextDouble() * 2 * pi,
      speed = 40 + rng.nextDouble() * 60,
      size = 3 + rng.nextDouble() * 5,
      color = _colors[rng.nextInt(_colors.length)],
      rotationSpeed = rng.nextDouble() * 4 - 2;
}

/// Painter for the particle burst
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final distance = p.speed * progress;
      final x = center.dx + cos(p.angle) * distance;
      final y = center.dy + sin(p.angle) * distance;

      final paint =
          Paint()
            ..color = p.color.withValues(alpha: opacity)
            ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * progress * pi);

      // Draw a small rounded rect (like a confetti piece)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(1),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
