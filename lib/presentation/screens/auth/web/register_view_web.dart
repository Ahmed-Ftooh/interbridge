import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_event.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_state.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/country_picker_sheet.dart';

/// Professional web register screen — interpreter-focused final step
class RegisterViewWeb extends StatelessWidget {
  const RegisterViewWeb({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
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
  String? _hoveredField;

  // Always interpreter on web
  late List<String> languages;
  late Map<String, String?> fluency;
  late List<int> skills;
  late List<int> specializations;
  late String? voiceSamplePath;
  late String? certificatePath;
  late String? medicalCertificatePath;
  // Web: raw bytes for uploads (blob URLs don't survive page navigation)
  Uint8List? voiceSampleBytes;
  String? voiceSampleName;
  Uint8List? certificateBytes;
  String? certificateName;
  Uint8List? medicalCertificateBytes;
  String? medicalCertificateName;
  late String? bio;
  late int? yearsExperience;
  late String? employmentType;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    try {
      final languagesData = widget.data['languages'];
      if (languagesData is List) {
        languages =
            languagesData
                .where((e) => e != null && e.toString().isNotEmpty)
                .map((e) => e.toString())
                .toList();
      } else {
        languages = [];
      }
    } catch (e) {
      languages = [];
    }

    try {
      final fluencyData = widget.data['fluency'];
      fluency =
          fluencyData is Map ? Map<String, String?>.from(fluencyData) : {};
    } catch (e) {
      fluency = {};
    }

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
      skills = [];
    }

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
      specializations = [];
    }

    voiceSamplePath = widget.data['voiceSamplePath'];
    certificatePath = widget.data['certificatePath'];
    medicalCertificatePath = widget.data['medicalCertificatePath'];
    // Web: get voice sample and certificate bytes if available
    voiceSampleBytes = widget.data['voiceSampleBytes'] as Uint8List?;
    voiceSampleName = widget.data['voiceSampleName'] as String?;
    certificateBytes = widget.data['certificateBytes'] as Uint8List?;
    certificateName = widget.data['certificateName'] as String?;
    medicalCertificateBytes =
        widget.data['medicalCertificateBytes'] as Uint8List?;
    medicalCertificateName = widget.data['medicalCertificateName'] as String?;
    bio = widget.data['bio'] as String?;
    yearsExperience =
        widget.data['yearsExperience'] is int
            ? widget.data['yearsExperience'] as int
            : int.tryParse(widget.data['yearsExperience']?.toString() ?? '');

    final trackValue =
        widget.data['interpreterTrack'] ??
        widget.data['interpreterLevel'] ??
        widget.data['employmentType'];
    if (trackValue is String) {
      final normalized = trackValue.toLowerCase();
      employmentType =
          (normalized.contains('paid') || normalized.contains('professional'))
              ? 'paid'
              : 'volunteer';
    } else {
      employmentType = 'volunteer';
    }
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

    if (_selectedGender == null) {
      CustomSnackBar.show(
        context,
        message: 'Please select your gender',
        type: SnackBarType.warning,
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
        languages: languages,
        fluency: fluency,
        skillIds: skills,
        specializationIds: specializations,
        role: 'interpreter',
        voiceSamplePath: voiceSamplePath,
        certificatePath: certificatePath,
        medicalCertificatePath: medicalCertificatePath,
        voiceSampleBytes: voiceSampleBytes,
        voiceSampleName: voiceSampleName,
        certificateBytes: certificateBytes,
        certificateName: certificateName,
        medicalCertificateBytes: medicalCertificateBytes,
        medicalCertificateName: medicalCertificateName,
        bio: bio,
        yearsExperience: yearsExperience,
        employmentType: employmentType,
      ),
    );
  }

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
          title: 'Create your account',
          subtitle: 'Final step — set up your interpreter profile credentials',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF0EA5E9),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${languages.length} language${languages.length != 1 ? 's' : ''} · '
                          '${specializations.length} specialization${specializations.length != 1 ? 's' : ''} · '
                          '${employmentType == 'paid' ? 'Professional' : 'Volunteer'} track',
                          style: const TextStyle(
                            color: Color(0xFF0C4A6E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Username field
                _buildTextField(
                  controller: _usernameController,
                  fieldName: 'username',
                  label: 'Username',
                  hint: 'Choose a username',
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email field
                _buildTextField(
                  controller: _emailController,
                  fieldName: 'email',
                  label: 'Email Address',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(value.trim())) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password field
                _buildTextField(
                  controller: _passwordController,
                  fieldName: 'password',
                  label: 'Password',
                  hint: 'Create a password',
                  icon: Icons.lock_outline,
                  obscureText: !_isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed:
                        () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Confirm password field
                _buildTextField(
                  controller: _confirmPasswordController,
                  fieldName: 'confirmPassword',
                  label: 'Confirm Password',
                  hint: 'Confirm your password',
                  icon: Icons.lock_outline,
                  obscureText: !_isConfirmPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed:
                        () => setState(
                          () =>
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible,
                        ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Gender
                _buildGenderDropdown(),
                const SizedBox(height: 20),

                // Country
                _buildCountrySelector(),

                const SizedBox(height: 24),

                // Privacy policy checkbox
                _buildPrivacyCheckbox(),

                const SizedBox(height: 32),

                // Register button
                _buildRegisterButton(isLoading),

                const SizedBox(height: 24),

                // Back to login
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      TextButton(
                        onPressed:
                            () => Navigator.of(
                              context,
                            ).pushReplacementNamed(Routes.loginRoute),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
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
    final isHovered = _hoveredField == fieldName;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredField = fieldName),
      onExit: (_) => setState(() => _hoveredField = null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  isHovered
                      ? [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              validator: validator,
              style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: Icon(
                  icon,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                suffixIcon: suffixIcon,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color:
                        isHovered
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
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
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  _selectedGender != null
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                      : const Color(0xFFE2E8F0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              hint: const Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Select Gender',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF64748B),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(
                  value: 'prefer_not_to_say',
                  child: Text('Prefer not to say'),
                ),
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
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _selectedCountry != null
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                        : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                if (_selectedCountryFlag != null) ...[
                  Text(
                    _selectedCountryFlag!,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(Icons.public, color: Color(0xFF64748B), size: 20),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    _selectedCountry ?? 'Select Country',
                    style: TextStyle(
                      color:
                          _selectedCountry != null
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyCheckbox() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToPrivacy,
            onChanged:
                (value) => setState(() => _agreedToPrivacy = value ?? false),
            activeColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              children: [
                const TextSpan(text: 'I agree to the '),
                WidgetSpan(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(Routes.privacyPolicy);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(Routes.termsOfService);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Terms of Service',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
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
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: const Color(
            0xFF0F172A,
          ).withValues(alpha: 0.6),
        ),
        child:
            isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
      ),
    );
  }
}
