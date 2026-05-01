import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/app_initializer.dart';
import 'package:interbridge/core/deeplink_config.dart';
import '../models/user_profile.dart';
import '../models/interpreter_language.dart';
import '../models/interpreter_specialization.dart';
import '../models/interpreter_skill.dart';
import '../models/interpreter_language_skill.dart';
import '../models/interpreter_details.dart';
import '../models/specialization.dart';
import '../models/skill.dart';
import '../models/language.dart';
import '../models/fluency_level.dart';
import 'language_cache_service.dart';

class SupabaseService {
  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();
  static const String _interpreterComplianceBucket =
      'interpreter-login-compliance';
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Use a getter so construction is safe even before Supabase.initialize() finishes.
  SupabaseClient get _client => Supabase.instance.client;

  /// Public getter for accessing the Supabase client directly
  SupabaseClient get client => _client;

  // --- AUTH ---
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? portalHint,
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: getAuthCallbackUrl(portalHint: portalHint),
    );
  }

  Future<void> sendEmailOtp(String email, {String? portalHint}) async {
    // Send magic link for verification
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
      emailRedirectTo: getAuthCallbackUrl(portalHint: portalHint),
    );
  }

  Future<void> sendMagicLink(String email, {String? portalHint}) async {
    // Send magic link for verification
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
      emailRedirectTo: getAuthCallbackUrl(portalHint: portalHint),
    );
  }

  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
    String? portalHint,
  }) async {
    final resolvedRedirect =
        redirectTo ?? getAuthCallbackUrl(portalHint: portalHint);

    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: resolvedRedirect,
    );
  }

  Future<void> updatePassword({required String newPassword}) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> verifyMagicLink({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      token: token,
      type: OtpType.magiclink,
      email: email,
    );
  }

  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      token: token,
      type: OtpType.recovery,
      email: email,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    // Reset auth state so next login can navigate properly
    AppInitializer.resetAuthState();
    await _client.auth.signOut();
  }

  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  // --- USER PROFILE ---
  Future<UserProfile?> getUserProfile(String userId) async {
    final response =
        await _client
            .from('users_profile')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  Future<void> createUserProfile(UserProfile profile) async {
    // Use the authenticated user's context to bypass RLS
    await _client.from('users_profile').insert(profile.toJson());
  }

  Future<void> createUserProfileWithAuth(UserProfile profile) async {
    // Alternative method that ensures we're using the authenticated user context
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Ensure the profile user_id matches the authenticated user
    if (profile.id != user.id) {
      throw Exception('Profile user_id must match authenticated user');
    }

    await _client.from('users_profile').insert(profile.toJson());
  }

  Future<void> createUserProfileAfterSignUp(UserProfile profile) async {
    // Method specifically for creating profile after signup
    log('createUserProfileAfterSignUp: Starting for userId=${profile.id}');

    // Check if user is authenticated
    final user = _client.auth.currentUser;
    log('createUserProfileAfterSignUp: currentUser=${user?.id}');

    // Ensure the profile user_id matches the authenticated user
    if (user != null && profile.id != user.id) {
      log(
        'createUserProfileAfterSignUp: User ID mismatch - profile.id=${profile.id}, user.id=${user.id}',
      );
      throw Exception('Profile user_id must match authenticated user');
    }

    // Ensure we're using the authenticated user's context
    if (user == null) {
      log('createUserProfileAfterSignUp: User is null, cannot create profile');
      throw Exception('User must be authenticated to create profile');
    }

    // Create the data map explicitly to match table structure
    final data = {
      'user_id': profile.id,
      'username': profile.username ?? '',
      'role': profile.role ?? '',
      'profile_image': profile.profileImage ?? '',
      'gender': profile.gender ?? '',
      'country': profile.country,
      // created_at will be set automatically by the database
    };

    log('createUserProfileAfterSignUp: Inserting profile data: $data');

    // First, check if profile already exists
    final existingProfile =
        await _client
            .from('users_profile')
            .select('user_id')
            .eq('user_id', profile.id)
            .maybeSingle();

    if (existingProfile != null) {
      log('createUserProfileAfterSignUp: Profile already exists, skipping');
      return;
    }

    // Use insert instead of upsert with ignoreDuplicates to catch actual errors
    try {
      await _client.from('users_profile').insert(data);
      log('createUserProfileAfterSignUp: Profile created successfully');
    } catch (e) {
      log('createUserProfileAfterSignUp: Insert failed with error: $e');

      // If it's a duplicate error, that's fine - profile exists
      if (e.toString().contains('duplicate') ||
          e.toString().contains('23505')) {
        log('createUserProfileAfterSignUp: Duplicate detected, profile exists');
        return;
      }

      // Re-throw other errors
      throw Exception('Failed to create user profile: $e');
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _client
        .from('users_profile')
        .update(profile.toJson())
        .eq('user_id', profile.id);
  }

  /// Get user's organization membership with organization details
  Future<Map<String, dynamic>?> getUserOrganizationMembership(
    String userId,
  ) async {
    try {
      final response =
          await _client
              .from('organization_members')
              .select('''
            id,
            organization_id,
            role,
            is_active,
            organizations!inner(name, email)
          ''')
              .eq('user_id', userId)
              .eq('is_active', true)
              .maybeSingle();

      if (response == null) return null;

      return {
        'id': response['id'],
        'organization_id': response['organization_id'],
        'role': response['role'],
        'is_active': response['is_active'],
        'organization_name': response['organizations']?['name'],
        'organization_email': response['organizations']?['email'],
      };
    } catch (e) {
      log('getUserOrganizationMembership error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getInstitutionStatus(
    String institutionId,
  ) async {
    final response =
        await _client
            .from('institutions')
            .select('''
          id,
          subscription_status,
          subscription_end_date,
          active_users
        ''')
            .eq('id', institutionId)
            .maybeSingle();

    return response;
  }

  // --- INTERPRETER LANGUAGE ---
  Future<List<InterpreterLanguage>> getInterpreterLanguages(
    String userId,
  ) async {
    final List data = await _client
        .from('interpreter_languages')
        .select()
        .eq('user_id', userId);
    return data.map((e) => InterpreterLanguage.fromJson(e)).toList();
  }

  Future<void> addInterpreterLanguage(InterpreterLanguage lang) async {
    await _client
        .from('interpreter_languages')
        .upsert(
          lang.toJson(),
          onConflict: 'user_id,language_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> deleteInterpreterLanguage(String userId, int languageId) async {
    // Drop dependent skills first to satisfy foreign key constraints
    await _client
        .from('interpreter_language_skills')
        .delete()
        .eq('user_id', userId)
        .eq('language_id', languageId);

    await _client
        .from('interpreter_languages')
        .delete()
        .eq('user_id', userId)
        .eq('language_id', languageId);
  }

  Future<void> updateInterpreterLanguageFluency(
    String userId,
    int languageId,
    int fluencyId,
  ) async {
    await _client
        .from('interpreter_languages')
        .update({'fluency_id': fluencyId})
        .eq('user_id', userId)
        .eq('language_id', languageId);
  }

  /// Get all unique languages that interpreters have registered
  /// This returns languages that at least one interpreter speaks
  Future<List<Language>> getAvailableInterpreterLanguages() async {
    try {
      // Get all unique language_ids from interpreter_languages
      final interpreterLangs = await _client
          .from('interpreter_languages')
          .select('language_id');

      if (interpreterLangs.isEmpty) {
        return [];
      }

      // Get unique language IDs
      final uniqueLanguageIds =
          interpreterLangs.map((e) => e['language_id'] as int).toSet().toList();

      // Get the language details for these IDs
      final languages = await _client
          .from('languages')
          .select()
          .inFilter('id', uniqueLanguageIds);

      return languages.map((e) => Language.fromJson(e)).toList();
    } catch (e) {
      log('Error getting available interpreter languages: $e');
      return [];
    }
  }

  // --- INTERPRETER SPECIALIZATION ---
  Future<List<InterpreterSpecialization>> getInterpreterSpecializations(
    String userId,
  ) async {
    final List data = await _client
        .from('interpreter_specializations')
        .select()
        .eq('user_id', userId);
    return data.map((e) => InterpreterSpecialization.fromJson(e)).toList();
  }

  Future<void> addInterpreterSpecialization(
    InterpreterSpecialization spec,
  ) async {
    await _client
        .from('interpreter_specializations')
        .upsert(
          spec.toJson(),
          onConflict: 'user_id,specialization_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> deleteInterpreterSpecialization(
    String userId,
    int specializationId,
  ) async {
    await _client
        .from('interpreter_specializations')
        .delete()
        .eq('user_id', userId)
        .eq('specialization_id', specializationId);
  }

  // --- INTERPRETER SKILL ---
  Future<List<InterpreterSkill>> getInterpreterSkills(String userId) async {
    final List data = await _client
        .from('interpreter_skills')
        .select()
        .eq('user_id', userId);
    return data.map((e) => InterpreterSkill.fromJson(e)).toList();
  }

  Future<void> addInterpreterSkill(InterpreterSkill skill) async {
    await _client
        .from('interpreter_skills')
        .upsert(
          skill.toJson(),
          onConflict: 'user_id,skill_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> deleteInterpreterSkill(String userId, int skillId) async {
    await _client
        .from('interpreter_skills')
        .delete()
        .eq('user_id', userId)
        .eq('skill_id', skillId);
  }

  // --- LANGUAGE-SPECIFIC SKILL MAP ---
  Future<List<InterpreterLanguageSkill>> getInterpreterLanguageSkills(
    String userId,
  ) async {
    final List data = await _client
        .from('interpreter_language_skills')
        .select()
        .eq('user_id', userId);
    return data.map((e) => InterpreterLanguageSkill.fromJson(e)).toList();
  }

  Future<void> replaceInterpreterLanguageSkills(
    String userId,
    int languageId,
    Set<int> skillIds,
  ) async {
    final table = _client.from('interpreter_language_skills');
    await table.delete().eq('user_id', userId).eq('language_id', languageId);
    if (skillIds.isEmpty) return;
    final rows =
        skillIds
            .map(
              (skillId) => {
                'user_id': userId,
                'language_id': languageId,
                'skill_id': skillId,
              },
            )
            .toList();
    await table.insert(rows);
  }

  // --- INTERPRETER DETAILS ---
  Future<InterpreterDetails?> getInterpreterDetails(String userId) async {
    // Use a safe select to avoid exceptions for non-interpreters
    final List data = await _client
        .from('interpreter_details')
        .select()
        .eq('user_id', userId)
        .limit(1);
    if (data.isEmpty) return null;
    return InterpreterDetails.fromJson(data.first);
  }

  Future<void> createInterpreterDetails(InterpreterDetails details) async {
    await _client
        .from('interpreter_details')
        .upsert(
          details.toJson(),
          onConflict: 'user_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> updateInterpreterDetails(InterpreterDetails details) async {
    await _client
        .from('interpreter_details')
        .update(details.toJson())
        .eq('user_id', details.userId);
  }

  /// Update interpreter details with voice sample and certificate URLs
  /// Note: voice_sample_url may be stored in users_profile table if the column exists
  Future<void> updateInterpreterDetailsWithUrls(
    String userId, {
    String? voiceSampleUrl,
    String? certificateUrl,
    String? bio,
    int? yearsExperience,
  }) async {
    // Voice sample URL - try to store in users_profile if column exists
    // Skip silently if column doesn't exist (migration not applied)
    if (voiceSampleUrl != null) {
      try {
        await _client
            .from('users_profile')
            .update({'voice_sample_url': voiceSampleUrl})
            .eq('user_id', userId);
      } catch (e) {
        log('Skipping voice_sample_url update (column may not exist): $e');
      }
    }

    // Other interpreter details are stored in interpreter_details table
    final updateData = <String, dynamic>{};
    if (certificateUrl != null) {
      updateData['certificate_url'] = certificateUrl;
    }
    if (bio != null) {
      updateData['bio'] = bio;
    }
    if (yearsExperience != null) {
      updateData['years_experience'] = yearsExperience;
    }

    if (updateData.isNotEmpty) {
      // Use upsert in case the interpreter_details row doesn't exist yet
      updateData['user_id'] = userId;
      try {
        await _client
            .from('interpreter_details')
            .upsert(updateData, onConflict: 'user_id');
      } catch (e) {
        log('Skipping interpreter_details update: $e');
      }
    }
  }

  // --- SPECIALIZATION ---
  Future<List<Specialization>> getSpecializations() async {
    final List data = await _client.from('specializations').select();
    final specializations =
        data.map((e) => Specialization.fromJson(e)).toList();
    // Filter out "None of the above" option from the list (check multiple variations)
    return specializations.where((s) {
      final name = s.name.toLowerCase().trim();
      return name != 'none of the above' &&
          name != 'noneoftheabove' &&
          !name.contains('none of the above');
    }).toList();
  }

  // --- SKILL ---
  Future<List<Skill>> getSkills() async {
    final List data = await _client.from('skills').select();
    return data.map((e) => Skill.fromJson(e)).toList();
  }

  // --- LANGUAGE ---
  Future<List<Language>> getLanguages() async {
    // Try to get cached languages first
    final cachedLanguages = await LanguageCacheService().getCachedLanguages();
    if (cachedLanguages != null) {
      return cachedLanguages;
    }

    // If no cache or expired, fetch from database
    final List data = await _client.from('languages').select();
    final languages = data.map((e) => Language.fromJson(e)).toList();

    // Cache the fetched languages
    await LanguageCacheService().cacheLanguages(languages);

    return languages;
  }

  /// Force refresh languages by clearing cache and fetching fresh data
  Future<List<Language>> getLanguagesForceRefresh() async {
    // Clear cache first
    await LanguageCacheService().forceRefresh();

    // Fetch fresh data
    final List data = await _client.from('languages').select();
    final languages = data.map((e) => Language.fromJson(e)).toList();

    // Cache the fresh languages
    await LanguageCacheService().cacheLanguages(languages);

    return languages;
  }

  Future<void> finalizePendingRegistrationData(
    Map<String, dynamic> data,
    String userId,
  ) async {
    final role = (data['role'] as String?) ?? 'requester';
    // Avoid setting organization_admin role until organization creation succeeds.
    final roleToPersist = role == 'organization_admin' ? 'requester' : role;
    log(
      'finalizePendingRegistrationData: Starting for userId=$userId, role=$role',
    );
    log('finalizePendingRegistrationData: data=$data');

    final username = (data['username'] as String?) ?? '';
    final employmentType = (data['employmentType'] as String?) ?? 'volunteer';

    // --- Upload profile image if provided ---
    Uint8List? profileImageBytes;
    if (data['profileImageBytes'] is Uint8List) {
      profileImageBytes = data['profileImageBytes'] as Uint8List;
    } else if (data['profileImageBytesBase64'] is String) {
      try {
        profileImageBytes = base64Decode(
          data['profileImageBytesBase64'] as String,
        );
      } catch (e) {
        log('Error decoding profile image base64: $e');
      }
    }
    if (profileImageBytes != null && profileImageBytes.isNotEmpty) {
      try {
        final imageName =
            data['profileImageName'] as String? ??
            'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageUrl = await uploadProfileImage(imageName, profileImageBytes);
        data['profileImage'] = imageUrl;
        log('Profile image uploaded: $imageUrl');
      } catch (e) {
        log('Error uploading profile image during registration: $e');
      }
    }

    // Check if user profile already exists
    bool profileExists = false;
    try {
      final existingProfile =
          await _client
              .from('users_profile')
              .select('user_id')
              .eq('user_id', userId)
              .maybeSingle();

      profileExists = existingProfile != null;
      log('finalizePendingRegistrationData: Profile exists=$profileExists');
    } catch (e) {
      log('Error checking existing profile: $e');
    }

    // Create or update profile
    if (!profileExists) {
      // Profile doesn't exist - create it
      final profile = UserProfile(
        id: userId,
        role: roleToPersist,
        username: username,
        profileImage: data['profileImage'],
        gender: data['gender'],
        country: data['country'],
      );

      log(
        'finalizePendingRegistrationData: Creating profile with role=$roleToPersist, username=$username',
      );

      try {
        await createUserProfileAfterSignUp(profile);
        log('finalizePendingRegistrationData: Profile created successfully');
      } catch (e) {
        log('finalizePendingRegistrationData: Error creating profile: $e');
        // Try upsert as fallback
        try {
          await _client.from('users_profile').upsert({
            'user_id': userId,
            'username': username,
            'role': roleToPersist,
            'profile_image': data['profileImage'] ?? '',
            'gender': data['gender'] ?? '',
            'country': data['country'],
          }, onConflict: 'user_id');
          log('finalizePendingRegistrationData: Profile upserted via fallback');
        } catch (e2) {
          log(
            'finalizePendingRegistrationData: Fallback upsert also failed: $e2',
          );
          rethrow;
        }
      }
    } else {
      // Profile exists (possibly auto-created by trigger) - update it with registration data
      log('finalizePendingRegistrationData: Updating existing profile');
      try {
        await _client
            .from('users_profile')
            .update({
              'username': username,
              'role': roleToPersist,
              if (data['profileImage'] != null)
                'profile_image': data['profileImage'],
              if (data['gender'] != null) 'gender': data['gender'],
              if (data['country'] != null) 'country': data['country'],
            })
            .eq('user_id', userId);
        log('finalizePendingRegistrationData: Profile updated successfully');
      } catch (e) {
        log('finalizePendingRegistrationData: Error updating profile: $e');
      }
    }

    // Update employment_type for interpreters
    if (role == 'interpreter') {
      try {
        await _client
            .from('users_profile')
            .update({'employment_type': employmentType})
            .eq('user_id', userId);
        log(
          'finalizePendingRegistrationData: Employment type set to $employmentType',
        );
      } catch (e) {
        log(
          'finalizePendingRegistrationData: Error setting employment type: $e',
        );
      }
    }

    // Check for pending organization invitations (for requesters/doctors)
    if (role == 'requester') {
      // First check if user registered via invite code (has organizationId in data)
      final organizationId = data['organizationId'] as String?;
      final organizationRole = data['organizationRole'] as String? ?? 'doctor';
      final inviteId = data['inviteId'] as String?;

      log(
        'finalizePendingRegistrationData: Checking organization data - organizationId=$organizationId, organizationRole=$organizationRole, inviteId=$inviteId',
      );

      if (organizationId != null) {
        log(
          'finalizePendingRegistrationData: User registered with invite code for org $organizationId',
        );

        // Add user to organization_members
        try {
          await _client.from('organization_members').insert({
            'organization_id': organizationId,
            'user_id': userId,
            'role': organizationRole,
            'is_active': true,
            'spending_limit': null,
            'total_spent': 0,
          });
          log(
            'finalizePendingRegistrationData: Added user to organization_members',
          );

          // Mark invite as accepted if there's an invite ID
          if (inviteId != null) {
            await _client
                .from('organization_invites')
                .update({
                  'status': 'accepted',
                  'redeemed_by': userId,
                  'redeemed_at': DateTime.now().toIso8601String(),
                })
                .eq('id', inviteId);
            log('finalizePendingRegistrationData: Marked invite as accepted');
          }
        } catch (e) {
          log(
            'finalizePendingRegistrationData: Error adding user to organization: $e',
          );
        }
      } else {
        // Fall back to checking pending invites by email
        final user = _client.auth.currentUser;
        if (user?.email != null) {
          final didJoinOrg = await checkAndProcessPendingInvite(
            userId,
            user!.email!,
          );
          if (didJoinOrg) {
            log(
              'finalizePendingRegistrationData: User joined organization via invite',
            );
            // Update user role to indicate they're part of an organization
            await _client
                .from('users_profile')
                .update({'role': 'requester'})
                .eq('user_id', userId);
          }
        }
      }
    }

    // Handle organization_admin role - create organization and membership
    if (role == 'organization_admin') {
      // Check if organization membership already exists
      final existingMembership =
          await _client
              .from('organization_members')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

      if (existingMembership != null) {
        log(
          'finalizePendingRegistrationData: Organization membership already exists for user',
        );
        return;
      }

      log('finalizePendingRegistrationData: Creating organization for admin');
      await _createOrganizationFromRegistration(data, userId);
      // Role promotion is now handled atomically inside the RPC.
      return;
    }

    if (role != 'interpreter') {
      return;
    }

    try {
      await createInterpreterDetails(
        InterpreterDetails(
          userId: userId,
          bio: data['bio'] as String?,
          yearsExperience:
              data['yearsExperience'] is int
                  ? data['yearsExperience'] as int
                  : int.tryParse(data['yearsExperience']?.toString() ?? ''),
        ),
      );
    } catch (_) {}

    final langs = (data['languages'] as List?)?.cast<String>() ?? [];
    final fluencyRaw = data['fluency'];
    final Map<String, dynamic> fluencyMap =
        fluencyRaw is Map
            ? fluencyRaw.map((k, v) => MapEntry(k.toString(), v))
            : {};

    for (final langIdStr in langs) {
      final languageId = int.tryParse(langIdStr);
      if (languageId == null || languageId <= 0) continue;
      final fluencyName = fluencyMap[langIdStr]?.toString();
      final fluencyId = _mapFluencyNameToId(fluencyName);
      try {
        await addInterpreterLanguage(
          InterpreterLanguage(
            userId: userId,
            languageId: languageId,
            fluencyId: fluencyId,
          ),
        );
      } catch (_) {}
    }

    final skills = _parseIntList(data['skillIds'] ?? data['skills']);
    for (final skillId in skills) {
      if (skillId <= 0) continue;
      try {
        await addInterpreterSkill(
          InterpreterSkill(userId: userId, skillId: skillId),
        );
      } catch (e) {
        log('Error adding skill $skillId: $e');
      }
    }

    // Also map skills to all languages
    if (skills.isNotEmpty) {
      for (final langIdStr in langs) {
        final languageId = int.tryParse(langIdStr);
        if (languageId == null || languageId <= 0) continue;
        try {
          await replaceInterpreterLanguageSkills(
            userId,
            languageId,
            skills.toSet(),
          );
        } catch (e) {
          log('Error mapping skills to language $languageId: $e');
        }
      }
    }

    final specs = _parseIntList(
      data['specializationIds'] ?? data['specializations'],
    );

    // Get valid specialization IDs from database to filter out deleted ones
    Set<int> validSpecIds = {};
    try {
      final validSpecs = await getSpecializations();
      validSpecIds = validSpecs.map((s) => s.id).toSet();
    } catch (e) {
      log('Error fetching valid specializations: $e');
    }

    for (final specId in specs) {
      if (specId <= 0) continue;
      // Skip if specialization no longer exists in database
      if (validSpecIds.isNotEmpty && !validSpecIds.contains(specId)) {
        log('Skipping invalid specialization ID: $specId');
        continue;
      }
      try {
        await addInterpreterSpecialization(
          InterpreterSpecialization(userId: userId, specializationId: specId),
        );
      } catch (e) {
        log('Error adding specialization $specId: $e');
      }
    }

    // --- Upload voice sample from local path if not already a URL ---
    String? voiceUrl = data['voiceSampleUrl'] as String?;
    final voicePath = data['voiceSamplePath'] as String?;
    // Bytes can be Uint8List (in-memory) or base64 string (from JSON)
    Uint8List? voiceBytes;
    if (data['voiceSampleBytes'] is Uint8List) {
      voiceBytes = data['voiceSampleBytes'] as Uint8List;
    } else if (data['voiceSampleBytesBase64'] is String) {
      try {
        voiceBytes = base64Decode(data['voiceSampleBytesBase64'] as String);
      } catch (e) {
        log('Error decoding voice sample base64: $e');
      }
    }
    if (voiceUrl == null || voiceUrl.isEmpty) {
      try {
        if (voiceBytes != null && voiceBytes.isNotEmpty) {
          // Web path: use bytes directly
          final voiceName =
              data['voiceSampleName'] as String? ?? 'voice_sample.webm';
          voiceUrl = await uploadVoiceSampleFromBytes(
            voiceBytes,
            fileName: voiceName,
            prompt: data['voicePrompt'] as String?,
            sentenceType: 'onboarding',
          );
          log('Voice sample uploaded from bytes: $voiceUrl');
        } else if (!kIsWeb && voicePath != null && voicePath.isNotEmpty) {
          // Mobile path: use file
          final file = File(voicePath);
          if (await file.exists()) {
            voiceUrl = await uploadVoiceSampleFromPath(
              voicePath,
              prompt: data['voicePrompt'] as String?,
              sentenceType: 'onboarding',
            );
            log('Voice sample uploaded: $voiceUrl');
          }
        }
      } catch (e) {
        log('Error uploading voice sample: $e');
      }
    }

    // --- Upload native-language voice sample ---
    String? voiceNativeUrl;
    final voiceNativePath = data['voiceSampleNativePath'] as String?;
    Uint8List? voiceNativeBytes;
    if (data['voiceSampleNativeBytes'] is Uint8List) {
      voiceNativeBytes = data['voiceSampleNativeBytes'] as Uint8List;
    } else if (data['voiceSampleNativeBytesBase64'] is String) {
      try {
        voiceNativeBytes = base64Decode(
          data['voiceSampleNativeBytesBase64'] as String,
        );
      } catch (e) {
        log('Error decoding native voice sample base64: $e');
      }
    }
    try {
      if (voiceNativeBytes != null && voiceNativeBytes.isNotEmpty) {
        final voiceNativeName =
            data['voiceSampleNativeName'] as String? ?? 'voice_native.webm';
        voiceNativeUrl = await uploadVoiceSampleFromBytes(
          voiceNativeBytes,
          fileName: voiceNativeName,
          prompt: 'native_language_intro',
          sentenceType: 'onboarding_native',
        );
        log('Native voice sample uploaded from bytes: $voiceNativeUrl');
      } else if (!kIsWeb &&
          voiceNativePath != null &&
          voiceNativePath.isNotEmpty) {
        final file = File(voiceNativePath);
        if (await file.exists()) {
          voiceNativeUrl = await uploadVoiceSampleFromPath(
            voiceNativePath,
            prompt: 'native_language_intro',
            sentenceType: 'onboarding_native',
          );
          log('Native voice sample uploaded: $voiceNativeUrl');
        }
      }
    } catch (e) {
      log('Error uploading native voice sample: $e');
    }

    // --- Upload voice prompt verification recordings (3 random-prompt samples) ---
    final promptRecordingsList = data['voicePromptRecordings'] as List?;
    if (promptRecordingsList != null && promptRecordingsList.isNotEmpty) {
      for (final recRaw in promptRecordingsList) {
        try {
          final rec = Map<String, dynamic>.from(recRaw as Map);
          final bytesB64 = rec['bytesBase64'] as String?;
          if (bytesB64 == null || bytesB64.isEmpty) continue;
          final bytes = base64Decode(bytesB64);
          if (bytes.isEmpty) continue;
          await uploadVoiceSampleFromBytes(
            bytes,
            fileName: 'voice_prompt_${rec['prompt_id']}.webm',
            prompt: rec['prompt_text'] as String?,
            sentenceType: 'prompt_verification',
          );
          log('Voice prompt recording uploaded for prompt ${rec['prompt_id']}');
        } catch (e) {
          log('Error uploading voice prompt recording: $e');
        }
      }
    }

    // --- Upload training certificate ---
    String? certUrl = data['certificateUrl'] as String?;
    final certPath = data['certificatePath'] as String?;
    final String? certName = data['certificateName'] as String?;
    // Bytes can be Uint8List (in-memory) or base64 string (from JSON)
    Uint8List? certBytes;
    if (data['certificateBytes'] is Uint8List) {
      certBytes = data['certificateBytes'] as Uint8List;
    } else if (data['certificateBytesBase64'] is String) {
      try {
        certBytes = base64Decode(data['certificateBytesBase64'] as String);
      } catch (e) {
        log('Error decoding certificate base64: $e');
      }
    }
    if (certUrl == null || certUrl.isEmpty) {
      try {
        if (certBytes != null && certBytes.isNotEmpty) {
          // Web path: use bytes directly
          certUrl = await uploadInterpreterCertificateFromBytes(
            certBytes,
            fileName: certName ?? 'training_certificate',
            certificateType: 'training',
          );
          log('Training certificate uploaded from bytes: $certUrl');
        } else if (!kIsWeb && certPath != null && certPath.isNotEmpty) {
          // Mobile path: use file
          final file = File(certPath);
          if (await file.exists()) {
            certUrl = await uploadInterpreterCertificate(
              file,
              certificateType: 'training',
            );
            log('Training certificate uploaded: $certUrl');
          }
        }
      } catch (e) {
        log('Error uploading training certificate: $e');
      }
    }

    // --- Upload medical certificate (paid interpreters) ---
    String? medicalCertUrl = data['medicalCertificateUrl'] as String?;
    final medicalCertPath = data['medicalCertificatePath'] as String?;
    final String? medicalCertName = data['medicalCertificateName'] as String?;
    // Bytes can be Uint8List (in-memory) or base64 string (from JSON)
    Uint8List? medicalCertBytes;
    if (data['medicalCertificateBytes'] is Uint8List) {
      medicalCertBytes = data['medicalCertificateBytes'] as Uint8List;
    } else if (data['medicalCertificateBytesBase64'] is String) {
      try {
        medicalCertBytes = base64Decode(
          data['medicalCertificateBytesBase64'] as String,
        );
      } catch (e) {
        log('Error decoding medical certificate base64: $e');
      }
    }
    if (medicalCertUrl == null || medicalCertUrl.isEmpty) {
      try {
        if (medicalCertBytes != null && medicalCertBytes.isNotEmpty) {
          // Web path: use bytes directly
          medicalCertUrl = await uploadInterpreterCertificateFromBytes(
            medicalCertBytes,
            fileName: medicalCertName ?? 'medical_certificate',
            certificateType: 'medical',
          );
          log('Medical certificate uploaded from bytes: $medicalCertUrl');
        } else if (!kIsWeb &&
            medicalCertPath != null &&
            medicalCertPath.isNotEmpty) {
          // Mobile path: use file
          final file = File(medicalCertPath);
          if (await file.exists()) {
            medicalCertUrl = await uploadInterpreterCertificate(
              file,
              certificateType: 'medical',
            );
            log('Medical certificate uploaded: $medicalCertUrl');
          }
        }
      } catch (e) {
        log('Error uploading medical certificate: $e');
      }
    }

    // --- Upload government ID if provided ---
    Uint8List? govIdBytes;
    if (data['governmentIdBytes'] is Uint8List) {
      govIdBytes = data['governmentIdBytes'] as Uint8List;
    } else if (data['governmentIdBytesBase64'] is String) {
      try {
        govIdBytes = base64Decode(data['governmentIdBytesBase64'] as String);
      } catch (e) {
        log('Error decoding government ID base64: $e');
      }
    }
    if (govIdBytes != null && govIdBytes.isNotEmpty) {
      try {
        final govFileName =
            data['governmentIdFileName'] as String? ?? 'government_id.jpg';
        final govIdType = data['governmentIdType'] as String? ?? 'national_id';
        await uploadGovernmentId(
          userId: userId,
          fileBytes: govIdBytes,
          fileName: govFileName,
          idType: govIdType,
        );
        log('Government ID uploaded during registration');
      } catch (e) {
        log('Error uploading government ID during registration: $e');
      }
    }

    // --- Record phone number if provided ---
    final phoneNumber = data['phoneNumber'] as String?;
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      try {
        await recordPhoneVerification(
          userId: userId,
          phoneNumber: phoneNumber,
          verified: false,
          email: data['email'] as String?,
        );
        log('Phone number recorded during registration');
      } catch (e) {
        log('Error recording phone number during registration: $e');
      }
    }

    final years =
        data['yearsExperience'] is int
            ? data['yearsExperience'] as int
            : int.tryParse(data['yearsExperience']?.toString() ?? '');

    // Try to update interpreter details with voice sample, certificates and bio
    // This is non-critical - don't fail the whole registration if this fails
    if (voiceUrl != null ||
        certUrl != null ||
        medicalCertUrl != null ||
        data['bio'] != null ||
        years != null) {
      try {
        await updateInterpreterDetailsWithUrls(
          userId,
          voiceSampleUrl: voiceUrl,
          certificateUrl: certUrl ?? medicalCertUrl,
          bio: data['bio'] as String?,
          yearsExperience: years,
        );
      } catch (e) {
        log('Error updating interpreter details with URLs (non-critical): $e');
        // Don't rethrow - this is not critical for registration
      }
    }
  }

  int _mapFluencyNameToId(String? name) {
    final normalized =
        (name ?? '')
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ')
            .trim();

    if (normalized.isEmpty) {
      return 1;
    }

    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric >= 1 && numeric <= 4) {
      return numeric;
    }

    if (normalized.contains('native') || normalized.contains('fluent')) {
      return 4;
    }
    if (normalized.contains('upper') && normalized.contains('intermediate')) {
      return 3;
    }
    if (normalized.contains('intermediate')) {
      return 2;
    }
    if (normalized.contains('beginner')) {
      return 1;
    }

    return 1;
  }

  List<int> _parseIntList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .toList();
    }
    return <int>[];
  }

  /// Languages that currently have at least one interpreter registered
  Future<List<Language>> getSupportedInterpreterLanguages() async {
    final List data = await _client
        .from('languages')
        .select('id, name, interpreter_languages!inner(user_id)')
        .order('name');

    final seenLanguageIds = <int>{};
    final supported = <Language>[];
    for (final row in data) {
      final langId = row['id'];
      final interpreterEntries = row['interpreter_languages'];
      final hasInterpreter =
          interpreterEntries is List && interpreterEntries.isNotEmpty;
      if (langId is int && hasInterpreter && seenLanguageIds.add(langId)) {
        supported.add(Language.fromJson(row));
      }
    }
    return supported;
  }

  // --- FLUENCY LEVEL ---
  Future<List<FluencyLevel>> getFluencyLevels() async {
    final List data = await _client.from('fluency_levels').select();
    return data.map((e) => FluencyLevel.fromJson(e)).toList();
  }

  Future<void> createUserProfileWithServiceRole(UserProfile profile) async {
    try {
      // Fallback to regular method
      await createUserProfileAfterSignUp(profile);
    } catch (e) {
      throw Exception('Service role method failed: $e');
    }
  }

  // --- PROFILE IMAGE STORAGE ---

  /// Upload profile image to Supabase storage
  Future<String> uploadProfileImage(String filename, Uint8List bytes) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload to profiles bucket
      await _client.storage
          .from('profiles')
          .updateBinary(
            'profile_images/$filename',
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final publicUrl = _client.storage
          .from('profiles')
          .getPublicUrl('profile_images/$filename');

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  /// Delete profile image from Supabase storage
  Future<void> deleteProfileImage(String filename) async {
    try {
      await _client.storage.from('profiles').remove([
        'profile_images/$filename',
      ]);
    } catch (e) {
      throw Exception('Failed to delete profile image: $e');
    }
  }

  /// Get profile image URL
  String getProfileImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // If it's already a full URL, return as is
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // Otherwise, construct the full URL
    return _client.storage
        .from('profiles')
        .getPublicUrl('profile_images/$imagePath');
  }

  /// Upload the required interpreter login compliance selfie.
  Future<void> uploadInterpreterLoginCompliancePhoto(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final user = getCurrentUser();
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (bytes.isEmpty) {
      throw Exception('Compliance photo is empty');
    }

    if (bytes.length > 12 * 1024 * 1024) {
      throw Exception('Compliance photo is too large (max 12MB)');
    }

    final extCandidate = fileName.split('.').last.toLowerCase();
    final ext =
        ['jpg', 'jpeg', 'png'].contains(extCandidate) ? extCandidate : 'jpg';
    final now = DateTime.now().toUtc();
    final storagePath =
        '${user.id}/${now.millisecondsSinceEpoch}_login_compliance.$ext';

    await cleanupExpiredInterpreterLoginCompliancePhotos(userId: user.id);

    await _client.storage
        .from(_interpreterComplianceBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _getContentType(ext),
          ),
        );

    await _client.from('interpreter_login_compliance_photos').insert({
      'user_id': user.id,
      'storage_path': storagePath,
      'status': 'pending',
      'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
    });
  }

  /// Deletes compliance photos after their retention period (7 days).
  Future<void> cleanupExpiredInterpreterLoginCompliancePhotos({
    required String userId,
  }) async {
    final rows = await _client
        .from('interpreter_login_compliance_photos')
        .select('id, storage_path')
        .eq('user_id', userId)
        .lt('expires_at', DateTime.now().toUtc().toIso8601String());

    final expiredRows = (rows as List).cast<Map<String, dynamic>>();
    if (expiredRows.isEmpty) {
      return;
    }

    final paths =
        expiredRows
            .map((row) => row['storage_path'] as String?)
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList();

    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(_interpreterComplianceBucket).remove(paths);
      } catch (e) {
        log(
          'cleanupExpiredInterpreterLoginCompliancePhotos: remove failed: $e',
        );
      }
    }

    final rowIds =
        expiredRows
            .map((row) => row['id'] as String?)
            .whereType<String>()
            .toList();

    if (rowIds.isNotEmpty) {
      await _client
          .from('interpreter_login_compliance_photos')
          .delete()
          .inFilter('id', rowIds);
    }
  }

  /// Upload a voice sample file to Supabase storage and return its public URL
  Future<String> uploadVoiceSampleFromPath(
    String absoluteFilePath, {
    String? prompt,
    String? sentenceType,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final file = File(absoluteFilePath);
      if (!await file.exists()) {
        throw Exception('Voice sample file not found');
      }

      // Validate file size (max 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Voice sample file is too large (max 10MB)');
      }

      final bytes = await file.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dateStr = DateTime.now().toIso8601String().split('T')[0];

      // Create a more descriptive filename
      final sentenceTypeStr = sentenceType ?? 'professional_sentence';
      final sanitized = (prompt ?? 'sample').replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-]'),
        '_',
      );
      final safePrompt =
          sanitized.length > 50 ? sanitized.substring(0, 50) : sanitized;

      final objectPath =
          'voice_samples/${user.id}/${dateStr}_${sentenceTypeStr}_${safePrompt}_$timestamp.m4a';

      await _client.storage
          .from('voice_samples')
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'audio/mp4',
            ),
          );

      final publicUrl = _client.storage
          .from('voice_samples')
          .getPublicUrl(objectPath);

      // Store metadata in database
      await _storeVoiceSampleMetadata(
        userId: user.id,
        url: publicUrl,
        prompt: prompt,
        sentenceType: sentenceType ?? 'professional_sentence',
        fileSize: fileSize,
        timestamp: DateTime.now(),
      );

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload voice sample: $e');
    }
  }

  /// Store voice sample metadata in the database
  Future<void> _storeVoiceSampleMetadata({
    required String userId,
    required String url,
    required String? prompt,
    required String sentenceType,
    required int fileSize,
    required DateTime timestamp,
  }) async {
    try {
      await _client.from('voice_samples').insert({
        'user_id': userId,
        'url': url,
        'prompt': prompt,
        'sentence_type': sentenceType,
        'file_size': fileSize,
        'created_at': timestamp.toIso8601String(),
        'is_verified': false, // Will be verified by admin
      });
    } catch (e) {
      // Log error but don't fail the upload
      log('Failed to store voice sample metadata: $e');
    }
  }

  /// Upload a voice sample from raw bytes (web-compatible)
  Future<String> uploadVoiceSampleFromBytes(
    Uint8List bytes, {
    String? fileName,
    String? prompt,
    String? sentenceType,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (bytes.isEmpty) {
        throw Exception('Voice sample data is empty');
      }

      // Validate file size (max 10MB)
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('Voice sample file is too large (max 10MB)');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final sentenceTypeStr = sentenceType ?? 'onboarding';
      final sanitized = (prompt ?? 'sample').replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-]'),
        '_',
      );
      final safePrompt =
          sanitized.length > 50 ? sanitized.substring(0, 50) : sanitized;
      final ext = fileName?.split('.').last ?? 'webm';

      final objectPath =
          'voice_samples/${user.id}/${dateStr}_${sentenceTypeStr}_${safePrompt}_$timestamp.$ext';

      await _client.storage
          .from('voice_samples')
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: ext == 'webm' ? 'audio/webm' : 'audio/mp4',
            ),
          );

      final publicUrl = _client.storage
          .from('voice_samples')
          .getPublicUrl(objectPath);

      // Store metadata in database
      await _storeVoiceSampleMetadata(
        userId: user.id,
        url: publicUrl,
        prompt: prompt,
        sentenceType: sentenceTypeStr,
        fileSize: bytes.length,
        timestamp: DateTime.now(),
      );

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload voice sample from bytes: $e');
    }
  }

  /// Upload an interpreter certificate file to a PRIVATE bucket and return a signed URL
  Future<String> uploadInterpreterCertificate(
    File certificateFile, {
    String? certificateType,
    String? issuingOrganization,
    DateTime? expirationDate,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (!await certificateFile.exists()) {
        throw Exception('Certificate file not found');
      }

      // Validate file size (max 25MB for certificates)
      final fileSize = await certificateFile.length();
      if (fileSize > 25 * 1024 * 1024) {
        throw Exception('Certificate file is too large (max 25MB)');
      }

      // Validate file extension
      final extension = certificateFile.path.split('.').last.toLowerCase();
      if (!['pdf', 'jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception(
          'Invalid file type. Only PDF, JPG, JPEG, and PNG files are allowed.',
        );
      }

      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final originalName = certificateFile.path.split('/').last;
      final safeName = originalName.replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-.]'),
        '_',
      );

      final certType = certificateType ?? 'medical_interpreter';
      final objectPath =
          'certificates/${user.id}/${dateStr}_${certType}_$safeName';

      // Upload to the interpreter_certificates bucket
      const bucket = 'interpreter_certificates';
      await _client.storage
          .from(bucket)
          .uploadBinary(
            objectPath,
            await certificateFile.readAsBytes(),
            fileOptions: FileOptions(
              upsert: true,
              contentType: _getContentType(extension),
            ),
          );

      // Generate a signed URL (valid for 7 days)
      final signedUrl = await _client.storage
          .from(bucket)
          .createSignedUrl(objectPath, 60 * 60 * 24 * 7);

      // Store certificate metadata in database
      await _storeCertificateMetadata(
        userId: user.id,
        url: signedUrl,
        storagePath: objectPath,
        certificateType: certType,
        issuingOrganization: issuingOrganization,
        expirationDate: expirationDate,
        fileSize: fileSize,
        fileName: originalName,
        timestamp: DateTime.now(),
      );

      return signedUrl;
    } catch (e) {
      throw Exception('Failed to upload interpreter certificate: $e');
    }
  }

  /// Upload an interpreter certificate from bytes (web-compatible) to a PRIVATE bucket
  Future<String> uploadInterpreterCertificateFromBytes(
    Uint8List bytes, {
    required String fileName,
    String? certificateType,
    String? issuingOrganization,
    DateTime? expirationDate,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (bytes.isEmpty) {
        throw Exception('Certificate file is empty');
      }

      // Validate file size (max 25MB for certificates)
      if (bytes.length > 25 * 1024 * 1024) {
        throw Exception('Certificate file is too large (max 25MB)');
      }

      // Validate file extension
      final extension = fileName.split('.').last.toLowerCase();
      if (!['pdf', 'jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception(
          'Invalid file type. Only PDF, JPG, JPEG, and PNG files are allowed.',
        );
      }

      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');

      final certType = certificateType ?? 'medical_interpreter';
      final objectPath =
          'certificates/${user.id}/${dateStr}_${certType}_$safeName';

      const bucket = 'interpreter_certificates';
      await _client.storage
          .from(bucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _getContentType(extension),
            ),
          );

      // Generate a signed URL (valid for 7 days)
      final signedUrl = await _client.storage
          .from(bucket)
          .createSignedUrl(objectPath, 60 * 60 * 24 * 7);

      // Store certificate metadata in database
      await _storeCertificateMetadata(
        userId: user.id,
        url: signedUrl,
        storagePath: objectPath,
        certificateType: certType,
        issuingOrganization: issuingOrganization,
        expirationDate: expirationDate,
        fileSize: bytes.length,
        fileName: fileName,
        timestamp: DateTime.now(),
      );

      return signedUrl;
    } catch (e) {
      throw Exception(
        'Failed to upload interpreter certificate from bytes: $e',
      );
    }
  }

  /// Get content type based on file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  /// Store certificate metadata in the database
  Future<void> _storeCertificateMetadata({
    required String userId,
    required String url,
    required String storagePath,
    required String certificateType,
    required String? issuingOrganization,
    required DateTime? expirationDate,
    required int fileSize,
    required String fileName,
    required DateTime timestamp,
  }) async {
    try {
      await _client.from('interpreter_certificates').insert({
        'user_id': userId,
        'url': url,
        'storage_path': storagePath,
        'certificate_type': certificateType,
        'issuing_organization': issuingOrganization,
        'expiration_date': expirationDate?.toIso8601String(),
        'file_size': fileSize,
        'file_name': fileName,
        'uploaded_at': timestamp.toIso8601String(),
        'is_verified': false, // Will be verified by admin
        'status': 'pending', // pending, verified, rejected
      });
    } catch (e) {
      // Log error but don't fail the upload
      log('Failed to store certificate metadata: $e');
    }
  }

  // --- QUIZ ---
  Future<List<Map<String, dynamic>>> getQuizQuestions({
    required String quizType,
    String? medicalSection,
  }) async {
    log(
      'getQuizQuestions called with quizType: $quizType, medicalSection: $medicalSection',
    );

    var query = _client
        .from('quiz_questions')
        .select()
        .eq('quiz_type', quizType)
        .eq('is_active', true);

    if (medicalSection != null) {
      query = query.eq('medical_section', medicalSection);
    }

    final List data = await query;
    log('getQuizQuestions returned ${data.length} questions');
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> submitQuizAttempt(Map<String, dynamic> attempt) async {
    log('submitQuizAttempt called with: $attempt');
    try {
      // Ensure taken_at is set
      attempt['taken_at'] = DateTime.now().toUtc().toIso8601String();

      // Insert a new row. The unique constraint was dropped so that
      // users can retry after 30 days — each attempt is stored.
      await _client.from('quiz_attempts').insert(attempt);

      log('Quiz attempt submitted successfully');
    } catch (e, stackTrace) {
      log('Error submitting quiz attempt: $e');
      log('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> awardBadge({
    required String userId,
    required String badge,
    required int score,
  }) async {
    log('awardBadge called: userId=$userId, badge=$badge, score=$score');
    try {
      // Check if badge already exists
      final existing =
          await _client
              .from('interpreter_badges')
              .select()
              .eq('user_id', userId)
              .eq('badge', badge)
              .maybeSingle();

      log('Existing badge check result: $existing');

      if (existing != null) {
        // Update if new score is higher
        final existingScore = existing['score'];
        final existingScoreNum =
            existingScore is num ? existingScore.toDouble() : 0.0;
        if (score > existingScoreNum) {
          log('Updating existing badge with higher score');
          await _client
              .from('interpreter_badges')
              .update({
                'score': score,
                'earned_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId)
              .eq('badge', badge);
        } else {
          log('Existing badge has higher or equal score, not updating');
        }
      } else {
        // Insert new badge
        log('Inserting new badge');
        await _client.from('interpreter_badges').insert({
          'user_id': userId,
          'badge': badge,
          'score': score,
        });
        log('Badge inserted successfully');
      }
    } catch (e, stackTrace) {
      log('Error in awardBadge: $e');
      log('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    final List data = await _client
        .from('interpreter_badges')
        .select()
        .eq('user_id', userId);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getQuizAttempts(String userId) async {
    final List data = await _client
        .from('quiz_attempts')
        .select()
        .eq('user_id', userId)
        .order('taken_at', ascending: false);
    return data.cast<Map<String, dynamic>>();
  }

  // ── Voice prompts ─────────────────────────────────────────────

  /// Fetch [count] random voice prompts from the voice_prompts table.
  Future<List<Map<String, dynamic>>> getRandomVoicePrompts({
    int count = 3,
  }) async {
    log('getRandomVoicePrompts called (count=$count)');
    // Fetch all active prompts and pick random subset client-side
    final List data = await _client
        .from('voice_prompts')
        .select()
        .eq('is_active', true);

    final prompts = data.cast<Map<String, dynamic>>();
    prompts.shuffle();
    final result = prompts.take(count).toList();
    log('getRandomVoicePrompts returning ${result.length} prompts');
    return result;
  }

  // ── Government ID ─────────────────────────────────────────────

  /// Upload government ID image to storage and record metadata in government_ids.
  Future<String?> uploadGovernmentId({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
    String idType = 'national_id',
  }) async {
    log('uploadGovernmentId: userId=$userId, fileName=$fileName');
    try {
      final ext = fileName.split('.').last;
      final path =
          '$userId/gov_id_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _client.storage
          .from('government-ids')
          .uploadBinary(
            path,
            Uint8List.fromList(fileBytes),
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _client.storage
          .from('government-ids')
          .getPublicUrl(path);

      // Insert metadata row
      await _client.from('government_ids').insert({
        'user_id': userId,
        'file_url': publicUrl,
        'file_name': fileName,
        'status': 'pending',
      });

      // Update users_profile
      await _client
          .from('users_profile')
          .update({
            'government_id_url': publicUrl,
            'government_id_status': 'pending',
          })
          .eq('user_id', userId);

      log('Government ID uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      log('Error uploading government ID: $e');
      return null;
    }
  }

  // ── Phone verification helpers ─────────────────────────────────

  /// Record a phone verification result in the phone_verifications table.
  Future<void> recordPhoneVerification({
    required String userId,
    required String phoneNumber,
    required bool verified,
    String? email,
  }) async {
    log('recordPhoneVerification: userId=$userId, phone=$phoneNumber');
    try {
      await _client.from('phone_verifications').insert({
        'user_id': userId,
        'phone_number': phoneNumber,
        'verified': verified,
        if (verified) 'verified_at': DateTime.now().toUtc().toIso8601String(),
        if (email != null) 'email': email,
      });

      // Also update users_profile
      await _client
          .from('users_profile')
          .update({'phone_number': phoneNumber, 'phone_verified': verified})
          .eq('user_id', userId);

      log('Phone verification recorded successfully');
    } catch (e) {
      log('Error recording phone verification: $e');
    }
  }

  /// Creates an organization and adds the user as organization_admin
  /// Uses an atomic RPC so org + member + role promotion happen in one transaction.
  Future<void> _createOrganizationFromRegistration(
    Map<String, dynamic> data,
    String userId,
  ) async {
    log('_createOrganizationFromRegistration: Starting for userId=$userId');

    final orgName = data['organizationName'] as String? ?? '';
    final orgEmail =
        (data['organizationEmail'] as String? ?? '').trim().toLowerCase();
    final orgPhone = data['organizationPhone'] as String?;
    final orgAddress = data['organizationAddress'] as String?;

    log(
      '_createOrganizationFromRegistration: orgName=$orgName, orgEmail=$orgEmail',
    );

    if (orgName.isEmpty || orgEmail.isEmpty) {
      log(
        '_createOrganizationFromRegistration: Organization name or email is empty, skipping organization creation. orgName="$orgName", orgEmail="$orgEmail"',
      );
      return;
    }

    try {
      final inviteCode = _generateInviteCode();
      log(
        '_createOrganizationFromRegistration: Generated invite code: $inviteCode',
      );

      // Atomic RPC: creates org, member, and promotes role in one transaction.
      final orgId = await _client.rpc(
        'create_organization_with_admin',
        params: {
          'p_org_name': orgName,
          'p_org_email': orgEmail,
          'p_org_phone': orgPhone,
          'p_org_address': orgAddress,
          'p_invite_code': inviteCode,
        },
      );

      log('Organization created successfully: $orgId');
    } catch (e) {
      log('Error creating organization: $e');
      rethrow;
    }
  }

  /// Uploads organization verification documents to Supabase storage
  Future<void> _uploadOrganizationDocuments({
    required String orgId,
    required String userId,
    String? businessLicensePath,
    String? registrationCertificatePath,
    String? additionalDocumentPath,
  }) async {
    final documents = <Map<String, String?>>[];

    if (businessLicensePath != null && businessLicensePath.isNotEmpty) {
      documents.add({'path': businessLicensePath, 'type': 'business_license'});
    }

    if (registrationCertificatePath != null &&
        registrationCertificatePath.isNotEmpty) {
      documents.add({
        'path': registrationCertificatePath,
        'type': 'registration_certificate',
      });
    }

    if (additionalDocumentPath != null && additionalDocumentPath.isNotEmpty) {
      documents.add({'path': additionalDocumentPath, 'type': 'additional'});
    }

    for (final doc in documents) {
      try {
        final localPath = doc['path']!;
        final docType = doc['type']!;
        final file = File(localPath);

        if (!await file.exists()) {
          log('Document file does not exist: $localPath');
          continue;
        }

        final fileName = localPath.split(Platform.pathSeparator).last;
        final storagePath = 'organization_documents/$orgId/$docType/$fileName';
        final fileBytes = await file.readAsBytes();

        // Upload to Supabase storage
        await _client.storage
            .from('documents')
            .uploadBinary(storagePath, fileBytes);

        // Record in organization_documents table
        await _client.from('organization_documents').insert({
          'organization_id': orgId,
          'document_type': docType,
          'storage_path': storagePath,
          'file_name': fileName,
          'file_size': fileBytes.length,
          'uploaded_by': userId,
        });

        log('Uploaded $docType document: $storagePath');
      } catch (e) {
        log('Error uploading document ${doc['type']}: $e');
        // Continue with other documents even if one fails
      }
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = StringBuffer();
    for (var i = 0; i < 8; i++) {
      code.write(chars[(random + i * 7) % chars.length]);
    }
    return code.toString();
  }

  // --- ORGANIZATION INVITATION METHODS ---

  /// Validate an invite code and return organization details if valid
  Future<Map<String, dynamic>?> validateInviteCode(String inviteCode) async {
    try {
      // Use the secure database function to look up invites by code
      // This bypasses RLS restrictions so anyone with a valid code can find it
      final response = await _client.rpc(
        'lookup_invite_by_code',
        params: {'p_invite_code': inviteCode.toUpperCase()},
      );

      log('validateInviteCode response: $response');

      // Handle both List and Map responses
      Map<String, dynamic>? result;
      if (response is List && response.isNotEmpty) {
        result = response.first as Map<String, dynamic>;
      } else if (response is Map<String, dynamic> && response.isNotEmpty) {
        result = response;
      }

      if (result != null && result['organization_id'] != null) {
        final inviteType = result['invite_type'] as String;
        return {
          'type': inviteType == 'personal_invite' ? 'personal' : 'general',
          'organization': {
            'id': result['organization_id'],
            'name': result['organization_name'],
            'email': result['organization_email'],
          },
          'organization_id': result['organization_id'],
          'role': result['role'] ?? 'doctor',
          'invite_id': result['invite_id'],
        };
      }

      return null; // Invalid code
    } catch (e) {
      log('Error validating invite code: $e');
      return null;
    }
  }

  /// Register a new doctor user and join them to an organization
  Future<AuthResponse> signUpDoctorWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String organizationId,
    required String role,
    String? inviteId,
  }) async {
    // First, sign up the user
    final authResponse = await signUp(
      email: email,
      password: password,
      portalHint: 'organization',
      data: {'role': 'requester', 'username': fullName},
    );

    if (authResponse.user != null) {
      final userId = authResponse.user!.id;

      // Create user profile as 'requester' (doctor role in the app)
      // Set both username and full_name so profile displays correctly
      await _client.from('users_profile').insert({
        'user_id': userId,
        'username': fullName,
        'full_name': fullName,
        'role': 'requester',
        'email': email.toLowerCase(),
      });

      // Add to organization_members
      await _client.from('organization_members').insert({
        'organization_id': organizationId,
        'user_id': userId,
        'role': role,
        'is_active': true,
        'spending_limit': null,
        'total_spent': 0,
      });

      // If personal invite, mark as accepted
      if (inviteId != null) {
        await _client
            .from('organization_invites')
            .update({
              'status': 'accepted',
              'redeemed_by': userId,
              'redeemed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', inviteId);
      }

      log('Doctor registered and joined organization: $organizationId');
    }

    return authResponse;
  }

  /// Check if an email has a pending organization invitation
  Future<Map<String, dynamic>?> getPendingInviteByEmail(String email) async {
    try {
      final response =
          await _client
              .from('organization_invites')
              .select('*, organizations(id, name)')
              .eq('email', email.toLowerCase())
              .eq('status', 'pending')
              .gt('expires_at', DateTime.now().toIso8601String())
              .maybeSingle();
      return response;
    } catch (e) {
      log('Error checking pending invite: $e');
      return null;
    }
  }

  /// Accept an organization invitation and add user as member
  Future<bool> acceptOrganizationInvite({
    required String inviteId,
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    try {
      // Update invite status to accepted
      await _client
          .from('organization_invites')
          .update({
            'status': 'accepted',
            'redeemed_by': userId,
            'redeemed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', inviteId);

      // Add user to organization_members
      await _client.from('organization_members').insert({
        'organization_id': organizationId,
        'user_id': userId,
        'role': role,
        'is_active': true,
        'spending_limit': null,
        'total_spent': 0,
      });

      log(
        'Organization invite accepted: user $userId joined org $organizationId',
      );
      return true;
    } catch (e) {
      log('Error accepting organization invite: $e');
      return false;
    }
  }

  /// Check and process pending invite after user registration/login
  Future<bool> checkAndProcessPendingInvite(String userId, String email) async {
    try {
      final invite = await getPendingInviteByEmail(email);
      if (invite == null) return false;

      final inviteId = invite['id'] as String;
      final orgId = invite['organization_id'] as String;
      final role = invite['role'] as String? ?? 'doctor';

      return await acceptOrganizationInvite(
        inviteId: inviteId,
        organizationId: orgId,
        userId: userId,
        role: role,
      );
    } catch (e) {
      log('Error processing pending invite: $e');
      return false;
    }
  }
}
