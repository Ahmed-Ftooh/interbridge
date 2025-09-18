import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

/// Widget to display errors with animations and user-friendly messages
class ErrorDisplayWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final String? title;
  final bool showAnimation;
  final bool showTechnicalDetails;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.showAnimation = true,
    this.showTechnicalDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showAnimation) ...[
              _buildErrorAnimation(),
              const SizedBox(height: AppSize.s24),
            ],
            _buildErrorIcon(),
            const SizedBox(height: AppSize.s16),
            _buildErrorTitle(context),
            const SizedBox(height: AppSize.s8),
            _buildErrorMessage(context),
            if (showTechnicalDetails) ...[
              const SizedBox(height: AppSize.s16),
              _buildTechnicalDetails(context),
            ],
            if (error.isRetryable && onRetry != null) ...[
              const SizedBox(height: AppSize.s24),
              _buildRetryButton(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorAnimation() {
    return SizedBox(
      width: AppSize.s120,
      height: AppSize.s120,
      child: Lottie.asset(
        'assets/json/erorr.json',
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
      ),
    );
  }

  Widget _buildErrorIcon() {
    if (showAnimation) return const SizedBox.shrink();

    IconData iconData;
    Color iconColor;

    switch (error.type) {
      case ErrorType.network:
        iconData = Icons.wifi_off;
        iconColor = Colors.orange;
        break;
      case ErrorType.authentication:
        iconData = Icons.lock;
        iconColor = Colors.red;
        break;
      case ErrorType.validation:
        iconData = Icons.warning;
        iconColor = Colors.amber;
        break;
      case ErrorType.server:
        iconData = Icons.error;
        iconColor = Colors.red;
        break;
      case ErrorType.permission:
        iconData = Icons.block;
        iconColor = Colors.purple;
        break;
      case ErrorType.timeout:
        iconData = Icons.schedule;
        iconColor = Colors.blue;
        break;
      case ErrorType.unknown:
        iconData = Icons.help;
        iconColor = Colors.grey;
        break;
    }

    return Icon(iconData, size: AppSize.s60, color: iconColor);
  }

  Widget _buildErrorTitle(BuildContext context) {
    final titleText = title ?? _getDefaultTitle();
    return Text(
      titleText,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: ColorManager.textPrimary,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Text(
      error.getDisplayMessage(),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: ColorManager.textSecondary),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTechnicalDetails(BuildContext context) {
    if (error.technicalDetails == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSize.s12),
      decoration: BoxDecoration(
        color: ColorManager.greyLight,
        borderRadius: BorderRadius.circular(AppSize.s8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Technical Details:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
          ),
          const SizedBox(height: AppSize.s4),
          Text(
            error.technicalDetails!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ColorManager.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Try Again'),
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorManager.primary,
        foregroundColor: ColorManager.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSize.s24,
          vertical: AppSize.s12,
        ),
      ),
    );
  }

  String _getDefaultTitle() {
    switch (error.type) {
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

/// Compact error display for smaller spaces
class CompactErrorDisplay extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final bool showRetryButton;

  const CompactErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.showRetryButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSize.s16),
      decoration: BoxDecoration(
        color: ColorManager.greyLight,
        borderRadius: BorderRadius.circular(AppSize.s8),
        border: Border.all(color: _getErrorColor(), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_getErrorIcon(), color: _getErrorColor(), size: AppSize.s20),
              const SizedBox(width: AppSize.s8),
              Expanded(
                child: Text(
                  error.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (error.userAction != null) ...[
            const SizedBox(height: AppSize.s8),
            Text(
              error.userAction!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorManager.textSecondary,
              ),
            ),
          ],
          if (showRetryButton && error.isRetryable && onRetry != null) ...[
            const SizedBox(height: AppSize.s12),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: onRetry, child: const Text('Retry')),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (error.type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock;
      case ErrorType.validation:
        return Icons.warning;
      case ErrorType.server:
        return Icons.error;
      case ErrorType.permission:
        return Icons.block;
      case ErrorType.timeout:
        return Icons.schedule;
      case ErrorType.unknown:
        return Icons.help;
    }
  }

  Color _getErrorColor() {
    switch (error.type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.server:
        return Colors.red;
      case ErrorType.permission:
        return Colors.purple;
      case ErrorType.timeout:
        return Colors.blue;
      case ErrorType.unknown:
        return Colors.grey;
    }
  }
}

/// Error snackbar with animation
class ErrorSnackBar {
  static void show(
    BuildContext context, {
    required AppError error,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: Colors.white,
              size: AppSize.s20,
            ),
            const SizedBox(width: AppSize.s8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (error.userAction != null)
                    Text(
                      error.userAction!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSize.s8),
        ),
        margin: const EdgeInsets.all(AppSize.s16),
        duration: duration,
        action:
            error.isRetryable && onRetry != null
                ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
                : null,
      ),
    );
  }

  static IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock;
      case ErrorType.validation:
        return Icons.warning;
      case ErrorType.server:
        return Icons.error;
      case ErrorType.permission:
        return Icons.block;
      case ErrorType.timeout:
        return Icons.schedule;
      case ErrorType.unknown:
        return Icons.help;
    }
  }

  static Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.server:
        return Colors.red;
      case ErrorType.permission:
        return Colors.purple;
      case ErrorType.timeout:
        return Colors.blue;
      case ErrorType.unknown:
        return Colors.grey;
    }
  }
}
