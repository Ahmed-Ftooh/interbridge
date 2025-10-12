import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'supabase_service.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();

  Future<List<Map<String, dynamic>>> fetchMessages(String requestId) async {
    log('Fetching messages for requestId: $requestId');
    try {
      final res = await _supabase
          .from('chat_messages')
          .select('''
            *,
            user_profiles!chat_messages_sender_id_fkey(
              username,
              profile_image,
              role
            )
          ''')
          .eq('request_id', requestId)
          .order('created_at', ascending: true);
      log('Successfully fetched ${res.length} messages with user profiles');

      // Process messages to ensure proper username fallbacks and profile image URLs
      return List<Map<String, dynamic>>.from(res).map((message) {
        final userProfile = message['user_profiles'] as Map<String, dynamic>?;
        if (userProfile == null || userProfile['username'] == null) {
          // Provide fallback username based on sender_id
          message['user_profiles'] = {
            'username': 'User',
            'profile_image': null,
            'role': 'user',
          };
        } else {
          // Ensure profile image URL is properly formatted
          final profileImage = userProfile['profile_image'] as String?;
          if (profileImage != null && profileImage.isNotEmpty) {
            userProfile['profile_image'] = _supabaseService.getProfileImageUrl(
              profileImage,
            );
          }
        }
        return message;
      }).toList();
    } catch (e) {
      log('Failed to fetch messages with user profiles: $e');
      // If the table doesn't exist or there's a foreign key issue,
      // try a simpler query without the join
      try {
        final res = await _supabase
            .from('chat_messages')
            .select('*')
            .eq('request_id', requestId)
            .order('created_at', ascending: true);
        log(
          'Successfully fetched ${res.length} messages without user profiles',
        );

        // Add fallback user profiles for messages without joins
        return List<Map<String, dynamic>>.from(res).map((message) {
          message['user_profiles'] = {
            'username': 'User',
            'profile_image': null,
            'role': 'user',
          };
          return message;
        }).toList();
      } catch (e2) {
        log('Failed to fetch messages even without user profiles: $e2');
        // If even the basic query fails, the table probably doesn't exist
        // Return empty list - this is not an error for a new chat
        log('Returning empty message list - chat table may not exist yet');
        return [];
      }
    }
  }

  Future<void> sendMessage(String requestId, String content) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    try {
      await _supabase.from('chat_messages').insert({
        'request_id': requestId,
        'sender_id': userId,
        'content': content,
      });
    } catch (e) {
      // If the table doesn't exist, provide a helpful error message
      if (e.toString().contains('relation "chat_messages" does not exist')) {
        throw Exception(
          'Chat functionality is not set up yet. Please contact support to enable chat features.',
        );
      }
      rethrow;
    }
  }

  RealtimeChannel subscribeToMessages(
    String requestId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
    try {
      final channel =
          _supabase.channel('chat_$requestId')
            ..onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'chat_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'request_id',
                value: requestId,
              ),
              callback: (payload) {
                final newRow = payload.newRecord;
                onInsert(newRow);
              },
            )
            ..subscribe();
      return channel;
    } catch (e) {
      // If subscription fails (e.g., table doesn't exist), return a dummy channel
      // This prevents the app from crashing when chat features aren't set up yet
      return _supabase.channel('chat_dummy_$requestId');
    }
  }

  Future<String> fetchAgoraToken(String channelName, int uid) async {
    final res = await _supabase.functions.invoke(
      'generate-agora-token',
      body: {'channelName': channelName, 'uid': uid.toString()},
    );
    return (res.data as Map)['token'] as String;
  }
}
