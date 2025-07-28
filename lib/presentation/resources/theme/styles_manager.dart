import 'package:flutter/material.dart';

import '../font_manager.dart';

TextStyle _getTextStyleQuickSand({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
}) {
  return TextStyle(
    fontFamily: FontConstants.fontFamilyQuicksand,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
  );
}

// regular style

TextStyle getRegularStyleQuickSand({
  double fontSize = FontSize.s12,
  required Color color,
}) {
  return _getTextStyleQuickSand(
    fontSize: fontSize,
    fontWeight: FontWeightManager.regular,
    color: color,
  );
}

// medium style

TextStyle getMediumStyleQuickSand({
  double fontSize = FontSize.s12,
  required Color color,
}) {
  return _getTextStyleQuickSand(
    fontSize: fontSize,
    fontWeight: FontWeightManager.medium,
    color: color,
  );
}

// medium style

TextStyle getLightStyleQuickSand({
  double fontSize = FontSize.s12,
  required Color color,
}) {
  return _getTextStyleQuickSand(
    fontSize: fontSize,
    fontWeight: FontWeightManager.light,
    color: color,
  );
}

// bold style

TextStyle getBoldStyleQuickSand({
  double fontSize = FontSize.s12,
  required Color color,
}) {
  return _getTextStyleQuickSand(
    fontSize: fontSize,
    fontWeight: FontWeightManager.bold,
    color: color,
  );
}

// semibold style

TextStyle getSemiBoldStyleQuickSand({
  double fontSize = FontSize.s12,
  required Color color,
}) {
  return _getTextStyleQuickSand(
    fontSize: fontSize,
    fontWeight: FontWeightManager.semiBold,
    color: color,
  );
}
