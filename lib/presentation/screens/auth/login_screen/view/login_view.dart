import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:interbridge/data/services/onesignal_service.dart';
import 'package:interbridge/data/services/permission_service.dart';
import 'package:interbridge/data/services/pending_registration_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/interpreter/interpreter_login_compliance_screen.dart';
import 'package:interbridge/presentation/screens/legal/interpreter_agreements_view.dart';
import 'package:interbridge/presentation/widgets/simple_fade_animation.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../view_Model/bloc/login_bloc.dart';
import '../view_Model/bloc/login_event.dart';
import '../view_Model/bloc/login_state.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: const _LoginViewBody(),
    );
  }
}

class _LoginViewBody extends StatefulWidget {
  const _LoginViewBody();

  @override
  State<_LoginViewBody> createState() => _LoginViewBodyState();
}

class _LoginViewBodyState extends State<_LoginViewBody> {
  final AppPreferences _appPreferences = instance<AppPreferences>();
  final SupabaseService _supabaseService = SupabaseService();

  Future<bool> _runInterpreterComplianceCheck() async {
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const InterpreterLoginComplianceScreen(),
      ),
    );
    return passed == true;
  }

  Future<void> _navigateBasedOnRole(String userId) async {
    try {
      final profile = await _supabaseService.getUserProfile(userId);
      if (!mounted) return;

      if (profile?.role == 'admin' || profile?.role == 'superadmin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.adminPortalDashboardRoute,
          (route) => false,
        );}

        else if (profile?.role == 'requester' ) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.mainRoute,
          (route) => false,
        );
      } else if (profile?.role == 'organization_admin') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.organizationDashboardRoute,
          (route) => false,
        );
      } else if (profile?.role == 'interpreter') {
        final interpreterDetails = await _supabaseService.getInterpreterDetails(userId);
        if (!mounted) return;

        // Only enforce compliance picture if they are fully verified
        if (interpreterDetails?.isVerified == true) {
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
                Routes.loginRoute,
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

        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.interpreterPortalDashboardRoute,
          (route) => false,
        );
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
      // Get current user ID for role-based navigation
      final userId = _supabaseService.getCurrentUser()?.id;

      // Request all app permissions
      if (mounted) {
        if (userId != null) {
          await _navigateBasedOnRole(userId);
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
        }
      }
      final permissionResults =
          await PermissionService.requestAllAppPermissions();

      // Log permission results
      log('Permission results: $permissionResults');

      // Show permission summary to user
      final grantedPermissions =
          permissionResults.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();

      final deniedPermissions =
          permissionResults.entries
              .where((entry) => !entry.value)
              .map((entry) => entry.key)
              .toList();

      if (grantedPermissions.isNotEmpty) {
        log('Granted permissions: $grantedPermissions');
      }

      if (deniedPermissions.isNotEmpty) {
        log('Denied permissions: $deniedPermissions');

        // Show a brief message about denied permissions
        if (mounted) {
          CustomSnackBar.show(
            context,
            message:
                'Some permissions were denied. You can enable them in app settings.',
            type: SnackBarType.warning,
            duration: const Duration(seconds: 3),
          );
        }
      }

      // Navigate to main screen
    } catch (e) {
      log('Error requesting permissions: $e');

      // Navigate anyway if permissions fail - use role-based navigation
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
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: BlocListener<LoginBloc, LoginState>(
            listener: (context, state) {
              if (!mounted) return;

              // Handle login success
              if (state.isSuccess) {
                // Show success message briefly before navigation
                CustomSnackBar.show(
                  context,
                  message: 'Login successful! Welcome back.',
                  type: SnackBarType.success,
                  duration: const Duration(seconds: 2),
                );

                // Navigate to main screen after a short delay
                Future.delayed(const Duration(milliseconds: 200), () async {
                  if (mounted) {
                    await PendingRegistrationService()
                        .finalizePendingRegistration();
                    await _appPreferences.setLoginViewed();

                    // Initialize OneSignal if not already initialized
                    final oneSignalService = instance<OneSignalService>();
                    final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
                    if (oneSignalAppId != null &&
                        oneSignalAppId.isNotEmpty &&
                        !oneSignalService.isInitialized) {
                      await oneSignalService.initialize(oneSignalAppId);
                    }
                    // Always refresh player ID after login to ensure it's registered
                    await oneSignalService.refreshPlayerId();

                    await _requestPermissionsAndNavigate();
                  }
                });
              }

              // Handle login failure
              if (state.isFailure && state.errorMessage != null) {
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
                  child: Padding(
                    padding: const EdgeInsets.all(AppSize.s24),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSize.s40),
                        // Welcome Section
                // Welcome Section
                        SimpleFadeAnimation(
                          child: Column(
                            children: [
                              // Updated Logo Container
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppSize.s24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ColorManager.primary2.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: AppSize.s24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppSize.s24),
                                  child: Image.asset(
                                    'assets/images/app_icons.png', // Ensure this matches your asset
                                    width: AppSize.s90, // Slightly larger for better brand visibility
                                    height: AppSize.s90,
                                    fit: BoxFit.cover,
                                    // NOTE: Removed the 'color' property so your original gradient and black background show perfectly
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSize.s24),
                              Text(
                                AppStrings.welcomeBackExclamation,
                                style: TextStyle(
                                  fontSize: AppSize.s28,
                                  fontWeight: FontWeight.bold,
                                  color: ColorManager.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSize.s8),
                              Text(
                                'Secure, Compliant, Ready to Connect.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: AppSize.s16,
                                  color: ColorManager.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSize.s40),
                        // Login Form
                        SimpleFadeAnimation(
                          delay: const Duration(milliseconds: 200),
                          child: Column(
                            children: [
                              // Email Field
                              Container(
                                margin: const EdgeInsets.only(
                                  bottom: AppSize.s16,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorManager.backgroundCard,
                                  borderRadius: BorderRadius.circular(
                                    AppSize.s12,
                                  ),
                                  border: Border.all(
                                    color: ColorManager.greyMedium.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: TextFormField(
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  keyboardType: TextInputType.emailAddress,
                                  initialValue: state.email,
                                  onChanged:
                                      (value) =>
                                          bloc.add(LoginEmailChanged(value)),
                                  decoration: InputDecoration(
                                    labelText: AppStrings.email,
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: ColorManager.primary2,
                                      size: AppSize.s20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(
                                      AppSize.s16,
                                    ),
                                  ),
                                ),
                              ),
                              // Password Field
                              Container(
                                margin: const EdgeInsets.only(
                                  bottom: AppSize.s16,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorManager.backgroundCard,
                                  borderRadius: BorderRadius.circular(
                                    AppSize.s12,
                                  ),
                                  border: Border.all(
                                    color: ColorManager.greyMedium.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: TextFormField(
                                  keyboardType: TextInputType.visiblePassword,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  initialValue: state.password,
                                  onChanged:
                                      (value) =>
                                          bloc.add(LoginPasswordChanged(value)),
                                  obscureText: state.isPasswordVisible,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.password,
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: ColorManager.primary2,
                                      size: AppSize.s20,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        bloc.add(
                                          LoginPasswordVisibilityToggled(),
                                        );
                                      },
                                      icon: Icon(
                                        state.isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: ColorManager.primary2,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(
                                      AppSize.s16,
                                    ),
                                  ),
                                ),
                              ),
                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      Routes.forgotPasswordRoute,
                                    );
                                  },
                                  child: Text(
                                    AppStrings.forgotPassword,
                                    style: TextStyle(
                                      color: ColorManager.primary2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSize.s24),
                              // Login Button
                              CustomButton(
                                onTap: () {
                                  bloc.add(LoginSubmitted());
                                },
                                color: ColorManager.primary2,
                                isLoading: state.isSubmitting,
                                borderRadius: BorderRadius.circular(
                                  AppSize.s12,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: AppSize.s20),
                                    SizedBox(width: AppSize.s8),
                                    Text(
                                      'Sign In', // Changed to match "Sign In" from the copy
                                      style: TextStyle(
                                        fontSize: AppSize.s16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: AppSize.s24),
                              
                              // Added Security / Compliance Trust Mark
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock, size: AppSize.s16, color: ColorManager.primary2),
                                      const SizedBox(width: AppSize.s6),
                                      Text(
                                        'Secure & Confidential Communication',
                                        style: TextStyle(
                                          color: ColorManager.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: AppSize.s14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSize.s4),
                                  Text(
                                    'Trusted by Healthcare Providers.',
                                    style: TextStyle(
                                      color: ColorManager.textSecondary,
                                      fontSize: AppSize.s12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSize.s32),
                        // Sign Up Section - Changed for Enterprise appeal
                        SimpleFadeAnimation(
                          delay: const Duration(milliseconds: 400),
                          child: Container(
                            padding: const EdgeInsets.all(AppSize.s20),
                            decoration: BoxDecoration(
                              color: ColorManager.backgroundCard,
                              borderRadius: BorderRadius.circular(AppSize.s12),
                              border: Border.all(
                                color: ColorManager.greyMedium.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            // CHANGED: Row replaced with Wrap to prevent pixel overflow
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Need an account?',
                                  style: TextStyle(
                                    color: ColorManager.textSecondary,
                                    fontSize: AppSize.s14,
                                  ),
                                ),
                                const SizedBox(width: AppSize.s4),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamed(Routes.selectRole);
                                  },
                                  child: Text(
                                    'Request pricing Account',
                                    style: TextStyle(
                                      color: ColorManager.primary2,
                                      fontWeight: FontWeight.bold,
                                      fontSize: AppSize.s14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}