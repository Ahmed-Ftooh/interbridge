import 'dart:developer';
import 'dart:convert';
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

      final interpreterData = await _client
          .from('interpreter_languages')
          .select('language_id')
          .eq('user_id', user.id);

      if (interpreterData.isEmpty) {
        log('No languages found for interpreter');
        return [];
      }
      // final interpreterSpecialization= await _client
      //     .from('interpreter_specializations')
      //     .select('''
      //       specialization_id,
      //     ''')
      //     .eq('user_id', user.id);

      final languageIds =
          interpreterData
              .map((lang) => lang['language_id'].toString())
              .toList();

      log('Interpreter languages: $languageIds');

      final response = await _client
          .from('interpreter_requests')
          .select('''
            *,
            from_language,
            to_language,
            specialization
          ''')
          .eq('status', 'pending')
          .inFilter('to_language', languageIds)
          .order('created_at', ascending: false)
          .limit(50);

      final requests =
          response.map((json) => InterpreterRequest.fromJson(json)).toList();

      log('Found ${requests.length} available jobs');
      return requests;
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

      final updated =
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

      if (updated == null) {
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

      // Add the job to the interpreter's declined jobs list
      await _client.from('interpreter_declined_jobs').insert({
        'interpreter_id': user.id,
        'request_id': requestId,
        'declined_at': DateTime.now().toIso8601String(),
      });

      log('Job declined by interpreter: $requestId');
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
            'type': 'request_accepted',
          },
          'tokens': requesterTokens,
        };

        log('DEBUG: Sending notification: $notificationData');

        await _client.functions.invoke(
          'send-notification',
          body: jsonEncode(notificationData), // ✅ fixed
        );
      } else {
        log('No FCM tokens found for requester $requesterId');
      }
    } catch (e) {
      log('Error notifying requester: $e');
    }
  }

  /// Get FCM tokens for a list of user IDs
  Future<List<String>> _getFCMTokensForUsers(List<String> userIds) async {
    try {
      final response = await _client
          .from('fcm_tokens')
          .select('token')
          .inFilter('user_id', userIds);

      final tokens =
          response
              .map((t) => t['token'] as String?)
              .where((t) => t != null && t.isNotEmpty)
              .cast<String>()
              .toList();

      log('DEBUG: Extracted ${tokens.length} valid FCM tokens');

      return tokens;
    } catch (e) {
      log('Error getting FCM tokens: $e');
      return [];
    }
  }
}
