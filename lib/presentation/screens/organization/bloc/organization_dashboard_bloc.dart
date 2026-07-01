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
    on<LoadInvoices>(_onLoadInvoices);
    on<GenerateInvoice>(_onGenerateInvoice);
    on<OpenStripeCheckout>(_onOpenStripeCheckout);
    on<ClearCheckoutUrl>(_onClearCheckoutUrl);
    on<OpenMobilePaymentSheet>(_onOpenMobilePaymentSheet);
    on<ClearPaymentSheetData>(_onClearPaymentSheetData);
    on<PaymentSheetCompleted>(_onPaymentSheetCompleted);
    on<ClearPaymentSuccess>(_onClearPaymentSuccess);
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
        _loadInvoices(orgId),
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
          invoices: results[5] as List<Map<String, dynamic>>,
        ),
      );
    } catch (e, stackTrace) {
      log('OrganizationDashboardBloc._onLoadOrganizationData error: $e');
      debugPrint('Stack trace: $stackTrace');
      emit(OrganizationDashboardError('Failed to load organization data: $e'));
    }
  }

  /// Refresh organization data (silently, without showing loading state)
  Future<void> _onRefreshOrganizationData(
    RefreshOrganizationData event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    try {
      final userId = _supabaseService.getCurrentUser()?.id;
      if (userId == null) return;

      final memberData =
          await _supabaseService.client
              .from('organization_members')
              .select('organization_id, role')
              .eq('user_id', userId)
              .maybeSingle();

      if (memberData == null) return;

      final orgId = memberData['organization_id'];

      final results = await Future.wait([
        _loadOrganization(orgId),
        _loadMembers(orgId),
        _loadPendingInvites(orgId),
        _loadCallHistory(orgId),
        _loadTransactions(orgId),
        _loadInvoices(orgId),
      ]);

      final organization = results[0] as Map<String, dynamic>?;
      if (organization == null) return;

      final currentState = state;
      emit(
        OrganizationDashboardLoaded(
          organization: organization,
          members: results[1] as List<Map<String, dynamic>>,
          pendingInvites: results[2] as List<Map<String, dynamic>>,
          callHistory: results[3] as List<Map<String, dynamic>>,
          transactions: results[4] as List<Map<String, dynamic>>,
          invoices: results[5] as List<Map<String, dynamic>>,
          // Preserve existing transient state
          paymentSuccessAmount:
              currentState is OrganizationDashboardLoaded
                  ? currentState.paymentSuccessAmount
                  : null,
        ),
      );
    } catch (e) {
      log('OrganizationDashboardBloc._onRefreshOrganizationData error: $e');
      // Silently fail — keep existing state
    }
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

  /// Process a top-up to the organization wallet (legacy — redirects to Stripe)
  Future<void> _onProcessTopUp(
    ProcessTopUp event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    // Delegate to OpenStripeCheckout
    add(OpenStripeCheckout(event.amount));
  }

  /// Open Stripe Checkout for wallet top-up
  Future<void> _onOpenStripeCheckout(
    OpenStripeCheckout event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    try {
      emit(currentState.copyWith(isProcessingTopUp: true));

      final orgId = currentState.organizationId;

      // Call the create-checkout-session edge function
      final response = await _supabaseService.client.functions.invoke(
        'create-checkout-session',
        body: {
          'organization_id': orgId,
          'amount': event.amount,
          'success_url':
              'https://gwvxwaqicnwiplafayoh.supabase.co/functions/v1/payment-success',
          'cancel_url':
              'https://gwvxwaqicnwiplafayoh.supabase.co/functions/v1/payment-cancelled',
        },
      );

      final data = response.data as Map<String, dynamic>?;

      if (response.status != 200 ||
          data == null ||
          data['checkout_url'] == null) {
        final errorMsg = data?['error'] ?? 'Failed to create checkout session';
        emit(
          currentState.copyWith(
            isProcessingTopUp: false,
            message: errorMsg.toString(),
            isError: true,
          ),
        );
        return;
      }

      emit(
        currentState.copyWith(
          isProcessingTopUp: false,
          checkoutUrl: data['checkout_url'] as String,
          message: 'Redirecting to payment...',
          isError: false,
        ),
      );
    } catch (e) {
      log('OrganizationDashboardBloc._onOpenStripeCheckout error: $e');
      emit(
        currentState.copyWith(
          isProcessingTopUp: false,
          message: 'Failed to process top-up: $e',
          isError: true,
        ),
      );
    }
  }

  /// Clear the checkout URL after UI has consumed it
  void _onClearCheckoutUrl(
    ClearCheckoutUrl event,
    Emitter<OrganizationDashboardState> emit,
  ) {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;
    emit(currentState.copyWith(checkoutUrl: null));
  }

  /// Open Stripe native Payment Sheet on mobile
  Future<void> _onOpenMobilePaymentSheet(
    OpenMobilePaymentSheet event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    try {
      emit(currentState.copyWith(isProcessingTopUp: true));

      final orgId = currentState.organizationId;

      // Call the create-payment-intent edge function
      // Call the create-payment-intent edge function
      final response = await _supabaseService.client.functions.invoke(
        'create-payment-intent',
        body: {
          'organization_id': orgId, 
          'amount': event.amount,
          if (event.minutes != null) 'minutes': event.minutes, // <-- ADD THIS LINE
        },
      );

      final data = response.data as Map<String, dynamic>?;

      if (response.status != 200 ||
          data == null ||
          data['payment_intent'] == null) {
        final errorMsg = data?['error'] ?? 'Failed to create payment intent';
        emit(
          currentState.copyWith(
            isProcessingTopUp: false,
            message: errorMsg.toString(),
            isError: true,
          ),
        );
        return;
      }

      emit(
        currentState.copyWith(
          isProcessingTopUp: false,
          paymentSheetData: {
            'paymentIntentClientSecret': data['payment_intent'] as String,
            'paymentIntentId': data['payment_intent_id'] as String? ?? '',
            'ephemeralKeySecret': data['ephemeral_key'] as String,
            'customerId': data['customer'] as String,
            'amount': event.amount.toString(),
          },
          message: null,
          isError: false,
        ),
      );
    } catch (e) {
      log('OrganizationDashboardBloc._onOpenMobilePaymentSheet error: $e');
      emit(
        currentState.copyWith(
          isProcessingTopUp: false,
          message: 'Failed to process top-up: $e',
          isError: true,
        ),
      );
    }
  }

  /// Clear payment sheet data after UI has consumed it
  void _onClearPaymentSheetData(
    ClearPaymentSheetData event,
    Emitter<OrganizationDashboardState> emit,
  ) {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;
    emit(currentState.copyWith(paymentSheetData: null));
  }

  /// Handle payment completed from mobile Payment Sheet
  Future<void> _onPaymentSheetCompleted(
    PaymentSheetCompleted event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    emit(
      currentState.copyWith(
        paymentSuccessAmount: event.amount,
        message: null,
        isError: false,
      ),
    );

    // Confirm the payment server-side and credit the wallet immediately.
    // This replaces the old webhook-polling approach.
    try {
      final response = await _supabaseService.client.functions.invoke(
        'confirm-mobile-payment',
        body: {'payment_intent_id': event.paymentIntentId},
      );

      if (response.status != 200) {
        final errorMsg =
            response.data?['error'] ?? 'Payment confirmation failed';
        debugPrint('confirm-mobile-payment error: $errorMsg');
      } else {
        debugPrint(
          'confirm-mobile-payment success: new_balance=${response.data?['new_balance']}',
        );
      }
    } catch (e) {
      debugPrint('confirm-mobile-payment call failed: $e');
    }

    // Refresh dashboard to reflect the updated balance
    add(const RefreshOrganizationData());
  }

  void _onClearPaymentSuccess(
    ClearPaymentSuccess event,
    Emitter<OrganizationDashboardState> emit,
  ) {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;
    emit(currentState.copyWith(paymentSuccessAmount: null));
  }

  /// Load invoices
  Future<void> _onLoadInvoices(
    LoadInvoices event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    try {
      final invoices = await _loadInvoices(currentState.organizationId);
      emit(currentState.copyWith(invoices: invoices));
    } catch (e) {
      log('OrganizationDashboardBloc._onLoadInvoices error: $e');
    }
  }

  /// Generate a monthly invoice
  Future<void> _onGenerateInvoice(
    GenerateInvoice event,
    Emitter<OrganizationDashboardState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrganizationDashboardLoaded) return;

    try {
      emit(currentState.copyWith(isGeneratingInvoice: true));

      final response = await _supabaseService.client.functions.invoke(
        'generate-invoice',
        body: {
          'organization_id': currentState.organizationId,
          'year': event.year,
          'month': event.month,
          'send_email': event.sendEmail,
        },
      );

      final data = response.data as Map<String, dynamic>?;

      if (data?['status'] == 'no_data') {
        emit(
          currentState.copyWith(
            isGeneratingInvoice: false,
            message: 'No calls found for this billing period',
            isError: false,
          ),
        );
        return;
      }

      // Reload invoices
      final invoices = await _loadInvoices(currentState.organizationId);

      emit(
        currentState.copyWith(
          isGeneratingInvoice: false,
          invoices: invoices,
          message: 'Invoice generated successfully!',
          isError: false,
        ),
      );
    } catch (e) {
      log('OrganizationDashboardBloc._onGenerateInvoice error: $e');
      emit(
        currentState.copyWith(
          isGeneratingInvoice: false,
          message: 'Failed to generate invoice: $e',
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
          (membersRaw).map((m) => m['user_id'] as String).toList();

      final profiles =
          memberUserIds.isNotEmpty
              ? await _supabaseService.client
                  .from('users_profile')
                  .select()
                  .inFilter('user_id', memberUserIds)
              : [];

      // Combine members with their profiles
      final profileMap = {for (var p in profiles) p['user_id']: p};

      return (membersRaw).map((m) {
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

      final callList =
          (calls as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

      // Enrich with requester profile names
      final requesterIds =
          callList
              .map((c) => c['requester_id'] as String?)
              .where((id) => id != null)
              .toSet()
              .toList();

      if (requesterIds.isNotEmpty) {
        final profiles = await _supabaseService.client
            .from('users_profile')
            .select('user_id, username')
            .inFilter('user_id', requesterIds);

        final profileMap = {
          for (var p in (profiles as List)) (p as Map)['user_id']: p,
        };

        for (final call in callList) {
          final rid = call['requester_id'];
          if (rid != null && profileMap.containsKey(rid)) {
            call['requester_profile'] = Map<String, dynamic>.from(
              profileMap[rid] as Map,
            );
          }
        }
      }

      return callList;
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

  Future<List<Map<String, dynamic>>> _loadInvoices(String orgId) async {
    try {
      final invoices = await _supabaseService.client
          .from('invoices')
          .select()
          .eq('organization_id', orgId)
          .order('billing_period_start', ascending: false)
          .limit(24);

      return (invoices as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Error loading invoices: $e');
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
