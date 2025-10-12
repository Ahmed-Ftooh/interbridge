import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? contentWidget;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool showCancelButton;
  final bool showConfirmButton;
  final IconData? icon;
  final Color? iconColor;

  const CustomDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.showCancelButton = true,
    this.showConfirmButton = true,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: iconColor ?? ColorManager.primary2,
              size: AppSize.s24,
            ),
            const SizedBox(width: AppSize.s12),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: ColorManager.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content:
          contentWidget ??
          (content != null
              ? Text(
                content!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ColorManager.textSecondary,
                ),
              )
              : null),
      actions: [
        if (showCancelButton)
          TextButton(
            onPressed: onCancel ?? () => Navigator.of(context).pop(),
            child: Text(cancelText ?? AppStrings.cancel),
          ),
        if (showConfirmButton)
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.primary2,
              foregroundColor: ColorManager.white,
            ),
            child: Text(confirmText ?? AppStrings.retry),
          ),
      ],
    );
  }
}

class CustomConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;
  final Color? iconColor;

  const CustomConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      title: title,
      content: content,
      confirmText: confirmText ?? AppStrings.delete,
      cancelText: cancelText ?? AppStrings.cancel,
      icon: icon ?? Icons.warning,
      iconColor: iconColor ?? ColorManager.error,
      onConfirm: onConfirm,
      onCancel: onCancel ?? () => Navigator.of(context).pop(),
    );
  }
}

class CustomInfoDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? buttonText;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;

  const CustomInfoDialog({
    super.key,
    required this.title,
    required this.content,
    this.buttonText,
    this.onPressed,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      title: title,
      content: content,
      confirmText: buttonText ?? AppStrings.close,
      showCancelButton: false,
      icon: icon ?? Icons.info,
      iconColor: iconColor ?? ColorManager.info,
      onConfirm: onPressed ?? () => Navigator.of(context).pop(),
    );
  }
}

class CustomSuccessDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? buttonText;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;

  const CustomSuccessDialog({
    super.key,
    required this.title,
    required this.content,
    this.buttonText,
    this.onPressed,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      title: title,
      content: content,
      confirmText: buttonText ?? AppStrings.close,
      showCancelButton: false,
      icon: icon ?? Icons.check_circle,
      iconColor: iconColor ?? ColorManager.success,
      onConfirm: onPressed ?? () => Navigator.of(context).pop(),
    );
  }
}

class CustomErrorDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? buttonText;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;

  const CustomErrorDialog({
    super.key,
    required this.title,
    required this.content,
    this.buttonText,
    this.onPressed,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      title: title,
      content: content,
      confirmText: buttonText ?? AppStrings.close,
      showCancelButton: false,
      icon: icon ?? Icons.error,
      iconColor: iconColor ?? ColorManager.error,
      onConfirm: onPressed ?? () => Navigator.of(context).pop(),
    );
  }
}

// Extension methods for easy dialog showing
extension CustomDialogExtension on BuildContext {
  Future<void> showCustomDialog({
    required String title,
    String? content,
    Widget? contentWidget,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool showCancelButton = true,
    bool showConfirmButton = true,
    IconData? icon,
    Color? iconColor,
  }) {
    return showDialog(
      context: this,
      builder:
          (context) => CustomDialog(
            title: title,
            content: content,
            contentWidget: contentWidget,
            confirmText: confirmText,
            cancelText: cancelText,
            onConfirm: onConfirm,
            onCancel: onCancel,
            showCancelButton: showCancelButton,
            showConfirmButton: showConfirmButton,
            icon: icon,
            iconColor: iconColor,
          ),
    );
  }

  Future<void> showConfirmDialog({
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    IconData? icon,
    Color? iconColor,
  }) {
    return showDialog(
      context: this,
      builder:
          (context) => CustomConfirmDialog(
            title: title,
            content: content,
            confirmText: confirmText,
            cancelText: cancelText,
            onConfirm: onConfirm,
            onCancel: onCancel,
            icon: icon,
            iconColor: iconColor,
          ),
    );
  }

  Future<void> showInfoDialog({
    required String title,
    required String content,
    String? buttonText,
    VoidCallback? onPressed,
    IconData? icon,
    Color? iconColor,
  }) {
    return showDialog(
      context: this,
      builder:
          (context) => CustomInfoDialog(
            title: title,
            content: content,
            buttonText: buttonText,
            onPressed: onPressed,
            icon: icon,
            iconColor: iconColor,
          ),
    );
  }

  Future<void> showSuccessDialog({
    required String title,
    required String content,
    String? buttonText,
    VoidCallback? onPressed,
    IconData? icon,
    Color? iconColor,
  }) {
    return showDialog(
      context: this,
      builder:
          (context) => CustomSuccessDialog(
            title: title,
            content: content,
            buttonText: buttonText,
            onPressed: onPressed,
            icon: icon,
            iconColor: iconColor,
          ),
    );
  }

  Future<void> showErrorDialog({
    required String title,
    required String content,
    String? buttonText,
    VoidCallback? onPressed,
    IconData? icon,
    Color? iconColor,
  }) {
    return showDialog(
      context: this,
      builder:
          (context) => CustomErrorDialog(
            title: title,
            content: content,
            buttonText: buttonText,
            onPressed: onPressed,
            icon: icon,
            iconColor: iconColor,
          ),
    );
  }
}
