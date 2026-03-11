import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/core/network_service.dart';
import 'dart:io';
import 'dart:async';

enum ErrorType {
  network,
  authentication,
  validation,
  server,
  permission,
  timeout,
  unknown,
}

class AppError {
  final String message;
  final ErrorType type;
  final String? technicalDetails;
  final String? userAction;
  final bool isRetryable;

  AppError({
    required this.message,
    required this.type,
    this.technicalDetails,
    this.userAction,
    this.isRetryable = true,
  });

  @override
  String toString() => message;

  /// Get user-friendly error message with action suggestion
  String getDisplayMessage() {
    if (userAction != null) {
      return '$message\n\n$userAction';
    }
    return message;
  }
}

class ErrorHandler {
  static final NetworkService _networkService = NetworkService();

  /// Handle any type of error with comprehensive analysis
  static AppError handleError(dynamic error, {String? context}) {
    // Check network connectivity first
    if (!_networkService.isConnected) {
      return AppError(
        message: 'No internet connection',
        type: ErrorType.network,
        technicalDetails: error.toString(),
        userAction: 'Please check your internet connection and try again.',
        isRetryable: true,
      );
    }

    // Handle specific error types
    if (error is SocketException) {
      return _handleSocketException(error);
    }

    if (error is HttpException) {
      return _handleHttpException(error);
    }

    if (error is TimeoutException) {
      return _handleTimeoutException(error);
    }

    if (error is AuthException) {
      return handleAuthError(error);
    }

    if (error is PostgrestException) {
      return _handlePostgrestException(error);
    }

    // StateError — e.g. "Supabase has not been initialized"
    if (error is StateError) {
      return AppError(
        message: 'Service not ready. Please refresh the page.',
        type: ErrorType.unknown,
        technicalDetails: error.toString(),
        userAction: 'Refresh the page and try again.',
        isRetryable: true,
      );
    }

    // Permission errors are typically handled through string detection

    // Handle string-based error detection
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('unreachable') ||
        errorString.contains('no internet') ||
        errorString.contains('xmlhttprequest') ||
        errorString.contains('failed to fetch') ||
        errorString.contains('fetch error')) {
      return AppError(
        message: 'Network connection error',
        type: ErrorType.network,
        technicalDetails: error.toString(),
        userAction: 'Please check your internet connection and try again.',
        isRetryable: true,
      );
    }

    if (errorString.contains('not initialized') ||
        errorString.contains('bad state')) {
      return AppError(
        message: 'Service not ready. Please refresh the page.',
        type: ErrorType.unknown,
        technicalDetails: error.toString(),
        userAction: 'Refresh the page and try again.',
        isRetryable: true,
      );
    }

    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return AppError(
        message: 'Request timed out',
        type: ErrorType.timeout,
        technicalDetails: error.toString(),
        userAction: 'The request took too long. Please try again.',
        isRetryable: true,
      );
    }

    if (errorString.contains('permission') || errorString.contains('denied')) {
      return AppError(
        message: 'Permission denied',
        type: ErrorType.permission,
        technicalDetails: error.toString(),
        userAction: 'Please grant the required permissions in app settings.',
        isRetryable: false,
      );
    }

    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return AppError(
        message: 'Invalid input',
        type: ErrorType.validation,
        technicalDetails: error.toString(),
        userAction: 'Please check your input and try again.',
        isRetryable: true,
      );
    }

    // Default unknown error
    return AppError(
      message: 'An unexpected error occurred',
      type: ErrorType.unknown,
      technicalDetails: error.toString(),
      userAction: 'Please try again. If the problem persists, contact support.',
      isRetryable: true,
    );
  }

  /// Handle socket exceptions (network connectivity issues)
  static AppError _handleSocketException(SocketException error) {
    String message;
    String userAction;

    switch (error.osError?.errorCode) {
      case 7: // No address associated with hostname
        message = 'Cannot reach server';
        userAction = 'Please check your internet connection and try again.';
        break;
      case 101: // Network is unreachable
        message = 'Network unreachable';
        userAction = 'Please check your internet connection and try again.';
        break;
      case 111: // Connection refused
        message = 'Server is not responding';
        userAction =
            'The server may be temporarily unavailable. Please try again later.';
        break;
      default:
        message = 'Network connection failed';
        userAction = 'Please check your internet connection and try again.';
    }

    return AppError(
      message: message,
      type: ErrorType.network,
      technicalDetails: error.toString(),
      userAction: userAction,
      isRetryable: true,
    );
  }

  /// Handle HTTP exceptions
  static AppError _handleHttpException(HttpException error) {
    return AppError(
      message: 'Server communication error',
      type: ErrorType.server,
      technicalDetails: error.toString(),
      userAction: 'Please try again. If the problem persists, contact support.',
      isRetryable: true,
    );
  }

  /// Handle timeout exceptions
  static AppError _handleTimeoutException(TimeoutException error) {
    return AppError(
      message: 'Request timed out',
      type: ErrorType.timeout,
      technicalDetails: error.toString(),
      userAction: 'The request took too long. Please try again.',
      isRetryable: true,
    );
  }

  /// Handle Postgrest exceptions
  static AppError _handlePostgrestException(PostgrestException error) {
    String message;
    String userAction;

    switch (error.code) {
      case 'PGRST116':
        message = 'Database connection failed';
        userAction =
            'Please try again. If the problem persists, contact support.';
        break;
      case '23505': // Unique constraint violation
        message = 'This information already exists';
        userAction = 'Please use different information and try again.';
        break;
      case '23503': // Foreign key constraint violation
        message = 'Invalid reference';
        userAction = 'Please check your input and try again.';
        break;
      default:
        message = 'Database operation failed';
        userAction =
            'Please try again. If the problem persists, contact support.';
    }

    return AppError(
      message: message,
      type: ErrorType.server,
      technicalDetails: error.toString(),
      userAction: userAction,
      isRetryable: true,
    );
  }

  static AppError handleAuthError(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return AppError(
            message: 'Invalid email or password',
            type: ErrorType.authentication,
            technicalDetails: error.message,
            userAction: 'Please check your credentials and try again.',
            isRetryable: true,
          );
        case 'Email not confirmed':
          return AppError(
            message: 'Email not confirmed',
            type: ErrorType.authentication,
            technicalDetails: error.message,
            userAction:
                'Please check your email and confirm your account before signing in.',
            isRetryable: false,
          );
        case 'Too many requests':
          return AppError(
            message: 'Too many login attempts',
            type: ErrorType.authentication,
            technicalDetails: error.message,
            userAction: 'Please wait a moment before trying again.',
            isRetryable: true,
          );
        case 'User not found':
          return AppError(
            message: 'No account found with this email address',
            type: ErrorType.authentication,
            technicalDetails: error.message,
            userAction: 'Please check your email or create a new account.',
            isRetryable: false,
          );
        default:
          return AppError(
            message: 'Authentication failed',
            type: ErrorType.authentication,
            technicalDetails: error.message,
            userAction: 'Please try again.',
            isRetryable: true,
          );
      }
    }

    if (error is PostgrestException) {
      return _handlePostgrestException(error);
    }

    // Use the comprehensive error handler
    return handleError(error);
  }

  static AppError? handleValidationError(String field, String? value) {
    switch (field.toLowerCase()) {
      case 'email':
        if (value == null || value.isEmpty) {
          return AppError(
            message: 'Email is required',
            type: ErrorType.validation,
            userAction: 'Please enter your email address.',
            isRetryable: true,
          );
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return AppError(
            message: 'Invalid email format',
            type: ErrorType.validation,
            userAction: 'Please enter a valid email address.',
            isRetryable: true,
          );
        }
        return null; // Valid email
      case 'password':
        if (value == null || value.isEmpty) {
          return AppError(
            message: 'Password is required',
            type: ErrorType.validation,
            userAction: 'Please enter your password.',
            isRetryable: true,
          );
        }
        if (value.length < 6) {
          return AppError(
            message: 'Password too short',
            type: ErrorType.validation,
            userAction: 'Password must be at least 6 characters long.',
            isRetryable: true,
          );
        }
        return null; // Valid password
      case 'username':
        if (value == null || value.isEmpty) {
          return AppError(
            message: 'Username is required',
            type: ErrorType.validation,
            userAction: 'Please enter a username.',
            isRetryable: true,
          );
        }
        if (value.length < 3) {
          return AppError(
            message: 'Username too short',
            type: ErrorType.validation,
            userAction: 'Username must be at least 3 characters long.',
            isRetryable: true,
          );
        }
        return null; // Valid username
      case 'confirmpassword':
        return AppError(
          message: 'Passwords do not match',
          type: ErrorType.validation,
          userAction: 'Please make sure both passwords are identical.',
          isRetryable: true,
        );
      default:
        return AppError(
          message: 'Invalid input',
          type: ErrorType.validation,
          userAction: 'Please fill in all required fields.',
          isRetryable: true,
        );
    }
  }

  static AppError handleGeneralError(dynamic error) {
    if (error is AppError) {
      return error;
    }

    if (error is Exception) {
      return handleError(error);
    }

    return AppError(
      message: 'Something went wrong',
      type: ErrorType.unknown,
      technicalDetails: error.toString(),
      userAction: 'Please try again.',
      isRetryable: true,
    );
  }

  static String getErrorMessage(AppError error) {
    return error.getDisplayMessage();
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

  static bool isPermissionError(AppError error) {
    return error.type == ErrorType.permission;
  }

  static bool isTimeoutError(AppError error) {
    return error.type == ErrorType.timeout;
  }

  static bool isServerError(AppError error) {
    return error.type == ErrorType.server;
  }

  static bool isRetryableError(AppError error) {
    return error.isRetryable;
  }

  /// Get appropriate icon for error type
  static String getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'wifi_off';
      case ErrorType.authentication:
        return 'lock';
      case ErrorType.validation:
        return 'warning';
      case ErrorType.server:
        return 'error';
      case ErrorType.permission:
        return 'block';
      case ErrorType.timeout:
        return 'schedule';
      case ErrorType.unknown:
        return 'help';
    }
  }

  /// Get appropriate color for error type
  static String getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'orange';
      case ErrorType.authentication:
        return 'red';
      case ErrorType.validation:
        return 'amber';
      case ErrorType.server:
        return 'red';
      case ErrorType.permission:
        return 'purple';
      case ErrorType.timeout:
        return 'blue';
      case ErrorType.unknown:
        return 'grey';
    }
  }
}
