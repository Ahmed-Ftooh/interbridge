import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/font_manager.dart';
import 'package:interbridge/presentation/resources/theme/styles_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

ThemeData getApplicationTheme() {
  return ThemeData(
    // main colors
    scaffoldBackgroundColor: ColorManager.backgroundPrimary,

    // ripple effect color
    // cardview theme
    cardTheme: CardThemeData(
      color: ColorManager.backgroundCard,
      shadowColor: ColorManager.primary2.withValues(alpha: 0.1),
      elevation: AppSize.s4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s12),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: ColorManager.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSize.s20),
          topRight: Radius.circular(AppSize.s20),
        ),
      ),
    ),

    // app bar theme
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: ColorManager.primary2,
      foregroundColor: ColorManager.white,
      elevation: AppSize.s2,
      shadowColor: ColorManager.primary2.withValues(alpha: 0.3),
      titleTextStyle: getBoldStyleQuickSand(
        fontSize: FontSize.s18,
        color: ColorManager.white,
      ),
      iconTheme: IconThemeData(color: ColorManager.white, size: AppSize.s24),
    ),

    // button theme
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s12),
      ),
      disabledColor: ColorManager.greyMedium,
      buttonColor: ColorManager.primary,
      splashColor: ColorManager.primaryLight,
    ),

    // elevated button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: getBoldStyleQuickSand(
          color: ColorManager.white,
          fontSize: FontSize.s16,
        ),
        backgroundColor: ColorManager.primary,
        foregroundColor: ColorManager.white,
        elevation: AppSize.s4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSize.s12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSize.s20,
          vertical: AppSize.s12,
        ),
      ),
    ),

    // text theme
    textTheme: TextTheme(
      displayLarge: getBoldStyleQuickSand(
        color: ColorManager.textPrimary,
        fontSize: FontSize.s36,
      ),
      headlineLarge: getBoldStyleQuickSand(
        color: ColorManager.textPrimary,
        fontSize: FontSize.s22,
      ),
      headlineMedium: getSemiBoldStyleQuickSand(
        color: ColorManager.textPrimary,
        fontSize: FontSize.s22,
      ),
      titleLarge: getBoldStyleQuickSand(
        color: ColorManager.textPrimary,
        fontSize: FontSize.s18,
      ),
      titleMedium: getMediumStyleQuickSand(
        color: ColorManager.textPrimary,
        fontSize: FontSize.s18,
      ),
      titleSmall: getMediumStyleQuickSand(
        color: ColorManager.textSecondary,
        fontSize: FontSize.s16,
      ),
      bodyLarge: getRegularStyleQuickSand(
        color: ColorManager.textPrimary,
        fontSize: FontSize.s16,
      ),
      bodyMedium: getRegularStyleQuickSand(
        color: ColorManager.textSecondary,
        fontSize: FontSize.s14,
      ),
      bodySmall: getRegularStyleQuickSand(
        color: ColorManager.textLight,
        fontSize: FontSize.s12,
      ),
      labelLarge: getMediumStyleQuickSand(
        color: ColorManager.textPrimary,
        fontSize: FontSize.s16,
      ),
      labelMedium: getRegularStyleQuickSand(
        color: ColorManager.textSecondary,
        fontSize: FontSize.s14,
      ),
      labelSmall: getRegularStyleQuickSand(
        color: ColorManager.textLight,
        fontSize: FontSize.s12,
      ),
    ),

    // input decoration theme (text form field)
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: getRegularStyleQuickSand(
        color: ColorManager.textLight,
        fontSize: AppSize.s16,
      ),
      labelStyle: getMediumStyleQuickSand(
        color: ColorManager.textPrimary,
        fontSize: AppSize.s16,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSize.s16,
        vertical: AppSize.s12,
      ),
      filled: true,
      fillColor: ColorManager.backgroundCard,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSize.s12),
        borderSide: BorderSide(color: ColorManager.primary, width: AppSize.s2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSize.s12),
        borderSide: BorderSide(
          color: ColorManager.greyMedium,
          width: AppSize.s1,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSize.s12),
        borderSide: BorderSide(color: ColorManager.error, width: AppSize.s2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSize.s12),
        borderSide: BorderSide(color: ColorManager.error, width: AppSize.s2),
      ),
    ),

    // checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColorManager.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(ColorManager.white),
      side: BorderSide(color: ColorManager.greyMedium, width: AppSize.s2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s4),
      ),
    ),

    // radio theme
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColorManager.primary;
        }
        return ColorManager.greyMedium;
      }),
    ),

    // switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColorManager.white;
        }
        return ColorManager.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColorManager.primary;
        }
        return ColorManager.greyMedium;
      }),
    ),

    // divider theme
    dividerTheme: DividerThemeData(
      color: ColorManager.greyMedium,
      thickness: AppSize.s1,
      space: AppSize.s16,
    ),

    // icon theme
    iconTheme: IconThemeData(
      color: ColorManager.textPrimary,
      size: AppSize.s24,
    ),
  );
}
