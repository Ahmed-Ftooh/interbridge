import 'dart:developer';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/models/interpreter_request.dart';

class InterpreterRequestService {
  static final InterpreterRequestService _instance =
      InterpreterRequestService._internal();
  factory InterpreterRequestService() => _instance;
  InterpreterRequestService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Create a new interpreter request and send notifications to matching interpreters
  Future<InterpreterRequest> createRequest({
    required String fromLanguage,
    required String toLanguage,
    String? specialization,
    required String urgency,
    String? description,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to create a request');
      }

      // Create the request data
      final requestData = {
        'requester_id': user.id,
        'from_language': fromLanguage,
        'to_language': toLanguage,
        'specialization': specialization,
        'urgency': urgency,
        'status': 'pending',
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Insert the request into database and return inserted row
      final response =
          await _client
              .from('interpreter_requests')
              .insert(requestData)
              .select(
                'id, requester_id, from_language, to_language, specialization, urgency, status, description, created_at',
              )
              .single();

      final request = InterpreterRequest.fromJson(response);

      // Notify matching interpreters (with a small delay to ensure DB consistency)
      // Run in background to not block the UI
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await _sendNotificationsToMatchingInterpreters(request);
        } catch (e) {
          log('Background notification failed: $e');
          // Don't throw - notification failure shouldn't fail the request creation
        }
      });

      return request;
    } catch (e) {
      log('Error creating interpreter request: $e');
      rethrow;
    }
  }

  _findLanguageById(String languageId) async {
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

  /// Find interpreters matching both from and to languages and optional specialization
  Future<List<Map<String, dynamic>>> _findMatchingInterpreters(
    InterpreterRequest request,
  ) async {
    try {
      log('Finding interpreters for request: ${request.id}');
      log(
        'From language: ${request.fromLanguage}, To language: ${request.toLanguage}',
      );
      log('Specialization: ${request.specialization}');

      // Get user_ids with fromLanguage
      final fromLangUsers = await _client
          .from('interpreter_languages')
          .select('user_id')
          .eq('language_id', request.fromLanguage);

      // Get user_ids with toLanguage
      final toLangUsers = await _client
          .from('interpreter_languages')
          .select('user_id')
          .eq('language_id', request.toLanguage);

      final fromUserIds =
          fromLangUsers.map((u) => u['user_id'] as String).toSet();
      final toUserIds = toLangUsers.map((u) => u['user_id'] as String).toSet();

      // Intersection: interpreters who know both languages
      final matchingUserIds = fromUserIds.intersection(toUserIds).toList();

      if (matchingUserIds.isEmpty) {
        log('No interpreters found matching both languages');
        return [];
      }

      log('Matching user IDs by languages: $matchingUserIds');

      // Get interpreter profiles by user_id and role
      final userProfiles = await _client
          .from('users_profile')
          .select('user_id, username, role')
          .inFilter('user_id', matchingUserIds)
          .eq('role', 'interpreter');

      // If specialization is specified, filter by specialization
      if (request.specialization != null &&
          request.specialization!.isNotEmpty) {
        log('Filtering by specialization: ${request.specialization}');

        try {
          // Get specialization ID by name
          final specializationResponse =
              await _client
                  .from('specializations')
                  .select('id')
                  .eq('name', request.specialization!)
                  .single();

          final specializationId = specializationResponse['id'] as int;
          log('Found specialization ID: $specializationId');

          // Find interpreters with that specialization among matching users
          final specializationQuery = await _client
              .from('interpreter_specializations')
              .select('user_id')
              .eq('specialization_id', specializationId)
              .inFilter('user_id', matchingUserIds);

          final specializedUserIds =
              specializationQuery
                  .map((spec) => spec['user_id'] as String)
                  .toList();

          log('Interpreters with specialization: ${specializedUserIds.length}');

          // Filter profiles by specialization
          return userProfiles
              .where(
                (profile) => specializedUserIds.contains(profile['user_id']),
              )
              .toList();
        } catch (e) {
          log('Specialization filter error: $e');
          // If specialization lookup fails, return all profiles without filtering
          return userProfiles;
        }
      }

      return userProfiles;
    } catch (e) {
      log('Error finding matching interpreters: $e');
      return [];
    }
  }

  /// Get FCM tokens for a list of user IDs
  Future<List<String>> _getFCMTokensForUsers(List<String> userIds) async {
    try {
      log('Getting FCM tokens for user IDs: $userIds');

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

      log('Found ${tokens.length} valid FCM tokens');

      return tokens;
    } catch (e) {
      log('Error getting FCM tokens: $e');
      return [];
    }
  }

  /// Send notification to matching interpreters
  Future<void> _sendNotificationsToMatchingInterpreters(
    InterpreterRequest request,
  ) async {
    try {
      log('Starting notification process for request: ${request.id}');

      final matchingInterpreters = await _findMatchingInterpreters(request);
      log('Found ${matchingInterpreters.length} matching interpreters');

      if (matchingInterpreters.isEmpty) {
        log('No matching interpreters found to notify');
        return;
      }

      final interpreterIds =
          matchingInterpreters
              .map((interpreter) => interpreter['user_id'] as String)
              .toList();

      final fcmTokens = await _getFCMTokensForUsers(interpreterIds);
      log('Found ${fcmTokens.length} FCM tokens to notify');

      if (fcmTokens.isEmpty) {
        log('No FCM tokens available, skipping notification');
        return;
      }

      await _sendNotificationToInterpreters(
        tokens: fcmTokens,
        request: request,
      );
    } catch (e) {
      log('Error sending notifications to interpreters: $e');
    }
  }

  /// Call Supabase Edge Function to send notifications
  Future<void> _sendNotificationToInterpreters({
    required List<String> tokens,
    required InterpreterRequest request,
  }) async {
    try {
      log('Sending notification to ${tokens.length} interpreters');
      final fromLanguageName = await _findLanguageById(request.fromLanguage);
      final toLanguageName = await _findLanguageById(request.toLanguage);

      final notificationData = {
        'title': 'New Interpreter Request',
        'body':
            'A new ${request.urgency.toLowerCase()} request from $fromLanguageName to $toLanguageName',
        'data': {
          'request_id': request.id,
          'from_language': fromLanguageName,
          'to_language': toLanguageName,
          'urgency': request.urgency,
          'specialization': request.specialization ?? '',
          'type': 'interpreter_request',
        },
        'tokens': tokens,
      };

      log('Notification payload: $notificationData');

      final response = await _client.functions.invoke(
        'send-notification',
        body: jsonEncode(notificationData),
      );

      log('Edge function response status: ${response.status}');
      log('Edge function response data: ${response.data}');

      if (response.status != 200) {
        throw Exception('Failed to send notification: ${response.data}');
      }

      log('Notification sent successfully');
    } catch (e) {
      log('Error sending notification via Edge Function: $e');
    }
  }
}

extension InterpreterRequestAdmin on InterpreterRequestService {
  /// Delete a pending interpreter request created by the current user
  Future<void> deleteRequest(String requestId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Verify ownership and status
      final row =
          await _client
              .from('interpreter_requests')
              .select('requester_id, status')
              .eq('id', requestId)
              .single();

      if (row['requester_id'] != user.id) {
        throw Exception('You can only delete your own requests');
      }
      if (row['status'] != 'pending') {
        throw Exception('Only pending requests can be deleted');
      }

      await _client.from('interpreter_requests').delete().eq('id', requestId);
    } catch (e) {
      log('Error deleting interpreter request: $e');
      rethrow;
    }
  }
}
