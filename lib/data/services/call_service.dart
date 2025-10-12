import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';

class CallService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch a short-lived Agora token from your Supabase Edge Function
  Future<String> fetchAgoraToken({
    required String channelName,
    required int uid,
  }) async {
    try {
      log('Fetching Agora token for channel: $channelName, uid: $uid');

      final res = await _supabase.functions.invoke(
        'generate-agora-token',
        body: {'channelName': channelName, 'uid': uid.toString()},
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

  /// Get call statistics for a user
  Future<Map<String, dynamic>> getCallStatistics({String? userId}) async {
    try {
      final targetUserId = userId ?? requireUserId();

      final response =
          await _supabase
              .from('call_statistics')
              .select('*')
              .eq('user_id', targetUserId)
              .single();

      return response;
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
          .eq('user_id', targetUserId)
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
}
