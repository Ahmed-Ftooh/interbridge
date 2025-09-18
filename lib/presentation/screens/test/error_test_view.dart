import 'package:flutter/material.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

/// Test view to demonstrate different error handling scenarios
class ErrorTestView extends StatelessWidget {
  const ErrorTestView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Handling Test'),
        backgroundColor: ColorManager.primary,
        foregroundColor: ColorManager.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSize.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Error Handling Test Scenarios',
              style: TextStyle(
                fontSize: AppSize.s24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSize.s24),

            // Network Error Test
            _buildTestButton(
              context,
              'Test Network Error',
              'Simulate network connectivity issues',
              () => _showErrorDialog(
                context,
                ErrorHandler.handleError(
                  Exception('Network connection failed'),
                  context: 'TestNetworkError',
                ),
              ),
            ),

            const SizedBox(height: AppSize.s16),

            // Authentication Error Test
            _buildTestButton(
              context,
              'Test Authentication Error',
              'Simulate login/authentication failures',
              () => _showErrorDialog(
                context,
                AppError(
                  message: 'Invalid login credentials',
                  type: ErrorType.authentication,
                  userAction: 'Please check your email and password.',
                  isRetryable: true,
                ),
              ),
            ),

            const SizedBox(height: AppSize.s16),

            // Validation Error Test
            _buildTestButton(
              context,
              'Test Validation Error',
              'Simulate input validation failures',
              () => _showErrorDialog(
                context,
                AppError(
                  message: 'Invalid email format',
                  type: ErrorType.validation,
                  userAction: 'Please enter a valid email address.',
                  isRetryable: true,
                ),
              ),
            ),

            const SizedBox(height: AppSize.s16),

            // Server Error Test
            _buildTestButton(
              context,
              'Test Server Error',
              'Simulate server/database errors',
              () => _showErrorDialog(
                context,
                AppError(
                  message: 'Database connection failed',
                  type: ErrorType.server,
                  userAction:
                      'Please try again. If the problem persists, contact support.',
                  isRetryable: true,
                ),
              ),
            ),

            const SizedBox(height: AppSize.s16),

            // Permission Error Test
            _buildTestButton(
              context,
              'Test Permission Error',
              'Simulate permission denied errors',
              () => _showErrorDialog(
                context,
                AppError(
                  message: 'Microphone permission required',
                  type: ErrorType.permission,
                  userAction:
                      'Please enable microphone permission in app settings.',
                  isRetryable: false,
                ),
              ),
            ),

            const SizedBox(height: AppSize.s16),

            // Timeout Error Test
            _buildTestButton(
              context,
              'Test Timeout Error',
              'Simulate request timeout errors',
              () => _showErrorDialog(
                context,
                AppError(
                  message: 'Request timed out',
                  type: ErrorType.timeout,
                  userAction: 'The request took too long. Please try again.',
                  isRetryable: true,
                ),
              ),
            ),

            const SizedBox(height: AppSize.s16),

            // Unknown Error Test
            _buildTestButton(
              context,
              'Test Unknown Error',
              'Simulate unexpected errors',
              () => _showErrorDialog(
                context,
                AppError(
                  message: 'An unexpected error occurred',
                  type: ErrorType.unknown,
                  userAction:
                      'Please try again. If the problem persists, contact support.',
                  isRetryable: true,
                ),
              ),
            ),

            const SizedBox(height: AppSize.s32),

            // Full Error Display Test
            ElevatedButton.icon(
              onPressed: () => _showFullErrorDisplay(context),
              icon: const Icon(Icons.error_outline),
              label: const Text('Show Full Error Display'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.error,
                foregroundColor: ColorManager.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSize.s24,
                  vertical: AppSize.s16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    BuildContext context,
    String title,
    String subtitle,
    VoidCallback onPressed,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.bug_report, color: ColorManager.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onPressed,
      ),
    );
  }

  void _showErrorDialog(BuildContext context, AppError error) {
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
                  const SizedBox(height: AppSize.s8),
                  Text(
                    error.userAction!,
                    style: TextStyle(
                      color: ColorManager.textSecondary,
                      fontSize: AppSize.s14,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              if (error.isRetryable)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Simulate retry action
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Retry action triggered'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Retry'),
                ),
            ],
          ),
    );
  }

  void _showFullErrorDisplay(BuildContext context) {
    final error = AppError(
      message: 'Failed to load data',
      type: ErrorType.network,
      technicalDetails:
          'SocketException: Network is unreachable (OS Error: Network is unreachable, errno = 101)',
      userAction: 'Please check your internet connection and try again.',
      isRetryable: true,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Full Error Display'),
                backgroundColor: ColorManager.primary,
                foregroundColor: ColorManager.white,
              ),
              body: ErrorDisplayWidget(
                error: error,
                onRetry: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Retry action triggered'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                title: 'Connection Failed',
                showTechnicalDetails: true,
              ),
            ),
      ),
    );
  }

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
}

