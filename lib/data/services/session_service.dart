import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionService {
  static const String _sessionKey = 'active_session';
  static const String _chatStateKey = 'chat_state';
  static const String _callStateKey = 'call_state';

  /// Save current session state
  static Future<void> saveSession({
    required String requestId,
    required String requesterId,
    required String interpreterId,
    String? currentScreen,
    Map<String, dynamic>? chatData,
    Map<String, dynamic>? callData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final sessionData = {
        'requestId': requestId,
        'requesterId': requesterId,
        'interpreterId': interpreterId,
        'currentScreen': currentScreen,
        'chatData': chatData,
        'callData': callData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_sessionKey, jsonEncode(sessionData));
      log('Session saved successfully');
    } catch (e) {
      log('Error saving session: $e');
    }
  }

  /// Get current session state
  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionKey);

      if (sessionJson == null) return null;

      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;

      // Check if session is not too old (24 hours)
      final timestamp = sessionData['timestamp'] as int;
      final sessionTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      if (now.difference(sessionTime).inHours > 24) {
        await clearSession();
        return null;
      }

      return sessionData;
    } catch (e) {
      log('Error getting session: $e');
      return null;
    }
  }

  /// Check if there's an active session
  static Future<bool> hasActiveSession() async {
    final session = await getSession();
    return session != null;
  }

  /// Clear current session
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_chatStateKey);
      await prefs.remove(_callStateKey);
      log('Session cleared successfully');
    } catch (e) {
      log('Error clearing session: $e');
    }
  }

  /// Save chat state
  static Future<void> saveChatState(Map<String, dynamic> chatState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatStateKey, jsonEncode(chatState));
    } catch (e) {
      log('Error saving chat state: $e');
    }
  }

  /// Get chat state
  static Future<Map<String, dynamic>?> getChatState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatJson = prefs.getString(_chatStateKey);

      if (chatJson == null) return null;

      return jsonDecode(chatJson) as Map<String, dynamic>;
    } catch (e) {
      log('Error getting chat state: $e');
      return null;
    }
  }

  /// Save call state
  static Future<void> saveCallState(Map<String, dynamic> callState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_callStateKey, jsonEncode(callState));
    } catch (e) {
      log('Error saving call state: $e');
    }
  }

  /// Get call state
  static Future<Map<String, dynamic>?> getCallState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final callJson = prefs.getString(_callStateKey);

      if (callJson == null) return null;

      return jsonDecode(callJson) as Map<String, dynamic>;
    } catch (e) {
      log('Error getting call state: $e');
      return null;
    }
  }

  /// End current session
  static Future<void> endSession({String? requestId}) async {
    if (requestId != null) {
      try {
        await Supabase.instance.client
            .from('interpreter_requests')
            .update({'status': 'completed'})
            .eq('id', requestId);
        log('Session marked as completed in DB');
      } catch (e) {
        log('Error updating session status in DB: $e');
      }
    }
    await clearSession();
    log('Session ended by user');
  }
}
