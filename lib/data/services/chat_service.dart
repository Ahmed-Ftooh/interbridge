import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchMessages(String requestId) async {
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
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> sendMessage(String requestId, String content) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _supabase.from('chat_messages').insert({
      'request_id': requestId,
      'sender_id': userId,
      'content': content,
    });
  }

  RealtimeChannel subscribeToMessages(
    String requestId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
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
  }

  Future<String> fetchAgoraToken(String channelName, int uid) async {
    final res = await _supabase.functions.invoke(
      'generate-agora-token',
      body: {'channelName': channelName, 'uid': uid.toString()},
    );
    return (res.data as Map)['token'] as String;
  }
}
