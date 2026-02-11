import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return AuthWebWrapper(
      title: 'Select Your Role',
      subtitle: 'Choose how you want to use Interbridge',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

          // I am an Interpreter
          _buildRoleCard(
            role: 'interpreter',
            icon: Icons.translate,
            iconColor: const Color(0xFF6366F1),
            title: 'I am an Interpreter',
            subtitle: 'Offer your interpretation services',
            onTap:
                () => Navigator.of(
                  context,
                ).pushNamed(Routes.interpreterTrackSelection),
          ),
          const SizedBox(height: 16),

          // Organization
          _buildRoleCard(
            role: 'organization',
            icon: Icons.business,
            iconColor: const Color(0xFFF59E0B),
            title: 'Organization',
            subtitle: 'Register your organization to manage doctors and calls',
            onTap:
                () => Navigator.of(
                  context,
                ).pushNamed(Routes.organizationRegisterRoute),
          ),
          const SizedBox(height: 32),

          // Back to login
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
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
