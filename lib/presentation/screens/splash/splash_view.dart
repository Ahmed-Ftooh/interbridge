import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/app_initializer.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/pending_registration_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/constants_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  final AppPreferences _appPreferences = instance<AppPreferences>();
  final SupabaseService _supabaseService = SupabaseService();

  /// Ensures navigation happens exactly once.
  bool _navigated = false;

  /// Auth state subscription (only used when a deep link is pending).
  StreamSubscription<AuthState>? _authSub;

  /// Timeout timer for deep-link auth resolution.
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _resolveAuth();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // ─────────────────── Auth Gate Logic ───────────────────
Future<void> _resolveAuth() async {
    // Brief settle time
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // ── 1. Already have a valid session? ──
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    // FIX: Removed the buggy 'emailConfirmedAt != null' check!
    if (user != null) {
      log('SplashView: User already authenticated: ${user.email}');
      await _finalizeAndNavigate(user.id);
      return;
    }

    // ── 2. Deep link pending (magic link opened the app)? ──
    if (AppInitializer.deepLinkPending) {
      log('SplashView: Deep link pending — waiting for auth to complete');

      if (!mounted) return;
      setState(() {}); // trigger rebuild to show "Verifying…" state

      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedIn && event.session != null) {
          log('SplashView: signedIn event received from deep link');
          _authSub?.cancel();
          _timeoutTimer?.cancel();
          _finalizeAndNavigate(event.session!.user.id);
        }
      });

      // Re-check immediately
      final recheck = Supabase.instance.client.auth.currentSession;
      // FIX: Removed the buggy 'emailConfirmedAt != null' check!
      if (recheck != null) {
        _authSub?.cancel();
        await _finalizeAndNavigate(recheck.user.id);
        return;
      }

      // Timeout — if auth doesn't resolve within 15 s, fall back to login.
      _timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!_navigated && mounted) {
          log('SplashView: Deep link auth timed out — going to login');
          _authSub?.cancel();
          _navigateOnce(() {
            Navigator.pushReplacementNamed(context, Routes.loginRoute);
          });
        }
      });
      return;
    }

    // ── 3. Normal cold start (no deep link) ──
    await Future.delayed(const Duration(seconds: AppConstants.splashDelay));
    if (!mounted) return;
    _normalSplashFlow();
  }

  // ────// ─────────────────── Navigation helpers ───────────────────
  Future<void> _finalizeAndNavigate(String userId) async {
    if (_navigated) return;
    AppInitializer.markInitialAuthHandled();

    try {
      final success =
          await PendingRegistrationService().finalizePendingRegistration();

      // Surface org-creation errors so the user knows what went wrong.
      if (!success) {
        final regError = PendingRegistrationService().lastError;
        
        // ONLY stop navigation if there is an actual error message to show.
        // If regError is null, it just means there was nothing to finalize!
        if (regError != null && regError.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(regError),
                backgroundColor: Colors.red[700],
                duration: const Duration(seconds: 6),
              ),
            );
          }
          return; // Stop navigation ONLY so the user can read the error
        }
      }
    } catch (e) {
      log('SplashView: Error finalizing pending registration: $e');
      // Do NOT put a 'return;' here. If there is a quick network timeout, 
      // returning here will freeze the splash screen forever. Let it proceed!
    }
    
    if (!mounted) return;

    // On web, always hand off to LoginViewWeb for role + onboarding routing.
    if (kIsWeb) {
      _navigateOnce(() {
        Navigator.pushReplacementNamed(context, _loginRouteForPortal());
      });
      return;
    }

    await _navigateBasedOnRole(userId);
  }

  /// Navigate exactly once. Prevents race conditions.
  void _navigateOnce(VoidCallback navigate) {
    if (_navigated || !mounted) return;
    _navigated = true;
    navigate();
  }

  /// Normal flow when no deep link and no existing session.
  void _normalSplashFlow() {
    // Mark initial auth as handled (no deep link, no session).
    AppInitializer.markInitialAuthHandled();

    _appPreferences.isLoginViewed().then((isViewed) async {
      if (!mounted) return;
      if (isViewed) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          if (kIsWeb) {
            _navigateOnce(() {
              Navigator.pushReplacementNamed(context, _loginRouteForPortal());
            });
          } else {
            await _navigateBasedOnRole(user.id);
          }
        } else {
          _navigateOnce(() {
            Navigator.pushReplacementNamed(context, Routes.loginRoute);
          });
        }
      } else {
        _appPreferences.isOnboardingViewed().then((isOnboardingViewed) {
          if (!mounted) return;
          if (isOnboardingViewed) {
            _navigateOnce(() {
              Navigator.pushReplacementNamed(context, Routes.loginRoute);
            });
          } else {
            _navigateOnce(() {
              Navigator.pushReplacementNamed(context, Routes.onBoardingRoute);
            });
          }
        });
      }
    });
  }

  String _loginRouteForPortal() {
    if (!kIsWeb) return Routes.loginRoute;

    final path = Uri.base.path.toLowerCase();
    final host = Uri.base.host.toLowerCase();

    if (path.startsWith('/admin') || host.startsWith('admin.')) {
      return Routes.adminPortalLoginRoute;
    }
    if (path.startsWith('/organization') ||
        host.startsWith('organization.')) {
      return Routes.organizationPortalLoginRoute;
    }
    if (path.startsWith('/interpreter') || host.startsWith('interpreter.')) {
      return Routes.interpreterPortalLoginRoute;
    }

    return Routes.loginRoute;
  }

  // ─────────────────── Role-based navigation ───────────────────

  Future<void> _navigateBasedOnRole(String userId) async {
    try {
      log('SplashView: Getting profile for userId: $userId');
      final profile = await _supabaseService.getUserProfile(userId);
      log('SplashView: Profile found: role=${profile?.role}');
      if (!mounted) return;
        
      if (profile?.role == 'admin' || profile?.role == 'superadmin') {
        log('SplashView: Navigating to admin portal dashboard');
        _navigateOnce(() {
          Navigator.pushReplacementNamed(
            context,
            Routes.adminPortalDashboardRoute,
          );
        });
      } else if (profile?.role == 'organization_admin') {
        log('SplashView: Navigating to organization dashboard');
        _navigateOnce(() {
          Navigator.pushReplacementNamed(
            context,
            Routes.organizationPortalDashboardRoute,
          );
        });
      } else if (profile?.role == 'interpreter') {
        log('SplashView: Navigating to interpreter dashboard');
        _navigateOnce(() {
          Navigator.pushReplacementNamed(
            context,
            Routes.interpreterPortalDashboardRoute,
          );
        });
        
      
      }else {
        log('SplashView: Navigating to main route');
        _navigateOnce(() {
          Navigator.pushReplacementNamed(context, Routes.mainRoute);
        });
      }
    } catch (e) {
      log('SplashView: Error getting user profile: $e');
      if (!mounted) return;
      _navigateOnce(() {
        Navigator.pushReplacementNamed(context, Routes.mainRoute);
      });
    }
  }

  // ─────────────────── UI ───────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              ImageAssets.logo2,
              fit: BoxFit.cover,
              width: 230,
              height: 230,
            ),
            // Show a subtle loading indicator when waiting for deep link auth
            if (AppInitializer.deepLinkPending && !_navigated) ...[
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Verifying your email…',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
