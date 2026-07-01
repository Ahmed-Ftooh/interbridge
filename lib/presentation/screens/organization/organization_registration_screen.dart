import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_bloc.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_event.dart';
import 'package:interbridge/presentation/screens/auth/register_screen/view_model/registerBloc/register_state.dart';
import 'package:flutter/services.dart'; // <--- ADD THIS
class OrganizationRegistrationScreen extends StatefulWidget {
  const OrganizationRegistrationScreen({super.key});

  @override
  State<OrganizationRegistrationScreen> createState() =>
      _OrganizationRegistrationScreenState();
}

class _OrganizationRegistrationScreenState
    extends State<OrganizationRegistrationScreen> {
      // Add this under your other controllers
  String _billingMethod = 'prepaid'; // Default to prepaid
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  bool _isValidatingCode = false;

  // Step 0: Registration Code
  final _codeController = TextEditingController();

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
    _codeController.dispose();
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
              _buildStepIndicator(0, 'Code'),
              _buildStepConnector(0),
              _buildStepIndicator(1, 'Account'),
              _buildStepConnector(1),
              _buildStepIndicator(2, 'Details'),
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
        return _buildCodeStep();
      case 1:
        return _buildAccountStep();
      case 2:
        return _buildOrganizationStep();
      default:
        return const SizedBox.shrink();
    }
  }
Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Registration Code',
          'Enter the code provided by InterBridge',
          Icons.vpn_key_outlined,
        ),
        const SizedBox(height: AppSize.s24),
        // ... (Keep your info container exactly as it is) ...
        const SizedBox(height: AppSize.s24),
        
        _buildTextField(
          controller: _codeController,
          label: 'Registration Code',
          hint: 'e.g. ORG-ABCD-1234',
          icon: Icons.tag,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [OrgCodeFormatter()], // <--- 1. ADD THE FORMATTER HERE
          validator: (value) {
            // 2. UPDATE THE VALIDATOR TO CHECK FOR THE FULL FORMAT
            if (value == null || value.isEmpty || value == 'ORG' || value == 'ORG-') {
              return 'Please enter your registration code';
            }
            if (value.length < 13) {
              return 'Please enter a complete code (e.g. ORG-ABCD-1234)';
            }
            return null;
          },
        ),
      ],
    );
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

// Find where you define _orgDescriptionController and add this right below it:

  const SizedBox(height: AppSize.s16),
  // --- ADD THIS NEW SECTION ---
  const Text(
    'Billing Preference',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Color(0xFF0F172A),
    ),
  ),
  const SizedBox(height: AppSize.s8),
  Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        RadioListTile<String>(
          title: const Text('Prepaid (Pay Upfront)', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Top up balance before calls. Includes 2 hours free trial.'),
          value: 'prepaid',
          groupValue: _billingMethod,
          activeColor: ColorManager.primary2,
          onChanged: (value) => setState(() => _billingMethod = value!),
        ),
        const Divider(height: 1),
        RadioListTile<String>(
          title: const Text('Postpaid (Billed Monthly)', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Use now, pay invoice at the end of the month.'),
          value: 'postpaid', // Notice I mapped this to 'postpaid' or 'pay_as_you_go' based on your preference
          groupValue: _billingMethod,
          activeColor: ColorManager.primary2,
          onChanged: (value) => setState(() => _billingMethod = value!),
        ),
        const Divider(height: 1),
        RadioListTile<String>(
          title: const Text('Subscription (Monthly Plan)', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Pay a fixed monthly fee for a set number of minutes.'),
          value: 'subscription',
          groupValue: _billingMethod,
          activeColor: ColorManager.primary2,
          onChanged: (value) => setState(() => _billingMethod = value!),
        ),
      ],
    ),
  ),
  // --- END NEW SECTION ---
  // --- END NEW SECTION ---

  const SizedBox(height: AppSize.s24),
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
            color: ColorManager.primary2.withValues(alpha: 0.1),
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
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters, // <--- 1. ADD THIS PARAMETER
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      validator: validator,
      inputFormatters: inputFormatters, // <--- 2. PASS IT TO THE TEXTFORMFIELD
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        // ... (keep the rest of your decoration the same)
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
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.all(AppSize.s20),
      decoration: BoxDecoration(
        color: ColorManager.backgroundPrimary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isFirstStep) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading || _isValidatingCode ? null : _previousStep,
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
            const SizedBox(width: AppSize.s16),
          ],
          Expanded(
            flex: isFirstStep ? 1 : 2,
            child: CustomButton(
              onTap: () {
                if (!isLoading && !_isValidatingCode) _nextStep(context);
              },
              isLoading: isLoading || _isValidatingCode,
              color: ColorManager.primary2,
              borderRadius: BorderRadius.circular(AppSize.s12),
              child: Text(
                _isValidatingCode
                    ? 'Validating...'
                    : (isLastStep ? 'Create Organization' : 'Continue'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  Future<void> _nextStep(BuildContext context) async {
    // Validate current step
    if (!_validateCurrentStep()) {
      return;
    }

    if (_currentStep == 0) {
      setState(() => _isValidatingCode = true);
      final code = _codeController.text.trim().toUpperCase();
      try {
        final response = await Supabase.instance.client
            .from('organization_registration_codes')
            .select('id, is_used')
            .eq('code', code)
            .maybeSingle();
            
        if (response == null) {
          if (mounted) _showError('Invalid or already used registration code.');
          setState(() => _isValidatingCode = false);
          return;
        }
        
        if (response['is_used'] == true) {
          if (mounted) _showError('This registration code has already been used.');
          setState(() => _isValidatingCode = false);
          return;
        }
        
        setState(() {
          _isValidatingCode = false;
          _currentStep++;
        });
      } catch (e) {
        if (mounted) _showError('Error validating code.');
        setState(() => _isValidatingCode = false);
      }
      return;
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      // Final step - submit
      _submitApplication(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_codeController.text.trim().isEmpty) {
          _showError('Please enter your registration code');
          return false;
        }
        return true;

      case 1:
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

      case 2:
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
        registrationCode: _codeController.text.trim().toUpperCase(),
        // Add this line (requires updating the event class)
        billingMethod: _billingMethod, 
      ),
    );
  }}
  // Place this at the very bottom of your file
class OrgCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    
    // 1. Strip out everything that isn't a letter or number, and force uppercase
    String cleanText = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // 2. Ensure it ALWAYS starts with 'ORG' (prevents user from deleting it)
    if (!cleanText.startsWith('ORG')) {
      cleanText = 'ORG' + cleanText.replaceFirst(RegExp(r'^O?R?G?'), '');
    }

    // 3. Separate the 'ORG' prefix from whatever the user is typing
    String remainder = cleanText.substring(3);

    // 4. Build the final formatted string
    StringBuffer buffer = StringBuffer();
    buffer.write('ORG');

    if (remainder.isNotEmpty) {
      buffer.write('-');
      if (remainder.length > 4) {
        // Add the first 4 characters, then another dash, then the final 4 characters (max 8)
        buffer.write(remainder.substring(0, 4));
        buffer.write('-');
        buffer.write(remainder.substring(4, remainder.length > 8 ? 8 : remainder.length));
      } else {
        // Add up to the first 4 characters
        buffer.write(remainder);
      }
    }

    String finalString = buffer.toString();

    // 5. Return the new formatted string, keeping the cursor at the end
    return TextEditingValue(
      text: finalString,
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}