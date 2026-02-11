import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modern web-specific settings view
class SettingViewWeb extends StatefulWidget {
  const SettingViewWeb({super.key});

  @override
  State<SettingViewWeb> createState() => _SettingViewWebState();
}

class _SettingViewWebState extends State<SettingViewWeb> {
  final AppPreferences _appPreferences = instance<AppPreferences>();
  final SupabaseService _supabaseService = SupabaseService();
  bool _isInOrganization = false;
  String? _userRole;
  String? _hoveredItem;

  @override
  void initState() {
    super.initState();
    _checkOrganizationMembership();
  }

  Future<void> _checkOrganizationMembership() async {
    final userId = _supabaseService.getCurrentUser()?.id;
    if (userId == null) return;

    try {
      final profile = await _supabaseService.getUserProfile(userId);
      _userRole = profile?.role;

      final member =
          await _supabaseService.client
              .from('organization_members')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

      if (mounted) {
        setState(() {
          _isInOrganization = member != null;
        });
      }
    } catch (e) {
      debugPrint('Error checking org membership: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your account and preferences',
                  style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 32),

                // Account Section
                _buildSection(
                  title: 'Account',
                  children: [
                    _buildSettingItem(
                      id: 'password',
                      icon: Icons.lock_reset,
                      iconColor: const Color(0xFF0955FA),
                      title: 'Change Password',
                      subtitle: 'Update your account password',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            Routes.changePassword,
                          ),
                    ),
                    if (_userRole == 'requester' && !_isInOrganization)
                      _buildSettingItem(
                        id: 'join_org',
                        icon: Icons.business,
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'Join Organization',
                        subtitle: 'Join a healthcare organization',
                        onTap:
                            () => Navigator.pushNamed(
                              context,
                              Routes.joinOrganizationRoute,
                            ),
                      ),
                    _buildSettingItem(
                      id: 'delete',
                      icon: Icons.delete_forever,
                      iconColor: const Color(0xFFEF4444),
                      title: 'Delete Account',
                      subtitle: 'Permanently remove your account',
                      onTap: _showDeleteDialog,
                      isDestructive: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Legal Section
                _buildSection(
                  title: 'Legal',
                  children: [
                    _buildSettingItem(
                      id: 'privacy',
                      icon: Icons.privacy_tip,
                      iconColor: const Color(0xFF22C55E),
                      title: 'Privacy Policy',
                      subtitle: 'Learn how we handle your data',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            Routes.privacyPolicy,
                          ),
                    ),
                    _buildSettingItem(
                      id: 'terms',
                      icon: Icons.description,
                      iconColor: const Color(0xFF6366F1),
                      title: 'Terms of Service',
                      subtitle: 'Rules for using InterBridge',
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            Routes.termsOfService,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sign Out Section
                _buildSection(
                  title: 'Session',
                  children: [
                    _buildSettingItem(
                      id: 'signout',
                      icon: Icons.logout,
                      iconColor: const Color(0xFFEF4444),
                      title: 'Sign Out',
                      subtitle: 'Sign out of your account',
                      onTap: _showSignOutDialog,
                      isDestructive: true,
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // App Version
                Center(
                  child: Text(
                    'InterBridge v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children:
                children.asMap().entries.map((entry) {
                  final index = entry.key;
                  final child = entry.value;
                  return Column(
                    children: [
                      child,
                      if (index < children.length - 1)
                        const Divider(height: 1, indent: 72),
                    ],
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required String id,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isHovered = _hoveredItem == id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredItem = id),
      onExit: (_) => setState(() => _hoveredItem = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isHovered ? const Color(0xFFF8FAFC) : Colors.transparent,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(
                        alpha: isHovered ? 0.15 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color:
                                isDestructive
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color:
                        isHovered
                            ? const Color(0xFF64748B)
                            : const Color(0xFFCBD5E1),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _supabaseService.signOut();
                  await _appPreferences.logout();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      Routes.loginRoute,
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                SizedBox(width: 8),
                Text('Delete Account'),
              ],
            ),
            content: const Text(
              'This action cannot be undone. All your data will be permanently deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final client = Supabase.instance.client;
                    final user = client.auth.currentUser;
                    if (user == null) {
                      throw Exception('Not authenticated');
                    }

                    // Invoke edge function that performs secure deletion
                    final response = await client.functions.invoke(
                      'delete-account',
                      body: {'user_id': user.id, 'mode': 'hard'},
                    );

                    if (response.data == null ||
                        (response.data is Map &&
                            response.data['status'] != 'ok')) {
                      throw Exception('Deletion failed or not confirmed');
                    }

                    await client.auth.signOut();
                    await _appPreferences.logout();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.loginRoute,
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      CustomSnackBar.show(
                        context,
                        message: 'Failed to delete account: $e',
                        type: SnackBarType.error,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete Account'),
              ),
            ],
          ),
    );
  }
}
