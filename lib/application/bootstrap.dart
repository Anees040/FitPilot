import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/local/seed_importer.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/core/services/notification_service.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'dart:async';

/// Utility to bootstrap the application's required data layers.
///
/// Startup is deliberately split in two. [initializeSync] does only what must
/// happen before the first frame — picking a sqflite factory, which is pure
/// local work — so `runApp` can draw immediately. Everything that touches the
/// network ([warmUp]) runs *after* the first frame.
///
/// The order matters more than it looks. Whatever `main()` awaits before
/// `runApp` is time the Android window spends showing `LaunchTheme`'s plain
/// `@color/splash_color`, with no logo on it. Awaiting `Supabase.initialize()`
/// there — which recovers the stored session and can hit the network to
/// refresh an expired token — held that flat orange rectangle on screen for
/// several seconds before the branded splash ever appeared.
class FitPilotBootstrap {
  static Future<void>? _warmUp;

  /// Whether [warmUp] finished its Supabase step. False both while the SDK is
  /// still starting and when it failed outright, so callers must not treat it
  /// as "the user is a guest" — only as "do not touch Supabase.instance yet".
  static bool supabaseReady = false;

  /// Local-only setup that must precede the first frame. Synchronous by
  /// design: adding an await here reintroduces the blank-launch-window delay.
  static void initializeSync() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Network and plugin setup, started right after `runApp` and awaited by the
  /// splash screen before it routes anywhere. Idempotent: repeated calls return
  /// the same future.
  static Future<void> warmUp() => _warmUp ??= _runWarmUp();

  static Future<void> _runWarmUp() async {
    if (Env.isSupabaseConfigured) {
      try {
        // A hard cap so a captive portal or a dead DNS server cannot strand the
        // splash forever. On timeout the app continues; the auth repository
        // simply has no session to read and the user lands on /welcome.
        await Supabase.initialize(
          url: Env.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: Env.supabaseAnonKey,
        ).timeout(const Duration(seconds: 12));
        supabaseReady = true;
      } catch (e) {
        debugPrint(
          'Supabase initialization failed, continuing in guest mode: $e',
        );
      }
    }
  }

  /// Local notification scheduling. Deliberately not part of [warmUp]: nothing
  /// on the first screen depends on it, so it must not sit on the launch path.
  static Future<void> initNotifications() async {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  /// Retained for callers (and tests) that want the whole startup sequence as
  /// one awaitable unit.
  static Future<void> initialize() async {
    initializeSync();
    await warmUp();
  }

  static Future<void> importSeedData() async {
    try {
      final db = await AppDatabase.instance();
      final importer = SeedImporter(db);
      await importer.importAll();
    } catch (e) {
      debugPrint('Seed import failed: $e');
      rethrow;
    }
  }
}
