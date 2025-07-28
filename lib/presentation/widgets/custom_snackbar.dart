import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

enum SnackBarType { success, error, warning, info }

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    required SnackBarType type,
    Duration duration = const Duration(seconds: 4),
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(_getIcon(type), color: ColorManager.white, size: AppSize.s20),
          const SizedBox(width: AppSize.s8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: ColorManager.white,
                fontSize: AppSize.s14,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _getBackgroundColor(type),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s8),
      ),
      margin: const EdgeInsets.all(AppSize.s16),
      duration: duration,
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: ColorManager.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static IconData _getIcon(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Icons.check_circle_outline;
      case SnackBarType.error:
        return Icons.error_outline;
      case SnackBarType.warning:
        return Icons.warning_amber_outlined;
      case SnackBarType.info:
        return Icons.info_outline;
    }
  }

  static Color _getBackgroundColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return ColorManager.success;
      case SnackBarType.error:
        return ColorManager.error;
      case SnackBarType.warning:
        return ColorManager.warning;
      case SnackBarType.info:
        return ColorManager.info;
    }
  }
}
