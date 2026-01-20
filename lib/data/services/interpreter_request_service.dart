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

  /// Create a new interpreter request and ring matching interpreters
  ///
  /// [interpreterType]: 'general' for entry-level/volunteer interpreters only
  ///                    'specialist' for experienced/paid interpreters with medical expertise
  /// [medicalSection]: Required when interpreterType is 'specialist' (e.g., 'neurology', 'cardiology')
  Future<InterpreterRequest> createRequest({
    required String fromLanguage,
    required String toLanguage,
    String? specialization,
    required String urgency,
    String? description,
    String callType = 'voice',
    String interpreterType = 'general', // 'general' or 'specialist'
    String? medicalSection, // e.g., 'neurology', 'cardiology', etc.
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to create a request');
      }

      // Create the request data with new fields
      final requestData = {
        'requester_id': user.id,
        'from_language': fromLanguage,
        'to_language': toLanguage,
        'specialization': specialization,
        'urgency': urgency,
        'status': 'pending',
        'description': description,
        'call_type': callType,
        'interpreter_type': interpreterType,
        'medical_section': medicalSection,
        'notification_tier': 1, // Start with tier 1
        'tier_started_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      // Insert the request into database and return inserted row
      final response =
          await _client
              .from('interpreter_requests')
              .insert(requestData)
              .select(
                'id, requester_id, from_language, to_language, specialization, urgency, status, description, call_type, interpreter_type, medical_section, notification_tier, created_at',
              )
              .single();

      final request = InterpreterRequest.fromJson(response);

      // Ring matching interpreters (with a small delay to ensure DB consistency)
      // Uses tiered matching for specialist requests:
      //   - Tier 1: Badge holders (80%+ score) - wait 30s
      //   - Tier 2: Passed quiz (50-79% score) - wait 30s
      //   - Tier 3: Volunteer interpreters (fallback)
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await _ringMatchingInterpreters(
            request,
            interpreterType: interpreterType,
            medicalSection: medicalSection,
          );
        } catch (e) {
          log('Background ringing failed: $e');
          // Don't throw - ringing failure shouldn't fail the request creation
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

  /// Find interpreters matching the request based on interpreter type and tier
  ///
  /// For GENERAL requests: Only return volunteer/entry-level interpreters
  /// For SPECIALIST requests with tiers:
  ///   - Tier 1: Interpreters with badges (scored 80%+) for the medical section
  ///   - Tier 2: Interpreters who passed (scored 50-79%) for the medical section
  ///   - Tier 3: Fallback to volunteer/entry-level interpreters
  Future<List<Map<String, dynamic>>> _findMatchingInterpreters(
    InterpreterRequest request, {
    int tier = 1,
    String? interpreterType,
    String? medicalSection,
  }) async {
    try {
      final type = interpreterType ?? 'general';
      final section = medicalSection;

      log('Finding interpreters for request: ${request.id}');
      log('Interpreter type: $type, Medical section: $section, Tier: $tier');
      log(
        'From language: ${request.fromLanguage}, To language: ${request.toLanguage}',
      );

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

      log('Matching user IDs by languages: ${matchingUserIds.length}');

      // === GENERAL INTERPRETER TYPE ===
      // Only return volunteer/entry-level interpreters
      if (type == 'general') {
        log('Finding GENERAL (volunteer) interpreters only');

        // Get volunteer interpreters from interpreter_details
        final volunteerInterpreters = await _client
            .from('interpreter_details')
            .select('user_id')
            .eq('employment_type', 'volunteer')
            .inFilter('user_id', matchingUserIds);

        final volunteerIds =
            volunteerInterpreters.map((u) => u['user_id'] as String).toList();
        log('Found ${volunteerIds.length} volunteer interpreters');

        if (volunteerIds.isEmpty) return [];

        // Get profiles for volunteer interpreters
        final userProfiles = await _client
            .from('users_profile')
            .select('user_id, username, role, employment_type')
            .inFilter('user_id', volunteerIds)
            .eq('role', 'interpreter');

        return List<Map<String, dynamic>>.from(userProfiles);
      }

      // === SPECIALIST INTERPRETER TYPE ===
      // Tiered matching based on medical section performance
      log(
        'Finding SPECIALIST (paid) interpreters for section: $section, Tier: $tier',
      );

      // Get paid interpreters from interpreter_details
      final paidInterpreters = await _client
          .from('interpreter_details')
          .select('user_id')
          .eq('employment_type', 'paid')
          .inFilter('user_id', matchingUserIds);

      final paidIds =
          paidInterpreters.map((u) => u['user_id'] as String).toList();
      log('Found ${paidIds.length} paid interpreters');

      List<String> tierInterpreterIds = [];

      if (section != null && section.isNotEmpty) {
        final medicalSectionKey = _specializationToMedicalSection(section);

        if (tier == 1) {
          // Tier 1: Interpreters with badges (80%+ score)
          log('Tier 1: Looking for interpreters with badges (80%+)');
          final badgeQuery = await _client
              .from('interpreter_badges')
              .select('user_id, score')
              .eq('badge', medicalSectionKey)
              .gte('score', 80)
              .inFilter('user_id', paidIds)
              .order('score', ascending: false);

          tierInterpreterIds =
              badgeQuery.map((b) => b['user_id'] as String).toList();
          log(
            'Found ${tierInterpreterIds.length} interpreters with badges for $medicalSectionKey',
          );
        } else if (tier == 2) {
          // Tier 2: Interpreters who passed (50-79% score) but no badge
          log('Tier 2: Looking for interpreters who passed (50-79%)');

          // Get interpreters who have passed this section (50%+) but scored less than 80%
          final passedQuery = await _client
              .from('quiz_attempts')
              .select('user_id, score_percentage')
              .eq('quiz_type', 'medical')
              .eq('medical_section', medicalSectionKey)
              .eq('passed', true)
              .gte('score_percentage', 50)
              .lt('score_percentage', 80)
              .inFilter('user_id', paidIds)
              .order('score_percentage', ascending: false);

          tierInterpreterIds =
              passedQuery.map((q) => q['user_id'] as String).toSet().toList();
          log(
            'Found ${tierInterpreterIds.length} interpreters who passed (50-79%)',
          );
        } else if (tier == 3) {
          // Tier 3: Fallback to volunteer/entry-level interpreters
          log('Tier 3: Fallback to volunteer interpreters');

          final volunteerInterpreters = await _client
              .from('interpreter_details')
              .select('user_id')
              .eq('employment_type', 'volunteer')
              .inFilter('user_id', matchingUserIds);

          tierInterpreterIds =
              volunteerInterpreters.map((u) => u['user_id'] as String).toList();
          log(
            'Found ${tierInterpreterIds.length} volunteer interpreters for fallback',
          );
        }
      } else {
        // No specific section, just get all paid interpreters
        tierInterpreterIds = paidIds;
      }

      if (tierInterpreterIds.isEmpty) {
        log('No interpreters found for tier $tier');
        return [];
      }

      // Get profiles for matching interpreters
      final userProfiles = await _client
          .from('users_profile')
          .select('user_id, username, role, employment_type')
          .inFilter('user_id', tierInterpreterIds)
          .eq('role', 'interpreter');

      return List<Map<String, dynamic>>.from(userProfiles);
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

  /// Ring matching interpreters based on tier
  /// Uses tiered matching for specialist requests:
  ///   - Tier 1: Badge holders (80%+ score) - wait 30s
  ///   - Tier 2: Passed quiz (50-79% score) - wait 30s
  ///   - Tier 3: Volunteer interpreters (fallback)
  Future<void> _ringMatchingInterpreters(
    InterpreterRequest request, {
    required String interpreterType,
    String? medicalSection,
    int startTier = 1,
  }) async {
    try {
      log('Starting ring process for request: ${request.id}');
      log(
        'Interpreter type: $interpreterType, Medical section: $medicalSection',
      );

      // For general type, just ring volunteers directly
      if (interpreterType == 'general') {
        await _ringInterpretersForTier(
          request: request,
          tier: 1,
          interpreterType: 'general',
          medicalSection: null,
        );
        return;
      }

      // For specialist type, start with the specified tier
      await _ringInterpretersForTier(
        request: request,
        tier: startTier,
        interpreterType: interpreterType,
        medicalSection: medicalSection,
      );
    } catch (e) {
      log('Error ringing interpreters: $e');
    }
  }

  /// Ring interpreters for a specific tier
  Future<void> _ringInterpretersForTier({
    required InterpreterRequest request,
    required int tier,
    required String interpreterType,
    String? medicalSection,
  }) async {
    try {
      log('Ringing interpreters for tier $tier');

      final matchingInterpreters = await _findMatchingInterpreters(
        request,
        tier: tier,
        interpreterType: interpreterType,
        medicalSection: medicalSection,
      );

      log('Found ${matchingInterpreters.length} interpreters for tier $tier');

      if (matchingInterpreters.isEmpty) {
        log('No interpreters found for tier $tier');

        // If specialist and no interpreters in current tier, try next tier
        if (interpreterType == 'specialist' && tier < 3) {
          log('Escalating to tier ${tier + 1}');
          await _updateRequestTier(request.id, tier + 1);
          await _ringInterpretersForTier(
            request: request,
            tier: tier + 1,
            interpreterType: interpreterType,
            medicalSection: medicalSection,
          );
        } else {
          log('No more tiers to try, request may timeout');
        }
        return;
      }

      final interpreterIds =
          matchingInterpreters
              .map((interpreter) => interpreter['user_id'] as String)
              .toList();

      final fcmTokens = await _getFCMTokensForUsers(interpreterIds);
      log('Found ${fcmTokens.length} FCM tokens for tier $tier');

      if (fcmTokens.isEmpty) {
        log('No FCM tokens available for tier $tier');

        // Escalate to next tier if possible
        if (interpreterType == 'specialist' && tier < 3) {
          log('No tokens, escalating to tier ${tier + 1}');
          await _updateRequestTier(request.id, tier + 1);
          await _ringInterpretersForTier(
            request: request,
            tier: tier + 1,
            interpreterType: interpreterType,
            medicalSection: medicalSection,
          );
        }
        return;
      }

      // Update the request with current tier info
      await _updateRequestTier(request.id, tier);

      // Send ring notification to interpreters
      await _sendRingNotification(
        tokens: fcmTokens,
        request: request,
        interpreterType: interpreterType,
        medicalSection: medicalSection,
        tier: tier,
      );
    } catch (e) {
      log('Error ringing interpreters for tier $tier: $e');
    }
  }

  /// Update request with current notification tier
  Future<void> _updateRequestTier(String requestId, int tier) async {
    try {
      await _client
          .from('interpreter_requests')
          .update({
            'notification_tier': tier,
            'tier_started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      log('Updated request $requestId to tier $tier');
    } catch (e) {
      log('Error updating request tier: $e');
    }
  }

  /// Send ring notification via FCM with CallKit data
  Future<void> _sendRingNotification({
    required List<String> tokens,
    required InterpreterRequest request,
    required String interpreterType,
    String? medicalSection,
    required int tier,
  }) async {
    try {
      log(
        'Sending ring notification to ${tokens.length} interpreters (tier $tier)',
      );
      final fromLanguageName = await _findLanguageById(request.fromLanguage);
      final toLanguageName = await _findLanguageById(request.toLanguage);

      // Build caller name for CallKit display
      String callerName = '$fromLanguageName → $toLanguageName';
      if (interpreterType == 'specialist' && medicalSection != null) {
        callerName += ' ($medicalSection)';
      }

      // Determine call type label
      final callTypeLabel =
          interpreterType == 'specialist'
              ? 'Medical Specialist'
              : 'General Interpreter';

      final notificationData = {
        'title': 'Incoming Call - $callTypeLabel',
        'body': 'New ${request.callType} call: $callerName',
        'data': {
          'request_id': request.id,
          'from_language': fromLanguageName ?? request.fromLanguage,
          'to_language': toLanguageName ?? request.toLanguage,
          'urgency': request.urgency,
          'specialization': request.specialization ?? '',
          'call_type': request.callType,
          'interpreter_type': interpreterType,
          'medical_section': medicalSection ?? '',
          'notification_tier': tier.toString(),
          'type': 'INCOMING_CALL', // Triggers CallKit incoming call UI
          'caller_name': callerName, // For CallKit display
          'caller_id': request.id, // Use request ID as caller ID
        },
        'tokens': tokens,
      };

      log('Ring notification payload: $notificationData');

      final response = await _client.functions.invoke(
        'send-notification',
        body: jsonEncode(notificationData),
      );

      log('Edge function response status: ${response.status}');

      if (response.status != 200) {
        throw Exception('Failed to send ring notification: ${response.data}');
      }

      log('Ring notification sent successfully for tier $tier');
    } catch (e) {
      log('Error sending ring notification: $e');
    }
  }

  /// Check if request should escalate to next tier (called after timeout)
  Future<bool> checkAndEscalateTier(String requestId) async {
    try {
      final request =
          await _client
              .from('interpreter_requests')
              .select('*')
              .eq('id', requestId)
              .eq('status', 'pending')
              .maybeSingle();

      if (request == null) {
        log('Request $requestId not found or already accepted');
        return false;
      }

      final currentTier = request['notification_tier'] as int? ?? 1;
      final interpreterType =
          request['interpreter_type'] as String? ?? 'general';
      final medicalSection = request['medical_section'] as String?;
      final tierStartedAt = DateTime.parse(
        request['tier_started_at'] as String,
      );

      // Check if 30 seconds have passed since tier started
      final elapsed = DateTime.now().difference(tierStartedAt);
      if (elapsed.inSeconds < 30) {
        log(
          'Tier $currentTier has not timed out yet (${elapsed.inSeconds}s elapsed)',
        );
        return false;
      }

      // Only escalate for specialist requests
      if (interpreterType == 'specialist' && currentTier < 3) {
        log('Escalating from tier $currentTier to tier ${currentTier + 1}');

        // Create a minimal request object for ringing
        final interpretReq = InterpreterRequest(
          id: requestId,
          requesterId: request['requester_id'] as String,
          fromLanguage: request['from_language'] as String,
          toLanguage: request['to_language'] as String,
          specialization: request['specialization'] as String?,
          urgency: request['urgency'] as String,
          status: 'pending',
          callType: request['call_type'] as String? ?? 'voice',
          createdAt: DateTime.parse(request['created_at'] as String),
        );

        await _ringInterpretersForTier(
          request: interpretReq,
          tier: currentTier + 1,
          interpreterType: interpreterType,
          medicalSection: medicalSection,
        );
        return true;
      }

      log('Cannot escalate further, tier $currentTier is final');
      return false;
    } catch (e) {
      log('Error checking tier escalation: $e');
      return false;
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
