import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/local/seed_importer.dart';
import 'package:fitpilot/core/config/env.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:async';

/// Utility to bootstrap the application's required data layers.
class FitPilotBootstrap {
  /// Initializes required dependencies synchronously and launches async tasks in background.
  static void initialize() {
    if (kIsWeb) {
      throw UnsupportedError(
        'FitPilot is 100% offline using SQLite, which does not support Flutter Web. Please run on an Android emulator or iOS simulator.',
      );
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (Env.isSupabaseConfigured) {
      Supabase.initialize(
        url: Env.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: Env.supabaseAnonKey,
      ).catchError((e) {
        debugPrint(
          'Supabase initialization failed, continuing in guest mode: $e',
        );
        return Supabase.instance;
      });
    }

    unawaited(_importSeedData());
  }

  static Future<void> _importSeedData() async {
    try {
      final db = await AppDatabase.instance();
      final importer = SeedImporter(db);
      await importer.importAll();
    } catch (e) {
      debugPrint('Seed import failed: $e');
    }
  }
}
