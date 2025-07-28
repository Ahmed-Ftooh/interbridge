import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_text_field_container.dart';
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

  @override
  void initState() {
    super.initState();
    role = widget.data['role'] ?? 'requester';

    // Safe type conversion for languages
    try {
      final languagesData = widget.data['languages'];
      if (languagesData is List) {
        // Convert to strings since bloc expects List<String>
        languages = languagesData.map((e) => e.toString()).toList();
      } else {
        languages = [];
      }
    } catch (e) {
      languages = [];
    }

    // Safe type conversion for fluency
    try {
      final fluencyData = widget.data['fluency'];
      if (fluencyData is Map) {
        fluency = Map<String, String?>.from(fluencyData);
      } else {
        fluency = {};
      }
    } catch (e) {
      fluency = {};
    }

    // Safe type conversion for skills
    try {
      final skillsData = widget.data['skills'];
      if (skillsData is List) {
        skills =
            skillsData
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e != 0)
                .toList();
      } else {
        skills = [];
      }
    } catch (e) {
      skills = [];
    }

    // Safe type conversion for specializations
    try {
      final specializationsData = widget.data['specializations'];
      if (specializationsData is List) {
        specializations =
            specializationsData
                .map((e) => int.tryParse(e.toString()) ?? 0)
                .where((e) => e != 0)
                .toList();
      } else {
        specializations = [];
      }
    } catch (e) {
      specializations = [];
    }

    // Debug: Print the role being used
    log('DEBUG: Role being used: $role');
    log('DEBUG: Data received: ${widget.data}');
    log('DEBUG: Languages: $languages');
    log('DEBUG: Fluency: $fluency');
    log('DEBUG: Skills: $skills');
    log('DEBUG: Specializations: $specializations');
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
                  context: context,
                  message: state.error,
                  type: SnackBarType.error,
                );
              }
              if (state is RegisterSuccess) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
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
                                          ),
                                        ),
                                        const TextSpan(text: AppStrings.and),
                                        TextSpan(
                                          text: AppStrings.termsOfService,
                                          style: TextStyle(
                                            color: ColorManager.primary2,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                              if (!_agreedToPrivacy) {
                                CustomSnackBar.show(
                                  context: context,
                                  message: 'Please agree to the privacy policy',
                                  type: SnackBarType.error,
                                );
                                return;
                              }
                              if (_passwordController.text !=
                                  _confirmPasswordController.text) {
                                CustomSnackBar.show(
                                  context: context,
                                  message: 'Passwords do not match',
                                  type: SnackBarType.error,
                                );
                                return;
                              }
                              if (_usernameController.text.isEmpty ||
                                  _emailController.text.isEmpty ||
                                  _passwordController.text.isEmpty) {
                                CustomSnackBar.show(
                                  context: context,
                                  message: 'Please fill in all required fields',
                                  type: SnackBarType.error,
                                );
                                return;
                              }

                              // Check if user is requester or interpreter
                              if (role == 'requester') {
                                // Simple registration for requesters
                                log(
                                  'DEBUG: Calling RequesterRegisterSubmitted',
                                );
                                context.read<RegisterBloc>().add(
                                  RequesterRegisterSubmitted(
                                    email: _emailController.text,
                                    password: _passwordController.text,
                                    username: _usernameController.text,
                                  ),
                                );
                              } else {
                                // Full registration for interpreters
                                log(
                                  'DEBUG: Calling RegisterSubmitted with role: $role',
                                );
                                context.read<RegisterBloc>().add(
                                  RegisterSubmitted(
                                    email: _emailController.text,
                                    password: _passwordController.text,
                                    username: _usernameController.text,
                                    gender:
                                        '', // always null/empty as per your requirement
                                    languages:
                                        languages
                                            .map((e) => e.toString())
                                            .toList(),
                                    fluency: fluency,
                                    skillIds: skills,
                                    specializationIds: specializations,
                                    role: role,
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
