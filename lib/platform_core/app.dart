import 'package:flutter/material.dart';
import 'router.dart';

class NeuroVisionApp extends StatelessWidget {
  const NeuroVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroVision',
      debugShowCheckedModeBanner: false,
      home: const AppRouter(),
    );
  }
}
