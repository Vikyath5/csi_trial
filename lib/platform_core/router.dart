import 'package:flutter/material.dart';
import '../modules/adhd/adhd_entry.dart';
import '../modules/tactile/tactile_entry.dart';
import 'module_resolver.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // TEMP: hardcoded, later from Supabase
    final mode = ModuleResolver.resolve('adhd');

    switch (mode) {
      case ActiveModule.tactile:
        return const TactileEntry();
      case ActiveModule.adhd:
      default:
        return const ADHDEntry();
    }
  }
}
