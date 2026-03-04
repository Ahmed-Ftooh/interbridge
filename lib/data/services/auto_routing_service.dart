import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for auto-routing calls to the best available interpreter.
/// Handles: pre-call intake → auto-match → enterprise overflow → queue management.
class AutoRoutingService {
  static final AutoRoutingService _instance = AutoRoutingService._internal();
  factory AutoRoutingService() => _instance;
  AutoRoutingService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Create a request with intake data and auto-route to best interpreter.
  /// Returns the routing result with status, interpreter info, or queue position.
  ///
  /// Flow:
  /// 1. Insert request with intake fields (doctor name, patient ID, department)
  /// 2. Call auto-route edge function
  /// 3. Edge function calls DB function auto_route_interpreter()
  /// 4. Returns: matched (with interpreter_id) | queued (with wait time)
  Future<AutoRouteResult> createAndRoute({
    required String fromLanguage,
    required String toLanguage,
    String? specialization,
    String callType = 'voice',
    String? doctorName,
    String? patientId,
    String? department,
    String? organizationId,
    String interpreterType = 'general',
    String? medicalSection,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Detect organization membership
      String? orgId = organizationId;
      if (orgId == null) {
        try {
          final memberRow =
              await _client
                  .from('organization_members')
                  .select('organization_id')
                  .eq('user_id', user.id)
                  .eq('is_active', true)
                  .maybeSingle();
          orgId = memberRow?['organization_id'] as String?;
        } catch (e) {
          log('No org membership found: $e');
        }
      }

      // Check spending limits before creating request
      if (orgId != null) {
        try {
          // Check organization wallet balance
          final org =
              await _client
                  .from('organizations')
                  .select('wallet_balance, rate_per_minute')
                  .eq('id', orgId)
                  .maybeSingle();

          if (org != null) {
            final walletBalance =
                (org['wallet_balance'] as num?)?.toDouble() ?? 0.0;
            final ratePerMinute =
                (org['rate_per_minute'] as num?)?.toDouble() ?? 0.50;

            if (walletBalance < ratePerMinute) {
              throw Exception(
                'Insufficient organization balance. '
                'Please ask your admin to top up the wallet.',
              );
            }
          }

          // Check individual spending limit
          final member =
              await _client
                  .from('organization_members')
                  .select('total_spent, spending_limit')
                  .eq('user_id', user.id)
                  .eq('organization_id', orgId)
                  .eq('is_active', true)
                  .maybeSingle();

          if (member != null) {
            final spent = (member['total_spent'] as num?)?.toDouble() ?? 0.0;
            final limit = (member['spending_limit'] as num?)?.toDouble() ?? 0.0;
            if (limit > 0 && spent >= limit) {
              throw Exception(
                'You have reached your spending limit (\$${limit.toStringAsFixed(0)}). '
                'Contact your organization admin.',
              );
            }
          }
        } catch (e) {
          if (e.toString().contains('Insufficient') ||
              e.toString().contains('spending limit')) {
            rethrow;
          }
          log('Spending limit check failed (non-fatal): $e');
        }
      }

      // 1. Create the request with intake data
      final requestData = {
        'requester_id': user.id,
        'from_language': fromLanguage,
        'to_language': toLanguage,
        'specialization': specialization,
        'urgency': 'Normal',
        'status': 'pending',
        'call_type': callType,
        'interpreter_type': interpreterType,
        'medical_section': medicalSection,
        'routing_mode': 'auto',
        'routing_phase': 'matching',
        'doctor_name': doctorName,
        'patient_id': patientId,
        'department': department,
        'organization_id': orgId,
        'intake_completed_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _client
              .from('interpreter_requests')
              .insert(requestData)
              .select()
              .single();

      final requestId = response['id'] as String;
      log('Created auto-route request: $requestId');

      // 2. Call auto-route edge function
      final routeResponse = await _client.functions.invoke(
        'auto-route-call',
        body: {
          'request_id': requestId,
          'from_language': fromLanguage,
          'to_language': toLanguage,
          'specialization': specialization ?? medicalSection,
          'organization_id': orgId,
        },
      );

      final routeData = routeResponse.data as Map<String, dynamic>?;
      log('Auto-route result: $routeData');

      if (routeData == null) {
        return AutoRouteResult(
          requestId: requestId,
          status: AutoRouteStatus.error,
          errorMessage: 'No response from routing service',
        );
      }

      final status = routeData['status'] as String? ?? 'error';

      if (status == 'matched' || status == 'overflow') {
        return AutoRouteResult(
          requestId: requestId,
          status:
              status == 'overflow'
                  ? AutoRouteStatus.overflow
                  : AutoRouteStatus.matched,
          interpreterId: routeData['interpreter_id'] as String?,
          interpreterName: routeData['interpreter_name'] as String?,
          isOverflow: routeData['overflow'] == true,
        );
      } else if (status == 'queued') {
        return AutoRouteResult(
          requestId: requestId,
          status: AutoRouteStatus.queued,
          queuePosition: routeData['queue_position'] as int? ?? 1,
          estimatedWaitSeconds:
              routeData['estimated_wait_seconds'] as int? ?? 60,
        );
      } else {
        return AutoRouteResult(
          requestId: requestId,
          status: AutoRouteStatus.error,
          errorMessage:
              routeData['error'] as String? ?? 'Unknown routing error',
        );
      }
    } catch (e) {
      log('Error in createAndRoute: $e');
      rethrow;
    }
  }

  /// Get current queue status for a request
  Future<Map<String, dynamic>?> getQueueStatus(String requestId) async {
    try {
      final row =
          await _client
              .from('routing_queue')
              .select('*')
              .eq('request_id', requestId)
              .eq('status', 'waiting')
              .maybeSingle();
      return row;
    } catch (e) {
      log('Error getting queue status: $e');
      return null;
    }
  }

  /// Cancel a queued request
  Future<void> cancelQueuedRequest(String requestId) async {
    try {
      await _client
          .from('routing_queue')
          .update({'status': 'cancelled'})
          .eq('request_id', requestId);

      await _client
          .from('interpreter_requests')
          .update({'status': 'cancelled', 'routing_phase': 'cancelled'})
          .eq('id', requestId);
    } catch (e) {
      log('Error cancelling queued request: $e');
      rethrow;
    }
  }

  /// Get estimated available interpreter count for a language pair
  Future<int> getAvailableCount({
    required String fromLanguage,
    required String toLanguage,
    String? organizationId,
  }) async {
    try {
      final result = await _client.rpc(
        'get_available_interpreter_count',
        params: {
          'p_from_language': fromLanguage,
          'p_to_language': toLanguage,
          'p_organization_id': organizationId,
        },
      );
      return (result as int?) ?? 0;
    } catch (e) {
      log('Error getting available count: $e');
      return 0;
    }
  }
}

enum AutoRouteStatus { matched, overflow, queued, error }

class AutoRouteResult {
  final String requestId;
  final AutoRouteStatus status;
  final String? interpreterId;
  final String? interpreterName;
  final bool isOverflow;
  final int queuePosition;
  final int estimatedWaitSeconds;
  final String? errorMessage;

  AutoRouteResult({
    required this.requestId,
    required this.status,
    this.interpreterId,
    this.interpreterName,
    this.isOverflow = false,
    this.queuePosition = 0,
    this.estimatedWaitSeconds = 0,
    this.errorMessage,
  });
}
