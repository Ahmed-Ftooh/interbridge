import 'dart:developer';
import 'dart:typed_data';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
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
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // --- AUTH ---
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: kAuthCallbackUrl,
    );
  }

  Future<void> sendEmailOtp(String email) async {
    // Send magic link for verification
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  Future<void> sendMagicLink(String email) async {
    // Send magic link for verification
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo:
          const String.fromEnvironment('SUPABASE_RESET_REDIRECT') != ''
              ? const String.fromEnvironment('SUPABASE_RESET_REDIRECT')
              : null,
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
            .single();
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
    try {
      // Check if user is authenticated
      final user = _client.auth.currentUser;

      // Ensure the profile user_id matches the authenticated user
      if (user != null && profile.id != user.id) {
        throw Exception('Profile user_id must match authenticated user');
      }

      // Create the data map explicitly to match table structure
      final data = {
        'user_id': profile.id,
        'username': profile.username ?? '',
        'role': profile.role ?? '',
        'profile_image': profile.profileImage ?? '',
        'gender': profile.gender ?? '',
        // created_at will be set automatically by the database
      };

      // Ensure we're using the authenticated user's context
      if (user == null) {
        throw Exception('User must be authenticated to create profile');
      }

      await _client.from('users_profile').insert(data);
    } catch (e) {
      // Try alternative approach with explicit error handling
      try {
        final fallbackData = {
          'user_id': profile.id,
          'username': profile.username ?? '',
          'role': profile.role ?? '',
          'profile_image': profile.profileImage ?? '',
          'gender': profile.gender ?? '',
        };

        await _client.from('users_profile').insert(fallbackData);
      } catch (e2) {
        throw Exception('Failed to create user profile: $e2');
      }
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _client
        .from('users_profile')
        .update(profile.toJson())
        .eq('user_id', profile.id);
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
    await _client.from('interpreter_languages').insert(lang.toJson());
  }

  Future<void> deleteInterpreterLanguage(String userId, int languageId) async {
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
    await _client.from('interpreter_specializations').insert(spec.toJson());
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
    await _client.from('interpreter_skills').insert(skill.toJson());
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
    await _client.from('interpreter_details').insert(details.toJson());
  }

  Future<void> updateInterpreterDetails(InterpreterDetails details) async {
    await _client
        .from('interpreter_details')
        .update(details.toJson())
        .eq('user_id', details.userId);
  }

  /// Update interpreter details with voice sample and certificate URLs
  Future<void> updateInterpreterDetailsWithUrls(
    String userId, {
    String? voiceSampleUrl,
    String? certificateUrl,
    String? bio,
    int? yearsExperience,
  }) async {
    final updateData = <String, dynamic>{};
    if (voiceSampleUrl != null) {
      updateData['voice_sample_url'] = voiceSampleUrl;
    }
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
      await _client
          .from('interpreter_details')
          .update(updateData)
          .eq('user_id', userId);
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
    final username = (data['username'] as String?) ?? '';
    final profile = UserProfile(
      id: userId,
      role: role,
      username: username,
      profileImage: data['profileImage'],
      gender: data['gender'],
    );

    try {
      await createUserProfileAfterSignUp(profile);
    } catch (_) {}

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
    for (final specId in specs) {
      if (specId <= 0) continue;
      try {
        await addInterpreterSpecialization(
          InterpreterSpecialization(userId: userId, specializationId: specId),
        );
      } catch (e) {
        log('Error adding specialization $specId: $e');
      }
    }

    final voiceUrl = data['voiceSampleUrl'] as String?;
    String? certUrl = data['certificateUrl'] as String?;
    final certPath = data['certificatePath'] as String?;
    if ((certUrl == null || certUrl.isEmpty) &&
        certPath != null &&
        certPath.isNotEmpty) {
      try {
        final file = File(certPath);
        if (await file.exists()) {
          certUrl = await uploadInterpreterCertificate(
            file,
            certificateType: 'onboarding',
          );
        }
      } catch (_) {}
    }

    final years =
        data['yearsExperience'] is int
            ? data['yearsExperience'] as int
            : int.tryParse(data['yearsExperience']?.toString() ?? '');

    if (voiceUrl != null ||
        certUrl != null ||
        data['bio'] != null ||
        years != null) {
      await updateInterpreterDetailsWithUrls(
        userId,
        voiceSampleUrl: voiceUrl,
        // Don't pass certificateUrl - it's already stored in interpreter_certificates table
        bio: data['bio'] as String?,
        yearsExperience: years,
      );
    }
  }

  int _mapFluencyNameToId(String? name) {
    switch (name) {
      case 'Beginner':
        return 1;
      case 'Intermediate':
        return 2;
      case 'Upper Intermediate':
        return 3;
      case 'Native Or Fluent':
        return 4;
      default:
        return 1;
    }
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
      final safePrompt = (prompt ?? 'sample')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
          .substring(0, 50); // Limit length

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

      // Upload to a private onboarding bucket
      // NOTE: Ensure a private bucket named 'onboarding' exists with appropriate RLS.
      const bucket = 'onboarding';
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
}
