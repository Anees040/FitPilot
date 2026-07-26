import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (or creates) the FitPilot SQLite database.
///
/// Version 1 — tables mirror the Supabase schema with local-only additions.
class AppDatabase {
  static Database? _db;

  /// Returns the singleton database instance.
  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'fitpilot.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  /// For testing: open an in-memory database with the same schema.
  static Future<Database> inMemory() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE food_catalog (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        name_ur TEXT,
        portion_label TEXT NOT NULL,
        grams INTEGER,
        kcal_min INTEGER NOT NULL,
        kcal_max INTEGER NOT NULL,
        is_verified INTEGER NOT NULL DEFAULT 1
      )
    ''');

    batch.execute('''
      CREATE TABLE food_logs (
        id TEXT PRIMARY KEY,
        food_id TEXT,
        custom_name TEXT,
        quantity REAL NOT NULL,
        kcal_min INTEGER NOT NULL,
        kcal_max INTEGER NOT NULL,
        source TEXT NOT NULL,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE burn_completions (
        id TEXT PRIMARY KEY,
        for_date TEXT NOT NULL,
        activity TEXT NOT NULL,
        minutes INTEGER NOT NULL,
        kcal INTEGER NOT NULL,
        completed_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE weight_entries (
        id TEXT PRIMARY KEY,
        for_date TEXT NOT NULL UNIQUE,
        weight_kg REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        equipment TEXT NOT NULL,
        difficulty INTEGER NOT NULL,
        muscles TEXT NOT NULL,
        steps TEXT NOT NULL,
        mistakes TEXT NOT NULL,
        met REAL NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        weight_kg REAL,
        height_cm INTEGER,
        age INTEGER,
        gender TEXT,
        goal TEXT,
        allowance_kcal INTEGER NOT NULL DEFAULT 300,
        equipment TEXT NOT NULL DEFAULT '[]',
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        row_id TEXT NOT NULL,
        op TEXT NOT NULL,
        payload TEXT,
        queued_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Indexes.
    batch.execute(
        'CREATE INDEX idx_food_logs_logged_at ON food_logs (logged_at)');
    batch.execute(
        'CREATE INDEX idx_burn_completions_for_date ON burn_completions (for_date)');
    batch.execute(
        'CREATE INDEX idx_food_catalog_name ON food_catalog (name)');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Future migrations go here.
  }
}
