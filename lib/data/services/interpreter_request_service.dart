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
    String callType = 'voice',
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
        'call_type': callType,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Insert the request into database and return inserted row
      final response =
          await _client
              .from('interpreter_requests')
              .insert(requestData)
              .select(
                'id, requester_id, from_language, to_language, specialization, urgency, status, description, call_type, created_at',
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
  /// Prioritizes interpreters with badges for the requested medical section
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

      List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(
        userProfiles,
      );

      // If specialization is specified, prioritize by badge
      if (request.specialization != null &&
          request.specialization!.isNotEmpty) {
        log(
          'Prioritizing by badge for specialization: ${request.specialization}',
        );

        try {
          // Convert specialization name to medical_section enum key
          // e.g., "Neurology" -> "neurology", "OB/GYN" -> "ob_gyn"
          final medicalSection = _specializationToMedicalSection(
            request.specialization!,
          );
          log('Medical section key: $medicalSection');

          // Find interpreters with a badge for this medical section
          final badgeQuery = await _client
              .from('interpreter_badges')
              .select('user_id, score')
              .eq('badge', medicalSection)
              .inFilter('user_id', matchingUserIds)
              .order('score', ascending: false);

          final interpretersWithBadge =
              badgeQuery.map((b) => b['user_id'] as String).toList();

          log(
            'Interpreters with badge for $medicalSection: ${interpretersWithBadge.length}',
          );

          if (interpretersWithBadge.isNotEmpty) {
            // Sort results: interpreters with badges first (sorted by score), then others
            final withBadge =
                result
                    .where((p) => interpretersWithBadge.contains(p['user_id']))
                    .toList();
            final withoutBadge =
                result
                    .where((p) => !interpretersWithBadge.contains(p['user_id']))
                    .toList();

            // Sort withBadge by their position in interpretersWithBadge (which is sorted by score)
            withBadge.sort((a, b) {
              final aIndex = interpretersWithBadge.indexOf(
                a['user_id'] as String,
              );
              final bIndex = interpretersWithBadge.indexOf(
                b['user_id'] as String,
              );
              return aIndex.compareTo(bIndex);
            });

            result = [...withBadge, ...withoutBadge];
            log('Prioritized ${withBadge.length} interpreters with badges');
          }
        } catch (e) {
          log('Badge prioritization error: $e');
          // Continue without badge prioritization if it fails
        }

        // Also filter by specialization if applicable
        try {
          // Get specialization ID by name
          final specializationResponse =
              await _client
                  .from('specializations')
                  .select('id')
                  .eq('name', request.specialization!)
                  .maybeSingle();

          if (specializationResponse != null) {
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
                    .toSet();

            log(
              'Interpreters with specialization: ${specializedUserIds.length}',
            );

            // Filter profiles by specialization (but keep badge ordering)
            if (specializedUserIds.isNotEmpty) {
              result =
                  result
                      .where((p) => specializedUserIds.contains(p['user_id']))
                      .toList();
            }
          }
        } catch (e) {
          log('Specialization filter error: $e');
          // Continue without specialization filtering if it fails
        }
      }

      return result;
    } catch (e) {
      log('Error finding matching interpreters: $e');
      return [];
    }
  }

  /// Convert specialization display name to medical_section enum key
  String _specializationToMedicalSection(String specialization) {
    final map = {
      'Neurology': 'neurology',
      'Cardiology': 'cardiology',
      'Respiratory': 'respiratory',
      'Gastrointestinal': 'gastrointestinal',
      'Endocrinology': 'endocrinology',
      'Renal': 'renal',
      'OB/GYN': 'ob_gyn',
      'Oncology': 'oncology',
      'Emergency': 'emergency',
      'Psychology': 'psychology',
      'Musculoskeletal': 'musculoskeletal',
      'Dermatology': 'dermatology',
    };
    return map[specialization] ??
        specialization.toLowerCase().replaceAll('/', '_').replaceAll(' ', '_');
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
      log('Sending call invite notification to ${tokens.length} interpreters');
      final fromLanguageName = await _findLanguageById(request.fromLanguage);
      final toLanguageName = await _findLanguageById(request.toLanguage);

      // Build caller name for CallKit display
      final callerName =
          '$fromLanguageName → $toLanguageName${request.specialization != null ? ' (${request.specialization})' : ''}';

      final notificationData = {
        'title': 'Incoming Call Request',
        'body': 'New ${request.callType} call: $callerName',
        'data': {
          'request_id': request.id,
          'from_language': fromLanguageName,
          'to_language': toLanguageName,
          'urgency': request.urgency,
          'specialization': request.specialization ?? '',
          'call_type': request.callType,
          'type': 'incoming_call', // Triggers CallKit incoming call UI
          'caller_name': callerName, // For CallKit display
          'caller_id': request.id, // Use request ID as caller ID
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

      log('Call invite notification sent successfully');
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
