import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/app_state_restoration_service.dart';
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
  final AppStateRestorationService _restorationService =
      instance<AppStateRestorationService>();

  startDelay() {
    _timer = Timer(const Duration(seconds: AppConstants.splashDelay), _goNext);
  }

  _goNext() async {
    _appPreferences.isLoginViewed().then((isViewed) async {
      if (isViewed) {
        if (!mounted) return;
        // Check for cached translation before navigating to main
        await _checkAndRestoreTranslation();
        // Navigate to home screen
        Navigator.pushReplacementNamed(context, Routes.mainRoute);
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

  Future<void> _checkAndRestoreTranslation() async {
    try {
      // Check for cached translation and restore if found
      await _restorationService.checkAndRestoreTranslation(context);
    } catch (e) {
      log('Error checking for cached translation: $e');
    }
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
