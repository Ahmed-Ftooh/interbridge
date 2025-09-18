import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/models/document_translation_request.dart';

class DocumentTranslationService {
  static final DocumentTranslationService _instance =
      DocumentTranslationService._internal();
  factory DocumentTranslationService() => _instance;
  DocumentTranslationService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Create a new document translation request and send notifications to matching interpreters
  Future<DocumentTranslationRequest> createRequest({
    required String fromLanguage,
    required String toLanguage,
    String? specialization,
    String? text,
    File? file,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to create a request');
      }

      String? fileUrl;
      if (file != null) {
        // Upload file to Supabase Storage
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final filePath = 'document_translations/${user.id}/$fileName';

        await _client.storage.from('documents').upload(filePath, file);

        fileUrl = _client.storage.from('documents').getPublicUrl(filePath);
      }

      // Create the request
      final requestData = {
        'requester_id': user.id,
        'from_language': fromLanguage,
        'to_language': toLanguage,
        'specialization': specialization,
        'text': text,
        'file_url': fileUrl,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _client
              .from('document_translation_requests')
              .insert(requestData)
              .select()
              .single();

      final request = DocumentTranslationRequest.fromJson(response);

      // Find matching interpreters and send notifications
      await _sendNotificationsToMatchingInterpreters(request);

      return request;
    } catch (e) {
      log('Error creating document translation request: $e');
      rethrow;
    }
  }

  /// Find interpreters that match the request criteria and send notifications
  Future<void> _sendNotificationsToMatchingInterpreters(
    DocumentTranslationRequest request,
  ) async {
    try {
      log(
        'DEBUG: Starting notification process for document translation request: ${request.id}',
      );

      // Get all interpreters with the required language pair
      final matchingInterpreters = await _findMatchingInterpreters(request);
      log('DEBUG: Found ${matchingInterpreters.length} matching interpreters');

      if (matchingInterpreters.isEmpty) {
        log('DEBUG: No matching interpreters found, skipping notification');
        return;
      }

      // Get FCM tokens for matching interpreters
      final interpreterIds =
          matchingInterpreters
              .map((interpreter) => interpreter['user_id'] as String)
              .toList();
      log('DEBUG: Getting FCM tokens for interpreter IDs: $interpreterIds');

      final fcmTokens = await _getFCMTokensForUsers(interpreterIds);
      log('DEBUG: Found ${fcmTokens.length} FCM tokens');

      if (fcmTokens.isEmpty) {
        log('DEBUG: No FCM tokens found, skipping notification');
        return;
      }

      log('DEBUG: Sending notification to ${fcmTokens.length} interpreters');
      // Send notification via Edge Function
      await _sendNotificationToInterpreters(
        tokens: fcmTokens,
        request: request,
      );
    } catch (e) {
      log('Error sending notifications to interpreters: $e');
    }
  }

  /// Find interpreters that match the request criteria
  Future<List<Map<String, dynamic>>> _findMatchingInterpreters(
    DocumentTranslationRequest request,
  ) async {
    try {
      log(
        'DEBUG: Finding interpreters for document translation request: ${request.id}',
      );
      log(
        'DEBUG: From language: ${request.fromLanguage}, To language: ${request.toLanguage}',
      );
      log('DEBUG: Specialization: ${request.specialization}');

      // Query interpreters with the required language pair
      final languageQuery = await _client
          .from('interpreter_languages')
          .select('user_id, language_id, fluency_id')
          .eq('language_id', request.toLanguage);

      log(
        'DEBUG: Found ${languageQuery.length} interpreters with target language',
      );

      // Get user IDs of matching interpreters
      final matchingUserIds =
          languageQuery.map((lang) => lang['user_id'] as String).toList();

      if (matchingUserIds.isEmpty) {
        log('DEBUG: No interpreters found with target language');
        return [];
      }

      log('DEBUG: Matching user IDs: $matchingUserIds');

      // Get user profiles for the matching user IDs
      final userProfiles = await _client
          .from('users_profile')
          .select('user_id, username, role')
          .inFilter('user_id', matchingUserIds);

      log('DEBUG: Raw user profiles query result: $userProfiles');
      log(
        'DEBUG: Found ${userProfiles.length} user profiles (before role filter)',
      );

      // Filter by interpreter role
      final interpreterProfiles =
          userProfiles
              .where((profile) => profile['role'] == 'interpreter')
              .toList();

      log(
        'DEBUG: Found ${interpreterProfiles.length} interpreter profiles (after role filter)',
      );

      // If specialization is specified, filter by specialization
      if (request.specialization != null &&
          request.specialization!.isNotEmpty) {
        log('DEBUG: Filtering by specialization: ${request.specialization}');

        // Get the specialization ID for the given specialization name
        int specializationId;
        try {
          final specializationResponse =
              await _client
                  .from('specializations')
                  .select('id')
                  .eq('name', request.specialization!)
                  .single();

          specializationId = specializationResponse['id'] as int;
          log(
            'DEBUG: Found specialization ID: $specializationId for "${request.specialization}"',
          );
        } catch (e) {
          log(
            'DEBUG: Specialization "${request.specialization}" not found or error: $e',
          );
          log('DEBUG: Proceeding without specialization filter');
          return interpreterProfiles;
        }

        final specializationQuery = await _client
            .from('interpreter_specializations')
            .select('user_id')
            .eq('specialization_id', specializationId)
            .inFilter('user_id', matchingUserIds);

        final specializedUserIds =
            specializationQuery
                .map((spec) => spec['user_id'] as String)
                .toList();

        log(
          'DEBUG: Found ${specializedUserIds.length} interpreters with required specialization',
        );

        // Filter user profiles to only include those with the required specialization
        final filteredProfiles =
            interpreterProfiles
                .where(
                  (profile) => specializedUserIds.contains(profile['user_id']),
                )
                .toList();

        log('DEBUG: Final filtered profiles: ${filteredProfiles.length}');

        // If no filtered profiles found, try using the fallback
        if (filteredProfiles.isEmpty) {
          log(
            'DEBUG: No filtered profiles found, using fallback from interpreter_languages',
          );
          log('DEBUG: Fallback user IDs: $matchingUserIds');

          // Create minimal profile objects from the users we found in interpreter_languages
          final fallbackProfiles =
              matchingUserIds
                  .map(
                    (userId) => {
                      'user_id': userId,
                      'username': 'Interpreter_$userId',
                      'role': 'interpreter',
                    },
                  )
                  .toList();

          log('DEBUG: Created ${fallbackProfiles.length} fallback profiles');
          return fallbackProfiles;
        }

        return filteredProfiles;
      }

      log(
        'DEBUG: Returning all ${interpreterProfiles.length} interpreter profiles',
      );
      return interpreterProfiles;
    } catch (e) {
      log('Error finding matching interpreters: $e');
      return [];
    }
  }

  /// Get FCM tokens for a list of user IDs
  Future<List<String>> _getFCMTokensForUsers(List<String> userIds) async {
    try {
      log('DEBUG: Getting FCM tokens for user IDs: $userIds');

      final response = await _client
          .from('fcm_tokens')
          .select('token')
          .inFilter('user_id', userIds);

      log('DEBUG: FCM tokens query response: $response');

      final tokens = response.map((token) => token['token'] as String).toList();
      log(
        'DEBUG: Extracted ${tokens.length} FCM tokens: ${tokens.map((t) => t.substring(0, 20) + "...").toList()}',
      );

      return tokens;
    } catch (e) {
      log('Error getting FCM tokens: $e');
      return [];
    }
  }

  /// Send notification to interpreters via Edge Function
  Future<void> _sendNotificationToInterpreters({
    required List<String> tokens,
    required DocumentTranslationRequest request,
  }) async {
    try {
      log('DEBUG: Sending notification to ${tokens.length} interpreters');
      log('DEBUG: Request ID: ${request.id}');

      final notificationData = {
        'title': 'New Document Translation Request',
        'body':
            'A new document translation request for ${request.fromLanguage} to ${request.toLanguage}',
        'data': {
          'request_id': request.id,
          'from_language': request.fromLanguage,
          'to_language': request.toLanguage,
          'specialization': request.specialization ?? '',
          'type': 'document_translation_request',
        },
        'tokens': tokens,
      };

      log('DEBUG: Notification data: $notificationData');

      // Call the Firebase Messaging Edge Function
      final response = await _client.functions.invoke(
        'send-notification',
        body: jsonEncode(notificationData),
      );

      log('DEBUG: Edge function response status: ${response.status}');
      log('DEBUG: Edge function response data: ${response.data}');

      if (response.status != 200) {
        throw Exception('Failed to send notification: ${response.data}');
      }

      log('Notification sent successfully to ${tokens.length} interpreters');
    } catch (e) {
      log('Error sending notification via Edge Function: $e');
    }
  }

  /// Get all document translation requests for the current user
  Future<List<DocumentTranslationRequest>> getUserRequests() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      final response = await _client
          .from('document_translation_requests')
          .select()
          .eq('requester_id', user.id)
          .order('created_at', ascending: false);

      return response
          .map((json) => DocumentTranslationRequest.fromJson(json))
          .toList();
    } catch (e) {
      log('Error getting user document translation requests: $e');
      return [];
    }
  }

  /// Accept a document translation request (for interpreters)
  Future<void> acceptRequest(String requestId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      await _client
          .from('document_translation_requests')
          .update({
            'status': 'accepted',
            'accepted_by': user.id,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Send notification to requester that their request was accepted
      await _notifyRequesterRequestAccepted(requestId, user.id);
    } catch (e) {
      log('Error accepting document translation request: $e');
      rethrow;
    }
  }

  /// Notify requester that their request was accepted
  Future<void> _notifyRequesterRequestAccepted(
    String requestId,
    String interpreterId,
  ) async {
    try {
      // Get the request details
      final requestResponse =
          await _client
              .from('document_translation_requests')
              .select('requester_id')
              .eq('id', requestId)
              .single();

      final requesterId = requestResponse['requester_id'];

      // Get interpreter profile
      final interpreterProfile =
          await _client
              .from('users_profile')
              .select('username')
              .eq('user_id', interpreterId)
              .single();

      // Get requester's FCM token
      final requesterTokens = await _getFCMTokensForUsers([requesterId]);

      if (requesterTokens.isNotEmpty) {
        final notificationData = {
          'title': 'Document Translation Request Accepted',
          'body':
              '${interpreterProfile['username']} has accepted your document translation request',
          'data': {
            'request_id': requestId,
            'interpreter_id': interpreterId,
            'type': 'document_translation_accepted',
          },
          'tokens': requesterTokens,
        };

        await _client.functions.invoke(
          'send-notification',
          body: jsonEncode(notificationData),
        );
      }
    } catch (e) {
      log('Error notifying requester: $e');
    }
  }

  /// Get available document translation requests for interpreters
  Future<List<DocumentTranslationRequest>> getAvailableRequests() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      final response = await _client
          .from('document_translation_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return response
          .map((json) => DocumentTranslationRequest.fromJson(json))
          .toList();
    } catch (e) {
      log('Error getting available document translation requests: $e');
      return [];
    }
  }
}
