import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text.trim();
    final newPass = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (newPass != confirm) {
      _showSnack('New passwords do not match', true);
      return;
    }
    if (newPass.length < 8) {
      _showSnack('Password must be at least 8 characters', true);
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _showSnack('Not authenticated', true);
      return;
    }

    setState(() => _submitting = true);
    try {
      // 1. Re-authenticate by signing in with current password to verify
      final email = user.email;
      if (email == null) {
        throw Exception('User email unavailable');
      }
      final signInRes = await client.auth.signInWithPassword(
        email: email,
        password: current,
      );
      if (signInRes.user == null) {
        throw Exception('Current password incorrect');
      }

      // 2. Update password
      await client.auth.updateUser(UserAttributes(password: newPass));

      // 3. Force refresh of session
      await client.auth.signInWithPassword(email: email, password: newPass);

      if (!mounted) return;
      _showSnack('Password updated successfully', false);
      Navigator.pop(context);
    } on AuthException catch (e) {
      _showSnack(e.message, true);
    } catch (e) {
      _showSnack('Failed: $e', true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? ColorManager.error : ColorManager.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: ColorManager.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPasswordField(
              label: 'Current Password',
              controller: _currentController,
              visible: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
            ),
            const SizedBox(height: AppSize.s16),
            _buildPasswordField(
              label: 'New Password',
              controller: _newController,
              visible: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
            ),
            const SizedBox(height: AppSize.s16),
            _buildPasswordField(
              label: 'Confirm New Password',
              controller: _confirmController,
              visible: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),
            const SizedBox(height: AppSize.s32),
            SizedBox(
              width: double.infinity,
              height: AppSize.s50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primary2,
                  foregroundColor: ColorManager.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSize.s12),
                  ),
                ),
                child:
                    _submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: AppSize.s16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: ColorManager.backgroundCard,
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.s12),
        ),
      ),
    );
  }
}
