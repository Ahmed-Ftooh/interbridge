import 'dart:developer';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added SharedPreferences
import 'package:interbridge/presentation/screens/interpreter/interpreter_login_compliance_screen.dart' // Your mobile version
    if (dart.library.html) 'package:interbridge/presentation/screens/interpreter/interpreter_login_compliance_screen_web.dart'; // Your web version
import 'package:interbridge/presentation/screens/auth/web/auth_selection_web.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_constants.dart';
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
import 'package:interbridge/data/services/compliance_storage.dart';

class Routes {
  static const String splashRoute = "/";
  static const String interpreterPortalRootRoute = "/interpreter";
  static const String organizationPortalRootRoute = "/organization";
  static const String loginRoute = "/login";
  static const String interpreterPortalLoginRoute = "/interpreter/login";
  static const String interpreterPortalSignupRoute = "/interpreter/signup";
  static const String interpreterPortalDashboardRoute = "/interpreter/dashboard";
  static const String organizationPortalLoginRoute = "/organization/login";
  static const String organizationPortalDashboardRoute = "/organization/dashboard";
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
  static const String medicalQuizRoute = "/medicalQuiz";
  static const String interpreterOnboardingRoute = "/interpreterOnboarding"; 
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
  static const String doctorRegisterWithInviteRoute = "/doctorRegisterWithInvite";
  static const String phoneOtpRoute = "/phoneOtp";
  static const String governmentIdUploadRoute = "/governmentIdUpload";
  static const String interpreterComplianceRoute = "/interpreter/compliance";
}

enum _WebPortalKind { interpreter, organization, admin }

class RouteGenerator {
  static _WebPortalKind? _portalFromCurrentHost() {
    if (!kIsWeb) return null;
    final host = Uri.base.host.toLowerCase();
    if (host.startsWith('interpreter.')) return _WebPortalKind.interpreter;
    if (host.startsWith('organization.')) return _WebPortalKind.organization;
    if (host.startsWith('admin.')) return _WebPortalKind.admin;
    return null;
  }

  static String _loginRouteForPortal(_WebPortalKind? kind) {
    switch (kind) {
      case _WebPortalKind.interpreter:
        return Routes.interpreterPortalLoginRoute;
      case _WebPortalKind.organization:
        return Routes.organizationPortalLoginRoute;
      case _WebPortalKind.admin:
        return Routes.adminPortalLoginRoute;
      default:
        return Routes.loginRoute;
    }
  }

  static Route<dynamic> _buildRoute(Widget webScreen, Widget mobileScreen, {RouteSettings? settings}) {
    return MaterialPageRoute(
      builder: (_) => kIsWeb ? webScreen : mobileScreen,
      settings: settings,
    );
  }

  static Route<dynamic> getRoute(RouteSettings settings) {
    final String? routeName = settings.name;
    final Uri? parsedUri = routeName != null ? Uri.tryParse(routeName) : null;
    final String? basePath = parsedUri?.path.isNotEmpty == true ? parsedUri!.path : routeName?.split('?').first;
    final String? host = parsedUri?.host;
    final String scheme = parsedUri?.scheme ?? '';
    final Map<String, String> queryParams = parsedUri?.queryParameters ?? const {};
    final Map<String, String> webQueryParams = kIsWeb ? Uri.base.queryParameters : const {};
    final String webFragment = kIsWeb ? Uri.base.fragment : '';

    final bool isInitialRoute = settings.name == '/' || settings.name == null;

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

    if (isInitialRoute && (hasAuthQueryParams || hasAuthFragmentToken)) {
      log('RouteGenerator: Matched auth callback via query/fragment');
      return MaterialPageRoute(builder: (_) => const _AuthCallbackLoadingScreen(), settings: settings);
    }

    log('RouteGenerator: routeName=$routeName, basePath=$basePath, host=$host, scheme=$scheme');

    final bool isSupabaseScheme = scheme == 'io.supabase.flutter';
    final bool isLoginCallback =
        host == 'login-callback' ||
        host?.startsWith('login-callback') == true ||
        basePath == '/login-callback' ||
        basePath == 'login-callback' ||
        basePath?.startsWith('/login-callback') == true ||
        routeName?.contains('login-callback') == true ||
        isSupabaseScheme;

    if (isLoginCallback) {
      log('RouteGenerator: Matched login-callback route');
      return MaterialPageRoute(builder: (_) => const _AuthCallbackLoadingScreen(), settings: settings);
    }

    switch (basePath ?? settings.name) {
      case Routes.splashRoute:
        if (kIsWeb) {
          final portalKind = _portalFromCurrentHost();
          return MaterialPageRoute(builder: (_) => _WebPortalEntryResolver(kind: portalKind), settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const SplashView(), settings: settings);

      case Routes.interpreterPortalRootRoute:
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const _WebPortalEntryResolver(kind: _WebPortalKind.interpreter), settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const LoginView(), settings: settings);

      case Routes.organizationPortalRootRoute:
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const _WebPortalEntryResolver(kind: _WebPortalKind.organization), settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const LoginView(), settings: settings);

      case Routes.emailVerificationRoute:
        return MaterialPageRoute(
          builder: (_) => const EmailVerificationView(),
          settings: settings,
        );

      case Routes.confirmEmailRoute:
        return _buildRoute(const ConfirmEmailPendingViewWeb(), const ConfirmEmailPendingView(), settings: settings);

      case Routes.resetPasswordRoute:
        return MaterialPageRoute(
          builder: (_) => const ResetPasswordView(),
          settings: settings,
        );

      case Routes.accepteddocument:
        return MaterialPageRoute(builder: (_) => const InterpreterDocumentView(), settings: settings);

      case Routes.loginRoute:
      case Routes.interpreterPortalLoginRoute:
      case Routes.organizationPortalLoginRoute:
      case Routes.adminPortalLoginRoute:
        return _buildRoute(const LoginViewWeb(), const LoginView(), settings: settings);

      case Routes.interpreterPortalSignupRoute:
        final defaultArgs = settings.arguments ?? {'role': 'interpreter'};
        return _buildRoute(const InterpreterTrackSelectionWebScreen(), const InterpreterTrackSelectionScreen(), settings: RouteSettings(name: settings.name, arguments: defaultArgs));

      case Routes.onBoardingRoute:
        return MaterialPageRoute(builder: (_) => const OnboardingView(), settings: settings);

      case Routes.registerRoute:
        return _buildRoute(const RegisterViewWeb(), const RegisterView(), settings: settings);

      case Routes.forgotPasswordRoute:
        return _buildRoute(const ForgotPasswordViewWeb(), const ForgotPasswordView(), settings: settings);

      case Routes.selectRole:
        return _buildRoute(const SelectRoleScreenWeb(), const SelectRoleScreen(), settings: settings);

      case Routes.interpreterTrackSelection:
        return _buildRoute(const InterpreterTrackSelectionWebScreen(), const InterpreterTrackSelectionScreen(), settings: settings);

      case Routes.interpreterFieldScreen:
        return _buildRoute(const SelectFieldWebScreen(), const InterpreterFieldScreen(), settings: settings);

      case Routes.selectLanguage:
        return _buildRoute(const LanguageSelectionWebScreen(), const LanguageSelectionScreen(), settings: settings);

      case Routes.languageFluencyScreen:
        return _buildRoute(const LanguageFluencyWebScreen(), const LanguageFluencyScreen(), settings: settings);

      case Routes.voiceSampleRoute:
        return _buildRoute(const VoiceSampleWebScreen(), const VoiceSampleScreen(), settings: settings);

      case Routes.certificateUploadRoute:
        return _buildRoute(const CertificateUploadWebScreen(), const CertificateUploadScreen(), settings: settings);

      case Routes.generalQuizRoute:
        return _buildRoute(const _GeneralQuizRouteWrapperWeb(), const _GeneralQuizRouteWrapper(), settings: settings);

      case Routes.medicalSectionsRoute:
        return _buildRoute(const _MedicalSectionsRouteWrapperWeb(), const _MedicalSectionsRouteWrapper(), settings: settings);

      case Routes.medicalQuizRoute:
        return MaterialPageRoute(
          builder: (_) => const MedicalQuizScreen(),
          settings: settings,
        );

      case Routes.volunteerSuccessRoute:
        return _buildRoute(const VolunteerSuccessWebScreen(), const VolunteerSuccessScreen(), settings: settings);
       
      case Routes.interpreterComplianceRoute:
        return MaterialPageRoute(builder: (_) => const InterpreterLoginComplianceScreen(), settings: settings);
        
      case Routes.organizationRegisterRoute:
        return MaterialPageRoute(builder: (_) => const OrganizationRegistrationScreen(), settings: settings);

      case Routes.organizationDashboardRoute:
      case Routes.organizationPortalDashboardRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => _PortalRoleGateWeb(
              allowedRoles: const {'organization_admin'},
              unauthenticatedRoute: Routes.organizationPortalLoginRoute,
              child: BlocProvider(
                create: (context) => instance<OrganizationDashboardBloc>(),
                child: const OrganizationDashboardWebView(),
              ),
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => instance<OrganizationDashboardBloc>(),
            child: const OrganizationDashboardView(),
          ),
          settings: settings,
        );

      case Routes.joinOrganizationRoute:
        return MaterialPageRoute(builder: (_) => const JoinOrganizationView(), settings: settings);

      case Routes.organizationSettingsRoute:
        return MaterialPageRoute(builder: (_) => const OrganizationSettingsView(), settings: settings);

      case Routes.interpreterQuizHubRoute:
        return _buildRoute(const InterpreterQuizHubWebScreen(), const InterpreterQuizHubScreen(), settings: settings);

      case Routes.doctorJoinOrganizationRoute:
        return _buildRoute(const DoctorJoinOrganizationWebScreen(), const DoctorJoinOrganizationScreen(), settings: settings);

      case Routes.doctorRegisterWithInviteRoute:
        return MaterialPageRoute(
          builder: (_) => const DoctorRegisterWithInviteScreen(),
          settings: settings,
        );

      case Routes.mainRoute:
        return _buildRoute(const MainViewWeb(), const MainView(), settings: settings);

      case Routes.interpreterPortalDashboardRoute:
        return _buildRoute(const _InterpreterPortalGateWeb(child: MainViewWeb()), const MainView(), settings: settings);

      case Routes.adminPortalDashboardRoute:
      case Routes.adminRoute:
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => const _PortalRoleGateWeb(
              allowedRoles: {'admin', 'superadmin'},
              unauthenticatedRoute: Routes.adminPortalLoginRoute,
              child: AdminDashboardWeb(),
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(builder: (_) => const AdminListScreen(), settings: settings);

      case Routes.chatRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ChatView(
            requestId: args?['requestId'],
            requesterId: args?['requesterId'],
            interpreterId: args?['interpreterId'],
          ),
          settings: settings,
        );

      case Routes.requestWaiting:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RequestWaitingView(
            fromLanguageId: args['fromLanguageId'],
            toLanguageId: args['toLanguageId'],
            specialization: args['specialization'],
            urgency: args['urgency'],
            description: args['description'],
          ),
          settings: settings,
        );

      case Routes.documentTranslation:
        return MaterialPageRoute(builder: (_) => const DocumentTranslationView(), settings: settings);

      case Routes.privacyPolicy:
        return MaterialPageRoute(builder: (_) => const PrivacyPolicyView(), settings: settings);

      case Routes.termsOfService:
        return MaterialPageRoute(builder: (_) => const TermsOfServiceView(), settings: settings);

      case Routes.changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordView(), settings: settings);

      case Routes.phoneOtpRoute:
        return _buildRoute(const PhoneOtpWebScreen(), const PhoneOtpWebScreen(), settings: settings);

      case Routes.governmentIdUploadRoute:
        return _buildRoute(const GovernmentIdUploadWebScreen(), const GovernmentIdUploadWebScreen(), settings: settings);

      default:
        log('RouteGenerator: Unmatched route - ${settings.name}');
        if (settings.name?.contains('://') == true ||
            settings.name?.contains('code=') == true ||
            settings.name?.contains('token=') == true ||
            settings.name?.contains('token_hash=') == true ||
            settings.name?.contains('type=magiclink') == true ||
            settings.name?.contains('access_token=') == true) {
          return MaterialPageRoute(builder: (_) => const _AuthCallbackLoadingScreen(), settings: settings);
        }
        return unDefinedRoute();
    }
  }

  static Route<dynamic> unDefinedRoute() {
    return MaterialPageRoute(builder: (_) => const _UnknownRouteRecoveryScreen());
  }
}

Future<User?> _waitForAuthSession() async {
  User? user = Supabase.instance.client.auth.currentUser;
  int attempts = 0;
  while (user == null && attempts < 15) {
    await Future.delayed(const Duration(milliseconds: 200));
    user = Supabase.instance.client.auth.currentUser;
    if (user != null) break;
    attempts++;
  }
  return user;
}

class _UnknownRouteRecoveryScreen extends StatefulWidget {
  const _UnknownRouteRecoveryScreen();

  @override
  State<_UnknownRouteRecoveryScreen> createState() => _UnknownRouteRecoveryScreenState();
}

class _UnknownRouteRecoveryScreenState extends State<_UnknownRouteRecoveryScreen> {
  @override
  void initState() {
    super.initState();
    _recover();
  }
Future<void> _recover() async {
    final user = await _waitForAuthSession();

    if (user != null && user.emailConfirmedAt != null) {
      try {
        final profile = await SupabaseService().getUserProfile(user.id);
        final role = profile?.role;
        
        // FIX: Let the _InterpreterPortalGateWeb handle compliance and onboarding!
        // Do not check compliance here.
        final route = role == 'interpreter'
            ? Routes.interpreterPortalDashboardRoute
            : role == 'organization_admin'
                ? Routes.organizationPortalDashboardRoute
                : role == 'admin' || role == 'superadmin'
                    ? Routes.adminPortalDashboardRoute
                    : Routes.mainRoute;
        
        log('UnknownRouteRecovery: User authenticated, going to $route');
        Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
      } catch (_) {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } else {
      log('UnknownRouteRecovery: No auth, going to splash');
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.splashRoute, (route) => false);
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
      final user = await _waitForAuthSession();

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
    if (_isChecking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isAllowed) return const SizedBox.shrink();
    return widget.child;
  }
}

class _InterpreterPortalGateWeb extends StatefulWidget {
  const _InterpreterPortalGateWeb({required this.child});
  final Widget child;

  @override
  State<_InterpreterPortalGateWeb> createState() => _InterpreterPortalGateWebState();
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
      final user = await _waitForAuthSession();

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
      final profileData = await client.from('users_profile').select('employment_type').eq('user_id', user.id).maybeSingle();
      final detailsData = await client.from('interpreter_details').select('onboarding_status, is_verified, employment_type').eq('user_id', user.id).maybeSingle();

      final employmentType = detailsData?['employment_type'] as String? ?? profileData?['employment_type'] as String? ?? 'paid';
      final onboardingStatus = detailsData?['onboarding_status'] as String? ?? 'not_started';
      final isVerified = detailsData?['is_verified'] == true;

      if (isVerified || onboardingStatus == 'under_review') {
        final hasPassed = await ComplianceStorage.hasPassedCompliance(); // Read LocalStorage
        
        if (!hasPassed) {
          _redirect(Routes.interpreterComplianceRoute);
          return;
        }
        
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
            final rows = await client.from('interpreter_languages').select('language_id').eq('user_id', user.id);
            final languageIds = (rows as List).map((row) => row['language_id']).whereType<num>().map((id) => id.toInt()).toList();
            if (languageIds.isNotEmpty) resumeArgs['languages'] = languageIds;
          } catch (_) {}

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
    if (_isChecking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isAllowed) return const SizedBox.shrink();
    return widget.child;
  }
}

class _WebPortalEntryResolver extends StatefulWidget {
  const _WebPortalEntryResolver({this.kind});
  final _WebPortalKind? kind;

  @override
  State<_WebPortalEntryResolver> createState() => _WebPortalEntryResolverState();
}

class _WebPortalEntryResolverState extends State<_WebPortalEntryResolver> {
  bool _isResolving = true;
  Widget? _resolvedWidget;

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

    final user = await _waitForAuthSession();

    if (user == null) {
      if (widget.kind == _WebPortalKind.organization) {
        _redirect(Routes.organizationPortalLoginRoute);
      } else if (widget.kind == _WebPortalKind.admin) {
        _redirect(Routes.adminPortalLoginRoute);
      } else {
        if (mounted) {
          setState(() {
            _resolvedWidget = const AuthSelectionWeb();
            _isResolving = false;
          });
        }
      }
      return;
    }

    try {
      final profile = await SupabaseService().getUserProfile(user.id);
      final role = profile?.role;
      final allowed = (widget.kind == _WebPortalKind.organization && role == 'organization_admin') ||
                      (widget.kind == _WebPortalKind.interpreter && role == 'interpreter') ||
                      (widget.kind == _WebPortalKind.admin && (role == 'admin' || role == 'superadmin'));

      if (allowed) {
        if (widget.kind == _WebPortalKind.interpreter) {
          // FIX: Removed the manual compliance check! 
          // Redirecting to the Dashboard route forces the _InterpreterPortalGateWeb 
          // to correctly check onboarding status first.
          _redirect(Routes.interpreterPortalDashboardRoute);
        } else if (widget.kind == _WebPortalKind.organization) {
          _redirect(Routes.organizationPortalDashboardRoute);
        } else {
          _redirect(Routes.adminPortalDashboardRoute);
        }
        return;
      }

      await SupabaseService().signOut();
      if (widget.kind == _WebPortalKind.interpreter) {
        _redirect(Routes.interpreterPortalRootRoute);
      } else {
        _redirect(targetLogin);
      }
    } catch (e) {
      log('WebPortalEntryResolver error: $e');
      if (mounted) {
        setState(() {
          _resolvedWidget = const AuthSelectionWeb();
          _isResolving = false;
        });
      }
    }
  }

  void _redirect(String route) {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolving) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81))),
      );
    }
    return _resolvedWidget ?? const AuthSelectionWeb();
  }
}

class _AuthCallbackLoadingScreen extends StatefulWidget {
  const _AuthCallbackLoadingScreen();

  @override
  State<_AuthCallbackLoadingScreen> createState() => _AuthCallbackLoadingScreenState();
}

class _AuthCallbackLoadingScreenState extends State<_AuthCallbackLoadingScreen> {
  String _statusMessage = 'Authenticating your secure link...';
  bool _hasError = false;
  
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _handleAuthCallback();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  void _handleAuthCallback() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        _authSub.cancel();
        await _finalizeAndNavigate(session.user.id);
      }
    });

    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        _authSub.cancel();
        await _finalizeAndNavigate(session.user.id);
      } else {
        if (mounted) setState(() => _statusMessage = 'Waiting for secure connection...');
        
        Future.delayed(const Duration(seconds: 4), () {
          if (!mounted) return;
          final retrySession = Supabase.instance.client.auth.currentSession;
          if (retrySession != null) {
            _authSub.cancel();
            _finalizeAndNavigate(retrySession.user.id);
          } else {
            _authSub.cancel();
            if (mounted) Navigator.of(context).pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);
          }
        });
      }
    });
  }Future<void> _finalizeAndNavigate(String userId) async {
    if (!mounted) return;
    setState(() => _statusMessage = 'Email verified! Setting up your workspace...');
    
    try {
      await PendingRegistrationService().finalizePendingRegistration();
    } catch (e) {
      log('AuthCallback Error finalizing data: $e');
    }

    if (!mounted) return;
    
    // We removed the signOut() command! 
    // The magic link securely authenticates the user. We just pass them to 
    // the dashboard router. The _InterpreterPortalGateWeb will seamlessly 
    // bypass the camera screen and drop them directly at Select Language.
    try {
      final profile = await SupabaseService().getUserProfile(userId);
      if (profile?.role == 'interpreter') {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterPortalDashboardRoute, (route) => false);
      } else if (profile?.role == 'organization_admin') {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.organizationPortalDashboardRoute, (route) => false);
      } else if (profile?.role == 'admin' || profile?.role == 'superadmin') {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.adminPortalDashboardRoute, (route) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (_) {
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
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
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterPortalDashboardRoute, (route) => false);
      return true;
    }

    final resumeArgs = _buildInterpreterResumeArgs(employmentType);

    switch (onboardingStatus) {
      case 'not_started':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterTrackSelection, (route) => false, arguments: resumeArgs);
        return true;
      case 'track_selected':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.selectLanguage, (route) => false, arguments: resumeArgs);
        return true;
      case 'languages_selected':
        try {
          final rows = await client.from('interpreter_languages').select('language_id').eq('user_id', userId);
          final languageIds = (rows as List).map((row) => row['language_id']).whereType<num>().map((id) => id.toInt()).toList();
          if (languageIds.isNotEmpty) resumeArgs['languages'] = languageIds;
        } catch (_) {}

        if (!mounted) return true;
        if ((resumeArgs['languages'] as List?)?.isNotEmpty == true) {
          Navigator.of(context).pushNamedAndRemoveUntil(Routes.languageFluencyScreen, (route) => false, arguments: resumeArgs);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(Routes.selectLanguage, (route) => false, arguments: resumeArgs);
        }
        return true;
      case 'fluency_selected':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterFieldScreen, (route) => false, arguments: resumeArgs);
        return true;
      case 'specialization_selected':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.voiceSampleRoute, (route) => false, arguments: resumeArgs);
        return true;
      case 'voice_sample_uploaded':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.phoneOtpRoute, (route) => false, arguments: resumeArgs);
        return true;
      case 'phone_entered':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.governmentIdUploadRoute, (route) => false, arguments: resumeArgs);
        return true;
      case 'government_id_uploaded':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.certificateUploadRoute, (route) => false, arguments: resumeArgs);
        return true;
      case 'document_uploaded':
        if (!mounted) return true;
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterQuizHubRoute, (route) => false);
        return true;
      default:
        return false;
    }
  }

  Future<void> _navigateBasedOnRole(String userId) async {
    try {
      final profile = await SupabaseService().getUserProfile(userId);
      if (!mounted) return;

      if (profile == null) {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
        return;
      }

      if (profile.role == 'organization_admin') {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.organizationPortalDashboardRoute, (route) => false);
      } else if (profile.role == 'admin' || profile.role == 'superadmin') {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.adminPortalDashboardRoute, (route) => false);
      } else if (profile.role == 'interpreter') {
        final appPrefs = instance<AppPreferences>();
        try {
          final client = Supabase.instance.client;
          final profileFuture = client.from('users_profile').select('employment_type').eq('user_id', userId).maybeSingle();
          final detailsFuture = client.from('interpreter_details').select('onboarding_status, is_verified, employment_type').eq('user_id', userId).maybeSingle();
          final attemptsFuture = client.from('quiz_attempts').select('quiz_type').eq('user_id', userId).eq('quiz_type', 'general');
          final fluencyFuture = client.from('voice_samples').select('id').eq('user_id', userId).eq('sentence_type', advancedFluencySentenceType);

          final results = await Future.wait<dynamic>([profileFuture, detailsFuture, attemptsFuture, fluencyFuture]);
          final profileData = results[0] as Map<String, dynamic>?;
          final detailsData = results[1] as Map<String, dynamic>?;
          final attemptsData = results[2] as List<dynamic>;
          final fluencyData = results[3] as List<dynamic>;

          final employmentType = detailsData?['employment_type'] as String? ?? profileData?['employment_type'] as String? ?? 'paid';
          final onboardingStatus = detailsData?['onboarding_status'] as String? ?? 'not_started';
          final isVerified = detailsData?['is_verified'] == true;

          final resumed = await _resumeInterpreterOnboarding(client: client, userId: userId, onboardingStatus: onboardingStatus, employmentType: employmentType, isVerified: isVerified);
          if (resumed) return;

          final hasGeneralAttempt = attemptsData.isNotEmpty;
          final hasAdvancedFluency = fluencyData.length >= advancedFluencyQuestionCount;
          final bool allComplete = hasGeneralAttempt && hasAdvancedFluency;

          if (!mounted) return;
          if (allComplete) {
            await appPrefs.setQuizOnboardingDone();
            
            final hasPassed = await ComplianceStorage.hasPassedCompliance(); // Read LocalStorage
            if (!mounted) return;
            
            if (!hasPassed) {
              Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterComplianceRoute, (route) => false);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterPortalDashboardRoute, (route) => false);
            }
            
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterQuizHubRoute, (route) => false);
          }
        } catch (e) {
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(Routes.interpreterQuizHubRoute, (route) => false);
        }
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_hasError) 
              const Icon(Icons.error_outline, size: 48, color: Colors.red) 
            else 
              const CircularProgressIndicator(color: Color(0xFF0F4C81)),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 16, 
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalSectionsRouteWrapper extends StatefulWidget {
  const _MedicalSectionsRouteWrapper();

  @override
  State<_MedicalSectionsRouteWrapper> createState() => _MedicalSectionsRouteWrapperState();
}

class _MedicalSectionsRouteWrapperState extends State<_MedicalSectionsRouteWrapper> {
  final List<String> _allSections = ['neurology', 'cardiology', 'respiratory', 'gastrointestinal', 'endocrinology', 'renal', 'ob_gyn', 'oncology', 'emergency', 'psychology', 'musculoskeletal'];
  Set<String> _earnedSections = {};
  int _currentSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSequentialQuizzes());
  }

  Future<void> _startSequentialQuizzes() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    _earnedSections = (args['medicalSectionsPassed'] as Set<String>?) ?? <String>{};

    while (_currentSectionIndex < _allSections.length && mounted) {
      final sectionId = _allSections[_currentSectionIndex];
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => QuizScreen(quizType: 'medical', medicalSection: sectionId)),
      );

      if (!mounted) return;
      if (result != null && result['passed'] == true) {
        setState(() => _earnedSections.add(sectionId));
      }
      _currentSectionIndex++;
    }

    if (!mounted) return;
    args['medicalSectionsPassed'] = _earnedSections;

    if (_earnedSections.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed(Routes.registerRoute, arguments: args);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _GeneralQuizRouteWrapper extends StatefulWidget {
  const _GeneralQuizRouteWrapper();

  @override
  State<_GeneralQuizRouteWrapper> createState() => _GeneralQuizRouteWrapperState();
}

class _GeneralQuizRouteWrapperState extends State<_GeneralQuizRouteWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToQuiz());
  }

  Future<void> _navigateToQuiz() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const QuizScreen(quizType: 'general', isRequired: true)),
    );

    if (!mounted) return;
    if (result != null && result['passed'] == true) {
      args['generalQuizPassed'] = true;
      args['generalQuizScore'] = result['score'];

      final track = args['interpreterTrack'] ?? args['track'] ?? args['interpreterLevel'];
      final isPaid = track == 'paid' || track == 'pro' || (track is String && (track.toLowerCase().contains('paid') || track.toLowerCase().contains('pro')));

      if (isPaid) {
        Navigator.of(context).pushReplacementNamed(Routes.medicalSectionsRoute, arguments: args);
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.volunteerSuccessRoute, arguments: args);
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _GeneralQuizRouteWrapperWeb extends StatefulWidget {
  const _GeneralQuizRouteWrapperWeb();

  @override
  State<_GeneralQuizRouteWrapperWeb> createState() => _GeneralQuizRouteWrapperWebState();
}

class _GeneralQuizRouteWrapperWebState extends State<_GeneralQuizRouteWrapperWeb> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToQuiz());
  }

  Future<void> _navigateToQuiz() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdvancedFluencyQuizScreen()),
    );

    if (!mounted) return;
    if (result == true) {
      args['generalQuizPassed'] = true;

      final track = args['interpreterTrack'] ?? args['track'] ?? args['interpreterLevel'];
      final isPaid = track == 'paid' || track == 'pro' || (track is String && (track.toLowerCase().contains('paid') || track.toLowerCase().contains('pro')));

      if (isPaid) {
        Navigator.of(context).pushReplacementNamed(Routes.medicalSectionsRoute, arguments: args);
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.volunteerSuccessRoute, arguments: args);
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _MedicalSectionsRouteWrapperWeb extends StatefulWidget {
  const _MedicalSectionsRouteWrapperWeb();

  @override
  State<_MedicalSectionsRouteWrapperWeb> createState() => _MedicalSectionsRouteWrapperWebState();
}

class _MedicalSectionsRouteWrapperWebState extends State<_MedicalSectionsRouteWrapperWeb> {
  final List<String> _allSections = ['neurology', 'cardiology', 'respiratory', 'gastrointestinal', 'endocrinology', 'renal', 'ob_gyn', 'oncology', 'emergency', 'psychology', 'musculoskeletal'];
  Set<String> _earnedSections = {};
  int _currentSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSequentialQuizzes());
  }

  Future<void> _startSequentialQuizzes() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    _earnedSections = (args['medicalSectionsPassed'] as Set<String>?) ?? <String>{};

    while (_currentSectionIndex < _allSections.length && mounted) {
      final sectionId = _allSections[_currentSectionIndex];
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => QuizWebScreen(quizType: 'medical', medicalSection: sectionId)),
      );

      if (!mounted) return;
      if (result != null && result['passed'] == true) {
        setState(() => _earnedSections.add(sectionId));
      }
      _currentSectionIndex++;
    }

    if (!mounted) return;
    args['medicalSectionsPassed'] = _earnedSections;

    if (_earnedSections.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed(Routes.registerRoute, arguments: args);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}