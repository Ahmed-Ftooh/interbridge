// lib/data/services/document_translation_service.dart
import 'dart:convert';
import 'dart:developer';

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
    String? title,
    String? comment,
    String?
    translationMethod, // This will now correctly be 'text', 'pdf', 'image', or 'voice'
    String? fileUrl,
    String? fileType, // Keep this for potential future use if needed
    String? fileName,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to create a request');
      }

      // --- *** FIXED: Removed incorrect normalization for 'voice' *** ---
      // The translationMethod passed in (e.g., 'voice') will be used directly.
      // We still map 'pdf' to 'document' for consistency if needed, but keep 'voice' as 'voice'.
      String dbTranslationMethod =
          translationMethod ?? 'text'; // Default to 'text' if null
      if (translationMethod == 'pdf') {
        dbTranslationMethod =
            'document'; // Map pdf input to 'document' type if desired
      }
      // Keep 'text', 'image', 'voice' as they are.
      // --- *** END FIX *** ---

      final requestData = {
        'requester_id': user.id,
        'from_language': fromLanguage,
        'to_language': toLanguage,
        'specialization': specialization,
        'text': text,
        'title': title,
        'comment': comment,
        'translation_method':
            dbTranslationMethod, // Use the (potentially adjusted) method
        'file_url': fileUrl,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        // Conditionally add fileName and fileType if they exist AND are not null
        // This avoids errors if the columns don't exist in your Supabase table yet.
        if (fileName != null) 'file_name': fileName,
        if (fileType != null) 'file_type': fileType,
      };

      // Use insert and select in one go. Supabase handles missing optional columns gracefully.
      final response =
          await _client
              .from('document_translation_requests')
              .insert(requestData)
              .select()
              .single();

      final request = DocumentTranslationRequest.fromJson(response);

      // Find matching interpreters and send notifications (existing logic)
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
    // ... (Your existing notification logic - no changes needed here)
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
    // ... (Your existing matching logic - no changes needed here)
    try {
      log(
        'DEBUG: Finding interpreters for document translation request: ${request.id}',
      );
      log(
        'DEBUG: From language: ${request.fromLanguage}, To language: ${request.toLanguage}',
      );
      log('DEBUG: Specialization: ${request.specialization}');

      // First, get language IDs for the from and to languages
      final fromLanguageQuery =
          await _client
              .from('languages')
              .select('id')
              .eq('name', request.fromLanguage)
              .maybeSingle(); // Use maybeSingle to handle potential nulls gracefully
      final toLanguageQuery =
          await _client
              .from('languages')
              .select('id')
              .eq('name', request.toLanguage)
              .maybeSingle();

      // Check if languages were found
      if (fromLanguageQuery == null || toLanguageQuery == null) {
        log(
          'DEBUG: One or both languages not found in the database: From="${request.fromLanguage}", To="${request.toLanguage}"',
        );
        return [];
      }

      final fromLanguageId = fromLanguageQuery['id'] as int;
      final toLanguageId = toLanguageQuery['id'] as int;

      log(
        'DEBUG: From language ID: $fromLanguageId, To language ID: $toLanguageId',
      );

      // Find interpreters who have BOTH the from and to languages
      final fromLanguageUsers = await _client
          .from('interpreter_languages')
          .select('user_id')
          .eq('language_id', fromLanguageId);

      final toLanguageUsers = await _client
          .from('interpreter_languages')
          .select('user_id')
          .eq('language_id', toLanguageId);

      final fromUserIds =
          fromLanguageUsers.map((lang) => lang['user_id'] as String).toSet();
      final toUserIds =
          toLanguageUsers.map((lang) => lang['user_id'] as String).toSet();

      // Find intersection - interpreters who have both languages
      final matchingUserIds = fromUserIds.intersection(toUserIds).toList();

      log(
        'DEBUG: Found ${matchingUserIds.length} interpreters with both languages',
      );

      if (matchingUserIds.isEmpty) {
        log('DEBUG: No interpreters found with both languages');
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

      // If no interpreters found after role filter, return empty
      if (interpreterProfiles.isEmpty) {
        log('DEBUG: No users with interpreter role found among matches.');
        return [];
      }

      // If specialization is specified, filter by specialization
      if (request.specialization != null &&
          request.specialization!.isNotEmpty) {
        log('DEBUG: Filtering by specialization: ${request.specialization}');

        // Get the specialization ID for the given specialization name
        int? specializationId;
        try {
          final specializationResponse =
              await _client
                  .from('specializations')
                  .select('id')
                  .eq('name', request.specialization!)
                  .maybeSingle(); // Use maybeSingle

          if (specializationResponse == null) {
            log('DEBUG: Specialization "${request.specialization}" not found.');
          } else {
            specializationId = specializationResponse['id'] as int?;
            log(
              'DEBUG: Found specialization ID: $specializationId for "${request.specialization}"',
            );
          }
        } catch (e) {
          log(
            'DEBUG: Error fetching specialization ID for "${request.specialization}": $e',
          );
          // Continue without specialization filter if ID lookup fails
          specializationId = null;
        }

        // Only filter if we successfully found a specialization ID
        if (specializationId != null) {
          final specializationQuery = await _client
              .from('interpreter_specializations')
              .select('user_id')
              .eq('specialization_id', specializationId)
              .inFilter(
                'user_id',
                interpreterProfiles.map((p) => p['user_id'] as String).toList(),
              ); // Filter based on interpreter profiles found

          final specializedUserIds =
              specializationQuery
                  .map((spec) => spec['user_id'] as String)
                  .toSet(); // Use a Set for efficient lookup

          log(
            'DEBUG: Found ${specializedUserIds.length} interpreters with required specialization ID $specializationId',
          );

          // Filter interpreter profiles to only include those with the required specialization
          final filteredProfiles =
              interpreterProfiles
                  .where(
                    (profile) =>
                        specializedUserIds.contains(profile['user_id']),
                  )
                  .toList();

          log(
            'DEBUG: Final filtered profiles after specialization: ${filteredProfiles.length}',
          );

          // Return the specialization-filtered list if not empty
          if (filteredProfiles.isNotEmpty) {
            // Continue with additional capability filters below
            // by updating interpreterProfiles to the filtered subset
            interpreterProfiles
              ..clear()
              ..addAll(filteredProfiles);
          } else {
            log(
              'DEBUG: No interpreters found matching the specific specialization. Returning empty list.',
            );
            return []; // Return empty if specialization filter yields no results
          }
        } else {
          log(
            'DEBUG: Proceeding without specialization filter as ID was not found or lookup failed.',
          );
        }
      }

      // Additional filter: require interpreters to have reading AND writing capability
      try {
        // Resolve skill IDs for reading and writing using loose name match
        final readSkills = await _client
            .from('skills')
            .select('id,name')
            .ilike('name', '%read%');
        final writeSkills = await _client
            .from('skills')
            .select('id,name')
            .ilike('name', '%writ%');

        final readSkillIds = readSkills.map<int>((s) => s['id'] as int).toSet();
        final writeSkillIds =
            writeSkills.map<int>((s) => s['id'] as int).toSet();

        if (readSkillIds.isEmpty || writeSkillIds.isEmpty) {
          log(
            'DEBUG: Read/Write skill IDs not found; skipping capability filter.',
          );
          log(
            'DEBUG: Returning ${interpreterProfiles.length} interpreter profiles (no specialization filter or fallback)',
          );
          return interpreterProfiles;
        }

        final candidateUserIds =
            interpreterProfiles.map((p) => p['user_id'] as String).toList();

        // Fetch interpreter_skills for candidates and required skill sets
        final skillsRows = await _client
            .from('interpreter_skills')
            .select('user_id, skill_id')
            .inFilter('user_id', candidateUserIds);

        final byUser = <String, Set<int>>{};
        for (final row in skillsRows) {
          final uid = row['user_id'] as String;
          final sid = row['skill_id'] as int;
          byUser.putIfAbsent(uid, () => <int>{}).add(sid);
        }

        bool hasBoth(Set<int> s) =>
            s.any((id) => readSkillIds.contains(id)) &&
            s.any((id) => writeSkillIds.contains(id));

        final filteredByCapability =
            interpreterProfiles.where((p) {
              final uid = p['user_id'] as String;
              final set = byUser[uid] ?? const <int>{};
              return hasBoth(set);
            }).toList();

        log(
          'DEBUG: Capability filter reduced interpreters from ${interpreterProfiles.length} to ${filteredByCapability.length}',
        );

        return filteredByCapability;
      } catch (e) {
        log('DEBUG: Error applying read/write capability filter: $e');
        log(
          'DEBUG: Returning ${interpreterProfiles.length} interpreter profiles (capability filter skipped)',
        );
        return interpreterProfiles;
      }
    } catch (e) {
      log('Error finding matching interpreters: $e');
      return [];
    }
  }

  /// Get FCM tokens for a list of user IDs
  Future<List<String>> _getFCMTokensForUsers(List<String> userIds) async {
    // ... (Your existing FCM token logic - no changes needed here)
    try {
      log('DEBUG: Getting FCM tokens for user IDs: $userIds');
      if (userIds.isEmpty) {
        log('DEBUG: No user IDs provided to get FCM tokens.');
        return [];
      }

      final response = await _client
          .from('fcm_tokens')
          .select('token')
          .inFilter('user_id', userIds);

      log('DEBUG: FCM tokens query response: $response');

      final tokens = response.map((token) => token['token'] as String).toList();
      log(
        'DEBUG: Extracted ${tokens.length} FCM tokens: ${tokens.map((t) => '${t.substring(0, 5)}...').toList()}', // Shorten tokens for logs
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
    // ... (Your existing Edge Function call logic - no changes needed here)
    try {
      log('DEBUG: Sending notification to ${tokens.length} interpreters');
      if (tokens.isEmpty) {
        log('DEBUG: No tokens provided, skipping notification send.');
        return;
      }
      log('DEBUG: Request ID: ${request.id}');

      final notificationData = {
        'title': 'New Document Translation Request',
        'body':
            'Request: ${request.fromLanguage} → ${request.toLanguage}${request.specialization != null ? ' (${request.specialization})' : ''}', // More informative body
        'data': {
          'request_id': request.id.toString(), // Ensure ID is string
          'from_language': request.fromLanguage,
          'to_language': request.toLanguage,
          'specialization': request.specialization ?? '',
          'request_title': request.title ?? '',
          'request_comment': request.comment ?? '',
          'type': 'document_translation_request', // For client-side routing
          'click_action':
              'FLUTTER_NOTIFICATION_CLICK', // Standard for FCM with Flutter
        },
        'tokens': tokens,
      };

      log(
        'DEBUG: Notification payload: ${jsonEncode(notificationData)}',
      ); // Log the full payload

      // Call the Firebase Messaging Edge Function
      final response = await _client.functions.invoke(
        'send-notification', // Ensure this matches your Edge Function name
        body:
            notificationData, // Send the map directly, Supabase client handles JSON encoding
      );

      log('DEBUG: Edge function response status: ${response.status}');
      log('DEBUG: Edge function response data: ${response.data}');

      if (response.status != 200) {
        // Log detailed error if possible
        String errorMessage = 'Failed to send notification';
        if (response.data != null) {
          errorMessage += ': ${response.data}';
        }
        log('ERROR: $errorMessage');
        throw Exception(errorMessage);
      }

      log('Notification sent successfully to targeted interpreters');
    } catch (e) {
      log('Error sending notification via Edge Function: $e');
      // Don't rethrow here, allow the flow to continue even if notifications fail
    }
  }

  /// Get all document translation requests for the current user
  Future<List<DocumentTranslationRequest>> getUserRequests() async {
    // ... (Existing logic is fine)
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
    // ... (Existing logic is fine)
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
          .eq('id', requestId)
          .eq('status', 'pending'); // Ensure we only accept pending requests

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
    // ... (Existing logic is fine)
    try {
      // Get the request details including title for better notification
      final requestResponse =
          await _client
              .from('document_translation_requests')
              .select('requester_id, title') // Select title too
              .eq('id', requestId)
              .maybeSingle();

      if (requestResponse == null) {
        log('ERROR: Request $requestId not found for acceptance notification.');
        return;
      }
      final requesterId = requestResponse['requester_id'];
      final requestTitle = requestResponse['title'] as String?;

      // Get interpreter profile
      final interpreterProfileResponse =
          await _client
              .from('users_profile')
              .select('username')
              .eq('user_id', interpreterId)
              .maybeSingle(); // Use maybeSingle

      // Use a default name if profile not found (shouldn't happen ideally)
      final interpreterUsername =
          interpreterProfileResponse?['username'] as String? ??
          'An interpreter';

      // Get requester's FCM token(s)
      final requesterTokens = await _getFCMTokensForUsers([requesterId]);

      if (requesterTokens.isNotEmpty) {
        // Construct a more informative body message
        String notificationBody =
            '$interpreterUsername has accepted your translation request';
        if (requestTitle != null && requestTitle.isNotEmpty) {
          notificationBody += ' "$requestTitle"';
        }
        notificationBody += '.';

        final notificationData = {
          'title': 'Translation Request Accepted',
          'body': notificationBody,
          'data': {
            'request_id': requestId.toString(),
            'interpreter_id': interpreterId,
            'type': 'document_translation_accepted',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'tokens': requesterTokens,
        };

        log(
          'DEBUG: Sending acceptance notification payload: ${jsonEncode(notificationData)}',
        );
        await _client.functions.invoke(
          'send-notification',
          body: notificationData,
        );
        log('DEBUG: Acceptance notification sent to requester $requesterId');
      } else {
        log(
          'DEBUG: No FCM tokens found for requester $requesterId. Cannot send acceptance notification.',
        );
      }
    } catch (e) {
      log('Error notifying requester about request acceptance: $e');
    }
  }

  /// Get available document translation requests for interpreters
  Future<List<DocumentTranslationRequest>> getAvailableRequests() async {
    // ... (Existing logic is fine)
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        // Allow viewing available requests even if not logged in, or handle as needed
        // For now, let's assume authentication is required to see available jobs
        throw Exception('User must be authenticated');
      }

      // TODO: Add filtering based on interpreter's languages/specializations later if needed
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

  /// Get accepted document translation requests for the current interpreter
  Future<List<DocumentTranslationRequest>> getAcceptedRequests() async {
    // ... (Existing logic is fine)
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      final response = await _client
          .from('document_translation_requests')
          .select()
          .eq('accepted_by', user.id)
          .eq('status', 'accepted') // Only fetch those currently accepted
          .order('accepted_at', ascending: false);

      return response
          .map((json) => DocumentTranslationRequest.fromJson(json))
          .toList();
    } catch (e) {
      log('Error getting accepted document translation requests: $e');
      return [];
    }
  }

  /// Get completed document translation requests for the current interpreter
  Future<List<DocumentTranslationRequest>> getCompletedRequests() async {
    // ... (Existing logic is fine)
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      final response = await _client
          .from('document_translation_requests')
          .select()
          .eq('accepted_by', user.id) // Filter by interpreter who completed it
          .eq('status', 'completed')
          .order('completed_at', ascending: false);

      return response
          .map((json) => DocumentTranslationRequest.fromJson(json))
          .toList();
    } catch (e) {
      log('Error getting completed document translation requests: $e');
      return [];
    }
  }

  /// Complete a document translation request
  Future<void> completeRequest({
    required String requestId,
    String? translatedText,
    String? translatedFileUrl,
  }) async {
    // ... (Existing logic is fine)
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Optional: Verify the request is currently accepted by this user before completing
      final requestCheck =
          await _client
              .from('document_translation_requests')
              .select('status, accepted_by')
              .eq('id', requestId)
              .maybeSingle();

      if (requestCheck == null) {
        throw Exception('Request not found.');
      }
      if (requestCheck['status'] != 'accepted' ||
          requestCheck['accepted_by'] != user.id) {
        throw Exception(
          'Cannot complete this request. It might not be assigned to you or is already completed/pending.',
        );
      }

      // Update the request with completed translation
      await _client
          .from('document_translation_requests')
          .update({
            'status': 'completed',
            'translated_text':
                translatedText, // Can be null if file is provided
            'translated_file_url':
                translatedFileUrl, // Can be null if text is provided
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Send notification to requester that translation is completed
      await _notifyRequesterTranslationCompleted(requestId, user.id);
    } catch (e) {
      log('Error completing document translation request: $e');
      rethrow;
    }
  }

  /// Notify requester that their translation is completed
  Future<void> _notifyRequesterTranslationCompleted(
    String requestId,
    String interpreterId,
  ) async {
    // ... (Existing logic is fine)
    try {
      // Get the request details
      final requestResponse =
          await _client
              .from('document_translation_requests')
              .select('requester_id, title') // Select title too
              .eq('id', requestId)
              .maybeSingle();

      if (requestResponse == null) {
        log('ERROR: Request $requestId not found for completion notification.');
        return;
      }
      final requesterId = requestResponse['requester_id'];
      final requestTitle = requestResponse['title'] as String?;

      // Get interpreter profile (optional, but good for the message)
      final interpreterProfileResponse =
          await _client
              .from('users_profile')
              .select('username')
              .eq('user_id', interpreterId)
              .maybeSingle();
      final interpreterUsername =
          interpreterProfileResponse?['username'] as String? ??
          'Your interpreter';

      // Get requester's FCM token(s)
      final requesterTokens = await _getFCMTokensForUsers([requesterId]);

      if (requesterTokens.isNotEmpty) {
        // Construct a more informative body message
        String notificationBody =
            '$interpreterUsername has completed your translation request';
        if (requestTitle != null && requestTitle.isNotEmpty) {
          notificationBody += ' "$requestTitle"';
        }
        notificationBody += '.';

        final notificationData = {
          'title': 'Translation Completed',
          'body': notificationBody,
          'data': {
            'request_id': requestId.toString(),
            'interpreter_id': interpreterId,
            'type': 'document_translation_completed', // For client-side routing
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'tokens': requesterTokens,
        };

        log(
          'DEBUG: Sending completion notification payload: ${jsonEncode(notificationData)}',
        );
        await _client.functions.invoke(
          'send-notification',
          body: notificationData,
        );
        log('DEBUG: Completion notification sent to requester $requesterId');
      } else {
        log(
          'DEBUG: No FCM tokens found for requester $requesterId. Cannot send completion notification.',
        );
      }
    } catch (e) {
      log('Error notifying requester of translation completion: $e');
    }
  }

  /// Delete a document translation request (by the requester)
  Future<void> deleteRequest(String requestId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // First, verify that the user owns this request and its status
      final requestResponse =
          await _client
              .from('document_translation_requests')
              .select('requester_id, status')
              .eq('id', requestId)
              .maybeSingle(); // Use maybeSingle

      if (requestResponse == null) {
        // If the request doesn't exist, maybe it was already deleted.
        // Consider returning successfully or logging, instead of throwing.
        log(
          'WARN: Attempted to delete request $requestId which was not found.',
        );
        return; // Or throw Exception('Request not found');
      }

      if (requestResponse['requester_id'] != user.id) {
        throw Exception('You can only delete your own requests');
      }

      // --- *** FIXED: Allow deletion for 'pending' OR 'completed' *** ---
      final status = requestResponse['status'];
      if (status != 'pending' && status != 'completed') {
        throw Exception(
          'You can only delete requests that are pending or completed. Current status: $status',
        );
      }
      // --- *** END FIX *** ---

      // Delete the request
      await _client
          .from('document_translation_requests')
          .delete()
          .eq('id', requestId);

      log('INFO: Request $requestId deleted successfully by user ${user.id}');
    } catch (e) {
      log('Error deleting document translation request $requestId: $e');
      rethrow; // Rethrow to allow the UI to show an error
    }
  }
}
