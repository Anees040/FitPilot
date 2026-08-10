import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/core/navigation/app_router.dart';
import 'package:fitpilot/application/bootstrap.dart';
import 'package:fitpilot/application/providers/theme_provider.dart';

import 'package:fitpilot/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FitPilotBootstrap.initialize();
  await NotificationService().init();
  runApp(const ProviderScope(child: FitPilotApp()));
}

class FitPilotApp extends ConsumerStatefulWidget {
  const FitPilotApp({super.key});

  @override
  ConsumerState<FitPilotApp> createState() => _FitPilotAppState();
}

class _FitPilotAppState extends ConsumerState<FitPilotApp> {
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (Env.isSupabaseConfigured) {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            if (data.event == AuthChangeEvent.passwordRecovery) {
              appRouter.go('/update-password');
            }
          });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final themeColor = ref.watch(themeColorProvider);

    return MaterialApp.router(
      title: 'FitPilot',
      theme: AppTheme.getLightTheme(themeColor),
      darkTheme: AppTheme.getDarkTheme(themeColor),
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
