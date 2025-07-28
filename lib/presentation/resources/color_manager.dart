import 'package:flutter/material.dart';

class ColorManager {
  // Main Brand Colors (InterBridge Academy Inspired)
  static Color primary = const Color(0xffF78A30); // Warm Orange
  static Color primary2 = const Color(0xff102F5C); // Deep Blue
  static Color primary3 = const Color(0xff18100F); // Dark Brown
  static Color subtitle = const Color(0xff666666); // Medium Grey
  static Color darkPrimary = const Color(0xff6D4ACD); // Purple

  // Enhanced Brand Colors
  static Color primaryLight = const Color(0xFFFF9F5A); // Light Orange
  static Color primaryDark = const Color(0xFFE67A1A); // Dark Orange
  static Color primary2Light = const Color(0xFF1A4A8A); // Light Blue
  static Color primary2Dark = const Color(0xFF0A1F3D); // Dark Blue

  // Neutral Colors
  static Color black = const Color(0xff000000);
  static Color white = const Color(0xffFFFFFF);
  static Color grey = const Color(0xFFCECBD3);
  static Color greyLight = const Color(0xFFF5F5F5);
  static Color greyMedium = const Color(0xFFE0E0E0);
  static Color greyDark = const Color(0xFF757575);

  // Background Colors
  static Color backgroundPrimary = const Color(
    0xFFFAFAFA,
  ); // Light Grey Background
  static Color backgroundSecondary = const Color(0xFFF8F9FA); // Very Light Grey
  static Color backgroundCard = const Color(0xFFFFFFFF); // White Cards

  // Text Colors
  static Color textPrimary = const Color(0xFF2C3E50); // Dark Blue-Grey
  static Color textSecondary = const Color(0xFF7F8C8D); // Medium Grey
  static Color textLight = const Color(0xFF95A5A6); // Light Grey

  // Status Colors
  static Color success = const Color(0xFF27AE60); // Green
  static Color warning = const Color(0xFFF39C12); // Orange
  static Color error = const Color(0xFFE74C3C); // Red
  static Color info = const Color(0xFF3498DB); // Blue

  // Legacy Colors (for backward compatibility)
  static Color lightwhite = const Color(0xffCDCBD7);
  static Color lightwhite2 = const Color(0xffE7E7E7);
  static Color lightgrey = const Color(0xffCECBD2);
  static Color lightpurple2 = const Color(0xffCFAFE1);
  static Color pink = const Color(0xFFD195EE);
  static Color darkPrimary2 = const Color(0xff635A8F);
  static Color lightPrimary = const Color(0xCCd17d11);
  static Color grey1 = const Color(0xff707070);
  static Color grey2 = const Color(0xff797979);
  static Color grey3 = Colors.white54;
  static Color grey200 = Colors.grey.shade200;
  static Color grey100 = Colors.grey.shade100;
  static Color red = const Color(0xffA72525);

  // Gradient Colors
  static LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xffF78A30), Color(0xFFE67A1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient secondaryGradient = const LinearGradient(
    colors: [Color(0xff102F5C), Color(0xFF0A1F3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient backgroundGradient = const LinearGradient(
    colors: [Color(0xFFFAFAFA), Color(0xFFF8F9FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
