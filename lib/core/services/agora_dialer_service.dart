import 'package:supabase_flutter/supabase_flutter.dart';
class AgoraDialerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> callInterpreter(
      String targetPhoneNumber, 
      String channelName, 
      String twilioPhoneNumber,
      String token, // <--- 1. ADD THE TOKEN PARAMETER HERE
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'agora-dialer',
        body: {
          'to': targetPhoneNumber,
          'channel': channelName,
          'from': twilioPhoneNumber,
          'token': token, // <--- 2. ADD THE TOKEN TO THE BODY HERE
        },
      );

      if (response.status >= 200 && response.status < 300) {
        print('Successfully triggered dialer. Response: ${response.data}');
        return _extractCallId(response.data);
      } else {
        print('Failed to trigger dialer. Status: ${response.status}, Error: ${response.data}');
        throw Exception('Dialer failed with status ${response.status}');
      }
    } on FunctionException catch (e) {
      print('Edge Function returned an error: $e');
      rethrow;
    } catch (e) {
      print('Unexpected error calling interpreter: $e');
      rethrow;
    }
  }

  Future<void> hangupCall({
    required String callId,
    required String channelName,
  }) async {
    final response = await _supabase.functions.invoke(
      'agora-dialer',
      body: {
        'action': 'hangup',
        'call_id': callId,
        'channel': channelName,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw Exception('Hangup failed with status ${response.status}');
    }
  }

  String? _extractCallId(dynamic data) {
    if (data is Map) {
      final callId =
          data['call_id'] ?? data['callid'] ?? data['callId'] ?? data['id'];
      if (callId is String && callId.isNotEmpty) return callId;
      final nested = data['data'];
      if (nested is Map) {
        final nestedCallId =
            nested['call_id'] ??
            nested['callid'] ??
            nested['callId'] ??
            nested['id'];
        if (nestedCallId is String && nestedCallId.isNotEmpty) {
          return nestedCallId;
        }
      }
    }
    return null;
  }
}