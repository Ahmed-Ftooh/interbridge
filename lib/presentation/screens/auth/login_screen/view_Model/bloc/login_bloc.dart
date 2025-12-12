import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/core/error_handler.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final SupabaseService _supabaseService = SupabaseService();

  LoginBloc() : super(const LoginState()) {
    on<LoginEmailChanged>((event, emit) {
      emit(state.copyWith(email: event.email));
    });
    on<LoginPasswordChanged>((event, emit) {
      emit(state.copyWith(password: event.password));
    });
    on<LoginSubmitted>((event, emit) async {
      emit(
        state.copyWith(
          isSubmitting: true,
          isFailure: false,
          isSuccess: false,
          errorMessage: null,
        ),
      );

      try {
        // Validate email and password
        final emailError = ErrorHandler.handleValidationError(
          'email',
          state.email,
        );
        if (emailError != null) {
          emit(
            state.copyWith(
              isSubmitting: false,
              isFailure: true,
              errorMessage: emailError.message,
            ),
          );
          return;
        }

        final passwordError = ErrorHandler.handleValidationError(
          'password',
          state.password,
        );
        if (passwordError != null) {
          emit(
            state.copyWith(
              isSubmitting: false,
              isFailure: true,
              errorMessage: passwordError.message,
            ),
          );
          return;
        }

        // Attempt to sign in with Supabase
        final response = await _supabaseService.signIn(
          email: state.email,
          password: state.password,
        );

        if (response.user != null) {
          // Check for Institution Status if user is a Doctor
          try {
            final profile = await _supabaseService.getUserProfile(
              response.user!.id,
            );

            if (profile?.role == 'doctor') {
              if (profile?.institutionId == null) {
                throw Exception(
                  'Doctor account not linked to any institution.',
                );
              }

              final institutionData = await _supabaseService
                  .getInstitutionStatus(profile!.institutionId!);

              if (institutionData == null) {
                throw Exception('Institution not found.');
              }

              final status = institutionData['subscription_status'];
              if (status != 'active') {
                await _supabaseService.signOut(); // Logout immediately
                throw Exception(
                  'Institution subscription is expired. Please contact your administrator.',
                );
              }
            }
          } catch (e) {
            emit(
              state.copyWith(
                isSubmitting: false,
                isFailure: true,
                errorMessage: e.toString().replaceAll('Exception: ', ''),
              ),
            );
            return;
          }

          emit(state.copyWith(isSubmitting: false, isSuccess: true));
        } else {
          emit(
            state.copyWith(
              isSubmitting: false,
              isFailure: true,
              errorMessage: 'Login failed. Please check your credentials.',
            ),
          );
        }
      } catch (e) {
        final appError = ErrorHandler.handleAuthError(e);
        emit(
          state.copyWith(
            isSubmitting: false,
            isFailure: true,
            errorMessage: appError.message,
          ),
        );
      }
    });
    on<LoginPasswordVisibilityToggled>((event, emit) {
      emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
    });
  }
}
