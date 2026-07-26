import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/local/seed_importer.dart';

/// Utility to bootstrap the application's required data layers.
class FitPilotBootstrap {
  /// Initializes the SQLite database and runs the seed importer.
  /// Throws an exception if initialization fails.
  static Future<Database> initialize() async {
    final db = await AppDatabase.instance();
    final importer = SeedImporter(db);
    await importer.importAll();
    return db;
  }
}
