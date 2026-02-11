import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modern web-specific email confirmation pending view
class ConfirmEmailPendingViewWeb extends StatefulWidget {
  const ConfirmEmailPendingViewWeb({super.key});

  @override
  State<ConfirmEmailPendingViewWeb> createState() =>
      _ConfirmEmailPendingViewWebState();
}

class _ConfirmEmailPendingViewWebState
    extends State<ConfirmEmailPendingViewWeb> {
  bool _isResending = false;
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;
  final AppPreferences _prefs = instance<AppPreferences>();

  String? _resolveEmail() {
    final userEmail = Supabase.instance.client.auth.currentUser?.email;
    if (userEmail != null && userEmail.isNotEmpty) {
      return userEmail;
    }
    final pendingStr = _prefs.getPendingRegistration();
    if (pendingStr != null && pendingStr.isNotEmpty) {
      try {
        final data = jsonDecode(pendingStr) as Map<String, dynamic>;
        final storedEmail = data['email']?.toString();
        if (storedEmail != null && storedEmail.isNotEmpty) {
          return storedEmail;
        }
      } catch (_) {}
    }
    return null;
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _resendSecondsRemaining = 0);
        }
      } else if (mounted) {
        setState(() => _resendSecondsRemaining -= 1);
      }
    });
  }

  Future<void> _resendLink() async {
    final email = _resolveEmail();
    if (email == null || email.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'No email found in session',
        type: SnackBarType.error,
      );
      return;
    }
    setState(() => _isResending = true);
    try {
      await SupabaseService().sendMagicLink(email);
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Magic link sent. Please check your inbox.',
          type: SnackBarType.success,
        );
        _startResendCooldown();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to send link: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = _resolveEmail();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 500,
            ),
            margin: EdgeInsets.all(isMobile ? 16 : 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/branding
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0955FA).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Main content card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Check Your Email',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We\'ve sent a confirmation link to',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (email != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            email,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0955FA),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF0955FA,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildStep(1, 'Open the email we sent you'),
                            const SizedBox(height: 12),
                            _buildStep(2, 'Click the confirmation link'),
                            const SizedBox(height: 12),
                            _buildStep(3, 'You\'ll be automatically signed in'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Resend button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              (_isResending || _resendSecondsRemaining > 0)
                                  ? null
                                  : _resendLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0955FA),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: const Color(
                              0xFF0955FA,
                            ).withValues(alpha: 0.5),
                          ),
                          child:
                              _isResending
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : _resendSecondsRemaining > 0
                                  ? Text(
                                    'Resend in ${_resendSecondsRemaining}s',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                  : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.refresh, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Resend Confirmation Link',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Back to login
                      TextButton(
                        onPressed:
                            () => Navigator.of(context).pushNamedAndRemoveUntil(
                              Routes.loginRoute,
                              (route) => false,
                            ),
                        child: const Text(
                          'Back to Login',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Help section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Didn\'t receive the email?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Check your spam or junk folder\n'
                        '• Make sure you entered the correct email\n'
                        '• Wait a few minutes and try again',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF92400E),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF0955FA).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0955FA),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0369A1)),
          ),
        ),
      ],
    );
  }
}
