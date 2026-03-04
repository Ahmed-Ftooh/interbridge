import 'package:flutter/material.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';

class DoctorRegisterWithInviteScreen extends StatefulWidget {
  const DoctorRegisterWithInviteScreen({super.key});

  @override
  State<DoctorRegisterWithInviteScreen> createState() =>
      _DoctorRegisterWithInviteScreenState();
}

class _DoctorRegisterWithInviteScreenState
    extends State<DoctorRegisterWithInviteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _supabase = SupabaseService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  Map<String, dynamic>? _inviteData;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inviteData ??=
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      CustomSnackBar.show(
        context,
        message: 'Please agree to the Terms & Conditions',
        type: SnackBarType.warning,
      );
      return;
    }

    if (_inviteData == null) {
      CustomSnackBar.show(
        context,
        message: 'Invalid invite data. Please try again.',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final organizationId = _inviteData!['organization_id'] as String;
      final role = _inviteData!['role'] as String? ?? 'doctor';
      final inviteId = _inviteData!['invite_id'] as String?;

      final response = await _supabase.signUpDoctorWithInvite(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        organizationId: organizationId,
        role: role,
        inviteId: inviteId,
      );

      if (response.user != null) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Registration successful! Please verify your email.',
            type: SnackBarType.success,
          );
          // Navigate to email confirmation
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.confirmEmailRoute,
            (route) => false,
            arguments: {'email': _emailController.text.trim()},
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Registration failed. Please try again.',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String message = 'Registration failed';
        if (e.toString().contains('already registered')) {
          message = 'This email is already registered';
        } else if (e.toString().contains('weak_password')) {
          message = 'Password is too weak';
        }
        CustomSnackBar.show(
          context,
          message: message,
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final organization =
        _inviteData?['organization'] as Map<String, dynamic>? ?? {};
    final orgName = organization['name'] ?? 'Organization';

    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        centerTitle: true,
        elevation: 0,
        title: Text(
          'Create Account',
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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSize.s24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Organization info banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSize.s12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.business, color: Colors.orange),
                        const SizedBox(width: AppSize.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Joining Organization',
                                style: TextStyle(
                                  fontSize: AppSize.s12,
                                  color: ColorManager.textSecondary,
                                ),
                              ),
                              Text(
                                orgName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppSize.s16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSize.s12,
                            vertical: AppSize.s6,
                          ),
                          decoration: BoxDecoration(
                            color: ColorManager.primary2.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSize.s16),
                          ),
                          child: Text(
                            'Doctor',
                            style: TextStyle(
                              color: ColorManager.primary2,
                              fontSize: AppSize.s12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSize.s24),

                  // Full Name Field
                  Text(
                    'Full Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSize.s8),
                  TextFormField(
                    controller: _fullNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: ColorManager.primary2,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      filled: true,
                      fillColor: ColorManager.backgroundCard,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSize.s20),

                  // Email Field
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSize.s8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: ColorManager.primary2,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      filled: true,
                      fillColor: ColorManager.backgroundCard,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      final emailRegex = RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSize.s20),

                  // Password Field
                  Text(
                    'Password',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSize.s8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Create a password',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: ColorManager.primary2,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: ColorManager.greyMedium,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      filled: true,
                      fillColor: ColorManager.backgroundCard,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSize.s20),

                  // Confirm Password Field
                  Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSize.s8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Confirm your password',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: ColorManager.primary2,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: ColorManager.greyMedium,
                        ),
                        onPressed: () {
                          setState(
                            () =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                          );
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSize.s12),
                      ),
                      filled: true,
                      fillColor: ColorManager.backgroundCard,
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

                  const SizedBox(height: AppSize.s20),

                  // Terms checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (value) {
                          setState(() => _agreedToTerms = value ?? false);
                        },
                        activeColor: ColorManager.primary2,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _agreedToTerms = !_agreedToTerms);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSize.s12),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: ColorManager.textSecondary,
                                  fontSize: AppSize.s14,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: ColorManager.primary2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: ColorManager.primary2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSize.s32),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 56.0,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.primary2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSize.s16),
                        ),
                      ),
                      child:
                          _isLoading
                              ? SizedBox(
                                height: AppSize.s24,
                                width: AppSize.s24,
                                child: CircularProgressIndicator(
                                  color: ColorManager.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: AppSize.s18,
                                  fontWeight: FontWeight.bold,
                                  color: ColorManager.white,
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: AppSize.s24),

                  // Already have account
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.loginRoute,
                          (route) => false,
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: ColorManager.textSecondary,
                            fontSize: AppSize.s14,
                          ),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: ColorManager.primary2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
