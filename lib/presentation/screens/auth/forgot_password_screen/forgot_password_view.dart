import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_text_field_container.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/customButtom.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // Show success message
    CustomSnackBar.show(
      context: context,
      message: AppStrings.resetLinkSentToEmail,
      type: SnackBarType.success,
    );

    // Navigate back after showing success message
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
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
          AppStrings.titleforgotPassword,
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
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(AppSize.s24),
              child: Column(
                children: [
                  const SizedBox(height: AppSize.s40),

                  // Description Card
                  Container(
                    padding: const EdgeInsets.all(AppSize.s16),
                    decoration: BoxDecoration(
                      color: ColorManager.backgroundCard,
                      borderRadius: BorderRadius.circular(AppSize.s12),
                      border: Border.all(
                        color: ColorManager.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: ColorManager.primary,
                          size: AppSize.s20,
                        ),
                        const SizedBox(width: AppSize.s12),
                        Expanded(
                          child: Text(
                            AppStrings.enterEmailAndWeWillSend,
                            style: TextStyle(
                              fontSize: AppSize.s14,
                              color: ColorManager.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSize.s20),

                  // Email Field
                  CustomTextFieldContainer(
                    controller: _emailController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppStrings.pleaseEnterEmailAddress;
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$',
                      ).hasMatch(value)) {
                        return AppStrings.pleaseEnterValidEmail;
                      }
                      return null;
                    },
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

                  const SizedBox(height: AppSize.s24),

                  // Send Reset Link Button
                  CustomButton(
                    onTap: _sendResetLink,
                    color: ColorManager.primary2,
                    isLoading: _isLoading,
                    borderRadius: BorderRadius.circular(AppSize.s12),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, size: AppSize.s20),
                        SizedBox(width: AppSize.s8),
                        Text(
                          AppStrings.sendResetLink,
                          style: TextStyle(
                            fontSize: AppSize.s16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSize.s24),

                  // Back to Login
                  Container(
                    padding: const EdgeInsets.all(AppSize.s20),
                    decoration: BoxDecoration(
                      color: ColorManager.backgroundCard,
                      borderRadius: BorderRadius.circular(AppSize.s12),
                      border: Border.all(
                        color: ColorManager.greyMedium.withValues(alpha: 0.3),
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
