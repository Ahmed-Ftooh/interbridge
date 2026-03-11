import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_event.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_state.dart';

class OrganizationRegistrationScreen extends StatefulWidget {
  const OrganizationRegistrationScreen({super.key});

  @override
  State<OrganizationRegistrationScreen> createState() =>
      _OrganizationRegistrationScreenState();
}

class _OrganizationRegistrationScreenState
    extends State<OrganizationRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Step 1: Admin Account
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Step 2: Organization Details
  final _orgNameController = TextEditingController();
  final _orgEmailController = TextEditingController();
  final _orgPhoneController = TextEditingController();
  final _orgAddressController = TextEditingController();
  final _orgDescriptionController = TextEditingController();

  bool _agreedToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _orgNameController.dispose();
    _orgEmailController.dispose();
    _orgPhoneController.dispose();
    _orgAddressController.dispose();
    _orgDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RegisterBloc(),
      child: Scaffold(
        backgroundColor: ColorManager.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: ColorManager.primary2,
          elevation: 0,
          title: const Text(
            'Register Organization',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: BlocConsumer<RegisterBloc, RegisterState>(
          listener: (context, state) {
            if (state is RegisterFailure) {
              CustomSnackBar.show(
                context,
                message: state.error,
                type: SnackBarType.error,
              );
            }
            if (state is RegisterSuccess) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.confirmEmailRoute,
                (route) => false,
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is RegisterLoading;

            return Column(
              children: [
                // Progress indicator
                _buildProgressIndicator(),

                // Form content
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSize.s20),
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),

                // Navigation buttons
                _buildNavigationButtons(context, isLoading),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSize.s20,
        vertical: AppSize.s16,
      ),
      color: ColorManager.primary2,
      child: Column(
        children: [
          Row(
            children: [
              _buildStepIndicator(0, 'Account'),
              _buildStepConnector(0),
              _buildStepIndicator(1, 'Organization'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : Colors.white24,
              border:
                  isCurrent ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Center(
              child:
                  isActive && !isCurrent
                      ? Icon(
                        Icons.check,
                        size: 18,
                        color: ColorManager.primary2,
                      )
                      : Text(
                        '${step + 1}',
                        style: TextStyle(
                          color:
                              isActive ? ColorManager.primary2 : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isActive = _currentStep > step;
    return Container(
      height: 2,
      width: 30,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? Colors.white : Colors.white24,
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildAccountStep();
      case 1:
        return _buildOrganizationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Admin Account',
          'Create your administrator account',
          Icons.person,
        ),
        const SizedBox(height: AppSize.s24),

        _buildTextField(
          controller: _usernameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSize.s16),

        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'admin@organization.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSize.s16),

        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Create a strong password',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: ColorManager.greyMedium,
            ),
            onPressed:
                () => setState(() => _obscurePassword = !_obscurePassword),
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
        const SizedBox(height: AppSize.s16),

        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Re-enter your password',
          icon: Icons.lock_outline,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: ColorManager.greyMedium,
            ),
            onPressed:
                () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
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
      ],
    );
  }

  Widget _buildOrganizationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Organization Details',
          'Tell us about your organization',
          Icons.business,
        ),
        const SizedBox(height: AppSize.s24),

        _buildTextField(
          controller: _orgNameController,
          label: 'Organization Name',
          hint: 'Enter organization name',
          icon: Icons.business,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter organization name';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSize.s16),

        _buildTextField(
          controller: _orgEmailController,
          label: 'Organization Email',
          hint: 'contact@organization.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter organization email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSize.s16),

        _buildTextField(
          controller: _orgPhoneController,
          label: 'Phone Number',
          hint: '+1 234 567 8900',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSize.s16),

        _buildTextField(
          controller: _orgAddressController,
          label: 'Address',
          hint: 'Enter organization address',
          icon: Icons.location_on_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: AppSize.s16),

        _buildTextField(
          controller: _orgDescriptionController,
          label: 'Description (Optional)',
          hint: 'Brief description of your organization',
          icon: Icons.description_outlined,
          maxLines: 3,
        ),

        const SizedBox(height: AppSize.s24),

        // Terms and conditions
        Container(
          padding: const EdgeInsets.all(AppSize.s16),
          decoration: BoxDecoration(
            color: ColorManager.backgroundCard,
            borderRadius: BorderRadius.circular(AppSize.s12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreedToTerms,
                onChanged:
                    (value) => setState(() => _agreedToTerms = value ?? false),
                activeColor: ColorManager.primary2,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorManager.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'I confirm that all the information provided is accurate and I agree to the ',
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pushNamed(Routes.termsOfService);
                            },
                            child: Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontSize: 13,
                                color: ColorManager.primary2,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pushNamed(Routes.privacyPolicy);
                            },
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 13,
                                color: ColorManager.primary2,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSize.s12),
          decoration: BoxDecoration(
            color: ColorManager.primary2.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSize.s12),
          ),
          child: Icon(icon, color: ColorManager.primary2, size: 28),
        ),
        const SizedBox(width: AppSize.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: AppSize.s20,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: ColorManager.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: ColorManager.primary2),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: ColorManager.backgroundCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.s12),
          borderSide: BorderSide(color: ColorManager.greyLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.s12),
          borderSide: BorderSide(color: ColorManager.greyLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.s12),
          borderSide: BorderSide(color: ColorManager.primary2, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.s12),
          borderSide: BorderSide(color: ColorManager.error),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(AppSize.s20),
      decoration: BoxDecoration(
        color: ColorManager.backgroundCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorManager.primary2,
                  side: BorderSide(color: ColorManager.primary2),
                  padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSize.s12),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: AppSize.s16),
          Expanded(
            flex:
                _currentStep == 0
                    ? 1
                    : 2, // Give more space to Submit button when Back is showing
            child: CustomButton(
              onTap: () {
                if (!isLoading) _nextStep(context);
              },
              isLoading: isLoading,
              color: ColorManager.primary2,
              borderRadius: BorderRadius.circular(AppSize.s12),
              child: Text(
                _currentStep < 1 ? 'Continue' : 'Submit Application',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow:
                    TextOverflow
                        .ellipsis, // Ensure it doesn't wrap or get cut off strangely
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _nextStep(BuildContext context) {
    // Validate current step
    if (!_validateCurrentStep()) {
      return;
    }

    if (_currentStep < 1) {
      setState(() => _currentStep++);
    } else {
      // Final step - submit
      _submitApplication(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_usernameController.text.isEmpty) {
          _showError('Please enter your name');
          return false;
        }
        if (_emailController.text.isEmpty ||
            !RegExp(
              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
            ).hasMatch(_emailController.text)) {
          _showError('Please enter a valid email');
          return false;
        }
        if (_passwordController.text.length < 8) {
          _showError('Password must be at least 8 characters');
          return false;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          _showError('Passwords do not match');
          return false;
        }
        return true;

      case 1:
        if (_orgNameController.text.isEmpty) {
          _showError('Please enter organization name');
          return false;
        }
        if (_orgEmailController.text.isEmpty ||
            !RegExp(
              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
            ).hasMatch(_orgEmailController.text)) {
          _showError('Please enter a valid organization email');
          return false;
        }
        if (!_agreedToTerms) {
          _showError('Please agree to the terms and conditions');
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  void _showError(String message) {
    CustomSnackBar.show(context, message: message, type: SnackBarType.error);
  }

  void _submitApplication(BuildContext context) {
    context.read<RegisterBloc>().add(
      OrganizationRegisterSubmitted(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        organizationName: _orgNameController.text.trim(),
        organizationEmail: _orgEmailController.text.trim(),
        organizationPhone: _orgPhoneController.text.trim(),
        organizationAddress: _orgAddressController.text.trim(),
      ),
    );
  }
}
