import 'dart:developer';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'register_event.dart';
import 'register_state.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/app/app_prf.dart';
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

      // Sign up the user only. Defer profile creation until email verified
      final authResponse = await supabase.signUp(
        email: event.email,
        password: event.password,
      );
      await supabase.sendEmailOtp(event.email);
      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Registration failed');

      // Persist pending registration locally
      final pending = {
        'email': event.email,
        'role': 'requester',
        'username': event.username,
      };
      await GetIt.I<AppPreferences>().savePendingRegistration(
        jsonEncode(pending),
      );

      // After sign up, navigate user to email verification screen.
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

      // Sign up only; defer DB writes until email is verified
      final authResponse = await supabase.signUp(
        email: event.email,
        password: event.password,
      );
      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Registration failed');

      log('DEBUG: User created with ID: $userId');

      // Wait a moment for the auth context to be established
      await Future.delayed(const Duration(milliseconds: 500));

      // Persist pending registration locally
      final pending = {
        'email': event.email,
        'role': event.role,
        'username': event.username,
        'gender': event.gender,
        'languages': event.languages,
        'fluency': event.fluency,
        'skillIds': event.skillIds,
        'specializationIds': event.specializationIds,
        'voiceSampleUrl': event.voiceSampleUrl,
        'voicePrompt': event.voicePrompt,
        'certificateUrl': event.certificateUrl,
        'voiceSamplePath': event.voiceSamplePath,
        'certificatePath': event.certificatePath,
      };
      await GetIt.I<AppPreferences>().savePendingRegistration(
        jsonEncode(pending),
      );

      log('DEBUG: Registration completed successfully');
      emit(RegisterSuccess());
    } catch (e) {
      log('DEBUG: Registration failed with error: $e');
      final appError = ErrorHandler.handleAuthError(e);
      emit(RegisterFailure(appError.message));
    }
  }

  // (removed) helper not used anymore; registration writes deferred

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
