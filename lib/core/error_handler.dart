import 'package:supabase_flutter/supabase_flutter.dart';

enum ErrorType { network, authentication, validation, server, unknown }

class AppError {
  final String message;
  final ErrorType type;
  final String? technicalDetails;

  AppError({required this.message, required this.type, this.technicalDetails});

  @override
  String toString() => message;
}

class ErrorHandler {
  static AppError handleAuthError(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return AppError(
            message:
                'Invalid email or password. Please check your credentials and try again.',
            type: ErrorType.authentication,
            technicalDetails: error.message,
          );
        case 'Email not confirmed':
          return AppError(
            message:
                'Please check your email and confirm your account before signing in.',
            type: ErrorType.authentication,
            technicalDetails: error.message,
          );
        case 'Too many requests':
          return AppError(
            message:
                'Too many login attempts. Please wait a moment before trying again.',
            type: ErrorType.authentication,
            technicalDetails: error.message,
          );
        case 'User not found':
          return AppError(
            message:
                'No account found with this email address. Please check your email or create a new account.',
            type: ErrorType.authentication,
            technicalDetails: error.message,
          );
        default:
          return AppError(
            message: 'Authentication failed. Please try again.',
            type: ErrorType.authentication,
            technicalDetails: error.message,
          );
      }
    }

    if (error is PostgrestException) {
      return AppError(
        message: 'Database operation failed. Please try again.',
        type: ErrorType.server,
        technicalDetails: error.message,
      );
    }

    if (error.toString().contains('network') ||
        error.toString().contains('connection') ||
        error.toString().contains('timeout')) {
      return AppError(
        message:
            'Network connection error. Please check your internet connection and try again.',
        type: ErrorType.network,
        technicalDetails: error.toString(),
      );
    }

    if (error.toString().contains('validation') ||
        error.toString().contains('invalid')) {
      return AppError(
        message: 'Please check your input and try again.',
        type: ErrorType.validation,
        technicalDetails: error.toString(),
      );
    }

    return AppError(
      message: 'An unexpected error occurred. Please try again.',
      type: ErrorType.unknown,
      technicalDetails: error.toString(),
    );
  }

  static AppError? handleValidationError(String field, String? value) {
    switch (field.toLowerCase()) {
      case 'email':
        if (value == null || value.isEmpty) {
          return AppError(
            message: 'Please enter your email address.',
            type: ErrorType.validation,
          );
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return AppError(
            message: 'Please enter a valid email address.',
            type: ErrorType.validation,
          );
        }
        return null; // Valid email
      case 'password':
        if (value == null || value.isEmpty) {
          return AppError(
            message: 'Please enter your password.',
            type: ErrorType.validation,
          );
        }
        if (value.length < 6) {
          return AppError(
            message: 'Password must be at least 6 characters long.',
            type: ErrorType.validation,
          );
        }
        return null; // Valid password
      case 'username':
        if (value == null || value.isEmpty) {
          return AppError(
            message: 'Please enter a username.',
            type: ErrorType.validation,
          );
        }
        if (value.length < 3) {
          return AppError(
            message: 'Username must be at least 3 characters long.',
            type: ErrorType.validation,
          );
        }
        return null; // Valid username
      case 'confirmpassword':
        return AppError(
          message: 'Passwords do not match. Please try again.',
          type: ErrorType.validation,
        );
      default:
        return AppError(
          message: 'Please fill in all required fields.',
          type: ErrorType.validation,
        );
    }
  }

  static AppError handleGeneralError(dynamic error) {
    if (error is AppError) {
      return error;
    }

    if (error is Exception) {
      return handleAuthError(error);
    }

    return AppError(
      message: 'Something went wrong. Please try again.',
      type: ErrorType.unknown,
      technicalDetails: error.toString(),
    );
  }

  static String getErrorMessage(AppError error) {
    return error.message;
  }

  static bool isNetworkError(AppError error) {
    return error.type == ErrorType.network;
  }

  static bool isAuthError(AppError error) {
    return error.type == ErrorType.authentication;
  }

  static bool isValidationError(AppError error) {
    return error.type == ErrorType.validation;
  }
}
