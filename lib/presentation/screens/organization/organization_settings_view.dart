import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationSettingsView extends StatefulWidget {
  const OrganizationSettingsView({super.key});

  @override
  State<OrganizationSettingsView> createState() =>
      _OrganizationSettingsViewState();
}

class _OrganizationSettingsViewState extends State<OrganizationSettingsView> {
  final _supabase = SupabaseService();
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

          // Account Section
          _sectionHeader('Account'),
          _buildSettingsTile(
            icon: Icons.lock_reset,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => Navigator.pushNamed(context, Routes.changePassword),
          ),
          const Divider(height: 1),

          // Legal Section
          _sectionHeader('Legal'),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'Learn how we handle your data',
            onTap: () => Navigator.pushNamed(context, Routes.privacyPolicy),
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'Rules for using InterBridge',
            onTap: () => Navigator.pushNamed(context, Routes.termsOfService),
          ),
          const Divider(height: 1),

          // Danger Zone Section
          _sectionHeader('Danger Zone'),
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            iconColor: ColorManager.error,
            titleColor: ColorManager.error,
            onTap: _showSignOutDialog,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently remove your account',
            iconColor: ColorManager.error,
            titleColor: ColorManager.error,
            onTap: _showDeleteAccountDialog,
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
        AppSize.s16,
        AppSize.s16,
        AppSize.s8,
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

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSize.s8),
        decoration: BoxDecoration(
          color: (iconColor ?? ColorManager.primary2).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSize.s8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? ColorManager.primary2,
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
      trailing: Icon(
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

  Future<void> _signOut() async {
    try {
      // Navigate FIRST to prevent disposed BLoCs from reacting to auth change
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);

      // THEN sign out (auth state fires on login page)
      await _appPreferences.logout();
      await _supabase.signOut();
    } catch (e) {
      // Already navigated — log but don't show snackbar
      debugPrint('Error during sign out: $e');
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'This action is permanent and will remove your profile, organization data, and all associated information. This cannot be undone.\n\nAre you sure you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAccount();
                },
                child: const Text('Delete Account'),
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

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Invoke edge function for secure deletion
      final response = await client.functions.invoke(
        'delete-account',
        body: {'user_id': user.id, 'mode': 'hard'},
      );

      if (response.data == null ||
          (response.data is Map && response.data['status'] != 'ok')) {
        throw Exception('Deletion failed or not confirmed');
      }

      // Sign out locally after deletion
      await client.auth.signOut();
      await _appPreferences.logout();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      CustomSnackBar.show(
        context,
        message: 'Account deleted successfully',
        type: SnackBarType.success,
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.loginRoute,
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      CustomSnackBar.show(
        context,
        message: 'Error deleting account: $e',
        type: SnackBarType.error,
      );
    }
  }
}
