import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/pending_registration_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfirmEmailPendingView extends StatefulWidget {
  const ConfirmEmailPendingView({super.key});

  @override
  State<ConfirmEmailPendingView> createState() =>
      _ConfirmEmailPendingViewState();
}

class _ConfirmEmailPendingViewState extends State<ConfirmEmailPendingView> {
  bool _isResending = false;
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;
  StreamSubscription<AuthState>? _authSub;
  bool _isNavigating = false;

  final AppPreferences _prefs = instance<AppPreferences>();

  @override
  void initState() {
    super.initState();
    _listenForAuthStateChange();
  }

  /// Listen for Supabase auth state changes so that when the user taps the
  /// magic link (which may be handled entirely in the background by the
  /// Supabase SDK + app_links), this screen navigates automatically.
  void _listenForAuthStateChange() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) async {
      if (_isNavigating || !mounted) return;

      if (event.event == AuthChangeEvent.signedIn && event.session != null) {
        log('ConfirmEmailPendingView: signedIn event — navigating');
        _isNavigating = true;

        try {
          // Finalize any pending registration data (interpreter profile, etc.)
          final success =
              await PendingRegistrationService().finalizePendingRegistration();
          if (!success) {
            final regError = PendingRegistrationService().lastError;
            if (regError != null && mounted) {
              CustomSnackBar.show(
                context,
                message: regError,
                type: SnackBarType.error,
              );
            }
          }
        } catch (e) {
          log('ConfirmEmailPendingView: Error finalizing registration: $e');
        }

        if (!mounted) return;
        await _navigateBasedOnRole(event.session!.user.id);
      }
    });
  }

  Future<void> _navigateBasedOnRole(String userId) async {
    try {
      final supabaseService = SupabaseService();
      final profile = await supabaseService.getUserProfile(userId);
      if (!mounted) return;

      if (profile?.role == 'admin' || profile?.role == 'superadmin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.adminPortalDashboardRoute,
          (route) => false,
        );
      } else if (profile?.role == 'organization_admin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.organizationPortalDashboardRoute,
          (route) => false,
        );
      } else if (profile?.role == 'interpreter') {
        final appPrefs = instance<AppPreferences>();
        if (appPrefs.isQuizOnboardingDone()) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.interpreterPortalDashboardRoute,
            (route) => false,
          );
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.interpreterQuizHubRoute,
            (route) => false,
          );
        }
      } else {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (e) {
      log('ConfirmEmailPendingView: Error navigating based on role: $e');
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    }
  }

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
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = _resolveEmail();
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Confirm Email'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSize.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email_outlined,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: AppSize.s32),
              Text(
                'Check your email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSize.s16),
              Text(
                email != null
                    ? 'We sent a magic link to $email'
                    : 'We sent a magic link to your email',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSize.s8),
              Text(
                'Tap the link to complete your registration',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSize.s32),
              TextButton.icon(
                onPressed:
                    _isResending || _resendSecondsRemaining > 0
                        ? null
                        : _resendLink,
                icon:
                    _isResending
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh),
                label: Text(
                  _resendSecondsRemaining > 0
                      ? 'Resend in $_resendSecondsRemaining s'
                      : 'Resend Link',
                ),
              ),
              const SizedBox(height: AppSize.s8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    Routes.loginRoute,
                    (route) => false,
                  );
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
