import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/screens/auth/forgot_password_screen/forgot_password_view.dart';
import 'package:interbridge/presentation/screens/auth/forgot_password_screen/reset_password_view.dart';
import 'package:interbridge/presentation/screens/auth/verification/confirm_email_pending_view.dart';
import 'package:interbridge/presentation/screens/auth/verification/email_verification_view.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view/login_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/register_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/select_field_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/select_language_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/language_fluency_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/interpreter_track_selection_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/voice_sample_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/certificate_upload_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/medical_quiz_view.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_screen.dart';
import 'package:interbridge/presentation/screens/quiz/medical_section_selector_screen.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/volunteer_success_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_document_view.dart';
import 'package:interbridge/presentation/screens/main/main_view.dart';
import 'package:interbridge/presentation/screens/main/main_view_web.dart';
import 'package:interbridge/presentation/screens/onboarding/view/onboarding_view.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view/select_role_screen.dart';
import 'package:interbridge/presentation/screens/splash/splash_view.dart';
import 'package:interbridge/presentation/screens/main/chat/chat_view.dart';
import 'package:interbridge/presentation/screens/main/request_waiting_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/document_translation_view.dart';
import 'package:interbridge/presentation/screens/legal/privacy_policy_view.dart';
import 'package:interbridge/presentation/screens/legal/terms_of_service_view.dart';
import 'package:interbridge/presentation/screens/main/setting/change_password_view.dart';
import 'package:interbridge/admin/screens/admin_list_screen.dart';
import 'package:interbridge/admin/screens/admin_dashboard_web.dart';
import 'package:interbridge/data/services/pending_registration_service.dart';
import 'package:interbridge/presentation/screens/organization/organization_dashboard_view.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_bloc.dart';
import 'package:interbridge/presentation/screens/organization/organization_registration_screen.dart';
import 'package:interbridge/presentation/screens/organization/join_organization_view.dart';
import 'package:interbridge/presentation/screens/organization/organization_settings_view.dart';
import 'package:interbridge/presentation/screens/interpreter/interpreter_quiz_hub_screen.dart';
import 'package:interbridge/presentation/screens/organization/doctor_join_organization_screen.dart';
import 'package:interbridge/presentation/screens/organization/doctor_register_with_invite_screen.dart';
import 'package:interbridge/presentation/screens/auth/web/login_view_web.dart';
import 'package:interbridge/presentation/screens/auth/web/register_view_web.dart';
import 'package:interbridge/presentation/screens/auth/web/forgot_password_view_web.dart';
import 'package:interbridge/presentation/screens/auth/web/select_role_screen_web.dart';
import 'package:interbridge/presentation/screens/auth/web/confirm_email_pending_view_web.dart';
import 'package:interbridge/presentation/screens/auth/web/interpreter_track_selection_web.dart';
import 'package:interbridge/presentation/screens/auth/web/doctor_join_organization_web.dart';
import 'package:interbridge/presentation/screens/auth/web/select_language_web.dart';
import 'package:interbridge/presentation/screens/auth/web/language_fluency_web.dart';
import 'package:interbridge/presentation/screens/auth/web/select_field_web.dart';
import 'package:interbridge/presentation/screens/auth/web/voice_sample_web.dart';
import 'package:interbridge/presentation/screens/auth/web/certificate_upload_web.dart';
import 'package:interbridge/presentation/screens/auth/web/volunteer_success_web.dart';
import 'package:interbridge/presentation/screens/organization/web/organization_dashboard_web_view.dart';
import 'package:interbridge/presentation/screens/interpreter/interpreter_quiz_hub_web_screen.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_web_screen_stub.dart'
    if (dart.library.html) 'package:interbridge/presentation/screens/quiz/quiz_web_screen.dart';
import 'package:interbridge/presentation/screens/auth/web/phone_otp_web.dart';
import 'package:interbridge/presentation/screens/auth/web/government_id_upload_web.dart';
import 'package:interbridge/presentation/screens/auth/web/voice_prompt_web.dart';

class Routes {
  static const String splashRoute = "/";
  static const String loginRoute = "/login";
  static const String registerRoute = "/register";
  static const String forgotPasswordRoute = "/forgotPassword";
  static const String emailVerificationRoute = "/emailVerification";
  static const String confirmEmailRoute = "/confirmEmailPending";
  static const String resetPasswordRoute = "/resetPassword";
  static const String onBoardingRoute = "/onBoarding";
  static const String mainRoute = "/main";
  static const String chatRoute = "/chat";
  static const String selectRole = "/Role";
  static const String interpreterTrackSelection = "/interpreterTrack";
  static const String selectLanguage = "/selectLanguage";
  static const String languageFluencyScreen = "/languageFluencyScreen";
  static const String voiceSampleRoute = "/voiceSample";
  static const String certificateUploadRoute = "/certificateUpload";
  static const String generalQuizRoute = "/generalQuiz";
  static const String medicalSectionsRoute = "/medicalSections";
  static const String medicalQuizRoute =
      "/medicalQuiz"; // deprecated - keeping for backward compatibility
  static const String interpreterOnboardingRoute =
      "/interpreterOnboarding"; // deprecated
  static const String interpreterFieldScreen = "/InterpreterFieldScreen";
  static const String requestWaiting = "/requestWaiting";
  static const String accepteddocument = "/accepteddocument";
  static const String documentTranslation = "/documentTranslation";
  static const String privacyPolicy = "/privacyPolicy";
  static const String termsOfService = "/termsOfService";
  static const String changePassword = "/changePassword";
  static const String adminRoute = "/admin";
  static const String volunteerSuccessRoute = "/volunteerSuccess";
  static const String organizationRegisterRoute = "/organizationRegister";
  static const String organizationDashboardRoute = "/organizationDashboard";
  static const String joinOrganizationRoute = "/joinOrganization";
  static const String organizationSettingsRoute = "/organizationSettings";
  static const String interpreterQuizHubRoute = "/interpreterQuizHub";
  static const String doctorJoinOrganizationRoute = "/doctorJoinOrganization";
  static const String doctorRegisterWithInviteRoute =
      "/doctorRegisterWithInvite";
  static const String phoneOtpRoute = "/phoneOtp";
  static const String governmentIdUploadRoute = "/governmentIdUpload";
  static const String voicePromptRoute = "/voicePrompt";
}

class RouteGenerator {
  static Route<dynamic> getRoute(RouteSettings settings) {
    // Extract the path without query parameters for matching
    final String? routeName = settings.name;
    final Uri? parsedUri = routeName != null ? Uri.tryParse(routeName) : null;
    final String? basePath =
        parsedUri?.path.isNotEmpty == true
            ? parsedUri!.path
            : routeName?.split('?').first;
    final String? host = parsedUri?.host;
    final String scheme = parsedUri?.scheme ?? '';

    // Debug logging to track deep link routing
    log(
      'RouteGenerator: routeName=$routeName, basePath=$basePath, host=$host, scheme=$scheme',
    );

    // Handle deep link callback routes (may include query parameters)
    // The deep link format is: io.supabase.flutter://login-callback?token=xxx
    // In this case, 'login-callback' is the HOST, not the path
    // Also handle various URL formats that might come from different platforms
    final bool isSupabaseScheme = scheme == 'io.supabase.flutter';
    final bool isLoginCallback =
        host == 'login-callback' ||
        host?.startsWith('login-callback') == true ||
        basePath == '/login-callback' ||
        basePath == 'login-callback' ||
        basePath?.startsWith('/login-callback') == true ||
        routeName?.contains('login-callback') == true ||
        isSupabaseScheme; // Catch ALL supabase scheme URLs

    if (isLoginCallback) {
      log(
        'RouteGenerator: Matched login-callback route (isSupabaseScheme=$isSupabaseScheme)',
      );
      return MaterialPageRoute(
        builder: (_) => const _AuthCallbackLoadingScreen(),
      );
    }

    switch (settings.name) {
      case Routes.splashRoute:
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const LoginViewWeb());
        }
        return MaterialPageRoute(builder: (_) => const SplashView());
      case Routes.emailVerificationRoute:
        return MaterialPageRoute(
          builder: (_) => const EmailVerificationView(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.confirmEmailRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const ConfirmEmailPendingViewWeb(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const ConfirmEmailPendingView(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.resetPasswordRoute:
        return MaterialPageRoute(
          builder: (_) => const ResetPasswordView(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.accepteddocument:
        return MaterialPageRoute(
          builder: (_) => const InterpreterDocumentView(),
        );
      case Routes.loginRoute:
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const LoginViewWeb());
        }
        return MaterialPageRoute(builder: (_) => const LoginView());
      case Routes.onBoardingRoute:
        return MaterialPageRoute(builder: (_) => const OnboardingView());
      case Routes.registerRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const RegisterViewWeb(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const RegisterView(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.forgotPasswordRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const ForgotPasswordViewWeb(),
          );
        }
        return MaterialPageRoute(builder: (_) => const ForgotPasswordView());
      case Routes.selectRole:
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const SelectRoleScreenWeb());
        }
        return MaterialPageRoute(builder: (_) => const SelectRoleScreen());
      case Routes.interpreterTrackSelection:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const InterpreterTrackSelectionWebScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const InterpreterTrackSelectionScreen(),
        );
      case Routes.interpreterFieldScreen:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const SelectFieldWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const InterpreterFieldScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.selectLanguage:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const LanguageSelectionWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const LanguageSelectionScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.languageFluencyScreen:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const LanguageFluencyWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const LanguageFluencyScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );

      case Routes.voiceSampleRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const VoiceSampleWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const VoiceSampleScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.certificateUploadRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const CertificateUploadWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const CertificateUploadScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.generalQuizRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const _GeneralQuizRouteWrapperWeb(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const _GeneralQuizRouteWrapper(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.medicalSectionsRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const _MedicalSectionsRouteWrapperWeb(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const _MedicalSectionsRouteWrapper(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.medicalQuizRoute:
        return MaterialPageRoute(
          builder: (_) => const MedicalQuizScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.volunteerSuccessRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const VolunteerSuccessWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const VolunteerSuccessScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );

      case Routes.organizationRegisterRoute:
        return MaterialPageRoute(
          builder: (_) => const OrganizationRegistrationScreen(),
        );
      case Routes.organizationDashboardRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder:
                (_) => BlocProvider(
                  create: (context) => instance<OrganizationDashboardBloc>(),
                  child: const OrganizationDashboardWebView(),
                ),
          );
        }
        return MaterialPageRoute(
          builder:
              (_) => BlocProvider(
                create: (context) => instance<OrganizationDashboardBloc>(),
                child: const OrganizationDashboardView(),
              ),
        );
      case Routes.joinOrganizationRoute:
        return MaterialPageRoute(builder: (_) => const JoinOrganizationView());
      case Routes.organizationSettingsRoute:
        return MaterialPageRoute(
          builder: (_) => const OrganizationSettingsView(),
        );
      case Routes.interpreterQuizHubRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const InterpreterQuizHubWebScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const InterpreterQuizHubScreen(),
        );
      case Routes.doctorJoinOrganizationRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const DoctorJoinOrganizationWebScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const DoctorJoinOrganizationScreen(),
        );
      case Routes.doctorRegisterWithInviteRoute:
        return MaterialPageRoute(
          builder: (_) => const DoctorRegisterWithInviteScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );

      // Routes.interpreterOnboardingRoute is deprecated and not used anymore

      case Routes.mainRoute:
        // Use web-specific main view on web platform
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const MainViewWeb());
        }
        return MaterialPageRoute(builder: (_) => const MainView());
      case Routes.chatRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder:
              (_) => ChatView(
                requestId: args?['requestId'],
                requesterId: args?['requesterId'],
                interpreterId: args?['interpreterId'],
              ),
        );
      case Routes.requestWaiting:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder:
              (_) => RequestWaitingView(
                fromLanguageId: args['fromLanguageId'],
                toLanguageId: args['toLanguageId'],
                specialization: args['specialization'],
                urgency: args['urgency'],
                description: args['description'],
              ),
        );
      case Routes.documentTranslation:
        return MaterialPageRoute(
          builder: (_) => const DocumentTranslationView(),
        );
      case Routes.privacyPolicy:
        return MaterialPageRoute(builder: (_) => const PrivacyPolicyView());
      case Routes.termsOfService:
        return MaterialPageRoute(builder: (_) => const TermsOfServiceView());
      case Routes.changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordView());
      case Routes.adminRoute:
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const AdminDashboardWeb());
        }
        return MaterialPageRoute(builder: (_) => const AdminListScreen());
      case Routes.phoneOtpRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const PhoneOtpWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        // Mobile fallback — reuse web screen for now
        return MaterialPageRoute(
          builder: (_) => const PhoneOtpWebScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.governmentIdUploadRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const GovernmentIdUploadWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const GovernmentIdUploadWebScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      case Routes.voicePromptRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const VoicePromptWebScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const VoicePromptWebScreen(),
          settings: RouteSettings(arguments: settings.arguments),
        );
      default:
        log('RouteGenerator: Unmatched route - ${settings.name}');
        log('RouteGenerator: Stack trace: ${StackTrace.current}');
        // If it looks like a deep link URL, treat it as auth callback
        if (settings.name?.contains('://') == true ||
            settings.name?.contains('code=') == true ||
            settings.name?.contains('token=') == true ||
            settings.name?.contains('access_token=') == true) {
          log(
            'RouteGenerator: Detected URL-like or auth route, treating as auth callback',
          );
          return MaterialPageRoute(
            builder: (_) => const _AuthCallbackLoadingScreen(),
          );
        }
        return unDefinedRoute();
    }
  }

  static Route<dynamic> unDefinedRoute() {
    return MaterialPageRoute(
      builder: (_) => const _UnknownRouteRecoveryScreen(),
    );
  }
}

/// Recovery screen that replaces the dead-end "no route found" page.
/// Checks current auth state and redirects to the appropriate screen.
class _UnknownRouteRecoveryScreen extends StatefulWidget {
  const _UnknownRouteRecoveryScreen();

  @override
  State<_UnknownRouteRecoveryScreen> createState() =>
      _UnknownRouteRecoveryScreenState();
}

class _UnknownRouteRecoveryScreenState
    extends State<_UnknownRouteRecoveryScreen> {
  @override
  void initState() {
    super.initState();
    _recover();
  }

  Future<void> _recover() async {
    // Give a brief pause for any pending navigation to settle
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user != null && user.emailConfirmedAt != null) {
      // User is authenticated — go to main screen
      log('UnknownRouteRecovery: User authenticated, going to main');
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    } else {
      // Not authenticated — go to splash (clean start)
      log('UnknownRouteRecovery: No auth, going to splash');
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.splashRoute, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Loading screen shown while the auth deep-link callback is processed.
class _AuthCallbackLoadingScreen extends StatefulWidget {
  const _AuthCallbackLoadingScreen();

  @override
  State<_AuthCallbackLoadingScreen> createState() =>
      _AuthCallbackLoadingScreenState();
}

class _AuthCallbackLoadingScreenState
    extends State<_AuthCallbackLoadingScreen> {
  String _statusMessage = 'Verifying your email...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _handleAuthCallback();
  }

  Future<void> _handleAuthCallback() async {
    log('_AuthCallbackLoadingScreen: Starting auth callback handling');

    try {
      // Wait a moment for Supabase to process the deep link tokens
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Check if we have a session now
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;

      log(
        '_AuthCallbackLoadingScreen: session=${session != null}, user=${user?.email}, emailConfirmed=${user?.emailConfirmedAt}',
      );

      if (user != null && user.emailConfirmedAt != null) {
        // Try to finalize pending registration
        try {
          if (!mounted) return;
          setState(() => _statusMessage = 'Setting up your account...');

          final didFinalize =
              await PendingRegistrationService().finalizePendingRegistration();
          log(
            '_AuthCallbackLoadingScreen: finalizePendingRegistration=$didFinalize',
          );

          if (!mounted) return;

          // Navigate based on user role (profile may or may not exist)
          await _navigateBasedOnRole(user.id);
        } catch (e) {
          log('_AuthCallbackLoadingScreen: Error finalizing registration: $e');
          if (!mounted) return;
          // Try to navigate based on role, fallback to main if profile doesn't exist
          await _navigateBasedOnRole(user.id);
        }
      } else {
        // No confirmed user, wait a bit more then fallback
        if (!mounted) return;
        setState(() => _statusMessage = 'Waiting for confirmation...');

        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;

        // Check again
        final refreshedUser = Supabase.instance.client.auth.currentUser;
        if (refreshedUser != null && refreshedUser.emailConfirmedAt != null) {
          await _navigateBasedOnRole(refreshedUser.id);
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);
        }
      }
    } catch (e) {
      log('_AuthCallbackLoadingScreen: Unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusMessage = 'An error occurred. Please try again.';
      });
      // Wait a moment then navigate to login
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);
    }
  }

  Future<void> _navigateBasedOnRole(String userId) async {
    try {
      final supabaseService = SupabaseService();
      final profile = await supabaseService.getUserProfile(userId);
      if (!mounted) return;

      if (profile == null) {
        // Profile doesn't exist yet - this can happen if:
        // 1. User clicked magic link on different device
        // 2. Pending registration data was lost
        // Navigate to main and let the app handle missing profile
        log('_AuthCallbackLoadingScreen: No profile found, navigating to main');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
        return;
      }

      if (profile.role == 'organization_admin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.organizationDashboardRoute,
          (route) => false,
        );
      } else if (profile.role == 'interpreter') {
        // Only check quizzes on first login — skip if already completed once
        final appPrefs = instance<AppPreferences>();
        if (appPrefs.isQuizOnboardingDone()) {
          if (!mounted) return;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
        } else {
          // For interpreters, check if they still need to complete quizzes
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

            final employmentType =
                profileData?['employment_type'] ?? 'volunteer';
            final badges =
                (badgesData as List)
                    .map((b) => b['badge']?.toString() ?? '')
                    .where((b) => b.isNotEmpty)
                    .toSet();

            final hasGeneral = badges.contains('general');
            final medicalCount = badges.where((b) => b != 'general').length;
            final bool isExperienced = employmentType == 'paid';
            final bool allComplete =
                isExperienced ? (hasGeneral && medicalCount >= 10) : hasGeneral;

            if (!mounted) return;

            if (allComplete) {
              await appPrefs.setQuizOnboardingDone();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.interpreterQuizHubRoute,
                (route) => false,
              );
            }
          } catch (e) {
            log(
              '_AuthCallbackLoadingScreen: Error checking interpreter quiz status: $e',
            );
            if (!mounted) return;
            // Fallback to quiz hub for new interpreters
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.interpreterQuizHubRoute,
              (route) => false,
            );
          }
        }
      } else {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (e) {
      log('_AuthCallbackLoadingScreen: Error getting user profile: $e');
      if (!mounted) return;
      // If we can't get profile, navigate to main anyway
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_hasError)
              const Icon(Icons.error_outline, size: 48, color: Colors.red)
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusMessage),
          ],
        ),
      ),
    );
  }
}

// Wrapper to handle medical section quiz completion and route back with updated args
class _MedicalSectionsRouteWrapper extends StatefulWidget {
  const _MedicalSectionsRouteWrapper();

  @override
  State<_MedicalSectionsRouteWrapper> createState() =>
      _MedicalSectionsRouteWrapperState();
}

class _MedicalSectionsRouteWrapperState
    extends State<_MedicalSectionsRouteWrapper> {
  final List<String> _allSections = [
    'neurology',
    'cardiology',
    'respiratory',
    'gastrointestinal',
    'endocrinology',
    'renal',
    'ob_gyn',
    'oncology',
    'emergency',
    'psychology',
    'musculoskeletal',
  ];

  Set<String> _earnedSections = {};
  int _currentSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSequentialQuizzes();
    });
  }

  Future<void> _startSequentialQuizzes() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    // Load existing sections if any
    _earnedSections =
        (args['medicalSectionsPassed'] as Set<String>?) ?? <String>{};

    // Start sequential quizzes
    while (_currentSectionIndex < _allSections.length && mounted) {
      final sectionId = _allSections[_currentSectionIndex];

      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder:
              (_) => QuizScreen(quizType: 'medical', medicalSection: sectionId),
        ),
      );

      if (!mounted) return;

      if (result != null && result['passed'] == true) {
        setState(() {
          _earnedSections.add(sectionId);
        });
      }

      _currentSectionIndex++;
    }

    // All sections completed - update args and continue
    if (!mounted) return;
    args['medicalSectionsPassed'] = _earnedSections;

    // Check if at least one section is earned
    if (_earnedSections.isNotEmpty) {
      // All quizzes done - go to register
      Navigator.of(
        context,
      ).pushReplacementNamed(Routes.registerRoute, arguments: args);
    } else {
      // No badges earned - go back
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _MedicalSectionSelectorWithCallback extends StatefulWidget {
  final Function(String sectionId) onSectionPassed;

  const _MedicalSectionSelectorWithCallback({required this.onSectionPassed});

  @override
  State<_MedicalSectionSelectorWithCallback> createState() =>
      _MedicalSectionSelectorWithCallbackState();
}

class _MedicalSectionSelectorWithCallbackState
    extends State<_MedicalSectionSelectorWithCallback> {
  Future<void> _startSection(String sectionId) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder:
            (_) => QuizScreen(quizType: 'medical', medicalSection: sectionId),
      ),
    );

    if (result != null && result['passed'] == true) {
      widget.onSectionPassed(sectionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MedicalSectionSelectorScreen(onSectionTap: _startSection);
  }
}

// Wrapper for general quiz route with navigation handling
class _GeneralQuizRouteWrapper extends StatefulWidget {
  const _GeneralQuizRouteWrapper();

  @override
  State<_GeneralQuizRouteWrapper> createState() =>
      _GeneralQuizRouteWrapperState();
}

class _GeneralQuizRouteWrapperState extends State<_GeneralQuizRouteWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToQuiz();
    });
  }

  Future<void> _navigateToQuiz() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    // Launch general quiz
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const QuizScreen(quizType: 'general', isRequired: true),
      ),
    );

    if (!mounted) return;

    // Handle navigation based on quiz outcome and selected track
    if (result != null && result['passed'] == true) {
      args['generalQuizPassed'] = true;
      args['generalQuizScore'] = result['score'];

      final track =
          args['interpreterTrack'] ?? args['track'] ?? args['interpreterLevel'];
      final isPaid =
          track == 'paid' ||
          track == 'pro' ||
          (track is String &&
              (track.toLowerCase().contains('paid') ||
                  track.toLowerCase().contains('pro')));

      if (isPaid) {
        // Paid: proceed to sequential medical sections
        Navigator.of(
          context,
        ).pushReplacementNamed(Routes.medicalSectionsRoute, arguments: args);
      } else {
        // Volunteer: proceed to success screen
        Navigator.of(
          context,
        ).pushReplacementNamed(Routes.volunteerSuccessRoute, arguments: args);
      }
    } else {
      // Not passed or cancelled: return to previous screen
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// Web wrapper for general quiz route with navigation handling
class _GeneralQuizRouteWrapperWeb extends StatefulWidget {
  const _GeneralQuizRouteWrapperWeb();

  @override
  State<_GeneralQuizRouteWrapperWeb> createState() =>
      _GeneralQuizRouteWrapperWebState();
}

class _GeneralQuizRouteWrapperWebState
    extends State<_GeneralQuizRouteWrapperWeb> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToQuiz();
    });
  }

  Future<void> _navigateToQuiz() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    // Launch general quiz (web version)
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder:
            (_) => const QuizWebScreen(quizType: 'general', isRequired: true),
      ),
    );

    if (!mounted) return;

    // Handle navigation based on quiz outcome and selected track
    if (result != null && result['passed'] == true) {
      args['generalQuizPassed'] = true;
      args['generalQuizScore'] = result['score'];

      final track =
          args['interpreterTrack'] ?? args['track'] ?? args['interpreterLevel'];
      final isPaid =
          track == 'paid' ||
          track == 'pro' ||
          (track is String &&
              (track.toLowerCase().contains('paid') ||
                  track.toLowerCase().contains('pro')));

      if (isPaid) {
        // Paid: proceed to medical sections (web)
        Navigator.of(
          context,
        ).pushReplacementNamed(Routes.medicalSectionsRoute, arguments: args);
      } else {
        // Volunteer: proceed to success screen
        Navigator.of(
          context,
        ).pushReplacementNamed(Routes.volunteerSuccessRoute, arguments: args);
      }
    } else {
      // Not passed or cancelled: return to previous screen
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// Web wrapper for medical sections route
class _MedicalSectionsRouteWrapperWeb extends StatefulWidget {
  const _MedicalSectionsRouteWrapperWeb();

  @override
  State<_MedicalSectionsRouteWrapperWeb> createState() =>
      _MedicalSectionsRouteWrapperWebState();
}

class _MedicalSectionsRouteWrapperWebState
    extends State<_MedicalSectionsRouteWrapperWeb> {
  final List<String> _allSections = [
    'neurology',
    'cardiology',
    'respiratory',
    'gastrointestinal',
    'endocrinology',
    'renal',
    'ob_gyn',
    'oncology',
    'emergency',
    'psychology',
    'musculoskeletal',
  ];

  Set<String> _earnedSections = {};
  int _currentSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSequentialQuizzes();
    });
  }

  Future<void> _startSequentialQuizzes() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    // Load existing sections if any
    _earnedSections =
        (args['medicalSectionsPassed'] as Set<String>?) ?? <String>{};

    // Start sequential quizzes using web quiz screen
    while (_currentSectionIndex < _allSections.length && mounted) {
      final sectionId = _allSections[_currentSectionIndex];

      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder:
              (_) =>
                  QuizWebScreen(quizType: 'medical', medicalSection: sectionId),
        ),
      );

      if (!mounted) return;

      if (result != null && result['passed'] == true) {
        setState(() {
          _earnedSections.add(sectionId);
        });
      }

      _currentSectionIndex++;
    }

    // All sections completed - update args and continue
    if (!mounted) return;
    args['medicalSectionsPassed'] = _earnedSections;

    // Check if at least one section is earned
    if (_earnedSections.isNotEmpty) {
      // All quizzes done - go to register
      Navigator.of(
        context,
      ).pushReplacementNamed(Routes.registerRoute, arguments: args);
    } else {
      // No badges earned - go back
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
