import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/models/interpreter_request.dart';

class InterpreterJobService {
  static final InterpreterJobService _instance =
      InterpreterJobService._internal();
  factory InterpreterJobService() => _instance;
  InterpreterJobService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Get available jobs for the current interpreter
  Future<List<InterpreterRequest>> getAvailableJobs() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Fetch languages assigned to interpreter so we only show relevant jobs
      final interpreterData = await _client
          .from('interpreter_languages')
          .select('language_id')
          .eq('user_id', user.id);

      if (interpreterData.isEmpty) {
        log('No languages found for interpreter');
        return [];
      }

      final languageIds =
          interpreterData
              .map((lang) => lang['language_id'].toString())
              .toList();

      log('Interpreter languages: $languageIds');

      // Fetch this interpreter's employment type so we only show matching
      // request types: volunteer → general requests, paid → specialist requests.
      // employment_type is stored in users_profile, NOT interpreter_details.
      String employmentType = 'volunteer'; // safe default
      try {
        final detailsRow =
            await _client
                .from('users_profile')
                .select('employment_type')
                .eq('user_id', user.id)
                .maybeSingle();
        if (detailsRow != null) {
          employmentType =
              (detailsRow['employment_type'] as String?) ?? 'volunteer';
        }
      } catch (e) {
        log(
          'Could not fetch interpreter employment_type (defaulting to volunteer): $e',
        );
      }

      // Map employment type → allowed interpreter_type values in requests:
      // volunteer → 'general' only
      // paid      → 'general' AND 'specialist'
      final requestTypeFilter =
          employmentType == 'paid' ? 'specialist' : 'general';
      log(
        'Interpreter employment_type=$employmentType → showing '
        '${employmentType == 'paid' ? '"general" + "specialist"' : '"general"'} requests only',
      );

      // Fetch declined job ids for this specific interpreter
      Set<String> declinedJobIds = {};
      try {
        final declinedJobRows = await _client
            .from('interpreter_declined_jobs')
            .select('request_id')
            .eq('interpreter_id', user.id);
        declinedJobIds =
            declinedJobRows
                .map((row) => row['request_id']?.toString())
                .whereType<String>()
                .toSet();
        log('Declined job ids for this interpreter: $declinedJobIds');
      } catch (e) {
        log('Could not fetch declined jobs (table may not exist): $e');
        // Continue without filtering - table will be created on first decline
      }

      // Fetch pending jobs that match interpreter's languages AND type
      // An interpreter must know BOTH languages (from and to) to handle
      // a request, so filter on both columns.
      // Paid interpreters can take any type; volunteers only take general.
      var query = _client
          .from('interpreter_requests')
          .select('''
            *,
            from_language,
            to_language,
            specialization
          ''')
          .eq('status', 'pending')
          .inFilter('from_language', languageIds)
          .inFilter('to_language', languageIds);

      if (employmentType != 'paid') {
        query = query.eq('interpreter_type', requestTypeFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50);

      final requests =
          response.map((json) => InterpreterRequest.fromJson(json)).toList();

      // Filter out jobs this interpreter has declined
      final filteredRequests =
          declinedJobIds.isEmpty
              ? requests
              : requests
                  .where((req) => !declinedJobIds.contains(req.id))
                  .toList();

      log(
        'Found ${filteredRequests.length} available jobs after filtering declines',
      );
      return filteredRequests;
    } catch (e) {
      log('Error getting available jobs: $e');
      return [];
    }
  }

  findLanguageById(String languageId) async {
    try {
      final response =
          await _client
              .from('languages')
              .select('name')
              .eq('id', languageId)
              .single();

      return response['name'] as String?;
    } catch (e) {
      log('Error finding language by ID: $e');
      return null;
    }
  }

  /// Accept a job request (atomic: only if still pending)
  Future<InterpreterRequest?> acceptJob(String requestId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      Map<String, dynamic>? updated;
      final rpcStopwatch = Stopwatch()..start();

      // Prefer atomic RPC to avoid race conditions when multiple interpreters
      // attempt acceptance at nearly the same time.
      try {
        final rpcResponse = await _client.rpc(
          'accept_interpreter_request',
          params: {'p_request_id': requestId},
        );

        if (rpcResponse is Map<String, dynamic>) {
          updated = rpcResponse;
        } else if (rpcResponse is Map) {
          updated = Map<String, dynamic>.from(rpcResponse);
        }
        if (updated != null) {
          log(
            '[ACCEPT:RPC:SUCCESS] request=$requestId interpreter=${user.id} latency=${rpcStopwatch.elapsedMilliseconds}ms',
          );
        }
      } catch (rpcError) {
        log('[ACCEPT:RPC:UNAVAILABLE] request=$requestId error=$rpcError');
      }
      rpcStopwatch.stop();

      // Backward-compatible fallback for environments where migration has not
      // been applied yet.
      if (updated == null) {
        final fallbackStopwatch = Stopwatch()..start();
        updated =
            await _client
                .from('interpreter_requests')
                .update({
                  'status': 'accepted',
                  'accepted_by': user.id,
                  'accepted_at': DateTime.now().toIso8601String(),
                })
                .eq('id', requestId)
                .eq('status', 'pending')
                .select()
                .maybeSingle();
        fallbackStopwatch.stop();

        if (updated != null) {
          log(
            '[ACCEPT:FALLBACK:SUCCESS] request=$requestId interpreter=${user.id} latency=${fallbackStopwatch.elapsedMilliseconds}ms',
          );
        }
      }

      if (updated == null) {
        log('[ACCEPT:RACE_LOST] request=$requestId interpreter=${user.id}');
        throw Exception(
          'This request was already accepted by another interpreter',
        );
      }

      await _notifyRequesterJobAccepted(requestId, user.id);

      return InterpreterRequest.fromJson(updated);
    } catch (e) {
      rethrow;
    }
  }

  /// Decline a job request
  Future<void> declineJob(String requestId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Store this interpreter's decline (only hides for them)
      try {
        await _client.from('interpreter_declined_jobs').insert({
          'interpreter_id': user.id,
          'request_id': requestId,
          'declined_at': DateTime.now().toIso8601String(),
        });
        log('Job declined by interpreter $user.id: $requestId');
      } catch (e) {
        // If table doesn't exist, it will be created in Supabase
        // Job will still be hidden for this interpreter on next refresh
        log('Could not store declined job: $e');
      }
    } catch (e) {
      log('Error declining job: $e');
      rethrow;
    }
  }

  /// Notify requester that their job was accepted
  Future<void> _notifyRequesterJobAccepted(
    String requestId,
    String interpreterId,
  ) async {
    try {
      final requestResponse =
          await _client
              .from('interpreter_requests')
              .select('requester_id')
              .eq('id', requestId)
              .single();

      final requesterId = requestResponse['requester_id'];

      final interpreterProfile =
          await _client
              .from('users_profile')
              .select('username')
              .eq('user_id', interpreterId)
              .single();

      final requesterTokens = await _getFCMTokensForUsers([requesterId]);

      if (requesterTokens.isNotEmpty) {
        final notificationData = {
          'title': 'Job Accepted',
          'body':
              '${interpreterProfile['username']} has accepted your interpreter request',
          'data': {
            'request_id': requestId,
            'interpreter_id': interpreterId,
            'requester_id': requesterId, // ✅ ADDED for navigation
            'type': 'request_accepted',
          },
          'player_ids': requesterTokens, // Changed from tokens to player_ids
        };

        log('DEBUG: Sending notification: $notificationData');

        const maxAttempts = 3;
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            log(
              '[NOTIFY:SEND] request=$requestId requester=$requesterId attempt=$attempt/$maxAttempts',
            );
            await _client.functions.invoke(
              'send-notification',
              body: notificationData,
            );
            log(
              '[NOTIFY:SUCCESS] request=$requestId requester=$requesterId attempt=$attempt',
            );
            break;
          } catch (notifyError) {
            log(
              '[NOTIFY:FAILED] request=$requestId requester=$requesterId attempt=$attempt error=$notifyError',
            );
            if (attempt == maxAttempts) {
              log(
                '[NOTIFY:GAVE_UP] request=$requestId requester=$requesterId after $maxAttempts attempts',
              );
              break;
            }
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      } else {
        log('No OneSignal player IDs found for requester $requesterId');
      }
    } catch (e) {
      log('Error notifying requester: $e');
    }
  }

  /// Get OneSignal player IDs for a list of user IDs
  Future<List<String>> _getFCMTokensForUsers(List<String> userIds) async {
    try {
      final response = await _client
          .from('onesignal_player_ids')
          .select('player_id')
          .inFilter('user_id', userIds);

      final playerIds =
          response
              .map((t) => t['player_id'] as String?)
              .where((t) => t != null && t.isNotEmpty)
              .cast<String>()
              .toList();

      log('DEBUG: Extracted ${playerIds.length} valid OneSignal player IDs');

      return playerIds;
    } catch (e) {
      log('Error getting OneSignal player IDs: $e');
      return [];
    }
  }
}
