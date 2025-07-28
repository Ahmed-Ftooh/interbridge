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

      emailRedirectTo: 'http://localhost:3000',
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
    // This bypasses RLS by using the service role or by ensuring proper auth context
    try {
      await _client.from('users_profile').insert(profile.toJson());
    } catch (e) {
      // If RLS fails, try with service role or disable RLS temporarily
      throw Exception('Failed to create user profile: $e');
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
    final List data = await _client.from('languages').select();
    return data.map((e) => Language.fromJson(e)).toList();
  }

  // --- FLUENCY LEVEL ---
  Future<List<FluencyLevel>> getFluencyLevels() async {
    final List data = await _client.from('fluency_levels').select();
    return data.map((e) => FluencyLevel.fromJson(e)).toList();
  }
}
