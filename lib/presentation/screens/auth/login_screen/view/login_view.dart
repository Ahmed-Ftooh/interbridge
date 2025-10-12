import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'dart:developer';

import 'package:interbridge/data/services/firebase_messaging_service.dart';
import 'package:interbridge/data/services/permission_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/simple_fade_animation.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/customButtom.dart';
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

  Future<void> _requestPermissionsAndNavigate() async {
    try {
      // Request a
      //ll app permissions
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
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

      // Navigate anyway if permissions fail
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
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
                    await _appPreferences.setLoginViewed();
                    await FirebaseMessagingService().initialize();
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
                        SimpleFadeAnimation(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSize.s20),
                                decoration: BoxDecoration(
                                  color: ColorManager.primary2.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppSize.s20,
                                  ),
                                ),
                                child: Icon(
                                  Icons.language,
                                  color: ColorManager.primary2,
                                  size: AppSize.s50,
                                ),
                              ),
                              const SizedBox(height: AppSize.s20),
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
                                AppStrings.signInToContinue,
                                style: TextStyle(
                                  fontSize: AppSize.s16,
                                  color: ColorManager.textSecondary,
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
                                      AppStrings.login,
                                      style: TextStyle(
                                        fontSize: AppSize.s16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSize.s32),
                        // Sign Up Section
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppStrings.donthaveAnAccount,
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
                                    AppStrings.signup,
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
