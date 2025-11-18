import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingView extends StatefulWidget {
  const SettingView({super.key});

  @override
  State<SettingView> createState() => _SettingViewState();
}

class _SettingViewState extends State<SettingView> {
  final AppPreferences _appPreferences = instance<AppPreferences>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppSize.s12),

          // Account Section Header
          _sectionHeader('Account'),
          _buildSimpleTile(
            icon: Icons.lock_reset,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => Navigator.pushNamed(context, Routes.changePassword),
          ),
          const Divider(height: 1),
          _buildSimpleTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently remove your account',
            titleColor: ColorManager.error,
            onTap: _showDeleteDialog,
          ),
          const Divider(height: 1),

          // Legal Section Header
          _sectionHeader('Legal'),
          _buildSimpleTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'Learn how we handle your data',
            onTap: () => Navigator.pushNamed(context, Routes.privacyPolicy),
          ),
          const Divider(height: 1),
          _buildSimpleTile(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'Rules for using InterBridge',
            onTap: () => Navigator.pushNamed(context, Routes.termsOfService),
          ),
          const Divider(height: 1),

          // Sign Out
          _buildSimpleTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            titleColor: ColorManager.error,
            onTap: _showSignOutDialog,
          ),

          const SizedBox(height: AppSize.s32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSize.s16,
        AppSize.s8,
        AppSize.s16,
        AppSize.s4,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: AppSize.s12,
          fontWeight: FontWeight.w600,
          color: ColorManager.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSimpleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSize.s8),
        decoration: BoxDecoration(
          color: ColorManager.primary2.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSize.s8),
        ),
        child: Icon(
          icon,
          color: titleColor ?? ColorManager.primary2,
          size: AppSize.s20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppSize.s16,
          fontWeight: FontWeight.w600,
          color: titleColor ?? ColorManager.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: AppSize.s14,
          color: ColorManager.textSecondary,
        ),
      ),
      trailing:
          trailing ??
          Icon(
            Icons.arrow_forward_ios,
            color: ColorManager.textSecondary,
            size: AppSize.s16,
          ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSize.s16,
        vertical: AppSize.s8,
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _appPreferences.logout();
                  _signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'This action is permanent and will remove your profile, requests, and interpreter data. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.error,
                  foregroundColor: ColorManager.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteAccount();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Not authenticated');
      }

      // Invoke edge function that performs secure deletion (must be implemented server-side)
      // Example edge function name: delete-account
      final response = await client.functions.invoke(
        'delete-account',
        body: {
          'user_id': user.id,
          // change to 'soft' to enable soft-delete behavior
          'mode': 'hard',
        },
      );

      if (response.data == null ||
          (response.data is Map && response.data['status'] != 'ok')) {
        throw Exception('Deletion failed or not confirmed');
      }

      // Sign out locally after deletion
      await client.auth.signOut();
      _showSnackBar('Account deleted');
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.loginRoute,
        (r) => false,
      );
    } catch (e) {
      _showSnackBar('Error deleting account: $e', isError: true);
    }
  }

  Future<void> _signOut() async {
    try {
      await SupabaseService().signOut();
      _showSnackBar('Signed out successfully');
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.loginRoute,
        (route) => false,
      );
    } catch (e) {
      _showSnackBar('Error signing out: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ColorManager.error : ColorManager.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
