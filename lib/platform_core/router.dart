import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/adhd/adhd_entry.dart';
import '../modules/tactile/tactile_entry.dart';
import 'session_controller.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    if (session.isTactile) {
      return const TactileEntry();
    }
    return const ADHDEntry();
  }
}
