/// ============================================================
/// NeuroVision — App Router
/// ============================================================
/// Central navigation hub. Determines which module screen
/// to display based on the user's session state.
/// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'session_controller.dart';
import '../modules/learning/learning_screen.dart';
import '../modules/vision/vision_screen.dart';
import 'dashboard_screen.dart';

/// The router simply watches the [SessionController.activeModule]
/// and renders the corresponding screen. No ambiguous navigation.
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    // Pick the active screen based on the current module
    switch (session.activeModule) {
      case ActiveModule.learning:
        return const LearningScreen();
      case ActiveModule.vision:
        return const VisionScreen();
      case ActiveModule.dashboard:
        return const DashboardScreen();
    }
  }
}
