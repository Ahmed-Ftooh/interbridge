import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';

import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_text_field_container.dart';
import 'package:flutter/gestures.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/customButtom.dart';

import '../view_model/registerBloc/register_bloc.dart';
import '../view_model/registerBloc/register_event.dart';
import '../view_model/registerBloc/register_state.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    return _RegisterViewBody(data: data);
  }
}

class _RegisterViewBody extends StatefulWidget {
  final Map<String, dynamic> data;
  const _RegisterViewBody({required this.data});

  @override
  State<_RegisterViewBody> createState() => _RegisterViewBodyState();
}

class _RegisterViewBodyState extends State<_RegisterViewBody> {
  bool _isPasswordVisible = true;
  bool _isConfirmPasswordVisible = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _agreedToPrivacy = false;

  late String role;
  late List<String>
  languages; // Keep as List<String> since bloc expects strings
  late Map<String, String?> fluency;
  late List<int> skills;
  late List<int> specializations;
  late String? voiceSampleUrl;
  late String? voicePrompt;
  late String? certificateUrl;
  // Local paths for deferred upload
  late String? voiceSamplePath;
  late String? certificatePath;

  @override
  void initState() {
    super.initState();
    role = widget.data['role'] ?? 'requester';

    // Safe type conversion for languages with better error handling
    try {
      final languagesData = widget.data['languages'];
      if (languagesData is List) {
        languages =
            languagesData
                .where((e) => e != null && e.toString().isNotEmpty)
                .map((e) => e.toString())
                .toList();
      } else if (languagesData is String) {
        // Handle case where languages might be passed as a single string
        languages = [languagesData];
      } else {
        languages = [];
      }
    } catch (e) {
      log('DEBUG: Error parsing languages: $e');
      languages = [];
    }

    // Safe type conversion for fluency with better error handling
    try {
      final fluencyData = widget.data['fluency'];
      if (fluencyData is Map) {
        fluency = Map<String, String?>.from(fluencyData);
      } else {
        fluency = {};
      }
    } catch (e) {
      log('DEBUG: Error parsing fluency: $e');
      fluency = {};
    }

    // Safe type conversion for skills with better error handling
    try {
      final skillsData = widget.data['skills'];
      if (skillsData is List) {
        skills =
            skillsData
                .where((e) => e != null)
                .map((e) => int.tryParse(e.toString()))
                .where((e) => e != null && e > 0)
                .cast<int>()
                .toList();
      } else {
        skills = [];
      }
    } catch (e) {
      log('DEBUG: Error parsing skills: $e');
      skills = [];
    }

    // Safe type conversion for specializations with better error handling
    try {
      final specializationsData = widget.data['specializations'];
      if (specializationsData is List) {
        specializations =
            specializationsData
                .where((e) => e != null)
                .map((e) => int.tryParse(e.toString()))
                .where((e) => e != null && e > 0)
                .cast<int>()
                .toList();
      } else {
        specializations = [];
      }
    } catch (e) {
      log('DEBUG: Error parsing specializations: $e');
      specializations = [];
    }

    // Initialize voice check data
    voiceSampleUrl = widget.data['voiceSampleUrl'];
    voicePrompt = widget.data['voicePrompt'];
    certificateUrl = widget.data['certificateUrl'];
    voiceSamplePath = widget.data['voiceSamplePath'];
    certificatePath = widget.data['certificatePath'];

    // Debug: Print the role being used
    log('DEBUG: Role being used: $role');
    log('DEBUG: Data received: ${widget.data}');
    log('DEBUG: Languages: $languages');
    log('DEBUG: Fluency: $fluency');
    log('DEBUG: Skills: $skills');
    log('DEBUG: Specializations: $specializations');
    log('DEBUG: Voice Sample URL: $voiceSampleUrl');
    log('DEBUG: Voice Prompt: $voicePrompt');
    log('DEBUG: Certificate URL: $certificateUrl');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        centerTitle: true,
        elevation: 0,
        title: Text(
          AppStrings.signup,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: ColorManager.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios,
            color: ColorManager.white,
            size: AppSize.s24,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: BlocConsumer<RegisterBloc, RegisterState>(
            listener: (context, state) {
              if (state is RegisterFailure) {
                log(state.error);
                CustomSnackBar.show(
                  context,
                  message: state.error,
                  type: SnackBarType.error,
                );
              }
              if (state is RegisterSuccess) {
                // mark that login flow started so splash doesn't route to onboarding
                Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.emailVerificationRoute,
                  (route) => false,
                );
              }
            },
            builder: (context, state) {
              final isLoading = state is RegisterLoading;
              return Form(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSize.s24),
                      child: Column(
                        children: [
                          const SizedBox(height: AppSize.s40),
                          CustomTextFieldContainer(
                            controller: _usernameController,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontSize: AppSize.s14),
                            keyboardType: TextInputType.name,
                            decoration: InputDecoration(
                              labelText: AppStrings.userName,
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: ColorManager.primary2,
                                size: AppSize.s20,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSize.s20),
                          CustomTextFieldContainer(
                            controller: _emailController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: AppStrings.email,
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: ColorManager.primary2,
                                size: AppSize.s20,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSize.s20),
                          CustomTextFieldContainer(
                            controller: _passwordController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            keyboardType: TextInputType.visiblePassword,
                            obscureText: _isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: AppStrings.password,
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: ColorManager.primary2,
                                size: AppSize.s20,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: ColorManager.primary2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSize.s20),
                          CustomTextFieldContainer(
                            controller: _confirmPasswordController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            keyboardType: TextInputType.visiblePassword,
                            obscureText: _isConfirmPasswordVisible,
                            decoration: InputDecoration(
                              labelText: AppStrings.confirmPassword,
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: ColorManager.primary2,
                                size: AppSize.s20,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible;
                                  });
                                },
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: ColorManager.primary2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSize.s24),
                          Container(
                            padding: const EdgeInsets.all(AppSize.s16),
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
                              children: [
                                Checkbox(
                                  value: _agreedToPrivacy,
                                  onChanged:
                                      (value) => setState(
                                        () => _agreedToPrivacy = value ?? false,
                                      ),
                                  activeColor: ColorManager.primary2,
                                ),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: ColorManager.textSecondary,
                                        fontSize: AppSize.s14,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: AppStrings.iAgreeToThe,
                                        ),
                                        TextSpan(
                                          text: AppStrings.privacyPolicy,
                                          style: TextStyle(
                                            color: ColorManager.primary2,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          recognizer:
                                              TapGestureRecognizer()
                                                ..onTap = () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    Routes.privacyPolicy,
                                                  );
                                                },
                                        ),
                                        const TextSpan(text: AppStrings.and),
                                        TextSpan(
                                          text: AppStrings.termsOfService,
                                          style: TextStyle(
                                            color: ColorManager.primary2,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          recognizer:
                                              TapGestureRecognizer()
                                                ..onTap = () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    Routes.termsOfService,
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSize.s24),
                          CustomButton(
                            onTap: () {
                              // Enhanced validation
                              if (!_agreedToPrivacy) {
                                CustomSnackBar.show(
                                  context,
                                  message:
                                      AppStrings.pleaseAgreeToPrivacyPolicy,
                                  type: SnackBarType.error,
                                );
                                return;
                              }

                              if (_passwordController.text !=
                                  _confirmPasswordController.text) {
                                CustomSnackBar.show(
                                  context,
                                  message: AppStrings.passwordsDoNotMatch,
                                  type: SnackBarType.error,
                                );
                                return;
                              }

                              if (_usernameController.text.trim().isEmpty ||
                                  _emailController.text.trim().isEmpty ||
                                  _passwordController.text.isEmpty) {
                                CustomSnackBar.show(
                                  context,
                                  message:
                                      AppStrings.pleaseFillInAllRequiredFields,
                                  type: SnackBarType.error,
                                );
                                return;
                              }

                              // Additional validation for interpreters
                              if (role == 'interpreter') {
                                if (languages.isEmpty) {
                                  CustomSnackBar.show(
                                    context,
                                    message:
                                        AppStrings
                                            .pleaseSelectAtLeastOneLanguage,
                                    type: SnackBarType.error,
                                  );
                                  return;
                                }

                                if (skills.isEmpty) {
                                  CustomSnackBar.show(
                                    context,
                                    message:
                                        AppStrings.pleaseSelectAtLeastOneSkill,
                                    type: SnackBarType.error,
                                  );
                                  return;
                                }

                                if (specializations.isEmpty) {
                                  CustomSnackBar.show(
                                    context,
                                    message:
                                        AppStrings
                                            .pleaseSelectAtLeastOneSpecialization,
                                    type: SnackBarType.error,
                                  );
                                  return;
                                }
                              }

                              // Check if user is requester or interpreter
                              if (role == 'requester') {
                                // Simple registration for requesters
                                log(
                                  'DEBUG: Calling RequesterRegisterSubmitted',
                                );
                                context.read<RegisterBloc>().add(
                                  RequesterRegisterSubmitted(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                    username: _usernameController.text.trim(),
                                  ),
                                );
                              } else {
                                // Full registration for interpreters
                                log(
                                  'DEBUG: Calling RegisterSubmitted with role: $role',
                                );
                                log('DEBUG: Languages being sent: $languages');
                                log('DEBUG: Skills being sent: $skills');
                                log(
                                  'DEBUG: Specializations being sent: $specializations',
                                );

                                context.read<RegisterBloc>().add(
                                  RegisterSubmitted(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                    username: _usernameController.text.trim(),
                                    gender: '',
                                    languages: languages,
                                    fluency: fluency,
                                    skillIds: skills,
                                    specializationIds: specializations,
                                    role: role,
                                    voiceSampleUrl: voiceSampleUrl,
                                    voicePrompt: voicePrompt,
                                    certificateUrl: certificateUrl,
                                    voiceSamplePath: voiceSamplePath,
                                    certificatePath: certificatePath,
                                  ),
                                );
                              }
                            },
                            color: ColorManager.primary2,
                            isLoading: isLoading,
                            borderRadius: BorderRadius.circular(AppSize.s12),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add, size: AppSize.s20),
                                SizedBox(width: AppSize.s8),
                                Text(
                                  AppStrings.signup,
                                  style: TextStyle(
                                    fontSize: AppSize.s16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSize.s24),
                          Container(
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
                                  AppStrings.allreadyHaveAnAccont,
                                  style: TextStyle(
                                    color: ColorManager.textSecondary,
                                    fontSize: AppSize.s14,
                                  ),
                                ),
                                const SizedBox(width: AppSize.s4),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      Routes.loginRoute,
                                    );
                                  },
                                  child: Text(
                                    AppStrings.signin,
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
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
