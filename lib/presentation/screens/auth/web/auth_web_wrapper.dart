import 'dart:math';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';

/// Professional interpreter-focused web auth wrapper
class AuthWebWrapper extends StatefulWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final bool fullScreen;

  const AuthWebWrapper({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.fullScreen = false,
  });

  @override
  State<AuthWebWrapper> createState() => _AuthWebWrapperState();
}

class _AuthWebWrapperState extends State<AuthWebWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      return _buildFullScreenLayout(context);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 960;

    if (isMobile) return _buildMobileLayout(context);
    return _buildDesktopLayout(context);
  }

  Widget _buildFullScreenLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 960;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
              ),
              child: CustomPaint(painter: _GridPatternPainter()),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 20 : 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isCompact ? 640 : 980),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 24 : 36),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildLogo(size: 40),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'InterBridge',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Text(
                                  'Interpreter platform',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (widget.title != null) ...[
                          SizedBox(height: isCompact ? 20 : 24),
                          Text(
                            widget.title!,
                            style: TextStyle(
                              fontSize: isCompact ? 28 : 34,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: isCompact ? 14 : 15,
                              color: Colors.white.withValues(alpha: 0.75),
                              height: 1.5,
                            ),
                          ),
                        ],
                        SizedBox(height: isCompact ? 20 : 26),
                        widget.child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Compact branding header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                ),
                child: Column(
                  children: [
                    _buildLogo(size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'InterBridge',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Interpreter platform',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Form
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null) ...[
                      Text(
                        widget.title!,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                    widget.child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Global Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
              ),
              child: CustomPaint(painter: _GridPatternPainter()),
            ),
          ),
          // Accent glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Row(
            children: [
              // Left — professional branding panel
              Expanded(
                flex: 5,
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 48,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 96,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo
                              Row(
                                children: [
                                  _buildLogo(size: 44),
                                  const SizedBox(width: 14),
                                  const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'InterBridge',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        'Interpreter plateform',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(
                                            0xFF94A3B8,
                                          ), // Lighter text
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Hero text
                              FadeTransition(
                                opacity: _fadeIn,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Empowering Medical Interpreters for a Global Impact',
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.2,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Join a specialized network of medical interpreters. Manage your sessions, track your earnings, and deliver expert care—all in one secure platform.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 48),
                                    // Stats row
                                    Row(
                                      children: [
                                        _buildGlassStatCard(
                                          '500+',
                                          'Interpreters',
                                          Icons.group,
                                        ),
                                        const SizedBox(width: 16),
                                        _buildGlassStatCard(
                                          '50+',
                                          'Languages',
                                          Icons.language,
                                        ),
                                        const SizedBox(width: 16),
                                        _buildGlassStatCard(
                                          '24/7',
                                          'Availability',
                                          Icons.access_time,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Testimonial
                              FadeTransition(
                                opacity: _fadeIn,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.format_quote_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        size: 28,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'InterBridge makes it easy to manage interpretation work in one place. '
                                        'I can accept sessions, track my activity, and stay organized through one simple dashboard.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          height: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.15),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Sarah M.',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'Medical Interpreter · Arabic',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Right — form panel
              Expanded(
                flex: 4,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.title != null) ...[
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (widget.subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 32),
                            ],
                            widget.child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo({double size = 44}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        ImageAssets.appIcon,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildGlassStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Icon(
                  icon,
                  color: Colors.blueAccent.withValues(alpha: 0.8),
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Molecule Network pattern for the branding panel
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final width = size.width;
    final height = size.height;

    final dotPaint =
        Paint()
          ..color = Colors.cyanAccent.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

    final linePaint =
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.1)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    final int nodeCount = 40;
    final List<Offset> nodes = [];

    // Generate random nodes
    for (int i = 0; i < nodeCount; i++) {
      nodes.add(Offset(rng.nextDouble() * width, rng.nextDouble() * height));
    }

    // Connect nodes if they are close enough
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final double dist = (nodes[i] - nodes[j]).distance;
        if (dist < 150) {
          canvas.drawLine(nodes[i], nodes[j], linePaint);
        }
      }
    }

    // Draw nodes
    for (var node in nodes) {
      canvas.drawCircle(node, rng.nextDouble() * 3 + 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
