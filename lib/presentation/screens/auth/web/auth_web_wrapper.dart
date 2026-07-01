import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_palette.dart';

class AuthWebWrapper extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final double maxWidth;
  final bool fullScreen;
  final bool wrapInCard; // NEW: Allows custom screens to bypass the standard white box

  const AuthWebWrapper({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.maxWidth = 480,
    this.fullScreen = false,
    this.wrapInCard = true, // Defaults to true for standard forms
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthWebPalette.bgBase,
      body: Stack(
        children: [
        
        //the background image
          Positioned.fill(
            child: Image.asset(
              ImageAssets.authBackground,
              fit: BoxFit.cover,
            ),
          ),
          // 4. The Foreground Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: wrapInCard ? _buildStandardCard() : child, // Bypasses the standard card if false
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the standard narrow white box for Login/Register forms
  Widget _buildStandardCard() {
    return Container(
      width: fullScreen ? double.infinity : maxWidth,
      decoration: BoxDecoration(
        color: AuthWebPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AuthWebPalette.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AuthWebPalette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AuthWebPalette.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(ImageAssets.appIcon, fit: BoxFit.cover),
              ),
            ),
          ),
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AuthWebPalette.textPrimary,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 15,
                color: AuthWebPalette.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (title != null || subtitle != null)
            const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    const double spacing = 28.0; 
    const double radius = 1.5;   

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}