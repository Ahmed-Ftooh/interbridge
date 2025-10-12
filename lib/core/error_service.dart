import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/core/network_service.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';
import 'dart:ui';

/// Centralized error handling service that manages all errors in the app
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  final NetworkService _networkService = NetworkService();
  final StreamController<AppError> _errorController =
      StreamController<AppError>.broadcast();

  /// Stream of errors that can be listened to globally
  Stream<AppError> get errorStream => _errorController.stream;

  /// Current error state
  AppError? _currentError;
  AppError? get currentError => _currentError;

  /// Initialize the error service
  Future<void> initialize() async {
    // Listen to network connectivity changes
    _networkService.connectivityStream.listen((isConnected) {
      if (!isConnected && _currentError?.type != ErrorType.network) {
        _handleNetworkDisconnection();
      } else if (isConnected && _currentError?.type == ErrorType.network) {
        _handleNetworkReconnection();
      }
    });
  }

  /// Handle any error in the app
  void handleError(
    dynamic error, {
    String? context,
    BuildContext? buildContext,
  }) {
    final appError = ErrorHandler.handleError(error, context: context);
    _currentError = appError;

    log('Error handled: ${appError.message} (Type: ${appError.type})');

    // Emit error to stream
    _errorController.add(appError);

    // Show error in UI if context is provided
    if (buildContext != null) {
      _showErrorInUI(buildContext, appError);
    }
  }

  /// Handle network disconnection
  void _handleNetworkDisconnection() {
    final networkError = AppError(
      message: 'No internet connection',
      type: ErrorType.network,
      userAction: 'Please check your internet connection and try again.',
      isRetryable: true,
    );

    _currentError = networkError;
    _errorController.add(networkError);

    log('Network disconnected');
  }

  /// Handle network reconnection
  void _handleNetworkReconnection() {
    _currentError = null;
    log('Network reconnected');

    // You could emit a success event here if needed
  }

  /// Show error in UI
  void _showErrorInUI(BuildContext context, AppError error) {
    // Show error snackbar
    ErrorSnackBar.show(
      context,
      error: error,
      onRetry:
          error.isRetryable
              ? () {
                // Retry logic can be implemented here
                log('Retry action triggered for error: ${error.message}');
              }
              : null,
    );
  }

  /// Show error dialog
  void showErrorDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_getErrorTitle(error.type)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error.message),
                if (error.userAction != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error.userAction!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              if (error.isRetryable && onRetry != null)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRetry();
                  },
                  child: const Text('Retry'),
                ),
            ],
          ),
    );
  }

  /// Show full error display page
  void showErrorPage(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: Text(_getErrorTitle(error.type)),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              body: ErrorDisplayWidget(
                error: error,
                onRetry: onRetry,
                showTechnicalDetails: true,
              ),
            ),
      ),
    );
  }

  /// Clear current error
  void clearError() {
    _currentError = null;
  }

  /// Check if there's a current error
  bool get hasError => _currentError != null;

  /// Check if current error is network related
  bool get hasNetworkError => _currentError?.type == ErrorType.network;

  /// Check if current error is retryable
  bool get isCurrentErrorRetryable => _currentError?.isRetryable ?? false;

  /// Get user-friendly error title
  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Connection Error';
      case ErrorType.authentication:
        return 'Authentication Failed';
      case ErrorType.validation:
        return 'Invalid Input';
      case ErrorType.server:
        return 'Server Error';
      case ErrorType.permission:
        return 'Permission Denied';
      case ErrorType.timeout:
        return 'Request Timeout';
      case ErrorType.unknown:
        return 'Something Went Wrong';
    }
  }

  /// Dispose resources
  void dispose() {
    _errorController.close();
  }
}

/// Helper class for error handling in BLoCs
class ErrorHandlingHelper {
  /// Handle error and return AppError
  static AppError handleError(dynamic error, {String? context}) {
    final appError = ErrorHandler.handleError(error, context: context);
    ErrorService().handleError(error, context: context);
    return appError;
  }
}

/// Global error handler for uncaught exceptions
class GlobalErrorHandler {
  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      log('Flutter Error: ${details.exception}');
      ErrorService().handleError(
        details.exception,
        context: 'FlutterFramework',
      );
    };

    // Handle async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      log('Async Error: $error');
      ErrorService().handleError(error, context: 'AsyncOperation');
      return true;
    };
  }
}
