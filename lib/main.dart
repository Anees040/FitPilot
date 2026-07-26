import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/navigation/app_router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: FitPilotApp(),
    ),
  );
}

class FitPilotApp extends StatelessWidget {
  const FitPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FitPilot',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
