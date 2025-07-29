import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final IconData? icon;
  final Color? iconColor;

  const CustomDialog({
    super.key,
    required this.title,
    required this.message,
    this.primaryButtonText,
    this.secondaryButtonText,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
      ),
      contentPadding: const EdgeInsets.all(AppSize.s20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AppSize.s50,
              color: iconColor ?? ColorManager.primary,
            ),
            const SizedBox(height: AppSize.s16),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: AppSize.s18,
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            message,
            style: TextStyle(
              fontSize: AppSize.s14,
              color: ColorManager.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (secondaryButtonText != null)
          TextButton(
            onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
            child: Text(
              secondaryButtonText!,
              style: TextStyle(
                color: ColorManager.textSecondary,
                fontSize: AppSize.s14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (primaryButtonText != null)
          ElevatedButton(
            onPressed: onPrimaryPressed ?? () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.primary,
              foregroundColor: ColorManager.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSize.s12),
              ),
            ),
            child: Text(
              primaryButtonText!,
              style: const TextStyle(
                fontSize: AppSize.s14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// Convenience method to show custom dialog
void showCustomDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? primaryButtonText,
  String? secondaryButtonText,
  VoidCallback? onPrimaryPressed,
  VoidCallback? onSecondaryPressed,
  IconData? icon,
  Color? iconColor,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return CustomDialog(
        title: title,
        message: message,
        primaryButtonText: primaryButtonText,
        secondaryButtonText: secondaryButtonText,
        onPrimaryPressed: onPrimaryPressed,
        onSecondaryPressed: onSecondaryPressed,
        icon: icon,
        iconColor: iconColor,
      );
    },
  );
}
