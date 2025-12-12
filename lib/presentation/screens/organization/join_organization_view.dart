import 'package:flutter/material.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';

/// Screen for existing users to join an organization using an invite code
class JoinOrganizationView extends StatefulWidget {
  const JoinOrganizationView({super.key});

  @override
  State<JoinOrganizationView> createState() => _JoinOrganizationViewState();
}

class _JoinOrganizationViewState extends State<JoinOrganizationView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _supabase = SupabaseService();
  bool _loading = false;
  Map<String, dynamic>? _foundOrganization;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _lookupCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _foundOrganization = null;
    });

    try {
      final code = _codeController.text.trim().toUpperCase();

      // Look up the invite code
      final invite =
          await _supabase.client
              .from('organization_invites')
              .select('*, organizations(id, name, email)')
              .eq('invite_code', code)
              .eq('status', 'pending')
              .gt('expires_at', DateTime.now().toIso8601String())
              .maybeSingle();

      if (invite == null) {
        // Try the organization's general invite code
        final org =
            await _supabase.client
                .from('organizations')
                .select('id, name, email')
                .eq('invite_code', code)
                .maybeSingle();

        if (org != null) {
          setState(() {
            _foundOrganization = {'type': 'org_code', 'organization': org};
          });
        } else {
          if (mounted) {
            CustomSnackBar.show(
              context,
              message: 'Invalid or expired invite code',
              type: SnackBarType.error,
            );
          }
        }
      } else {
        setState(() {
          _foundOrganization = {
            'type': 'personal_invite',
            'invite': invite,
            'organization': invite['organizations'],
          };
        });
      }
    } catch (e) {
      debugPrint('Error looking up code: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error looking up code',
          type: SnackBarType.error,
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _joinOrganization() async {
    if (_foundOrganization == null) return;

    setState(() => _loading = true);

    try {
      final userId = _supabase.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('Not logged in');
      }

      final org = _foundOrganization!['organization'] as Map<String, dynamic>;
      final orgId = org['id'] as String;
      final type = _foundOrganization!['type'] as String;

      // Check if user is already a member
      final existingMember =
          await _supabase.client
              .from('organization_members')
              .select('id')
              .eq('organization_id', orgId)
              .eq('user_id', userId)
              .maybeSingle();

      if (existingMember != null) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'You are already a member of this organization',
            type: SnackBarType.warning,
          );
        }
        return;
      }

      // If it's a personal invite, mark it as redeemed
      if (type == 'personal_invite') {
        final invite = _foundOrganization!['invite'] as Map<String, dynamic>;
        await _supabase.client
            .from('organization_invites')
            .update({
              'status': 'accepted',
              'redeemed_by': userId,
              'redeemed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', invite['id']);
      }

      // Add user to organization
      await _supabase.client.from('organization_members').insert({
        'organization_id': orgId,
        'user_id': userId,
        'role': 'doctor',
        'is_active': true,
        'spending_limit': null,
        'total_spent': 0,
      });

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Successfully joined ${org['name']}!',
          type: SnackBarType.success,
        );

        // Navigate back to main screen
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
      }
    } catch (e) {
      debugPrint('Error joining organization: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to join organization',
          type: SnackBarType.error,
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Organization'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSize.s24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(Icons.business, size: 64, color: ColorManager.primary2),
              const SizedBox(height: AppSize.s16),
              Text(
                'Join an Organization',
                style: TextStyle(
                  fontSize: AppSize.s24,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSize.s8),
              Text(
                'Enter the invite code provided by your organization administrator',
                style: TextStyle(
                  fontSize: AppSize.s14,
                  color: ColorManager.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSize.s32),

              // Invite Code Input
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Invite Code',
                  hintText: 'Enter 8-character code',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSize.s12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an invite code';
                  }
                  if (value.length < 6) {
                    return 'Code is too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSize.s16),

              // Look Up Button
              if (_foundOrganization == null)
                ElevatedButton(
                  onPressed: _loading ? null : _lookupCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primary2,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSize.s12),
                    ),
                  ),
                  child:
                      _loading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Look Up Code'),
                ),

              // Organization Found Card
              if (_foundOrganization != null) ...[
                const SizedBox(height: AppSize.s24),
                Container(
                  padding: const EdgeInsets.all(AppSize.s20),
                  decoration: BoxDecoration(
                    color: ColorManager.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSize.s12),
                    border: Border.all(
                      color: ColorManager.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: ColorManager.success,
                        size: 48,
                      ),
                      const SizedBox(height: AppSize.s12),
                      Text(
                        'Organization Found!',
                        style: TextStyle(
                          fontSize: AppSize.s18,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.success,
                        ),
                      ),
                      const SizedBox(height: AppSize.s8),
                      Text(
                        _foundOrganization!['organization']['name'] ??
                            'Unknown',
                        style: TextStyle(
                          fontSize: AppSize.s20,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                      if (_foundOrganization!['organization']['email'] != null)
                        Text(
                          _foundOrganization!['organization']['email'],
                          style: TextStyle(
                            fontSize: AppSize.s14,
                            color: ColorManager.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSize.s24),
                ElevatedButton(
                  onPressed: _loading ? null : _joinOrganization,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSize.s16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSize.s12),
                    ),
                  ),
                  child:
                      _loading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Join Organization'),
                ),
                const SizedBox(height: AppSize.s12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _foundOrganization = null;
                      _codeController.clear();
                    });
                  },
                  child: const Text('Try Different Code'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
