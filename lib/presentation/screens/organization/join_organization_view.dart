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
      debugPrint('Looking up invite code: $code');

      // Use the secure database function to look up invites by code
      // This bypasses RLS restrictions so anyone with a valid code can find it
      final response = await _supabase.client.rpc(
        'lookup_invite_by_code',
        params: {'p_invite_code': code},
      );

      // Show debug dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Debug Info'),
                content: SingleChildScrollView(
                  child: Text(
                    'Code: $code\n\nResponse type: ${response.runtimeType}\n\nResponse: $response',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }

      debugPrint('RPC response type: ${response.runtimeType}');
      debugPrint('RPC response: $response');

      // Handle both List and Map responses
      Map<String, dynamic>? result;
      if (response is List) {
        debugPrint('Response is a List with ${response.length} items');
        if (response.isNotEmpty) {
          result = response.first as Map<String, dynamic>;
        }
      } else if (response is Map<String, dynamic>) {
        debugPrint('Response is a Map');
        result = response;
      } else {
        debugPrint('Response is unexpected type: ${response.runtimeType}');
      }

      if (result != null && result.isNotEmpty) {
        final inviteType = result['invite_type'] as String;
        debugPrint('Found invite type: $inviteType');
        debugPrint('Organization ID: ${result['organization_id']}');
        debugPrint('Organization Name: ${result['organization_name']}');
        setState(() {
          _foundOrganization = {
            'type': inviteType,
            'invite_id': result!['invite_id'],
            'organization': {
              'id': result['organization_id'],
              'name': result['organization_name'],
              'email': result['organization_email'],
            },
            'role': result['role'],
          };
        });
      } else {
        debugPrint('No result found for code: $code');
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Invalid or expired invite code',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error looking up code: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error: ${e.toString()}',
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
      final role = _foundOrganization!['role'] as String? ?? 'doctor';

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
        final inviteId = _foundOrganization!['invite_id'] as String?;
        if (inviteId != null) {
          await _supabase.client
              .from('organization_invites')
              .update({
                'status': 'accepted',
                'redeemed_by': userId,
                'redeemed_at': DateTime.now().toIso8601String(),
              })
              .eq('id', inviteId);
        }
      }

      // Add user to organization
      await _supabase.client.from('organization_members').insert({
        'organization_id': orgId,
        'user_id': userId,
        'role': role,
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
