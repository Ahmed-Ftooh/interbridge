import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'register_event.dart';
import 'register_state.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final SupabaseService supabase = GetIt.I<SupabaseService>();

  RegisterBloc() : super(RegisterInitial()) {
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<RequesterRegisterSubmitted>(_onRequesterRegisterSubmitted);
    on<OrganizationRegisterSubmitted>(_onOrganizationRegisterSubmitted);
    on<DoctorWithInviteRegisterSubmitted>(_onDoctorWithInviteRegisterSubmitted);
  }

  Future<void> _onOrganizationRegisterSubmitted(
    OrganizationRegisterSubmitted event,
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
      await _signUpAllowingPendingConfirmation(
        email: event.email,
        password: event.password,
      );

      // Persist pending registration locally (organization data included)
      final pending = {
        'email': event.email,
        'role': 'organization_admin',
        'username': event.username,
        'organizationName': event.organizationName,
        'organizationEmail': event.organizationEmail,
        'organizationPhone': event.organizationPhone,
        'organizationAddress': event.organizationAddress,
      };
      await GetIt.I<AppPreferences>().savePendingRegistration(
        jsonEncode(pending),
      );

      emit(RegisterSuccess());
    } catch (e) {
      final appError = ErrorHandler.handleAuthError(e);
      emit(RegisterFailure(appError.message));
    }
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
      // Supabase automatically sends confirmation email during signUp
      await _signUpAllowingPendingConfirmation(
        email: event.email,
        password: event.password,
      );
      await supabase.sendMagicLink(event.email);

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

      // Sign up only; defer most DB writes until email is verified
      await _signUpAllowingPendingConfirmation(
        email: event.email,
        password: event.password,
      );
      // await supabase.sendMagicLink(event.email); // Redundant

      // Persist pending registration locally
      final pending = {
        'email': event.email,
        'role': event.role,
        'username': event.username,
        'gender': event.gender,
        'country': event.country,
        'languages': event.languages,
        'fluency': event.fluency,
        'skillIds': event.skillIds,
        'specializationIds': event.specializationIds,
        'voiceSampleUrl': event.voiceSampleUrl,
        'voicePrompt': event.voicePrompt,
        'certificateUrl': event.certificateUrl,
        'medicalCertificateUrl': event.medicalCertificateUrl,
        'voiceSamplePath': event.voiceSamplePath,
        'certificatePath': event.certificatePath,
        'medicalCertificatePath': event.medicalCertificatePath,
        // Web: base64-encode bytes for JSON storage (blob URLs/paths don't survive page navigation)
        if (event.voiceSampleBytes != null)
          'voiceSampleBytesBase64': base64Encode(event.voiceSampleBytes!),
        if (event.voiceSampleName != null)
          'voiceSampleName': event.voiceSampleName,
        // Native-language voice sample
        'voiceSampleNativePath': event.voiceSampleNativePath,
        if (event.voiceSampleNativeBytes != null)
          'voiceSampleNativeBytesBase64': base64Encode(
            event.voiceSampleNativeBytes!,
          ),
        if (event.voiceSampleNativeName != null)
          'voiceSampleNativeName': event.voiceSampleNativeName,
        if (event.certificateBytes != null)
          'certificateBytesBase64': base64Encode(event.certificateBytes!),
        if (event.certificateName != null)
          'certificateName': event.certificateName,
        if (event.medicalCertificateBytes != null)
          'medicalCertificateBytesBase64': base64Encode(
            event.medicalCertificateBytes!,
          ),
        if (event.medicalCertificateName != null)
          'medicalCertificateName': event.medicalCertificateName,
        'bio': event.bio,
        'yearsExperience': event.yearsExperience,
        'preferredShift': event.preferredShift,
        'shiftAvailability': event.shiftAvailability,
        'isOnlineNow': event.isOnlineNow,
        'employmentType': event.employmentType,
        if (event.profileImageBytes != null)
          'profileImageBytesBase64': base64Encode(event.profileImageBytes!),
        if (event.profileImageName != null)
          'profileImageName': event.profileImageName,
      };
      await GetIt.I<AppPreferences>().savePendingRegistration(
        jsonEncode(pending),
      );

      emit(RegisterSuccess());
    } catch (e) {
      final appError = ErrorHandler.handleAuthError(e);
      emit(RegisterFailure(appError.message));
    }
  }

  Future<void> _signUpAllowingPendingConfirmation({
    required String email,
    required String password,
  }) async {
    try {
      await supabase.signUp(email: email, password: password);
    } on AuthException catch (e) {
      // If the error is just that email is not confirmed, we can proceed
      // because we want to show the confirmation screen anyway.
      // Note: Supabase usually returns success with null session for this case,
      // but if it throws, we catch it here.
      if (e.message.contains('not confirmed') ||
          e.message.contains('security purposes')) {
        return;
      }
      rethrow;
    }
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

  Future<void> _onDoctorWithInviteRegisterSubmitted(
    DoctorWithInviteRegisterSubmitted event,
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
      await _signUpAllowingPendingConfirmation(
        email: event.email,
        password: event.password,
      );

      // Persist pending registration locally with organization data
      final pending = {
        'email': event.email,
        'role': 'requester', // Doctors are requesters in the app
        'username': event.username,
        'organizationId': event.organizationId,
        'organizationRole': event.role,
        'inviteId': event.inviteId,
      };
      await GetIt.I<AppPreferences>().savePendingRegistration(
        jsonEncode(pending),
      );

      emit(RegisterSuccess());
    } catch (e) {
      final appError = ErrorHandler.handleAuthError(e);
      emit(RegisterFailure(appError.message));
    }
  }
}
