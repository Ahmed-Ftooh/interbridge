import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';

class CustomLoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double? size;
  final bool showMessage;

  const CustomLoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size ?? AppSize.s40,
            height: size ?? AppSize.s40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? ColorManager.primary2,
              ),
            ),
          ),
          if (showMessage) ...[
            const SizedBox(height: AppSize.s16),
            Text(
              message ?? AppStrings.loading,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColorManager.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CustomLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;
  final Color? backgroundColor;

  const CustomLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingMessage,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: backgroundColor ?? ColorManager.black.withValues(alpha: 0.3),
            child: CustomLoadingWidget(message: loadingMessage),
          ),
      ],
    );
  }
}

class CustomEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? iconColor;

  const CustomEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppSize.s60, color: iconColor ?? ColorManager.grey),
          const SizedBox(height: AppSize.s16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: ColorManager.textPrimary),
          ),
          const SizedBox(height: AppSize.s8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ColorManager.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: AppSize.s16), action!],
        ],
      ),
    );
  }
}
