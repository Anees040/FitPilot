import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/core/navigation/app_router.dart';
import 'package:fitpilot/application/bootstrap.dart';
import 'package:fitpilot/application/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only local, synchronous setup before runApp. Anything awaited here is time
  // the OS spends showing the bare launch window (a flat orange rectangle on
  // Android) instead of the app's own splash — so Supabase and notifications
  // are started below, after the first frame is on screen.
  FitPilotBootstrap.initializeSync();

  // The layouts are designed for one hand in portrait; landscape has no
  // reviewed design, so it is disabled rather than shipped broken.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: FitPilotApp()));

  // Fire-and-forget: the splash awaits warmUp() itself before it routes.
  unawaited(FitPilotBootstrap.warmUp());
  unawaited(FitPilotBootstrap.initNotifications());
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
    // Supabase is started after the first frame now, so `Supabase.instance`
    // would throw if read here directly. Wait for the warm-up, then subscribe.
    unawaited(_attachAuthListener());
  }

  Future<void> _attachAuthListener() async {
    if (!Env.isSupabaseConfigured) return;
    await FitPilotBootstrap.warmUp();
    if (!mounted || !FitPilotBootstrap.supabaseReady) return;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        appRouter.go('/update-password');
      }
    });
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
