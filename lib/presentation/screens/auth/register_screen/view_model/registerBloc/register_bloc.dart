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
import 'package:interbridge/presentation/resources/strings_manager.dart';
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
        log(
          'DEBUG: Attempting to create user profile with createUserProfileAfterSignUp',
        );
        await supabase.createUserProfileAfterSignUp(profile);
        log('DEBUG: User profile created successfully');
      } catch (e) {
        log('DEBUG: createUserProfileAfterSignUp failed: $e');
        // Fallback to original method
        try {
          log('DEBUG: Attempting fallback with createUserProfile');
          await supabase.createUserProfile(profile);
          log('DEBUG: Fallback user profile creation successful');
        } catch (e2) {
          log('DEBUG: Both methods failed. createUserProfile error: $e2');
          throw Exception('Failed to create user profile: $e2');
        }
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
      // Enhanced validation using the helper method
      final validationError = _validateRegistrationData(event);
      if (validationError != null) {
        emit(RegisterFailure(validationError));
        return;
      }

      // Additional validation using ErrorHandler for basic fields
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

      log('DEBUG: Starting registration for ${event.role}');
      log('DEBUG: Languages: ${event.languages}');
      log('DEBUG: Skills: ${event.skillIds}');
      log('DEBUG: Specializations: ${event.specializationIds}');

      final authResponse = await supabase.signUp(
        email: event.email,
        password: event.password,
      );
      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Registration failed');

      log('DEBUG: User created with ID: $userId');

      // Wait a moment for the auth context to be established
      await Future.delayed(const Duration(milliseconds: 500));

      final profile = UserProfile(
        id: userId,
        role: event.role,
        username: event.username,
        profileImage: null,
        gender: event.gender,
      );

      // Create user profile with better error handling
      try {
        log('DEBUG: Creating user profile...');
        await supabase.createUserProfileAfterSignUp(profile);
        log('DEBUG: User profile created successfully');
      } catch (e) {
        log('DEBUG: createUserProfileAfterSignUp failed: $e');
        try {
          log('DEBUG: Attempting fallback with createUserProfile');
          await supabase.createUserProfile(profile);
          log('DEBUG: Fallback user profile creation successful');
        } catch (e2) {
          log('DEBUG: Both profile creation methods failed: $e2');
          throw Exception('Failed to create user profile: $e2');
        }
      }

      // Only create interpreter details if role is interpreter
      if (event.role == 'interpreter') {
        try {
          await supabase.createInterpreterDetails(
            InterpreterDetails(userId: userId),
          );
          log('DEBUG: Interpreter details created successfully');
        } catch (e) {
          log('DEBUG: Error creating interpreter details: $e');
          // Don't fail the entire registration for this
        }

        // Add languages with better error handling
        int successfulLanguages = 0;
        for (final langId in event.languages) {
          try {
            final fluencyLevelName = event.fluency[langId];
            final fluencyId =
                fluencyLevelName != null
                    ? _getFluencyLevelId(fluencyLevelName)
                    : 1; // Default to Beginner (ID 1)

            final languageId = int.tryParse(langId);
            if (languageId == null || languageId <= 0) {
              log('DEBUG: Invalid language ID: $langId');
              continue;
            }

            await supabase.addInterpreterLanguage(
              InterpreterLanguage(
                userId: userId,
                languageId: languageId,
                fluencyId: fluencyId,
              ),
            );
            successfulLanguages++;
            log('DEBUG: Successfully added language: $langId');
          } catch (e) {
            log('DEBUG: Error adding language $langId: $e');
          }
        }
        log('DEBUG: Successfully added $successfulLanguages languages');

        // Add skills with better error handling
        int successfulSkills = 0;
        for (final skillId in event.skillIds) {
          try {
            if (skillId <= 0) {
              log('DEBUG: Invalid skill ID: $skillId');
              continue;
            }
            await supabase.addInterpreterSkill(
              InterpreterSkill(userId: userId, skillId: skillId),
            );
            successfulSkills++;
            log('DEBUG: Successfully added skill: $skillId');
          } catch (e) {
            log('DEBUG: Error adding skill $skillId: $e');
          }
        }
        log('DEBUG: Successfully added $successfulSkills skills');

        // Add specializations with better error handling
        int successfulSpecializations = 0;
        for (final specId in event.specializationIds) {
          try {
            if (specId <= 0) {
              log('DEBUG: Invalid specialization ID: $specId');
              continue;
            }
            await supabase.addInterpreterSpecialization(
              InterpreterSpecialization(
                userId: userId,
                specializationId: specId,
              ),
            );
            successfulSpecializations++;
            log('DEBUG: Successfully added specialization: $specId');
          } catch (e) {
            log('DEBUG: Error adding specialization $specId: $e');
          }
        }
        log(
          'DEBUG: Successfully added $successfulSpecializations specializations',
        );
      }

      log('DEBUG: Registration completed successfully');
      emit(RegisterSuccess());
    } catch (e) {
      log('DEBUG: Registration failed with error: $e');
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

  // Helper method to validate registration data
  String? _validateRegistrationData(RegisterSubmitted event) {
    // Validate basic fields
    if (event.email.trim().isEmpty) {
      return 'Email is required';
    }
    if (event.password.isEmpty) {
      return 'Password is required';
    }
    if (event.username.trim().isEmpty) {
      return 'Username is required';
    }
    if (event.role.isEmpty) {
      return 'Role is required';
    }

    // Validate interpreter-specific data
    if (event.role == 'interpreter') {
      if (event.languages.isEmpty) {
        return AppStrings.pleaseSelectAtLeastOneLanguage;
      }
      if (event.skillIds.isEmpty) {
        return AppStrings.pleaseSelectAtLeastOneSkill;
      }
      if (event.specializationIds.isEmpty) {
        return AppStrings.pleaseSelectAtLeastOneSpecialization;
      }

      // Validate that all language IDs are valid
      for (final langId in event.languages) {
        final languageId = int.tryParse(langId);
        if (languageId == null || languageId <= 0) {
          return 'Invalid language ID: $langId';
        }
      }

      // Validate that all skill IDs are valid
      for (final skillId in event.skillIds) {
        if (skillId <= 0) {
          return 'Invalid skill ID: $skillId';
        }
      }

      // Validate that all specialization IDs are valid
      for (final specId in event.specializationIds) {
        if (specId <= 0) {
          return 'Invalid specialization ID: $specId';
        }
      }
    }

    return null; // All validations passed
  }
}
