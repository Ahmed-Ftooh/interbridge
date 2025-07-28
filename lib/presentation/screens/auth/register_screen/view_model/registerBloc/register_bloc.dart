import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'register_event.dart';
import 'register_state.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/models/interpreter_details.dart';
import 'package:interbridge/data/models/interpreter_language.dart';
import 'package:interbridge/data/models/interpreter_skill.dart';
import 'package:interbridge/data/models/interpreter_specialization.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:get_it/get_it.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final SupabaseService supabase = GetIt.I<SupabaseService>();

  RegisterBloc() : super(RegisterInitial()) {
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<RequesterRegisterSubmitted>(_onRequesterRegisterSubmitted);
  }

  Future<void> _onRequesterRegisterSubmitted(
    RequesterRegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    emit(RegisterLoading());
    try {
      // Validate input fields
      final emailError = ErrorHandler.handleValidationError(
        'email',
        event.email,
      );
      if (emailError != null) {
        emit(RegisterFailure(emailError.message));
        return;
      }

      final passwordError = ErrorHandler.handleValidationError(
        'password',
        event.password,
      );
      if (passwordError != null) {
        emit(RegisterFailure(passwordError.message));
        return;
      }

      final usernameError = ErrorHandler.handleValidationError(
        'username',
        event.username,
      );
      if (usernameError != null) {
        emit(RegisterFailure(usernameError.message));
        return;
      }

      // Sign up the user
      final authResponse = await supabase.signUp(
        email: event.email,
        password: event.password,
      );
      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Registration failed');

      // Wait a moment for the auth context to be established
      await Future.delayed(const Duration(milliseconds: 500));

      // Create a basic user profile for requester
      final profile = UserProfile(
        id: userId,
        role: 'requester', // Explicitly set role to requester
        username: event.username,
        profileImage: '',
        gender: '', // Empty for requesters
      );

      // Try the new method first, fallback to original if it fails
      try {
        await supabase.createUserProfileAfterSignUp(profile);
      } catch (e) {
        // Fallback to original method
        await supabase.createUserProfile(profile);
      }

      emit(RegisterSuccess());
    } catch (e) {
      final appError = ErrorHandler.handleAuthError(e);
      emit(RegisterFailure(appError.message));
    }
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    emit(RegisterLoading());
    try {
      // Validate input fields
      final emailError = ErrorHandler.handleValidationError(
        'email',
        event.email,
      );
      if (emailError != null) {
        emit(RegisterFailure(emailError.message));
        return;
      }

      final passwordError = ErrorHandler.handleValidationError(
        'password',
        event.password,
      );
      if (passwordError != null) {
        emit(RegisterFailure(passwordError.message));
        return;
      }

      final usernameError = ErrorHandler.handleValidationError(
        'username',
        event.username,
      );
      if (usernameError != null) {
        emit(RegisterFailure(usernameError.message));
        return;
      }

      final authResponse = await supabase.signUp(
        email: event.email,
        password: event.password,
      );
      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Registration failed');

      // Wait a moment for the auth context to be established
      await Future.delayed(const Duration(milliseconds: 500));

      final profile = UserProfile(
        id: userId,
        role: event.role, // Use the role from the event
        username: event.username,
        profileImage: null,
        gender: event.gender,
      );

      // Try the new method first, fallback to original if it fails
      try {
        await supabase.createUserProfileAfterSignUp(profile);
      } catch (e) {
        // Fallback to original method
        await supabase.createUserProfile(profile);
      }

      await supabase.createInterpreterDetails(
        InterpreterDetails(userId: userId),
      );

      // Add languages with error handling
      for (final langId in event.languages) {
        try {
          final fluencyLevelName = event.fluency[langId];
          final fluencyId =
              fluencyLevelName != null
                  ? _getFluencyLevelId(fluencyLevelName)
                  : 1; // Default to Beginner (ID 1)

          await supabase.addInterpreterLanguage(
            InterpreterLanguage(
              userId: userId,
              languageId: int.tryParse(langId) ?? 0,
              fluencyId: fluencyId,
            ),
          );
        } catch (e) {
          log('DEBUG: Error adding language $langId: $e');
        }
      }

      // Add skills with error handling
      for (final skillId in event.skillIds) {
        try {
          await supabase.addInterpreterSkill(
            InterpreterSkill(userId: userId, skillId: skillId),
          );
        } catch (e) {
          log('DEBUG: Error adding skill $skillId: $e');
        }
      }

      // Add specializations with error handling
      for (final specId in event.specializationIds) {
        try {
          await supabase.addInterpreterSpecialization(
            InterpreterSpecialization(userId: userId, specializationId: specId),
          );
        } catch (e) {
          log('DEBUG: Error adding specialization $specId: $e');
        }
      }

      emit(RegisterSuccess());
    } catch (e) {
      final appError = ErrorHandler.handleAuthError(e);
      emit(RegisterFailure(appError.message));
    }
  }

  // Helper method to convert fluency level names to database IDs
  int _getFluencyLevelId(String fluencyLevelName) {
    final Map<String, int> fluencyLevelMap = {
      'Beginner': 1,
      'Intermediate': 2,
      'Upper Intermediate': 3,
      'Native Or Fluent': 4,
    };

    return fluencyLevelMap[fluencyLevelName] ?? 1; // Default to Beginner (ID 1)
  }
}
