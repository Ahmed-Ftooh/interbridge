import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';

/// Modern web-specific role selection screen
/// Matches the mobile app with 3 options: Join Organization, Interpreter, Organization
class SelectRoleScreenWeb extends StatefulWidget {
  const SelectRoleScreenWeb({super.key});

  @override
  State<SelectRoleScreenWeb> createState() => _SelectRoleScreenWebState();
}

class _SelectRoleScreenWebState extends State<SelectRoleScreenWeb> {
  String? _hoveredRole;

  String _currentPortalIntent() {
    if (!kIsWeb) return 'shared';

    final path = Uri.base.path.toLowerCase();
    final host = Uri.base.host.toLowerCase();

    if (path.startsWith('/admin') || host.startsWith('admin.')) {
      return 'admin';
    }
    if (path.startsWith('/organization') || host.startsWith('organization.')) {
      return 'organization';
    }
    if (path.startsWith('/interpreter') || host.startsWith('interpreter.')) {
      return 'interpreter';
    }

    return 'shared';
  }

  String _titleForPortal(String portalIntent) {
    switch (portalIntent) {
      case 'interpreter':
        return 'Apply As Interpreter';
      case 'organization':
        return 'Organization Access';
      case 'admin':
        return 'Admin Portal';
      default:
        return 'Select Your Role';
    }
  }

  String _subtitleForPortal(String portalIntent) {
    switch (portalIntent) {
      case 'interpreter':
        return 'Create an interpreter account to join the network';
      case 'organization':
        return 'Register your organization or join via invite';
      case 'admin':
        return 'Account creation is disabled in the admin portal';
      default:
        return 'Choose how you want to use Interbridge';
    }
  }

  String _loginRouteForPortal(String portalIntent) {
    switch (portalIntent) {
      case 'interpreter':
        return Routes.interpreterPortalLoginRoute;
      case 'organization':
        return Routes.organizationPortalLoginRoute;
      case 'admin':
        return Routes.adminPortalLoginRoute;
      default:
        return Routes.loginRoute;
    }
  }

  @override
  Widget build(BuildContext context) {
    final portalIntent = _currentPortalIntent();
    final showJoinOrganization =
        portalIntent == 'shared' || portalIntent == 'organization';
    final showInterpreter =
        portalIntent == 'shared' || portalIntent == 'interpreter';
    final showOrganization =
        portalIntent == 'shared' || portalIntent == 'organization';

    return AuthWebWrapper(
      title: _titleForPortal(portalIntent),
      subtitle: _subtitleForPortal(portalIntent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showJoinOrganization) ...[
            // Join Organization (for doctors with invite code)
            _buildRoleCard(
              role: 'doctor_join',
              icon: Icons.group_add,
              iconColor: const Color(0xFF0955FA),
              title: 'Join Organization',
              subtitle: 'Join as a doctor with an invite code',
              onTap:
                  () => Navigator.of(
                    context,
                  ).pushNamed(Routes.doctorJoinOrganizationRoute),
            ),
            const SizedBox(height: 16),
          ],

          if (showInterpreter) ...[
            // I am an Interpreter
            _buildRoleCard(
              role: 'interpreter',
              icon: Icons.translate,
              iconColor: const Color(0xFF6366F1),
              title: 'I am an Interpreter',
              subtitle: 'Offer your interpretation services',
              onTap:
                  () => Navigator.of(context).pushNamed(
                    Routes.registerRoute,
                    arguments: {'role': 'interpreter'},
                  ),
            ),
            const SizedBox(height: 16),
          ],

          if (showOrganization) ...[
            // Organization
            _buildRoleCard(
              role: 'organization',
              icon: Icons.business,
              iconColor: const Color(0xFFF59E0B),
              title: 'Organization',
              subtitle:
                  'Register your organization to manage doctors and calls',
              onTap:
                  () => Navigator.of(
                    context,
                  ).pushNamed(Routes.organizationRegisterRoute),
            ),
            const SizedBox(height: 32),
          ],

          if (!showJoinOrganization && !showInterpreter && !showOrganization)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Self registration is not available in the admin portal. Please contact your system administrator if you need access.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          if (!showJoinOrganization && !showInterpreter && !showOrganization)
            const SizedBox(height: 24),

          // Back to login
          Center(
            child: TextButton.icon(
              onPressed:
                  () => Navigator.of(context).pushNamedAndRemoveUntil(
                    _loginRouteForPortal(portalIntent),
                    (route) => false,
                  ),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to Login'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isHovered = _hoveredRole == role;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRole = role),
      onExit: (_) => setState(() => _hoveredRole = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isHovered
                    ? iconColor.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0),
            width: isHovered ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isHovered
                      ? iconColor.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(
                        alpha: isHovered ? 0.15 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 30),
                  ),
                  const SizedBox(width: 20),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                isHovered ? iconColor : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    color: isHovered ? iconColor : const Color(0xFF94A3B8),
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
}
