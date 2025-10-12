import 'dart:developer';
import 'dart:typed_data';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/interpreter_language.dart';
import '../models/interpreter_specialization.dart';
import '../models/interpreter_skill.dart';
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
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<void> sendEmailOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        // You can specify a redirect URL after verification (optional
        shouldCreateUser: true, // creates a new user if not registered
      );
      print('OTP sent to $email');
    } catch (e) {
      print('Error sending OTP: $e');
    }
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

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      token: token,
      type: OtpType.signup,
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
      log('DEBUG: Creating user profile for user ID: ${profile.id}');
      log('DEBUG: Profile data: ${profile.toJson()}');

      // Check if user is authenticated
      final user = _client.auth.currentUser;
      log('DEBUG: Current authenticated user: ${user?.id}');

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

      log('DEBUG: Inserting data: $data');

      // Ensure we're using the authenticated user's context
      if (user == null) {
        throw Exception('User must be authenticated to create profile');
      }

      final response = await _client.from('users_profile').insert(data);
      log('DEBUG: Profile creation successful: $response');
    } catch (e) {
      log('DEBUG: Error in createUserProfileAfterSignUp: $e');

      // Try alternative approach with explicit error handling
      try {
        log('DEBUG: Attempting fallback profile creation method');
        final fallbackData = {
          'user_id': profile.id,
          'username': profile.username ?? '',
          'role': profile.role ?? '',
          'profile_image': profile.profileImage ?? '',
          'gender': profile.gender ?? '',
        };

        log('DEBUG: Fallback data: $fallbackData');
        await _client.from('users_profile').insert(fallbackData);
        log('DEBUG: Fallback profile creation successful');
      } catch (e2) {
        log('DEBUG: Fallback profile creation also failed: $e2');
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

  // --- INTERPRETER DETAILS ---
  Future<InterpreterDetails?> getInterpreterDetails(String userId) async {
    final response =
        await _client
            .from('interpreter_details')
            .select()
            .eq('user_id', userId)
            .single();
    return InterpreterDetails.fromJson(response);
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
  }) async {
    final updateData = <String, dynamic>{};
    if (voiceSampleUrl != null) {
      updateData['voice_sample_url'] = voiceSampleUrl;
    }
    if (certificateUrl != null) {
      updateData['certificate_url'] = certificateUrl;
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
    return data.map((e) => Specialization.fromJson(e)).toList();
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

  /// Upload an interpreter certificate file and return its public URL
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

      await _client.storage
          .from('documents')
          .uploadBinary(
            objectPath,
            await certificateFile.readAsBytes(),
            fileOptions: FileOptions(
              upsert: true,
              contentType: _getContentType(extension),
            ),
          );

      final publicUrl = _client.storage
          .from('documents')
          .getPublicUrl(objectPath);

      // Store certificate metadata in database
      await _storeCertificateMetadata(
        userId: user.id,
        url: publicUrl,
        certificateType: certType,
        issuingOrganization: issuingOrganization,
        expirationDate: expirationDate,
        fileSize: fileSize,
        fileName: originalName,
        timestamp: DateTime.now(),
      );

      return publicUrl;
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
