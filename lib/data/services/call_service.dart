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

  /// Convenience: current authenticated user's UUID (or throws)
  String requireUserId() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    return uid;
  }
}
