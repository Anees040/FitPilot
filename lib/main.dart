import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/navigation/app_router.dart';
import 'package:fitpilot/application/bootstrap.dart';
import 'package:fitpilot/application/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FitPilotBootstrap.initialize();
  runApp(const ProviderScope(child: FitPilotApp()));
}

class FitPilotApp extends ConsumerWidget {
  const FitPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'FitPilot',
      theme: AppTheme.getLightTheme(),
      darkTheme: AppTheme.getDarkTheme(),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final scale = mediaQuery.textScaler.scale(14) / 14;
        final clampedScale = scale.clamp(0.85, 1.15);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(clampedScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
