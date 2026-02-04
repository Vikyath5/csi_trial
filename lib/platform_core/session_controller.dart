import 'package:flutter/material.dart';

enum AccessibilityMode { adhd, tactile }

class SessionController extends ChangeNotifier {
  // User info
  String? userId;

  // Accessibility
  AccessibilityMode accessibilityMode = AccessibilityMode.adhd;
  double fontScale = 1.0;
  bool vibrationEnabled = false;

  // TEMP: Local mock (will be replaced by Supabase)
  void loadMockSession() {
    userId = "demo_user";
    accessibilityMode = AccessibilityMode.adhd;
    fontScale = 1.2;
    vibrationEnabled = true;
    notifyListeners();
  }

  bool get isADHD => accessibilityMode == AccessibilityMode.adhd;
  bool get isTactile => accessibilityMode == AccessibilityMode.tactile;
}
