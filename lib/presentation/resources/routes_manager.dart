import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_screen.dart';
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
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_constants.dart';

class Routes {
  static const String splashRoute = "/";
  static const String interpreterPortalRootRoute = "/interpreter";
  static const String organizationPortalRootRoute = "/organization";
  static const String loginRoute = "/login";
  static const String interpreterPortalLoginRoute = "/interpreter/login";
  static const String interpreterPortalSignupRoute = "/interpreter/signup";
  static const String interpreterPortalDashboardRoute =
      "/interpreter/dashboard";
  static const String organizationPortalLoginRoute = "/organization/login";
  static const String organizationPortalDashboardRoute =
      "/organization/dashboard";
  static const String adminPortalLoginRoute = "/admin/login";
  static const String adminPortalDashboardRoute = "/admin/dashboard";
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
}

enum _WebPortalKind { interpreter, organization, admin }

class RouteGenerator {
  static _WebPortalKind? _portalFromCurrentHost() {
    if (!kIsWeb) return null;

    final host = Uri.base.host.toLowerCase();
    if (host.startsWith('interpreter.')) {
      return _WebPortalKind.interpreter;
    }
    if (host.startsWith('organization.')) {
      return _WebPortalKind.organization;
    }
    if (host.startsWith('admin.')) {
      return _WebPortalKind.admin;
    }
    return null;
  }

  static String _loginRouteForPortal(_WebPortalKind kind) {
    switch (kind) {
      case _WebPortalKind.interpreter:
        return Routes.interpreterPortalLoginRoute;
      case _WebPortalKind.organization:
        return Routes.organizationPortalLoginRoute;
      case _WebPortalKind.admin:
        return Routes.adminPortalLoginRoute;
    }
  }

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
    final Map<String, String> queryParams = parsedUri?.queryParameters ?? const {};
    final Map<String, String> webQueryParams =
      kIsWeb ? Uri.base.queryParameters : const {};
    final String webFragment = kIsWeb ? Uri.base.fragment : '';

    // Handle auth callbacks even when hosting rewrites callback URLs to
    // a different path (for example /login?code=...).
    final bool hasAuthQueryParams =
        queryParams.containsKey('code') ||
        queryParams.containsKey('token_hash') ||
        queryParams.containsKey('access_token') ||
      queryParams.containsKey('refresh_token') ||
      webQueryParams.containsKey('code') ||
      webQueryParams.containsKey('token_hash') ||
      webQueryParams.containsKey('access_token') ||
      webQueryParams.containsKey('refresh_token');
    final bool hasAuthFragmentToken =
        (parsedUri?.fragment.contains('access_token=') ?? false) ||
      (parsedUri?.fragment.contains('refresh_token=') ?? false) ||
      webFragment.contains('access_token=') ||
      webFragment.contains('refresh_token=');

    if (hasAuthQueryParams || hasAuthFragmentToken) {
      log('RouteGenerator: Matched auth callback via query/fragment');
      return MaterialPageRoute(
        builder: (_) => const _AuthCallbackLoadingScreen(),
      );
    }

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

    switch (basePath ?? settings.name) {
      case Routes.splashRoute:
        if (kIsWeb) {
          final portalKind = _portalFromCurrentHost();
          if (portalKind != null) {
            return MaterialPageRoute(
              builder: (_) => _WebPortalEntryResolver(kind: portalKind),
            );
          }
          return MaterialPageRoute(builder: (_) => const LoginViewWeb());
        }
        return MaterialPageRoute(builder: (_) => const SplashView());
      case Routes.interpreterPortalRootRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder:
                (_) => const _WebPortalEntryResolver(
                  kind: _WebPortalKind.interpreter,
                ),
          );
        }
        return MaterialPageRoute(builder: (_) => const LoginView());
      case Routes.organizationPortalRootRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder:
                (_) => const _WebPortalEntryResolver(
                  kind: _WebPortalKind.organization,
                ),
          );
        }
        return MaterialPageRoute(builder: (_) => const LoginView());
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
      case Routes.interpreterPortalLoginRoute:
      case Routes.organizationPortalLoginRoute:
      case Routes.adminPortalLoginRoute:
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const LoginViewWeb());
        }
        return MaterialPageRoute(builder: (_) => const LoginView());
      case Routes.interpreterPortalSignupRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const InterpreterTrackSelectionWebScreen(),
            settings: RouteSettings(
              arguments: settings.arguments ?? {'role': 'interpreter'},
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const InterpreterTrackSelectionScreen(),
          settings: RouteSettings(
            arguments: settings.arguments ?? {'role': 'interpreter'},
          ),
        );
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
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const InterpreterTrackSelectionScreen(),
          settings: RouteSettings(arguments: settings.arguments),
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
                (_) => _PortalRoleGateWeb(
                  allowedRoles: const {'organization_admin'},
                  unauthenticatedRoute: Routes.organizationPortalLoginRoute,
                  child: BlocProvider(
                    create: (context) => instance<OrganizationDashboardBloc>(),
                    child: const OrganizationDashboardWebView(),
                  ),
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
      case Routes.interpreterPortalDashboardRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder:
                (_) => const _InterpreterPortalGateWeb(child: MainViewWeb()),
          );
        }
        return MaterialPageRoute(builder: (_) => const MainView());
      case Routes.organizationPortalDashboardRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder:
                (_) => _PortalRoleGateWeb(
                  allowedRoles: const {'organization_admin'},
                  unauthenticatedRoute: Routes.organizationPortalLoginRoute,
                  child: BlocProvider(
                    create: (context) => instance<OrganizationDashboardBloc>(),
                    child: const OrganizationDashboardWebView(),
                  ),
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
      case Routes.adminPortalDashboardRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder:
                (_) => const _PortalRoleGateWeb(
                  allowedRoles: {'admin', 'superadmin'},
                  unauthenticatedRoute: Routes.adminPortalLoginRoute,
                  child: AdminDashboardWeb(),
                ),
          );
        }
        return MaterialPageRoute(builder: (_) => const AdminListScreen());
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
          return MaterialPageRoute(
            builder:
                (_) => const _PortalRoleGateWeb(
                  allowedRoles: {'admin', 'superadmin'},
                  unauthenticatedRoute: Routes.adminPortalLoginRoute,
                  child: AdminDashboardWeb(),
                ),
          );
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
      default:
        log('RouteGenerator: Unmatched route - ${settings.name}');
        log('RouteGenerator: Stack trace: ${StackTrace.current}');
        // If it looks like a deep link URL, treat it as auth callback
        if (settings.name?.contains('://') == true ||
            settings.name?.contains('code=') == true ||
            settings.name?.contains('token=') == true ||
          settings.name?.contains('token_hash=') == true ||
          settings.name?.contains('type=magiclink') == true ||
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
      try {
        final profile = await SupabaseService().getUserProfile(user.id);
        final role = profile?.role;
        final route =
            role == 'interpreter'
            ? Routes.interpreterPortalDashboardRoute
                : role == 'organization_admin'
                ? Routes.organizationPortalDashboardRoute
                : role == 'admin' || role == 'superadmin'
                ? Routes.adminPortalDashboardRoute
                : Routes.mainRoute;
        log('UnknownRouteRecovery: User authenticated, going to $route');
        Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
      } catch (_) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
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

class _PortalRoleGateWeb extends StatefulWidget {
  const _PortalRoleGateWeb({
    required this.allowedRoles,
    required this.child,
    required this.unauthenticatedRoute,
  });

  final Set<String> allowedRoles;
  final Widget child;
  final String unauthenticatedRoute;

  @override
  State<_PortalRoleGateWeb> createState() => _PortalRoleGateWebState();
}

class _PortalRoleGateWebState extends State<_PortalRoleGateWeb> {
  bool _isAllowed = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    if (!kIsWeb) {
      if (!mounted) return;
      setState(() {
        _isAllowed = true;
        _isChecking = false;
      });
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _redirect(widget.unauthenticatedRoute);
        return;
      }

      final profile = await SupabaseService().getUserProfile(user.id);
      final role = profile?.role;

      if (role != null && widget.allowedRoles.contains(role)) {
        if (!mounted) return;
        setState(() {
          _isAllowed = true;
          _isChecking = false;
        });
        return;
      }

      _redirect(_routeForRole(role));
    } catch (e) {
      log('PortalRoleGate error: $e');
      _redirect(Routes.loginRoute);
    }
  }

  String _routeForRole(String? role) {
    switch (role) {
      case 'interpreter':
        return Routes.interpreterPortalLoginRoute;
      case 'organization_admin':
        return Routes.organizationPortalDashboardRoute;
      case 'admin':
      case 'superadmin':
        return Routes.adminPortalDashboardRoute;
      default:
        return Routes.mainRoute;
    }
  }

void _redirect(String route) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAllowed) {
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}

class _InterpreterPortalGateWeb extends StatefulWidget {
  const _InterpreterPortalGateWeb({required this.child});

  final Widget child;

  @override
  State<_InterpreterPortalGateWeb> createState() =>
      _InterpreterPortalGateWebState();
}

class _InterpreterPortalGateWebState extends State<_InterpreterPortalGateWeb> {
  bool _isAllowed = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Map<String, dynamic> _buildInterpreterResumeArgs(String employmentType) {
    final isPaid = employmentType == 'paid';
    return {
      'role': 'interpreter',
      'track': employmentType,
      'interpreterTrack': employmentType,
      'interpreterLevel': employmentType,
      'requiresMedicalDocs': isPaid,
      'authContinuationFullScreen': true,
    };
  }

  Future<void> _checkAccess() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _redirect(Routes.interpreterPortalLoginRoute);
        return;
      }

      final profile = await SupabaseService().getUserProfile(user.id);
      final role = profile?.role;

      if (role != 'interpreter') {
        _redirect(_routeForRole(role));
        return;
      }

      final client = Supabase.instance.client;
      final profileData =
          await client
              .from('users_profile')
              .select('employment_type')
              .eq('user_id', user.id)
              .maybeSingle();
      final detailsData =
          await client
              .from('interpreter_details')
              .select('onboarding_status, is_verified')
              .eq('user_id', user.id)
              .maybeSingle();

      final employmentType =
          profileData?['employment_type'] as String? ?? 'volunteer';
      final onboardingStatus =
          detailsData?['onboarding_status'] as String? ?? 'not_started';
      final isVerified = detailsData?['is_verified'] == true;

      if (isVerified || onboardingStatus == 'under_review') {
        if (!mounted) return;
        setState(() {
          _isAllowed = true;
          _isChecking = false;
        });
        return;
      }

      final resumeArgs = _buildInterpreterResumeArgs(employmentType);

      switch (onboardingStatus) {
        case 'not_started':
          _redirect(Routes.interpreterTrackSelection, arguments: resumeArgs);
          return;
        case 'track_selected':
          _redirect(Routes.selectLanguage, arguments: resumeArgs);
          return;
        case 'languages_selected':
          try {
            final rows = await client
                .from('interpreter_languages')
                .select('language_id')
                .eq('user_id', user.id);
            final languageIds =
                (rows as List)
                    .map((row) => row['language_id'])
                    .whereType<num>()
                    .map((id) => id.toInt())
                    .toList();
            if (languageIds.isNotEmpty) {
              resumeArgs['languages'] = languageIds;
            }
          } catch (_) {
            // Keep fallback route to language selection.
          }

          if ((resumeArgs['languages'] as List?)?.isNotEmpty == true) {
            _redirect(Routes.languageFluencyScreen, arguments: resumeArgs);
          } else {
            _redirect(Routes.selectLanguage, arguments: resumeArgs);
          }
          return;
        case 'fluency_selected':
          _redirect(Routes.interpreterFieldScreen, arguments: resumeArgs);
          return;
        case 'specialization_selected':
          _redirect(Routes.voiceSampleRoute, arguments: resumeArgs);
          return;
        case 'voice_sample_uploaded':
          _redirect(Routes.phoneOtpRoute, arguments: resumeArgs);
          return;
        case 'phone_entered':
          _redirect(Routes.governmentIdUploadRoute, arguments: resumeArgs);
          return;
        case 'government_id_uploaded':
          _redirect(Routes.certificateUploadRoute, arguments: resumeArgs);
          return;
        case 'document_uploaded':
          _redirect(Routes.interpreterQuizHubRoute);
          return;
        default:
          _redirect(Routes.interpreterTrackSelection, arguments: resumeArgs);
          return;
      }
    } catch (e) {
      log('InterpreterPortalGate error: $e');
      _redirect(Routes.interpreterPortalLoginRoute);
    }
  }

  String _routeForRole(String? role) {
    switch (role) {
      case 'organization_admin':
        return Routes.organizationPortalDashboardRoute;
      case 'admin':
      case 'superadmin':
        return Routes.adminPortalDashboardRoute;
      case 'interpreter':
      default:
        return Routes.interpreterPortalLoginRoute;
    }
  }

void _redirect(String route, {Object? arguments}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false, arguments: arguments);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAllowed) {
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}

class _WebPortalEntryResolver extends StatefulWidget {
  const _WebPortalEntryResolver({required this.kind});

  final _WebPortalKind kind;

  @override
  State<_WebPortalEntryResolver> createState() =>
      _WebPortalEntryResolverState();
}

class _WebPortalEntryResolverState extends State<_WebPortalEntryResolver> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final targetLogin = RouteGenerator._loginRouteForPortal(widget.kind);

    if (!kIsWeb) {
      _redirect(targetLogin);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    // Allow users to skip email confirmation check if they were already authenticated
    // Some older accounts or specific flows might not have emailConfirmedAt set.
    if (user == null) {
      _redirect(targetLogin);
      return;
    }

    try {
      final profile = await SupabaseService().getUserProfile(user.id);
      final role = profile?.role;
      final allowed =
          (widget.kind == _WebPortalKind.organization &&
              role == 'organization_admin') ||
          (widget.kind == _WebPortalKind.interpreter &&
              role == 'interpreter') ||
          (widget.kind == _WebPortalKind.admin &&
              (role == 'admin' || role == 'superadmin'));

      if (allowed) {
        if (widget.kind == _WebPortalKind.interpreter) {
          _redirect(Routes.interpreterPortalLoginRoute);
        } else if (widget.kind == _WebPortalKind.organization) {
          _redirect(Routes.organizationPortalDashboardRoute);
        } else {
          _redirect(Routes.adminPortalDashboardRoute);
        }
        return;
      }

      await SupabaseService().signOut();
      _redirect(targetLogin);
    } catch (e) {
      log('WebPortalEntryResolver error: $e');
      _redirect(targetLogin);
    }
  }
void _redirect(String route) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

  Map<String, dynamic> _buildInterpreterResumeArgs(String employmentType) {
    final isPaid = employmentType == 'paid';
    return {
      'role': 'interpreter',
      'track': employmentType,
      'interpreterTrack': employmentType,
      'interpreterLevel': employmentType,
      'requiresMedicalDocs': isPaid,
      'authContinuationFullScreen': true,
    };
  }

  Future<bool> _resumeInterpreterOnboarding({
    required SupabaseClient client,
    required String userId,
    required String onboardingStatus,
    required String employmentType,
    required bool isVerified,
  }) async {
    if (isVerified || onboardingStatus == 'under_review') {
      if (!mounted) return true;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.interpreterPortalDashboardRoute,
        (route) => false,
      );
      return true;
    }

    final resumeArgs = _buildInterpreterResumeArgs(employmentType);

    switch (onboardingStatus) {
      case 'not_started':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.interpreterTrackSelection,
          (route) => false,
          arguments: resumeArgs,
        );
        return true;
      case 'track_selected':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.selectLanguage,
          (route) => false,
          arguments: resumeArgs,
        );
        return true;
      case 'languages_selected':
        try {
          final rows = await client
              .from('interpreter_languages')
              .select('language_id')
              .eq('user_id', userId);
          final languageIds =
              (rows as List)
                  .map((row) => row['language_id'])
                  .whereType<num>()
                  .map((id) => id.toInt())
                  .toList();
          if (languageIds.isNotEmpty) {
            resumeArgs['languages'] = languageIds;
          }
        } catch (_) {
          // Fall back to language selection if data hydration fails.
        }

        if (!mounted) return true;
        if ((resumeArgs['languages'] as List?)?.isNotEmpty == true) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.languageFluencyScreen,
            (route) => false,
            arguments: resumeArgs,
          );
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.selectLanguage,
            (route) => false,
            arguments: resumeArgs,
          );
        }
        return true;
      case 'fluency_selected':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.interpreterFieldScreen,
          (route) => false,
          arguments: resumeArgs,
        );
        return true;
      case 'specialization_selected':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.voiceSampleRoute,
          (route) => false,
          arguments: resumeArgs,
        );
        return true;
      case 'voice_sample_uploaded':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.phoneOtpRoute,
          (route) => false,
          arguments: resumeArgs,
        );
        return true;
      case 'phone_entered':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.governmentIdUploadRoute,
          (route) => false,
          arguments: resumeArgs,
        );
        return true;
      case 'government_id_uploaded':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.certificateUploadRoute,
          (route) => false,
          arguments: resumeArgs,
        );
        return true;
      case 'document_uploaded':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.interpreterQuizHubRoute,
          (route) => false,
        );
        return true;
      default:
        return false;
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
          Routes.organizationPortalDashboardRoute,
          (route) => false,
        );
      } else if (profile.role == 'admin' || profile.role == 'superadmin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.adminPortalDashboardRoute,
          (route) => false,
        );
      } else if (profile.role == 'interpreter') {
        final appPrefs = instance<AppPreferences>();
        // For interpreters, check if they still need to complete quizzes
        try {
          final client = Supabase.instance.client;
          final profileFuture =
              client
                  .from('users_profile')
                  .select('employment_type')
                  .eq('user_id', userId)
                  .maybeSingle();
          final detailsFuture =
              client
                  .from('interpreter_details')
                  .select('onboarding_status, is_verified')
                  .eq('user_id', userId)
                  .maybeSingle();
          final badgesFuture = client
              .from('interpreter_badges')
              .select('badge')
              .eq('user_id', userId);
          final fluencyFuture = client
              .from('voice_samples')
              .select('id')
              .eq('user_id', userId)
              .eq('sentence_type', advancedFluencySentenceType);

          final results = await Future.wait<dynamic>([
            profileFuture,
            detailsFuture,
            badgesFuture,
            fluencyFuture,
          ]);

          final profileData = results[0] as Map<String, dynamic>?;
          final detailsData = results[1] as Map<String, dynamic>?;
          final badgesData = results[2] as List<dynamic>;
          final fluencyData = results[3] as List<dynamic>;

          final employmentType =
              profileData?['employment_type'] as String? ?? 'volunteer';
          final onboardingStatus =
              detailsData?['onboarding_status'] as String? ?? 'not_started';
          final isVerified = detailsData?['is_verified'] == true;

          final resumed = await _resumeInterpreterOnboarding(
            client: client,
            userId: userId,
            onboardingStatus: onboardingStatus,
            employmentType: employmentType,
            isVerified: isVerified,
          );
          if (resumed) return;

          final badges =
              badgesData
                  .map((b) => b['badge']?.toString() ?? '')
                  .where((b) => b.isNotEmpty)
                  .toSet();

          final hasGeneral = badges.contains('general');
          final medicalCount = badges.where((b) => b != 'general').length;
          final hasAdvancedFluency =
              fluencyData.length >= advancedFluencyQuestionCount;
          final bool isExperienced = employmentType == 'paid';
          final bool allComplete =
              isExperienced
                  ? (hasGeneral && medicalCount >= 10 && hasAdvancedFluency)
                  : (hasGeneral && hasAdvancedFluency);

          if (!mounted) return;

          if (allComplete) {
            await appPrefs.setQuizOnboardingDone();
            if (!mounted) return;
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

    // Launch NEW advanced fluency quiz (web version)
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AdvancedFluencyQuizScreen(),
      ),
    );

    if (!mounted) return;

    // Handle navigation based on new quiz outcome (which returns a bool)
    if (result == true) {
      args['generalQuizPassed'] = true;
      // Note: We removed the score since the new quiz just returns true/false

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
