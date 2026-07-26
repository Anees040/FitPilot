import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/navigation/app_router.dart';
import 'package:fitpilot/application/bootstrap.dart';

void main() {
  runApp(const ProviderScope(child: FitPilotApp()));
}

class FitPilotApp extends StatefulWidget {
  const FitPilotApp({super.key});

  @override
  State<FitPilotApp> createState() => _FitPilotAppState();
}

class _FitPilotAppState extends State<FitPilotApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = FitPilotBootstrap.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FitPilot',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        return FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            } else if (snapshot.hasError) {
              return _buildErrorScreen(snapshot.error.toString());
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FitPilot',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontSize: 32,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppTheme.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Initialization Failed',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: AppTheme.lightTheme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _initFuture = FitPilotBootstrap.initialize();
                  });
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
