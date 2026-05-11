import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/app/app_initializer.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/services/onesignal_service.dart';
import 'package:interbridge/data/services/permission_service.dart';
import 'package:interbridge/data/services/pending_registration_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/quiz/advanced_fluency_quiz_constants.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_bloc.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_event.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_state.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/screens/interpreter/interpreter_login_compliance_screen.dart';
import 'package:interbridge/presentation/screens/legal/interpreter_agreements_view.dart';

/// Professional interpreter-focused web login view
class LoginViewWeb extends StatelessWidget {
  const LoginViewWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: const _LoginViewWebBody(),
    );
  }
}

class _LoginViewWebBody extends StatefulWidget {
  const _LoginViewWebBody();

  @override
  State<_LoginViewWebBody> createState() => _LoginViewWebBodyState();
}

class _LoginViewWebBodyState extends State<_LoginViewWebBody> {
  final AppPreferences _appPreferences = instance<AppPreferences>();
  final SupabaseService _supabaseService = SupabaseService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  StreamSubscription<AuthState>? _authSub;
  bool _isNavigating = false;
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    // Immediate check — session may already be available
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.emailConfirmedAt != null) {
      if (_isNavigating) return;
      _isNavigating = true;
      AppInitializer.markInitialAuthHandled();
      // Finalize pending registration BEFORE navigating so the profile,
      // certificates, and voice samples are persisted first.
      if (mounted) setState(() => _isFinalizing = true);
      try {
        await PendingRegistrationService().finalizePendingRegistration();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      await _navigateBasedOnRole(user.id, enforceComplianceCheck: false);
      return;
    }

    // If a deep link (magic link) is pending, wait for the auth to complete
    if (AppInitializer.deepLinkPending) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
        event,
      ) async {
        if (event.event == AuthChangeEvent.signedIn && event.session != null) {
          _authSub?.cancel();
          if (_isNavigating) return;
          _isNavigating = true;
          AppInitializer.markInitialAuthHandled();
          if (mounted) setState(() => _isFinalizing = true);
          try {
            await PendingRegistrationService().finalizePendingRegistration();
          } catch (_) {}
          if (!mounted) return;
          setState(() => _isFinalizing = false);
          _navigateBasedOnRole(
            event.session!.user.id,
            enforceComplianceCheck: false,
          );
        }
      });

      // Re-check in case the event fired between our check and subscription
      final recheck = Supabase.instance.client.auth.currentUser;
      if (recheck != null && recheck.emailConfirmedAt != null) {
        _authSub?.cancel();
        if (_isNavigating) return;
        _isNavigating = true;
        AppInitializer.markInitialAuthHandled();
        await PendingRegistrationService().finalizePendingRegistration();
        if (!mounted) return;
        await _navigateBasedOnRole(recheck.id, enforceComplianceCheck: false);
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
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

  Future<bool> _runInterpreterComplianceCheck() async {
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const InterpreterLoginComplianceScreen(),
      ),
    );
    return passed == true;
  }

  String _currentPortalIntent() {
    if (!kIsWeb) return 'shared';

    final path = Uri.base.path.toLowerCase();
    final host = Uri.base.host.toLowerCase();

    if (path.startsWith('/admin') || host.startsWith('admin.')) {
      return 'admin';
    }
    if (path.startsWith('/organization') || host.startsWith('organization.')) {
      return 'organization';
    }
    if (path.startsWith('/interpreter') || host.startsWith('interpreter.')) {
      return 'interpreter';
    }

    return 'shared';
  }

  bool _roleMatchesPortal(String? role, String portalIntent) {
    switch (portalIntent) {
      case 'admin':
        return role == 'admin' || role == 'superadmin';
      case 'organization':
        return role == 'organization_admin';
      case 'interpreter':
        return role == 'interpreter';
      default:
        return true;
    }
  }

  String _loginRouteForPortal(String portalIntent) {
    switch (portalIntent) {
      case 'admin':
        return Routes.adminPortalLoginRoute;
      case 'organization':
        return Routes.organizationPortalLoginRoute;
      case 'interpreter':
        return Routes.interpreterPortalLoginRoute;
      default:
        return Routes.loginRoute;
    }
  }

  Future<String?> _recoverRoleForInterpreterPortal({
    required String userId,
    required String? role,
  }) async {
    if (role != 'requester' && role != null) return role;

    try {
      // Do not convert doctors already linked to an organization.
      final membership =
          await Supabase.instance.client
              .from('organization_members')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();
      if (membership != null) {
        return role;
      }

      await Supabase.instance.client.from('users_profile').upsert({
        'user_id': userId,
        'role': 'interpreter',
        'employment_type': 'volunteer',
      }, onConflict: 'user_id');

      await Supabase.instance.client.from('interpreter_details').upsert({
        'user_id': userId,
        'onboarding_status': 'not_started',
        'employment_type': 'volunteer',
      }, onConflict: 'user_id');

      return 'interpreter';
    } catch (e) {
      log('Interpreter portal role recovery failed: $e');
      return role;
    }
  }

  String _loginTitleForPortal(String portalIntent) {
    switch (portalIntent) {
      case 'admin':
        return 'Admin Login';
      case 'organization':
        return 'Organization Login';
      case 'interpreter':
        return 'Interpreter Login';
      default:
        return 'Sign in to InterBridge';
    }
  }

  String _loginSubtitleForPortal(String portalIntent) {
    switch (portalIntent) {
      case 'admin':
        return 'Sign in with your admin account';
      case 'organization':
        return 'Sign in to manage your organization';
      case 'interpreter':
        return 'Sign in to access your interpreter dashboard';
      default:
        return 'Sign in to continue';
    }
  }

  bool _canSelfRegisterInPortal(String portalIntent) {
    return portalIntent != 'admin';
  }

  String _signupSectionLabelForPortal(String portalIntent) {
    switch (portalIntent) {
      case 'interpreter':
        return 'New interpreter?';
      case 'organization':
        return 'Need organization access?';
      default:
        return 'New to InterBridge?';
    }
  }

  String _signupButtonLabelForPortal(String portalIntent) {
    switch (portalIntent) {
      case 'interpreter':
        return 'Apply to Join The Interpreter Network';
      case 'organization':
        return 'Register an Organization';
      default:
        return 'Apply to Join The Interpreter Network';
    }
  }

  void _handleSignupByPortal(String portalIntent) {
    switch (portalIntent) {
      case 'interpreter':
        Navigator.of(
          context,
        ).pushNamed(Routes.registerRoute, arguments: {'role': 'interpreter'});
        return;
      case 'organization':
        Navigator.of(context).pushNamed(Routes.organizationRegisterRoute);
        return;
      case 'admin':
        CustomSnackBar.show(
          context,
          message: 'Admin accounts are created by system administrators.',
          type: SnackBarType.info,
        );
        return;
      default:
        Navigator.of(context).pushNamed(Routes.selectRole);
    }
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
          // If we fail to hydrate languages, fallback route still lets user continue.
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

  Future<void> _navigateBasedOnRole(
    String userId, {
    bool enforceComplianceCheck = true,
  }) async {
    try {
      final profile = await _supabaseService
          .getUserProfile(userId)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;

      final portalIntent = _currentPortalIntent();
      String? role = profile?.role;

      // Recovery path: if a requester logs in through interpreter portal,
      // try auto-promoting to interpreter role first.
      if (portalIntent == 'interpreter') {
        role = await _recoverRoleForInterpreterPortal(
          userId: userId,
          role: role,
        );

        // If role is still requester or null (for example DB update blocked),
        // continue to interpreter onboarding instead of hard-blocking login.
        if (role == 'requester' || role == null) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.interpreterTrackSelection,
            (route) => false,
            arguments: {
              'role': 'interpreter',
              'authContinuationFullScreen': true,
              'forceInterpreterRoleUpgrade': true,
            },
          );
          return;
        }

        // Guard against legacy/unknown roles from older builds.
        // If it's not an admin/organization role, continue with interpreter onboarding.
        if (role != 'interpreter' &&
            role != 'organization_admin' &&
            role != 'admin' &&
            role != 'superadmin') {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.interpreterTrackSelection,
            (route) => false,
            arguments: {
              'role': 'interpreter',
              'authContinuationFullScreen': true,
              'forceInterpreterRoleUpgrade': true,
            },
          );
          return;
        }
      }

      if (!_roleMatchesPortal(role, portalIntent)) {
        await _supabaseService.signOut();
        await _appPreferences.logout();
        if (!mounted) return;
        CustomSnackBar.show(
          context,
          message:
              'This account is not allowed in this portal. Please use the correct portal login.',
          type: SnackBarType.error,
        );
        Navigator.of(context).pushNamedAndRemoveUntil(
          _loginRouteForPortal(portalIntent),
          (route) => false,
        );
        return;
      }

      if (role == 'admin' || role == 'superadmin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.adminPortalDashboardRoute,
          (route) => false,
        );
      } else if (role == 'organization_admin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.organizationPortalDashboardRoute,
          (route) => false,
        );
      } else if (role == 'interpreter') {
        final interpreterDetails = await _supabaseService.getInterpreterDetails(
          userId,
        );
        if (!mounted) return;

        // Enforce compliance only for actual login flow, not restored sessions on refresh.
        if (enforceComplianceCheck && interpreterDetails?.isVerified == true) {
          // Check for legal agreements first
          if (interpreterDetails?.hasAcceptedAgreements != true) {
            final accepted = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => InterpreterAgreementsView(
                  onAccept: () => Navigator.of(context).pop(true),
                ),
              ),
            );
            if (!mounted) return;

            if (accepted != true) {
              await _supabaseService.signOut();
              await _appPreferences.logout();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.interpreterPortalLoginRoute,
                (route) => false,
              );
              return;
            } else {
              await Supabase.instance.client
                  .from('interpreter_details')
                  .update({'has_accepted_agreements': true})
                  .eq('user_id', userId);
            }
          }

          final passedCompliance = await _runInterpreterComplianceCheck();
          if (!mounted) return;
          if (!passedCompliance) {
            await _supabaseService.signOut();
            await _appPreferences.logout();
            if (!mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.interpreterPortalLoginRoute,
              (route) => false,
            );
            return;
          }
        }

        final appPrefs = instance<AppPreferences>();
        // Check interpreter badge completion and onboarding status before navigating.
        try {
          final client = Supabase.instance.client;

          final Future<Map<String, dynamic>?> profileFuture =
              client
                  .from('users_profile')
                  .select('employment_type')
                  .eq('user_id', userId)
                  .maybeSingle();

          final Future<Map<String, dynamic>?> detailsFuture =
              client
                  .from('interpreter_details')
                  .select('onboarding_status, is_verified')
                  .eq('user_id', userId)
                  .maybeSingle();

          final Future<List<Map<String, dynamic>>> badgesFuture = client
              .from('interpreter_badges')
              .select('badge')
              .eq('user_id', userId);
          final Future<List<Map<String, dynamic>>> fluencyFuture = client
              .from('voice_samples')
              .select('id')
              .eq('user_id', userId)
              .eq('sentence_type', advancedFluencySentenceType);

          final results = await Future.wait<dynamic>([
            profileFuture,
            badgesFuture,
            detailsFuture,
            fluencyFuture,
          ]).timeout(const Duration(seconds: 5));

          final profileData = results[0] as Map<String, dynamic>?;
          final badgesData = results[1] as List<Map<String, dynamic>>;
          final detailsData = results[2] as Map<String, dynamic>?;
          final fluencyData = results[3] as List<Map<String, dynamic>>;

          final employmentType = profileData?['employment_type'] ?? 'volunteer';

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
            // Update onboarding status to under_review since quizzes are done
            await client
                .from('interpreter_details')
                .update({'onboarding_status': 'under_review'})
                .eq('user_id', userId);
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
          log('Error checking interpreter badges: $e');
          if (!mounted) return;
          // If checks fail/timeout, prefer quiz route for onboarding users.
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
      log('Error getting user profile: $e');
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        _loginRouteForPortal(_currentPortalIntent()),
        (route) => false,
      );
    }
  }

  Future<void> _requestPermissionsAndNavigate() async {
    try {
      final userId = _supabaseService.getCurrentUser()?.id;

      if (mounted) {
        if (userId != null) {
          await _navigateBasedOnRole(userId);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            _loginRouteForPortal(_currentPortalIntent()),
            (route) => false,
          );
        }
      }

      if (!kIsWeb) {
        final permissionResults =
            await PermissionService.requestAllAppPermissions();
        log('Permission results: $permissionResults');
      }
    } catch (e) {
      log('Error requesting permissions: $e');

      if (mounted) {
        final userId = _supabaseService.getCurrentUser()?.id;
        if (userId != null) {
          await _navigateBasedOnRole(userId);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            _loginRouteForPortal(_currentPortalIntent()),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final portalIntent = _currentPortalIntent();
    final showSignupSection = _canSelfRegisterInPortal(portalIntent);

    return AuthWebWrapper(
      title: _loginTitleForPortal(portalIntent),
      subtitle: _loginSubtitleForPortal(portalIntent),
      child: BlocListener<LoginBloc, LoginState>(
        listener: (context, state) {
          if (!mounted) return;

          if (state.isSuccess) {
            // Prevent multiple navigation attempts
            if (_isNavigating) return;
            _isNavigating = true;

            CustomSnackBar.show(
              context,
              message: 'Login successful! Welcome back.',
              type: SnackBarType.success,
              duration: const Duration(seconds: 2),
            );

            // Navigate immediately — no unnecessary delay
            () async {
              if (!mounted) {
                _isNavigating = false;
                return;
              }
              setState(() => _isFinalizing = true);
              try {
                await PendingRegistrationService()
                    .finalizePendingRegistration()
                    .timeout(const Duration(seconds: 5));
                await _appPreferences.setLoginViewed();

                if (!kIsWeb) {
                  final oneSignalService = instance<OneSignalService>();
                  final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
                  if (oneSignalAppId != null &&
                      oneSignalAppId.isNotEmpty &&
                      !oneSignalService.isInitialized) {
                    await oneSignalService.initialize(oneSignalAppId);
                  }
                  await oneSignalService.refreshPlayerId();
                }

                if (mounted) {
                  await _requestPermissionsAndNavigate();
                }
              } catch (e) {
                log('Error during post-login navigation: $e');
                _isNavigating = false;
                if (mounted) setState(() => _isFinalizing = false);
                if (mounted) {
                  // Fallback: try to navigate to main route
                  final userId = _supabaseService.getCurrentUser()?.id;
                  if (userId != null) {
                    await _navigateBasedOnRole(userId);
                  }
                }
              }
            }();
          }

          if (state.isFailure && state.errorMessage != null) {
            _isNavigating = false;
            CustomSnackBar.show(
              context,
              message: state.errorMessage!,
              type: SnackBarType.error,
            );
          }
        },
        child: BlocBuilder<LoginBloc, LoginState>(
          builder: (context, state) {
            final bloc = context.read<LoginBloc>();
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email
                  _buildLabel('Email'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    hintText: 'name@company.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => bloc.add(LoginEmailChanged(value)),
                    onSubmitted:
                        (_) =>
                            FocusScope.of(context).requestFocus(_passwordFocus),
                  ),
                  const SizedBox(height: 20),

                  // Password
                  _buildLabel('Password'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    hintText: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: !_isPasswordVisible,
                    onChanged: (value) => bloc.add(LoginPasswordChanged(value)),
                    onSubmitted: (_) {
                      if (!state.isSubmitting) bloc.add(LoginSubmitted());
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Forgot password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            () => Navigator.pushNamed(
                              context,
                              Routes.forgotPasswordRoute,
                            ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Sign in button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          state.isSubmitting || _isFinalizing
                              ? null
                              : () => bloc.add(LoginSubmitted()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(
                          0xFF3B82F6,
                        ).withValues(alpha: 0.5),
                      ),
                      child:
                          state.isSubmitting || _isFinalizing
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                  if (_isFinalizing) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Setting up your account, please wait...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                  if (showSignupSection) ...[
                    const SizedBox(height: 28),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _signupSectionLabelForPortal(portalIntent),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Create account button
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => _handleSignupByPortal(portalIntent),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _signupButtonLabelForPortal(portalIntent),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Function(String)? onChanged,
    Function(String)? onSubmitted,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 15, color: Colors.black),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.black.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: Colors.black.withValues(alpha: 0.5),
            size: 20,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
