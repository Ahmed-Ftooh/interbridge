import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/services/permission_service.dart';

class SettingView extends StatefulWidget {
  const SettingView({super.key});

  @override
  State<SettingView> createState() => _SettingViewState();
}

class _SettingViewState extends State<SettingView> {
  bool _notificationsEnabled = true;
  Map<String, bool> _permissionStatus = {};
  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  final AppPreferences _appPreferences = instance<AppPreferences>();

  Future<void> _loadPermissionStatus() async {
    final status = await PermissionService.checkAllAppPermissions();
    setState(() {
      _permissionStatus = status;
    });
  }

  Future<void> _requestPermissions() async {
    final results = await PermissionService.requestAllAppPermissions();
    setState(() {
      _permissionStatus = results;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permissions updated'),
          backgroundColor: ColorManager.success,
        ),
      );
    }
  }

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
          const SizedBox(height: AppSize.s16),

          // Notifications
          _buildSimpleTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Push notifications for calls and messages',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
              activeColor: ColorManager.primary2,
            ),
          ),

          const Divider(height: 1),

          // Permissions
          _buildSimpleTile(
            icon: Icons.security,
            title: 'App Permissions',
            subtitle: 'Manage app permissions',
            onTap: _requestPermissions,
          ),

          // Permission Status
          if (_permissionStatus.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSize.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSize.s8),
                  Text(
                    'Permission Status:',
                    style: TextStyle(
                      fontSize: AppSize.s12,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSize.s4),
                  ...(_permissionStatus.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(left: AppSize.s16),
                      child: Row(
                        children: [
                          Icon(
                            entry.value ? Icons.check_circle : Icons.cancel,
                            color: entry.value ? Colors.green : Colors.red,
                            size: AppSize.s16,
                          ),
                          const SizedBox(width: AppSize.s8),
                          Text(
                            '${entry.key}: ${entry.value ? "Granted" : "Denied"}',
                            style: TextStyle(
                              fontSize: AppSize.s12,
                              color: ColorManager.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: AppSize.s16),
                ],
              ),
            ),
          ],

          const Divider(height: 1),

          // Profile
          _buildSimpleTile(
            icon: Icons.person,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            onTap: () {
              // Navigate to profile edit
              _showSnackBar('Profile editing coming soon!');
            },
          ),

          const Divider(height: 1),

          // Help
          _buildSimpleTile(
            icon: Icons.help,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () {
              _showSnackBar('Help center coming soon!');
            },
          ),

          const Divider(height: 1),

          // About
          _buildSimpleTile(
            icon: Icons.info,
            title: 'About',
            subtitle: 'App version 1.0.0',
            onTap: () {
              _showSnackBar('About section coming soon!');
            },
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
