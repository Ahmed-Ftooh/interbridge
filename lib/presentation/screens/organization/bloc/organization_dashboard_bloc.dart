import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_event.dart';
import 'package:interbridge/presentation/screens/organization/bloc/organization_dashboard_state.dart';

/// BLoC for managing organization dashboard data
class OrganizationDashboardBloc
    extends Bloc<OrganizationDashboardEvent, OrganizationDashboardState> {
  final SupabaseService _supabaseService;

  OrganizationDashboardBloc({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService(),
      super(OrganizationDashboardInitial()) {
    on<LoadOrganizationData>(_onLoadOrganizationData);
    on<RefreshOrganizationData>(_onRefreshOrganizationData);
    on<SendDoctorInvitation>(_onSendDoctorInvitation);
    on<CancelInvitation>(_onCancelInvitation);
    on<ProcessTopUp>(_onProcessTopUp);
    on<UpdateMemberStatus>(_onUpdateMemberStatus);
  }

  /// Load all organization dashboard data
  Future<void> _onLoadOrganizationData(
    LoadOrganizationData event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    try {
      emit(OrganizationDashboardLoading());

      final userId = _supabaseService.getCurrentUser()?.id;
      debugPrint('OrganizationDashboardBloc: Loading data for userId=$userId');

      if (userId == null) {
        debugPrint('OrganizationDashboardBloc: No user logged in');
        emit(const OrganizationNotFound('Not logged in'));
        return;
      }

      // Get organization for current user
      final memberData =
          await _supabaseService.client
              .from('organization_members')
              .select('organization_id, role')
              .eq('user_id', userId)
              .maybeSingle();

      debugPrint('OrganizationDashboardBloc: memberData=$memberData');

      if (memberData == null) {
        debugPrint(
          'OrganizationDashboardBloc: No organization membership found',
        );
        emit(OrganizationNotFound(userId));
        return;
      }

      final orgId = memberData['organization_id'];

      // Load all data in parallel
      final results = await Future.wait([
        _loadOrganization(orgId),
        _loadMembers(orgId),
        _loadPendingInvites(orgId),
        _loadCallHistory(orgId),
        _loadTransactions(orgId),
      ]);

      final organization = results[0] as Map<String, dynamic>?;
      if (organization == null) {
        emit(OrganizationNotFound(userId));
        return;
      }

      emit(
        OrganizationDashboardLoaded(
          organization: organization,
          members: results[1] as List<Map<String, dynamic>>,
          pendingInvites: results[2] as List<Map<String, dynamic>>,
          callHistory: results[3] as List<Map<String, dynamic>>,
          transactions: results[4] as List<Map<String, dynamic>>,
        ),
      );
    } catch (e, stackTrace) {
      log('OrganizationDashboardBloc._onLoadOrganizationData error: $e');
      debugPrint('Stack trace: $stackTrace');
      emit(OrganizationDashboardError('Failed to load organization data: $e'));
    }
  }

  /// Refresh organization data (same as load but triggered by user action)
  Future<void> _onRefreshOrganizationData(
    RefreshOrganizationData event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    // Just call load with the same logic
    await _onLoadOrganizationData(const LoadOrganizationData(), emit);
  }

  /// Send an invitation to a doctor
  Future<void> _onSendDoctorInvitation(
    SendDoctorInvitation event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    try {
      emit(currentState.copyWith(isSendingInvite: true));

      final userId = _supabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final orgId = currentState.organizationId;
      final orgName = currentState.organizationName;

      // Generate a unique invite code
      final inviteCode = _generateInviteCode();

      // Create invitation record
      await _supabaseService.client.from('organization_invites').insert({
        'organization_id': orgId,
        'inviter_id': userId,
        'email': event.email.toLowerCase(),
        'invite_code': inviteCode,
        'role': 'doctor',
        'status': 'pending',
        'expires_at':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });

      debugPrint(
        'Invitation created for ${event.email} with code: $inviteCode',
      );

      // Send invitation email via Edge Function
      try {
        final response = await _supabaseService.client.functions.invoke(
          'send-invite-email',
          body: {
            'to': event.email.toLowerCase(),
            'inviteCode': inviteCode,
            'organizationName': orgName,
          },
        );

        if (response.status == 200) {
          debugPrint('Invitation email sent successfully');
        } else {
          debugPrint('Failed to send invitation email: ${response.data}');
        }
      } catch (emailError) {
        debugPrint('Error sending invitation email: $emailError');
        // Don't throw - the invite was created, just email failed
      }

      // Reload pending invites
      final updatedInvites = await _loadPendingInvites(orgId);

      emit(
        currentState.copyWith(
          pendingInvites: updatedInvites,
          isSendingInvite: false,
          message: 'Invitation sent successfully!',
          isError: false,
        ),
      );
    } catch (e) {
      log('OrganizationDashboardBloc._onSendDoctorInvitation error: $e');
      emit(
        currentState.copyWith(
          isSendingInvite: false,
          message: 'Failed to send invitation: $e',
          isError: true,
        ),
      );
    }
  }

  /// Cancel a pending invitation
  Future<void> _onCancelInvitation(
    CancelInvitation event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    try {
      emit(currentState.copyWith(isCancellingInvite: true));

      await _supabaseService.client
          .from('organization_invites')
          .update({'status': 'cancelled'})
          .eq('id', event.inviteId);

      // Reload pending invites
      final updatedInvites = await _loadPendingInvites(
        currentState.organizationId,
      );

      emit(
        currentState.copyWith(
          pendingInvites: updatedInvites,
          isCancellingInvite: false,
          message: 'Invitation cancelled',
          isError: false,
        ),
      );
    } catch (e) {
      log('OrganizationDashboardBloc._onCancelInvitation error: $e');
      emit(
        currentState.copyWith(
          isCancellingInvite: false,
          message: 'Failed to cancel invitation',
          isError: true,
        ),
      );
    }
  }

  /// Process a top-up to the organization wallet
  Future<void> _onProcessTopUp(
    ProcessTopUp event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    try {
      emit(currentState.copyWith(isProcessingTopUp: true));

      // TODO: Implement actual payment processing
      // For now, just show a message that it's coming soon

      emit(
        currentState.copyWith(
          isProcessingTopUp: false,
          message: 'Payment processing coming soon!',
          isError: false,
        ),
      );
    } catch (e) {
      log('OrganizationDashboardBloc._onProcessTopUp error: $e');
      emit(
        currentState.copyWith(
          isProcessingTopUp: false,
          message: 'Failed to process top-up: $e',
          isError: true,
        ),
      );
    }
  }

  /// Update member status (activate/deactivate)
  Future<void> _onUpdateMemberStatus(
    UpdateMemberStatus event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    try {
      await _supabaseService.client
          .from('organization_members')
          .update({'is_active': event.isActive})
          .eq('id', event.memberId);

      // Reload members
      final updatedMembers = await _loadMembers(currentState.organizationId);

      emit(
        currentState.copyWith(
          members: updatedMembers,
          message: event.isActive ? 'Member activated' : 'Member deactivated',
          isError: false,
        ),
      );
    } catch (e) {
      log('OrganizationDashboardBloc._onUpdateMemberStatus error: $e');
      emit(
        currentState.copyWith(
          message: 'Failed to update member status: $e',
          isError: true,
        ),
      );
    }
  }

  // ============================================
  // Helper Methods
  // ============================================

  Future<Map<String, dynamic>?> _loadOrganization(String orgId) async {
    try {
      final org =
          await _supabaseService.client
              .from('organizations')
              .select()
              .eq('id', orgId)
              .single();
      return Map<String, dynamic>.from(org);
    } catch (e) {
      debugPrint('Error loading organization: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadMembers(String orgId) async {
    try {
      debugPrint('Loading members for orgId=$orgId');
      final membersRaw = await _supabaseService.client
          .from('organization_members')
          .select()
          .eq('organization_id', orgId)
          .order('joined_at', ascending: false);

      debugPrint('Found ${(membersRaw as List).length} members');

      // Load profiles for all members
      final memberUserIds =
          (membersRaw as List).map((m) => m['user_id'] as String).toList();

      final profiles =
          memberUserIds.isNotEmpty
              ? await _supabaseService.client
                  .from('users_profile')
                  .select()
                  .inFilter('user_id', memberUserIds)
              : [];

      // Combine members with their profiles
      final profileMap = {for (var p in profiles) p['user_id']: p};

      return (membersRaw as List).map((m) {
        return Map<String, dynamic>.from({
          ...m,
          'users_profile': profileMap[m['user_id']],
        });
      }).toList();
    } catch (e) {
      debugPrint('Error loading members: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingInvites(String orgId) async {
    try {
      debugPrint('Loading pending invites for orgId=$orgId');
      final invites = await _supabaseService.client
          .from('organization_invites')
          .select()
          .eq('organization_id', orgId)
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      debugPrint('Found ${invites.length} pending invites');
      return (invites as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Error loading pending invites: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadCallHistory(String orgId) async {
    try {
      final calls = await _supabaseService.client
          .from('call_logs')
          .select()
          .eq('organization_id', orgId)
          .order('started_at', ascending: false)
          .limit(50);

      return (calls as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Error loading call history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTransactions(String orgId) async {
    try {
      final txns = await _supabaseService.client
          .from('organization_transactions')
          .select()
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(50);

      return (txns as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      return [];
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      8,
      (index) => chars[(random + index * 7) % chars.length],
    ).join();
  }
}
