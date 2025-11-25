import 'package:flutter/material.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:interbridge/presentation/widgets/custom_button.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Enter your email',
        type: SnackBarType.error,
      );
      return;
    }
    if (_codeController.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Enter the recovery code',
        type: SnackBarType.error,
      );
      return;
    }
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.isEmpty || password.length < 6) {
      CustomSnackBar.show(
        context,
        message: 'Password must be at least 6 characters',
        type: SnackBarType.error,
      );
      return;
    }
    if (password != confirm) {
      CustomSnackBar.show(
        context,
        message: 'Passwords do not match',
        type: SnackBarType.error,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      // First verify recovery token to establish a session
      await SupabaseService().verifyRecoveryOtp(
        email: _emailController.text.trim(),
        token: _codeController.text.trim(),
      );
      await SupabaseService().updatePassword(newPassword: password);
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Password updated successfully',
        type: SnackBarType.success,
      );
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Failed to update password: $e',
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        title: const Text('Reset Password'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSize.s24),
        child: Column(
          children: [
            const SizedBox(height: AppSize.s24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppSize.s16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Recovery code'),
            ),
            const SizedBox(height: AppSize.s16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: AppSize.s16),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
            ),
            const SizedBox(height: AppSize.s24),
            CustomButton(
              onTap: _submit,
              isLoading: _isLoading,
              color: ColorManager.primary2,
              borderRadius: BorderRadius.circular(AppSize.s12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_reset, size: AppSize.s20),
                  SizedBox(width: AppSize.s8),
                  Text('Update password'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
