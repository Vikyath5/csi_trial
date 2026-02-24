/// ============================================================
/// NeuroVision — App Shell
/// ============================================================
/// Root widget. Wraps the app in Provider and applies the
/// shared accessibility theme globally.
/// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'router.dart';
import 'session_controller.dart';
import '../shared/accessibility/accessibility_theme.dart';
import '../shared/voice/global_voice_assistant.dart';

class NeuroVisionApp extends StatelessWidget {
  const NeuroVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionController()..loadMockSession(),
      child: Consumer<SessionController>(
        builder: (context, session, _) {
          return MaterialApp(
            title: 'NeuroVision',
            debugShowCheckedModeBanner: false,

            // Apply the shared accessibility theme
            theme: AccessibilityTheme.buildTheme(
              fontScale: session.prefs.fontScale,
            ),

            home: const GlobalVoiceAssistant(
              child: AppRouter(),
            ),
          );
        },
      ),
    );
  }
}
