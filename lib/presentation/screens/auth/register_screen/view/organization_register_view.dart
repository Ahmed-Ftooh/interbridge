import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';

class OrganizationRegisterView extends StatefulWidget {
  const OrganizationRegisterView({super.key});

  @override
  State<OrganizationRegisterView> createState() =>
      _OrganizationRegisterViewState();
}

class _OrganizationRegisterViewState extends State<OrganizationRegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _orgNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
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
          'Register Organization',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSize.s24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Organization Info Section
              _buildSectionHeader('Organization Information', Icons.business),
              const SizedBox(height: AppSize.s16),
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
                controller: _emailController,
                label: 'Organization Email',
                hint: 'organization@example.com',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter organization email';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSize.s16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: '+1 234 567 8900',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSize.s16),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                hint: 'Enter organization address',
                icon: Icons.location_on,
                maxLines: 2,
              ),

              const SizedBox(height: AppSize.s40),

              // Continue Button
              CustomButton(
                onTap: _handleContinue,
                color: ColorManager.primary2,
                borderRadius: BorderRadius.circular(AppSize.s16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: AppSize.s16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: AppSize.s8),
                    Icon(Icons.arrow_forward, size: AppSize.s20),
                  ],
                ),
              ),

              const SizedBox(height: AppSize.s24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSize.s8),
          decoration: BoxDecoration(
            color: ColorManager.primary2.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSize.s8),
          ),
          child: Icon(icon, color: ColorManager.primary2, size: AppSize.s20),
        ),
        const SizedBox(width: AppSize.s12),
        Text(
          title,
          style: TextStyle(
            fontSize: AppSize.s18,
            fontWeight: FontWeight.bold,
            color: ColorManager.textPrimary,
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

  void _handleContinue() {
    if (_formKey.currentState!.validate()) {
      // Navigate to register screen with organization data
      Navigator.of(context).pushNamed(
        Routes.registerRoute,
        arguments: {
          'role': 'organization_admin',
          'organizationName': _orgNameController.text,
          'organizationEmail': _emailController.text,
          'organizationPhone': _phoneController.text,
          'organizationAddress': _addressController.text,
        },
      );
    } else {
      CustomSnackBar.show(
        context,
        message: 'Please fill all required fields correctly',
        type: SnackBarType.error,
      );
    }
  }
}
