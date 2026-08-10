import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/local/seed_importer.dart';
import 'package:fitpilot/core/config/env.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'dart:async';

/// Utility to bootstrap the application's required data layers.
class FitPilotBootstrap {
  /// Initializes required dependencies. Awaiting Supabase keeps the native
  /// splash visible until the SDK is ready, preventing a blank scaffold flash.
  static Future<void> initialize() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (Env.isSupabaseConfigured) {
      try {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: Env.supabaseAnonKey,
        );
      } catch (e) {
        debugPrint(
          'Supabase initialization failed, continuing in guest mode: $e',
        );
      }
    }
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
