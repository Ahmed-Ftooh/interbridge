import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_text_field_container.dart';
import 'package:interbridge/presentation/widgets/country_picker_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';

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

  // Gender and Country for interpreters
  String? _selectedGender;
  String? _selectedCountry;
  String? _selectedCountryFlag;

  late String role;
  // Organization data
  late String? organizationName;
  late String? organizationEmail;
  late String? organizationPhone;
  late String? organizationAddress;

  // Doctor invite data
  late String? inviteOrganizationId;
  late String? inviteRole;
  late String? inviteId;

  // Profile picture
  Uint8List? _profileImageBytes;
  String? _profileImageName;

  @override
  void initState() {
    super.initState();
    role = widget.data['role'] ?? 'requester';

    // Organization data
    organizationName = widget.data['organizationName'] as String?;
    organizationEmail = widget.data['organizationEmail'] as String?;
    organizationPhone = widget.data['organizationPhone'] as String?;
    organizationAddress = widget.data['organizationAddress'] as String?;

    // Doctor invite data (for doctors joining via invite code)
    inviteOrganizationId = widget.data['organization_id'] as String?;
    inviteRole = widget.data['organization_role'] as String? ?? 'doctor';
    inviteId = widget.data['invite_id'] as String?;

    // Pre-fill admin fields if coming from organization registration
    if (role == 'organization_admin') {
      _usernameController.text = widget.data['username'] as String? ?? '';
      _emailController.text = widget.data['email'] as String? ?? '';
      _passwordController.text = widget.data['password'] as String? ?? '';
      _confirmPasswordController.text =
          widget.data['password'] as String? ?? '';
    }
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
                  Routes.confirmEmailRoute,
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
                          const SizedBox(height: AppSize.s20),
                          // Profile picture picker
                          if (role == 'interpreter') ...[
                            _buildProfilePicturePicker(),
                            const SizedBox(height: AppSize.s24),
                          ],
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

                          // Gender and Country fields for interpreters only
                          if (role == 'interpreter') ...[
                            const SizedBox(height: AppSize.s20),
                            // Gender Selection
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSize.s16,
                              ),
                              decoration: BoxDecoration(
                                color: ColorManager.backgroundCard,
                                borderRadius: BorderRadius.circular(
                                  AppSize.s12,
                                ),
                                border: Border.all(
                                  color:
                                      _selectedGender != null
                                          ? ColorManager.primary2
                                          : ColorManager.greyMedium.withValues(
                                            alpha: 0.3,
                                          ),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGender,
                                  hint: Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        color: ColorManager.primary2,
                                        size: AppSize.s20,
                                      ),
                                      const SizedBox(width: AppSize.s12),
                                      Text(
                                        'Select Gender',
                                        style: TextStyle(
                                          color: ColorManager.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: ColorManager.primary2,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'male',
                                      child: Text('Male'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'female',
                                      child: Text('Female'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'prefer_not_to_say',
                                      child: Text('Prefer not to say'),
                                    ),
                                  ],
                                  onChanged:
                                      (value) => setState(
                                        () => _selectedGender = value,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSize.s20),

                            // Country Selection - Tappable to open searchable picker
                            GestureDetector(
                              onTap: () async {
                                final country = await CountryPickerSheet.show(
                                  context,
                                  selectedCountry: _selectedCountry,
                                );
                                if (country != null) {
                                  setState(() {
                                    _selectedCountry = country.name;
                                    _selectedCountryFlag = country.flag;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSize.s16,
                                  vertical: AppSize.s14,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorManager.backgroundCard,
                                  borderRadius: BorderRadius.circular(
                                    AppSize.s12,
                                  ),
                                  border: Border.all(
                                    color:
                                        _selectedCountry != null
                                            ? ColorManager.primary2
                                            : ColorManager.greyMedium
                                                .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (_selectedCountryFlag != null) ...[
                                      Text(
                                        _selectedCountryFlag!,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      const SizedBox(width: AppSize.s12),
                                    ] else ...[
                                      Icon(
                                        Icons.public,
                                        color: ColorManager.primary2,
                                        size: AppSize.s20,
                                      ),
                                      const SizedBox(width: AppSize.s12),
                                    ],
                                    Expanded(
                                      child: Text(
                                        _selectedCountry ?? 'Select Country',
                                        style: TextStyle(
                                          color:
                                              _selectedCountry != null
                                                  ? ColorManager.textPrimary
                                                  : ColorManager.textSecondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: ColorManager.primary2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

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

                              // Check if user is requester, interpreter, or organization_admin
                              if (role == 'doctor_with_invite' &&
                                  inviteOrganizationId != null) {
                                // Doctor registering via invite code
                                context.read<RegisterBloc>().add(
                                  DoctorWithInviteRegisterSubmitted(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                    username: _usernameController.text.trim(),
                                    organizationId: inviteOrganizationId!,
                                    role: inviteRole ?? 'doctor',
                                    inviteId: inviteId,
                                  ),
                                );
                              } else if (role == 'requester') {
                                // Simple registration for requesters
                                context.read<RegisterBloc>().add(
                                  RequesterRegisterSubmitted(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                    username: _usernameController.text.trim(),
                                  ),
                                );
                              } else if (role == 'organization_admin') {
                                // Organization admin registration
                                context.read<RegisterBloc>().add(
                                  OrganizationRegisterSubmitted(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                    username: _usernameController.text.trim(),
                                    organizationName: organizationName ?? '',
                                    organizationEmail: organizationEmail ?? '',
                                    organizationPhone: organizationPhone,
                                    organizationAddress: organizationAddress,
                                  ),
                                );
                              } else {
                                // Full registration for interpreters
                                context.read<RegisterBloc>().add(
                                  RegisterSubmitted(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                    username: _usernameController.text.trim(),
                                    gender: _selectedGender ?? '',
                                    country: _selectedCountry,
                                    languages: const [],
                                    fluency: const {},
                                    skillIds: const [],
                                    specializationIds: const [],
                                    role: role,
                                    voiceSampleUrl: null,
                                    voicePrompt: null,
                                    certificateUrl: null,
                                    medicalCertificateUrl: null,
                                    voiceSamplePath: null,
                                    certificatePath: null,
                                    medicalCertificatePath: null,
                                    voiceSampleNativePath: null,
                                    voiceSampleNativeBytes: null,
                                    voiceSampleNativeName: null,
                                    voiceSampleBytes: null,
                                    voiceSampleName: null,
                                    profileImageBytes: _profileImageBytes,
                                    profileImageName: _profileImageName,
                                    governmentIdBytes: null,
                                    governmentIdFileName: null,
                                    governmentIdType: null,
                                    phoneNumber: null,
                                    certificateBytes: null,
                                    certificateName: null,
                                    medicalCertificateBytes: null,
                                    medicalCertificateName: null,
                                    bio: null,
                                    yearsExperience: null,
                                    preferredShift: null,
                                    shiftAvailability: null,
                                    isOnlineNow: null,
                                    employmentType: 'volunteer',
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

  // ─── Profile picture picker ───────────────────────────────────
  Widget _buildProfilePicturePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickProfileImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: ColorManager.primary2.withValues(alpha: 0.1),
                backgroundImage:
                    _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                child:
                    _profileImageBytes == null
                        ? Icon(
                          Icons.person,
                          size: 48,
                          color: ColorManager.primary2.withValues(alpha: 0.5),
                        )
                        : null,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ColorManager.primary2,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _profileImageBytes != null
              ? 'Tap to change photo'
              : 'Add profile photo',
          style: TextStyle(fontSize: 13, color: ColorManager.textSecondary),
        ),
      ],
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
          _profileImageName =
              'profile_${DateTime.now().millisecondsSinceEpoch}.${picked.name.split('.').last}';
        });
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }
}
