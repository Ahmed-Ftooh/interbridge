import 'package:flutter/material.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';

/// Modern web-specific doctor join organization screen
class DoctorJoinOrganizationWebScreen extends StatefulWidget {
  const DoctorJoinOrganizationWebScreen({super.key});

  @override
  State<DoctorJoinOrganizationWebScreen> createState() =>
      _DoctorJoinOrganizationWebScreenState();
}

class _DoctorJoinOrganizationWebScreenState
    extends State<DoctorJoinOrganizationWebScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  final _supabase = SupabaseService();

  bool _isLoading = false;
  Map<String, dynamic>? _validatedInvite;
  String? _hoveredField;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _supabase.validateInviteCode(
        _inviteCodeController.text.trim(),
      );

      if (result != null) {
        setState(() {
          _validatedInvite = result;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Invalid or expired invite code',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error validating code: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _proceedToRegistration() {
    if (_validatedInvite == null) return;

    Navigator.of(context).pushNamed(
      Routes.registerRoute,
      arguments: {
        'role': 'doctor_with_invite',
        'organization_id': _validatedInvite!['organization_id'],
        'invite_id': _validatedInvite!['invite_id'],
        ..._validatedInvite!,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthWebWrapper(
      title: 'Join Organization',
      subtitle: 'Enter your invite code to join a healthcare organization',
      child:
          _validatedInvite != null
              ? _buildConfirmationContent()
              : _buildCodeEntryContent(),
    );
  }

  Widget _buildCodeEntryContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0955FA).withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0955FA), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ask your organization administrator for an invite code to join.',
                    style: TextStyle(
                      color: Color(0xFF0369A1),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Invite code field
          _buildTextField(
            controller: _inviteCodeController,
            fieldName: 'inviteCode',
            label: 'Invite Code',
            hint: 'Enter your organization invite code',
            icon: Icons.vpn_key_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an invite code';
              }
              if (value.trim().length < 6) {
                return 'Invite code must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Validate button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _validateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0955FA),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: const Color(
                  0xFF0955FA,
                ).withValues(alpha: 0.6),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Validate Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 24),

          // Back button
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to Role Selection'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationContent() {
    final orgName =
        _validatedInvite!['organization_name'] ?? 'Unknown Organization';
    final role = _validatedInvite!['role'] ?? 'Doctor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF22C55E).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF22C55E),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Invite Code Valid!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF166534),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You\'re ready to join:',
                style: TextStyle(fontSize: 14, color: Color(0xFF15803D)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Organization details
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.business,
                      color: Color(0xFF0955FA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Organization',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          orgName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF22C55E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Role',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          role.toString().replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Continue button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _proceedToRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue to Registration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Try different code button
        Center(
          child: TextButton(
            onPressed: () => setState(() => _validatedInvite = null),
            child: const Text(
              'Use a different code',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String fieldName,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    final isHovered = _hoveredField == fieldName;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredField = fieldName),
      onExit: (_) => setState(() => _hoveredField = null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  isHovered
                      ? [
                        BoxShadow(
                          color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: TextFormField(
              controller: controller,
              validator: validator,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 15, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0,
                ),
                prefixIcon: Icon(
                  icon,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color:
                        isHovered
                            ? const Color(0xFF0955FA).withValues(alpha: 0.5)
                            : const Color(0xFFE5E7EB),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0955FA),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
