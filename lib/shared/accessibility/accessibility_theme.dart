import 'package:flutter/material.dart';

class AccessibilityTheme {
  static ThemeData baseTheme(double fontScale) {
    return ThemeData(
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: 16 * fontScale),
        bodyMedium: TextStyle(fontSize: 14 * fontScale),
      ),
    );
  }
}
