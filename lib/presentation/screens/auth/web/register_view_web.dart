import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_palette.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_event.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_state.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/country_picker_sheet.dart';

/// Perfectly symmetrical, professional grid web register screen.
class RegisterViewWeb extends StatelessWidget {
  const RegisterViewWeb({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: If data is null (e.g. user refreshed the page), default safely to 'interpreter'
    // instead of kicking them back to the login screen.
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {'role': 'interpreter'};
        
    return _RegisterViewWebBody(data: data);
  }
}

class _RegisterViewWebBody extends StatefulWidget {
  final Map<String, dynamic> data;
  const _RegisterViewWebBody({required this.data});

  @override
  State<_RegisterViewWebBody> createState() => _RegisterViewWebBodyState();
}

class _RegisterViewWebBodyState extends State<_RegisterViewWebBody> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreedToPrivacy = false;
  String? _selectedGender;
  String? _selectedCountry;
  String? _selectedCountryFlag;

  // Profile picture
  Uint8List? _profileImageBytes;
  String? _profileImageName;

  // Doctor invite data
  String? _incomingRole;
  String? _inviteOrganizationId;
  String? _inviteOrgRole;
  String? _inviteId;

  @override
  void initState() {
    super.initState();
    _initializeData();
    // FIX: The aggressive "kick out" trap has been completely removed from here.
  }

  void _initializeData() {
    _incomingRole = widget.data['role'] as String?;
    _inviteOrganizationId = widget.data['organization_id'] as String?;
    _inviteOrgRole = widget.data['organization_role'] as String? ?? 'doctor';
    _inviteId = widget.data['invite_id'] as String?;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToPrivacy) {
      CustomSnackBar.show(
        context,
        message: 'Please agree to the Privacy Policy to continue',
        type: SnackBarType.warning,
      );
      return;
    }

    if (_selectedGender == null && _incomingRole != 'doctor_with_invite') {
      CustomSnackBar.show(
        context,
        message: 'Please select your gender',
        type: SnackBarType.warning,
      );
      return;
    }

    if (_incomingRole == 'doctor_with_invite' &&
        _inviteOrganizationId != null) {
      context.read<RegisterBloc>().add(
        DoctorWithInviteRegisterSubmitted(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
          organizationId: _inviteOrganizationId!,
          role: _inviteOrgRole ?? 'doctor',
          inviteId: _inviteId,
        ),
      );
      return;
    }

    context.read<RegisterBloc>().add(
      RegisterSubmitted(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        gender: _selectedGender ?? '',
        country: _selectedCountry,
        languages: [],
        fluency: {},
        skillIds: [],
        specializationIds: [],
        role: 'interpreter',
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
        certificateBytes: null,
        certificateName: null,
        medicalCertificateBytes: null,
        medicalCertificateName: null,
        bio: null,
        yearsExperience: null,
        employmentType: 'volunteer',
        governmentIdBytes: null,
        governmentIdFileName: null,
        governmentIdType: null,
        phoneNumber: null,
      ),
    );
  }
  
  // ... Keep the entire build() method exactly as you have it! ...

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, RegisterState>(
      listener: (context, state) {
        if (state is RegisterFailure) {
          CustomSnackBar.show(
            context,
            message: state.error,
            type: SnackBarType.error,
          );
        }
        if (state is RegisterSuccess) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.confirmEmailRoute, (route) => false);
        }
      },
      builder: (context, state) {
        final isLoading = state is RegisterLoading;

        return AuthWebWrapper(
          maxWidth: 680, // Wide enough for a beautiful 2-column grid
          title: 'Create your account',
          subtitle:
              _incomingRole == 'doctor_with_invite'
                  ? 'Please complete your doctor profile'
                  : 'Please set up your professional profile',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                
                // 1. Centered Profile Picture
                Center(child: _buildProfilePicturePicker()),
                const SizedBox(height: 32),

                // 2. ROW 1: Username & Email
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _usernameController,
                        fieldName: 'username',
                        label: 'Username',
                        hint: 'Choose a username',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Required';
                          if (value.trim().length < 3) return 'Min 3 chars';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 20), // Uniform spacing between columns
                    Expanded(
                      child: _buildTextField(
                        controller: _emailController,
                        fieldName: 'email',
                        label: 'Email Address',
                        hint: 'name@company.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Required';
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
                            return 'Invalid email';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24), // Uniform spacing between rows

                // 3. ROW 2: Password & Confirm Password
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _passwordController,
                        fieldName: 'password',
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: !_isPasswordVisible,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AuthWebPalette.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value.length < 6) return 'Min 6 chars';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        controller: _confirmPasswordController,
                        fieldName: 'confirmPassword',
                        label: 'Confirm Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: !_isConfirmPasswordVisible,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AuthWebPalette.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value != _passwordController.text) return 'Does not match';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. ROW 3: Gender & Country
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildGenderDropdown()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildCountrySelector()),
                  ],
                ),
                const SizedBox(height: 32),

                // 5. Privacy Checkbox
                _buildPrivacyCheckbox(),
                const SizedBox(height: 32),

                // 6. Register Button
                _buildRegisterButton(isLoading),
                const SizedBox(height: 24),

                // 7. Back to Login
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: AuthWebPalette.textSecondary, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed(Routes.loginRoute),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AuthWebPalette.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String fieldName,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AuthWebPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AuthWebPalette.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AuthWebPalette.textMuted, fontSize: 14),
            prefixIcon: Icon(icon, color: AuthWebPalette.textMuted, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AuthWebPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AuthWebPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AuthWebPalette.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AuthWebPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _selectedGender != null ? AuthWebPalette.primary : AuthWebPalette.border,
              width: _selectedGender != null ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              hint: const Text('Select Gender', style: TextStyle(color: AuthWebPalette.textMuted, fontSize: 14)),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AuthWebPalette.textMuted),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 'female', child: Text('Female', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say', style: TextStyle(fontSize: 14))),
              ],
              onChanged: (value) => setState(() => _selectedGender = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountrySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Country',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AuthWebPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
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
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedCountry != null ? AuthWebPalette.primary : AuthWebPalette.border,
                width: _selectedCountry != null ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                if (_selectedCountryFlag != null) ...[
                  Text(_selectedCountryFlag!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ] else ...[
                  const Icon(Icons.public, color: AuthWebPalette.textMuted, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _selectedCountry ?? 'Select Country',
                    style: TextStyle(
                      color: _selectedCountry != null ? AuthWebPalette.textPrimary : AuthWebPalette.textMuted,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: AuthWebPalette.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _agreedToPrivacy,
            onChanged: (value) => setState(() => _agreedToPrivacy = value ?? false),
            activeColor: AuthWebPalette.primary,
            side: const BorderSide(color: AuthWebPalette.textMuted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: AuthWebPalette.textSecondary, fontSize: 13),
              children: [
                const TextSpan(text: 'I agree to the '),
                WidgetSpan(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed(Routes.privacyPolicy),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Privacy Policy', style: TextStyle(color: AuthWebPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed(Routes.termsOfService),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Terms of Service', style: TextStyle(color: AuthWebPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(bool isLoading) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthWebPalette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // Centered & Refined Profile Picture Picker
  Widget _buildProfilePicturePicker() {
    return Column(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 46, // Slightly larger for the centered hero spot
                  backgroundColor: AuthWebPalette.border.withValues(alpha: 0.5),
                  backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                  child: _profileImageBytes == null
                      ? const Icon(Icons.person, size: 40, color: AuthWebPalette.textMuted)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AuthWebPalette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _profileImageBytes != null ? 'Change profile photo' : 'Upload profile photo',
          style: const TextStyle(fontSize: 13, color: AuthWebPalette.textSecondary, fontWeight: FontWeight.w500),
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
          _profileImageName = 'profile_${DateTime.now().millisecondsSinceEpoch}.${picked.name.split('.').last}';
        });
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }
}