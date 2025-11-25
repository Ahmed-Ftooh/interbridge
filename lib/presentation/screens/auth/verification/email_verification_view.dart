import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'dart:convert';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/models/interpreter_details.dart';
import 'package:interbridge/data/models/interpreter_language.dart';
import 'package:interbridge/data/models/interpreter_skill.dart';
import 'package:interbridge/data/models/interpreter_specialization.dart';

class EmailVerificationView extends StatefulWidget {
  const EmailVerificationView({super.key});

  @override
  State<EmailVerificationView> createState() => _EmailVerificationViewState();
}

class _EmailVerificationViewState extends State<EmailVerificationView> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;

  String? _resolveEmail() {
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;
    if (currentEmail != null && currentEmail.isNotEmpty) {
      return currentEmail;
    }

    final prefs = instance<AppPreferences>();
    final pendingStr = prefs.getPendingRegistration();
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

  Future<void> _verify() async {
    final email = _resolveEmail();
    if (email == null || email.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'No email found in session',
        type: SnackBarType.error,
      );
      return;
    }
    if (_codeController.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Enter the token from the magic link',
        type: SnackBarType.error,
      );
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await SupabaseService().verifyMagicLink(
        email: email,
        token: _codeController.text.trim(),
      );
      // After verification, write pending registration to DB
      final prefs = instance<AppPreferences>();
      final pendingStr = prefs.getPendingRegistration();
      if (pendingStr != null && pendingStr.isNotEmpty) {
        final data = jsonDecode(pendingStr) as Map<String, dynamic>;
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await SupabaseService().finalizePendingRegistrationData(data, userId);
        }
        await prefs.clearPendingRegistration();
        await prefs.setLoginViewed();
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Verification failed: $e',
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
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
          message: 'Failed to resend code: $e',
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
  Widget build(BuildContext context) {
    final shownEmail = _resolveEmail() ?? '';
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        centerTitle: true,
        elevation: 0,
        title: const Text('Verify your email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSize.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSize.s24),
            Text(
              'We sent a magic link to:\n$shownEmail',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSize.s16),
            Text(
              'Click the link in your email to verify your account, or enter the token from the link below:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSize.s24),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Token (optional)'),
            ),
            const SizedBox(height: AppSize.s16),
            CustomButton(
              onTap: _verify,
              isLoading: _isVerifying,
              color: ColorManager.primary2,
              borderRadius: BorderRadius.circular(AppSize.s12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, size: AppSize.s20),
                  SizedBox(width: AppSize.s8),
                  Text('Verify'),
                ],
              ),
            ),
            TextButton(
              onPressed:
                  _isVerifying || _isResending || _resendSecondsRemaining > 0
                      ? null
                      : _resendCode,
              child:
                  _isResending
                      ? const SizedBox(
                        height: AppSize.s20,
                        width: AppSize.s20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        _resendSecondsRemaining > 0
                            ? 'Resend link in $_resendSecondsRemaining s'
                            : 'Resend link',
                      ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }
}
