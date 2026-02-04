import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'router.dart';
import 'session_controller.dart';

class NeuroVisionApp extends StatelessWidget {
  const NeuroVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionController()..loadMockSession(),
      child: const AppRouter(),
    );
  }
}
