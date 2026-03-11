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
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_bloc.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_event.dart';
import 'package:interbridge/presentation/screens/auth/login_screen/view_Model/bloc/login_state.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';

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
  bool _rememberMe = false;

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
      await _navigateBasedOnRole(user.id);
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
          _navigateBasedOnRole(event.session!.user.id);
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
        await _navigateBasedOnRole(recheck.id);
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

  Future<void> _navigateBasedOnRole(String userId) async {
    try {
      final profile = await _supabaseService.getUserProfile(userId);
      if (!mounted) return;

      if (profile?.role == 'organization_admin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.organizationDashboardRoute,
          (route) => false,
        );
      } else if (profile?.role == 'interpreter') {
        // Only check quizzes on first login — skip if already completed once
        final appPrefs = instance<AppPreferences>();
        if (appPrefs.isQuizOnboardingDone()) {
          if (!mounted) return;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
        } else {
          // Check interpreter quiz badge completion before navigating
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
            log('Error checking interpreter badges: $e');
            if (!mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
          }
        }
      } else {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (e) {
      log('Error getting user profile: $e');
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    }
  }

  Future<void> _requestPermissionsAndNavigate() async {
    try {
      final userId = _supabaseService.getCurrentUser()?.id;

      if (mounted) {
        if (userId != null) {
          await _navigateBasedOnRole(userId);
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
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
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthWebWrapper(
      title: 'Welcome back',
      subtitle: 'Sign in to your interpreter account to get started',
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
                    .finalizePendingRegistration();
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

                  // Remember me + Forgot
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged:
                                  (v) =>
                                      setState(() => _rememberMe = v ?? false),
                              activeColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Remember me',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
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
                            color: Color(0xFF3B82F6),
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
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(
                          0xFF0F172A,
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
                  const SizedBox(height: 28),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'New to InterBridge?',
                          style: TextStyle(
                            color: const Color(
                              0xFF64748B,
                            ).withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Create account button
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pushNamed(Routes.interpreterTrackSelection),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Create an interpreter account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
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
        color: Color(0xFF374151),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF94A3B8),
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
