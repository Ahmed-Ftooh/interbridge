import 'package:supabase_flutter/supabase_flutter.dart';
class AgoraDialerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> callInterpreter(
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
}