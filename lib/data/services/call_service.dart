import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

class CallService {
  // Use a getter so construction is safe even before Supabase.initialize() finishes.
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Fetch a short-lived Agora token from your Supabase Edge Function.
  /// [role] can be 'publisher' (default) or 'subscriber' (audience/listen-only).
  Future<String> fetchAgoraToken({
    required String channelName,
    required int uid,
    String role = 'publisher',
  }) async {
    try {
      log(
        'Fetching Agora token for channel: $channelName, uid: $uid, role: $role',
      );

      final res = await _supabase.functions.invoke(
        'generate-agora-token',
        body: {'channelName': channelName, 'uid': uid.toString(), 'role': role},
      );

      log('Supabase function response: ${res.data}');

      final data = res.data;
      if (data is! Map) {
        log('Invalid response data type: ${data.runtimeType}');
        throw Exception('Invalid response format from token service');
      }

      if (data['token'] == null) {
        log('Token is null in response: $data');
        throw Exception('Token not found in response');
      }

      final token = data['token'] as String;
      if (token.isEmpty) {
        log('Token is empty string');
        throw Exception('Empty token received');
      }

      log('Successfully obtained Agora token');
      return token;
    } catch (e) {
      log('Error fetching Agora token: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to obtain Agora token: $e');
    }
  }

  /// Look up the other participant from the interpreter_requests table.
  /// Returns a map with 'requester_id', 'accepted_by', 'interpreter_type',
  /// 'from_language', 'to_language', etc.
  Future<Map<String, dynamic>?> lookupCallParticipants(String requestId) async {
    try {
      final row =
          await _supabase
              .from('interpreter_requests')
              .select(
                'requester_id, accepted_by, interpreter_type, from_language, to_language, specialization, call_type, organization_id',
              )
              .eq('id', requestId)
              .maybeSingle();
      return row;
    } catch (e) {
      log('Error looking up call participants: $e');
      return null;
    }
  }

  /// Best-effort cleanup for requester-side no-show scenarios.
  ///
  /// If the call request is still accepted and belongs to the current
  /// requester, mark it cancelled so stale sessions are not restored.
  Future<void> cancelAcceptedRequestAsRequester({
    required String requestId,
  }) async {
    try {
      final userId = requireUserId();
      await _supabase
          .from('interpreter_requests')
          .update({'status': 'cancelled'})
          .eq('id', requestId)
          .eq('requester_id', userId)
          .eq('status', 'accepted');
    } catch (e) {
      log('Error cancelling accepted request on no-show timeout: $e');
    }
  }

  /// Record call duration to database
  Future<void> recordCallDuration({
    required String channelId,
    required Duration duration,
    required String userId,
    String? remoteUserId,
    String callType = 'voice',
    String? connectionQuality,
    String endReason = 'user_hangup',
  }) async {
    try {
      log(
        'Recording call duration: ${duration.inMinutes} minutes for channel: $channelId',
      );

      final now = DateTime.now();
      final startTime = now.subtract(duration);

      await _supabase.from('call_sessions').insert({
        'channel_id': channelId,
        'user_id': userId,
        'duration_seconds': duration.inSeconds,
        'started_at': startTime.toIso8601String(),
        'ended_at': now.toIso8601String(),
        'call_type': callType,
        'connection_quality': connectionQuality,
        'end_reason': endReason,
        'remote_user_id': remoteUserId,
      });

      log('Call duration recorded successfully');
    } catch (e) {
      log('Error recording call duration: $e');
      // Don't throw here as call duration recording shouldn't break the call flow
    }
  }

  /// Record a call log entry (master record for the call)
  Future<void> recordCallLog({
    required String requestId,
    required String interpreterId,
    required String requesterId,
    required int durationSeconds,
    required DateTime startedAt,
    required DateTime endedAt,
    String callType = 'humanitarian',
    String? fromLanguage,
    String? toLanguage,
    String? organizationId,
  }) async {
    try {
      log('Recording call log for request: $requestId');

      final insertData = {
        'request_id': requestId,
        'interpreter_id': interpreterId,
        'requester_id': requesterId,
        'call_type': callType,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'metadata': {'from_language': fromLanguage, 'to_language': toLanguage},
      };
      if (organizationId != null) {
        insertData['organization_id'] = organizationId;
      }
      // Use upsert with request_id unique constraint — both call
      // participants attempt to write the log; the second one is a no-op.
      await _supabase
          .from('call_logs')
          .upsert(insertData, onConflict: 'request_id');

      log('Call log recorded successfully');
    } catch (e) {
      log('Error recording call log: $e (request_id=$requestId)');
    }
  }

  /// Get call statistics for a user
  Future<Map<String, dynamic>> getCallStatistics({String? userId}) async {
    try {
      final targetUserId = userId ?? requireUserId();

      final response =
          await _supabase
              .from('call_statistics')
              .select('*')
              .eq('user_id', targetUserId)
              .maybeSingle();

      // The call_statistics VIEW uses GROUP BY, so users with zero
      // call_sessions have no row → maybeSingle returns null.
      return response ??
          {
            'total_calls': 0,
            'total_duration_seconds': 0,
            'average_duration_seconds': 0,
          };
    } catch (e) {
      log('Error fetching call statistics: $e');
      return {
        'total_calls': 0,
        'total_duration_seconds': 0,
        'average_duration_seconds': 0,
      };
    }
  }

  /// Get recent call sessions for a user
  Future<List<Map<String, dynamic>>> getRecentCallSessions({
    String? userId,
    int limit = 10,
  }) async {
    try {
      final targetUserId = userId ?? requireUserId();

      final response = await _supabase
          .from('call_sessions')
          .select('*')
          .or('user_id.eq.$targetUserId,remote_user_id.eq.$targetUserId')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('Error fetching recent call sessions: $e');
      return [];
    }
  }

  /// Submit call feedback
  Future<void> submitCallFeedback({
    required String channelId,
    required int rating,
    required String connectionQuality,
    required String callExperience,
    String? comments,
  }) async {
    try {
      final userId = requireUserId();

      log('Submitting call feedback for channel: $channelId');

      await _supabase.from('call_feedback').insert({
        'channel_id': channelId,
        'user_id': userId,
        'rating': rating,
        'connection_quality': connectionQuality,
        'call_experience': callExperience,
        'comments': comments,
      });

      log('Call feedback submitted successfully');
    } catch (e) {
      log('Error submitting call feedback: $e');
      rethrow;
    }
  }

  /// Get call feedback for a channel
  Future<List<Map<String, dynamic>>> getCallFeedback({
    required String channelId,
  }) async {
    try {
      final response = await _supabase
          .from('call_feedback')
          .select('*')
          .eq('channel_id', channelId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('Error fetching call feedback: $e');
      return [];
    }
  }

  /// Get user's feedback history
  Future<List<Map<String, dynamic>>> getUserFeedbackHistory({
    String? userId,
    int limit = 20,
  }) async {
    try {
      final targetUserId = userId ?? requireUserId();

      final response = await _supabase
          .from('call_feedback')
          .select('*')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('Error fetching user feedback history: $e');
      return [];
    }
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStatistics({String? userId}) async {
    try {
      final targetUserId = userId ?? requireUserId();

      final response = await _supabase
          .from('call_feedback')
          .select('rating, connection_quality, call_experience')
          .eq('user_id', targetUserId);

      if (response.isEmpty) {
        return {
          'total_feedback': 0,
          'average_rating': 0.0,
          'connection_quality_distribution': {},
          'call_experience_distribution': {},
        };
      }

      // Calculate statistics
      final ratings = response.map((r) => r['rating'] as int).toList();
      final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;

      // Connection quality distribution
      final connectionQuality = <String, int>{};
      for (final item in response) {
        final quality = item['connection_quality'] as String;
        connectionQuality[quality] = (connectionQuality[quality] ?? 0) + 1;
      }

      // Call experience distribution
      final callExperience = <String, int>{};
      for (final item in response) {
        final experience = item['call_experience'] as String;
        callExperience[experience] = (callExperience[experience] ?? 0) + 1;
      }
return {
        'total_feedback': response.length,
        'average_rating': averageRating,
        'connection_quality_distribution': connectionQuality,
        'call_experience_distribution': callExperience,
      };
    } catch (e) {
      log('Error fetching feedback statistics: $e');
      return {
        'total_feedback': 0,
        'average_rating': 0.0,
        'connection_quality_distribution': {},
        'call_experience_distribution': {},
      };
    }
  }

  /// Convenience: current authenticated user's UUID (or throws)
  String requireUserId() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    return uid;
  }

  // 👇 --- PASTE THE NEW FUNCTION HERE --- 👇

  /// Validates if an organization can make a call based on their billing type
  Future<bool> canOrganizationMakeCall(String organizationId) async {
    try {
      final response = await _supabase
          .from('organizations')
          .select('wallet_balance, billing_method, is_active')
          .eq('id', organizationId)
          .single();

      if (response['is_active'] != true) return false;

      final billingMethod = response['billing_method'] as String? ?? 'prepaid';
      final walletBalance = (response['wallet_balance'] as num?) ?? 0;

      if (billingMethod == 'postpaid') {
        // Postpaid users can always make calls (balance represents amount owed when negative)
        return true;
      } else {
        // Prepaid users must have a balance strictly greater than 0
        return walletBalance > 0;
      }
    } catch (e) {
      log('Error checking organization balance: $e');
      return false;
    }
  }
  
  // 👆 --- PASTE THE NEW FUNCTION HERE --- 👆

} // <-- THIS IS THE VERY LAST BRACKET OF THE FILE