import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/screens/auth/forgot_password_screen/forgot_password_view.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view/login_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/register_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/select_field_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/select_language_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/language_fluency_view.dart';
import 'package:interbridge/presentation/screens/main/main_view.dart';
import 'package:interbridge/presentation/screens/onboarding/view/onboarding_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/select_role_screen.dart';
import 'package:interbridge/presentation/screens/splash/splash_view.dart';

class Routes {
  static const String splashRoute = "/";
  static const String loginRoute = "/login";
  static const String registerRoute = "/register";
  static const String forgotPasswordRoute = "/forgotPassword";
  static const String onBoardingRoute = "/onBoarding";
  static const String mainRoute = "/main";
  static const String chatRoute = "/chat";
  static const String selectRole = "/Role";
  static const String selectLanguage = "/selectLanguage";
  static const String languageFluencyScreen = "/languageFluencyScreen";
  static const String interpreterFieldScreen = "/InterpreterFieldScreen";
}

class RouteGenerator {
  static Route<dynamic> getRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splashRoute:
        return MaterialPageRoute(builder: (_) => const SplashView());
      case Routes.loginRoute:
        return MaterialPageRoute(builder: (_) => const LoginView());
      case Routes.onBoardingRoute:
        return MaterialPageRoute(builder: (_) => const OnboardingView());
      case Routes.registerRoute:
        return MaterialPageRoute(
          builder: (_) => const RegisterView(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.forgotPasswordRoute:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordView());
      case Routes.selectRole:
        return MaterialPageRoute(builder: (_) => const SelectRoleScreen());
      case Routes.interpreterFieldScreen:
        return MaterialPageRoute(
          builder: (_) => const InterpreterFieldScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.selectLanguage:
        return MaterialPageRoute(
          builder: (_) => const LanguageSelectionScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.languageFluencyScreen:
        return MaterialPageRoute(
          builder: (_) => const LanguageFluencyScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.mainRoute:
        return MaterialPageRoute(builder: (_) => const MainView());

      default:
        return unDefinedRoute();
    }
  }

  static Route<dynamic> unDefinedRoute() {
    return MaterialPageRoute(
      builder:
          (_) => Scaffold(
            appBar: AppBar(title: const Text(AppStrings.noRouteFound)),
            body: const Center(child: Text(AppStrings.noRouteFound)),
          ),
    );
  }
}
