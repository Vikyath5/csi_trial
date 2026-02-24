/// ============================================================
/// NeuroVision — Main Entry Point
/// ============================================================
/// Launches the NeuroVision assistive learning platform.
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'platform_core/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for consistent accessible layout
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark, high-contrast theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const NeuroVisionApp());
}
