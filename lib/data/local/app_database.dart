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
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _repairLogs(_db!);
    return _db!;
  }

  /// For testing: open an in-memory database with the same schema.
  static Future<Database> inMemory() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _repairLogs(db);
    return db;
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
        food_name TEXT,
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
        category TEXT NOT NULL DEFAULT 'indoor',
        subcategory TEXT,
        met REAL NOT NULL DEFAULT 5.0,
        equipment TEXT,
        primary_muscles TEXT NOT NULL DEFAULT '[]',
        secondary_muscles TEXT NOT NULL DEFAULT '[]',
        difficulty INTEGER NOT NULL DEFAULT 1,
        pace_tier TEXT NOT NULL DEFAULT 'moderate',
        steps TEXT NOT NULL DEFAULT '[]',
        mistakes TEXT NOT NULL DEFAULT '[]',
        media_asset TEXT,
        video_url TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        weight_kg REAL,
        goal_weight_kg REAL,
        height_cm INTEGER,
        age INTEGER,
        gender TEXT,
        goal TEXT,
        activity_level TEXT NOT NULL DEFAULT 'light',
        allowance_kcal INTEGER NOT NULL DEFAULT 300,
        target_override INTEGER,
        equipment TEXT NOT NULL DEFAULT '[]',
        theme_mode TEXT NOT NULL DEFAULT 'system',
        plan_category_pref TEXT NOT NULL DEFAULT 'recommended',
        plan_pace_pref TEXT NOT NULL DEFAULT 'any',
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
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE saved_products (
        barcode TEXT PRIMARY KEY,
        quantity REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE notification_prefs (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        meal_reminders_enabled INTEGER NOT NULL DEFAULT 0,
        meal_times TEXT NOT NULL DEFAULT '["08:00", "13:00", "19:00"]',
        streak_risk_enabled INTEGER NOT NULL DEFAULT 0,
        milestones_enabled INTEGER NOT NULL DEFAULT 0,
        global_mute INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Indexes.
    batch.execute(
      'CREATE INDEX idx_food_logs_logged_at ON food_logs (logged_at)',
    );
    batch.execute(
      'CREATE INDEX idx_burn_completions_for_date ON burn_completions (for_date)',
    );
    batch.execute('CREATE INDEX idx_food_catalog_name ON food_catalog (name)');
    batch.execute('CREATE INDEX idx_exercises_category ON exercises (category)');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE profile ADD COLUMN activity_level TEXT NOT NULL DEFAULT 'light'",
      );
      await db.execute(
        "ALTER TABLE profile ADD COLUMN target_override INTEGER",
      );
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          "ALTER TABLE sync_queue ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0",
        );
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sync_queue ADD COLUMN last_error TEXT");
      } catch (_) {}
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE saved_products (
          barcode TEXT PRIMARY KEY,
          quantity REAL NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE profile ADD COLUMN goal_weight_kg REAL");
      await db.execute('''
        CREATE TABLE notification_prefs (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          meal_reminders_enabled INTEGER NOT NULL DEFAULT 0,
          meal_times TEXT NOT NULL DEFAULT '["08:00", "13:00", "19:00"]',
          streak_risk_enabled INTEGER NOT NULL DEFAULT 0,
          milestones_enabled INTEGER NOT NULL DEFAULT 0,
          global_mute INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE profile ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'",
      );
    }
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE food_logs ADD COLUMN food_name TEXT");
      await db.execute('''
        UPDATE food_logs
        SET food_name = (
          SELECT name FROM food_catalog WHERE food_catalog.id = food_logs.food_id
        )
        WHERE food_name IS NULL AND food_id IS NOT NULL
      ''');
    }
    if (oldVersion < 8) {
      // Migrate exercises table from old v7 schema (columns: id, name,
      // category, equipment, difficulty, muscles, steps, mistakes, met)
      // to v8 schema with new columns.
      // SQLite ALTER TABLE only supports ADD COLUMN, so we add new columns
      // and migrate data.
      try {
        await db.execute(
          "ALTER TABLE exercises ADD COLUMN subcategory TEXT",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE exercises ADD COLUMN primary_muscles TEXT NOT NULL DEFAULT '[]'",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE exercises ADD COLUMN secondary_muscles TEXT NOT NULL DEFAULT '[]'",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE exercises ADD COLUMN pace_tier TEXT NOT NULL DEFAULT 'moderate'",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE exercises ADD COLUMN media_asset TEXT",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE exercises ADD COLUMN video_url TEXT",
        );
      } catch (_) {}

      // Copy old muscles column into primary_muscles for existing rows
      await db.execute('''
        UPDATE exercises SET primary_muscles = muscles
        WHERE primary_muscles = '[]' AND muscles IS NOT NULL AND muscles != '[]'
      ''');

      // Compute pace_tier from met for existing rows
      await db.execute('''
        UPDATE exercises SET pace_tier = 'quick'
        WHERE met >= 8.0 AND pace_tier = 'moderate'
      ''');
      await db.execute('''
        UPDATE exercises SET pace_tier = 'easy'
        WHERE met < 5.0 AND pace_tier = 'moderate'
      ''');

      // Clear old exercises so seed importer will re-import the new 60
      await db.execute('DELETE FROM exercises');

      // Add index on category for faster filtering
      try {
        await db.execute(
          'CREATE INDEX idx_exercises_category ON exercises (category)',
        );
      } catch (_) {}
    }
    if (oldVersion < 9) {
      await db.execute(
        "ALTER TABLE profile ADD COLUMN plan_category_pref TEXT NOT NULL DEFAULT 'recommended'",
      );
      await db.execute(
        "ALTER TABLE profile ADD COLUMN plan_pace_pref TEXT NOT NULL DEFAULT 'any'",
      );
    }
  }

  static Future<void> _repairLogs(Database db) async {
    // Delete logs with impossible states to prevent breaking UI
    await db.delete(
      'food_logs',
      where:
          "kcal_min > kcal_max OR kcal_min < 0 OR quantity <= 0 OR (food_id IS NULL AND (custom_name IS NULL OR trim(custom_name) = ''))",
    );
  }
}
