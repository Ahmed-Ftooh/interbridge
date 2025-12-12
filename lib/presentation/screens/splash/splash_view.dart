import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Timer? _timer;
  final AppPreferences _appPreferences = instance<AppPreferences>();
  final SupabaseService _supabaseService = SupabaseService();

  startDelay() {
    _timer = Timer(const Duration(seconds: AppConstants.splashDelay), _goNext);
  }

  Future<void> _navigateBasedOnRole(String userId) async {
    try {
      log('SplashView: Getting profile for userId: $userId');
      final profile = await _supabaseService.getUserProfile(userId);
      log('SplashView: Profile found: role=${profile?.role}');
      if (!mounted) return;

      if (profile?.role == 'organization_admin') {
        log('SplashView: Navigating to organization dashboard');
        Navigator.pushReplacementNamed(
          context,
          Routes.organizationDashboardRoute,
        );
      } else if (profile?.role == 'interpreter') {
        try {
          final client = Supabase.instance.client;
          final profileData =
              await client
                  .from('users_profile')
                  .select('employment_type')
                  .eq('user_id', userId)
                  .maybeSingle();

          final badgesData = await client
              .from('interpreter_badges')
              .select('badge')
              .eq('user_id', userId);

          final employmentType = profileData?['employment_type'] ?? 'volunteer';
          final badges =
              (badgesData as List)
                  .map((b) => b['badge']?.toString() ?? '')
                  .where((b) => b.isNotEmpty)
                  .toSet();

          final hasGeneral = badges.contains('general');
          final medicalCount = badges.where((b) => b != 'general').length;
          final bool isExperienced = employmentType == 'paid';
          final bool allComplete =
              isExperienced ? (hasGeneral && medicalCount >= 3) : hasGeneral;

          if (allComplete) {
            Navigator.pushReplacementNamed(context, Routes.mainRoute);
          } else {
            Navigator.pushReplacementNamed(
              context,
              Routes.interpreterQuizHubRoute,
            );
          }
        } catch (e) {
          log('SplashView: Error checking interpreter quiz status: $e');
          Navigator.pushReplacementNamed(context, Routes.mainRoute);
        }
      } else {
        log('SplashView: Navigating to main route');
        Navigator.pushReplacementNamed(context, Routes.mainRoute);
      }
    } catch (e) {
      log('SplashView: Error getting user profile: $e');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.mainRoute);
    }
  }

  _goNext() async {
    // Check if user is already authenticated (e.g., from email verification deep link)
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.emailConfirmedAt != null) {
      log('SplashView: User already authenticated: ${user.email}');
      // Try to finalize any pending registration
      try {
        await PendingRegistrationService().finalizePendingRegistration();
      } catch (e) {
        log('SplashView: Error finalizing pending registration: $e');
      }
      if (!mounted) return;

      // Check if user is organization_admin and navigate accordingly
      await _navigateBasedOnRole(user.id);
      return;
    }

    _appPreferences.isLoginViewed().then((isViewed) async {
      if (isViewed) {
        if (!mounted) return;
        // Check user role for navigation
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await _navigateBasedOnRole(user.id);
        } else {
          Navigator.pushReplacementNamed(context, Routes.mainRoute);
        }
      } else {
        _appPreferences.isOnboardingViewed().then(
          (isviewd) => {
            if (isviewd)
              {
                if (mounted)
                  Navigator.pushReplacementNamed(context, Routes.loginRoute),
              }
            else
              {
                if (mounted)
                  Navigator.pushReplacementNamed(
                    context,
                    Routes.onBoardingRoute,
                  ),
              },
          },
        );

        // Navigate to onboarding screen
      }
    });
    {}
  }

  @override
  void initState() {
    startDelay();
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.white,
      body: Center(
        child: Image.asset(
          ImageAssets.logo2,
          fit: BoxFit.cover,
          width: 230,
          height: 230,
        ),
      ),
    );
  }
}
