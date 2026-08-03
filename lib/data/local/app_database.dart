import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (or creates) the FitPilot SQLite database.
///
/// Version history:
///  1 — initial schema
///  2 — added activity_level, target_override to profile
///  3 — added attempts, last_error to sync_queue
///  4 — added saved_products table
///  5 — added goal_weight_kg to profile; added notification_prefs table
///  6 — added theme_mode to profile
///  7 — added food_name to food_logs
///  8 — migrated exercises table (new columns + cleared old seed data)
///  9 — added plan_category_pref, plan_pace_pref to profile
/// 10 — added image_url to food_catalog
/// 11 — added unit_kg_lb, week_starts_mon, haptics_on to profile
/// 12 — added updated_at to burn_completions; added theme_color + goal_weight_kg guards
/// 13 — added name to profile
/// 14 — added programs, program_sessions tables and active program profile fields
class AppDatabase {
  static Database? _db;

  /// Returns the singleton database instance.
  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'fitpilot.db');
    _db = await openDatabase(
      path,
      version: 14,
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
      version: 14,
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
        image_url TEXT,
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
        completed_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
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
        name TEXT,
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
        theme_color TEXT NOT NULL DEFAULT 'orange',
        plan_category_pref TEXT NOT NULL DEFAULT 'recommended',
        plan_pace_pref TEXT NOT NULL DEFAULT 'any',
        unit_kg_lb TEXT NOT NULL DEFAULT 'kg',
        week_starts_mon INTEGER NOT NULL DEFAULT 1,
        haptics_on INTEGER NOT NULL DEFAULT 1,
        active_program_id TEXT,
        active_program_week INTEGER,
        active_program_day INTEGER,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE programs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        goal TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE program_sessions (
        id TEXT PRIMARY KEY,
        program_id TEXT NOT NULL,
        week_number INTEGER NOT NULL,
        day_number INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        minutes INTEGER NOT NULL
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

    batch.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
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
      try {
        await db.execute("ALTER TABLE profile ADD COLUMN goal_weight_kg REAL");
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notification_prefs (
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
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'",
        );
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE food_logs ADD COLUMN food_name TEXT");
      } catch (_) {}
      await db.execute('''
        UPDATE food_logs
        SET food_name = (
          SELECT name FROM food_catalog WHERE food_catalog.id = food_logs.food_id
        )
        WHERE food_name IS NULL AND food_id IS NOT NULL
      ''');
    }
    if (oldVersion < 8) {
      // Migrate exercises table from old v7 schema to v8 schema with new columns.
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

      // Copy old muscles column into primary_muscles for existing rows.
      await db.execute('''
        UPDATE exercises SET primary_muscles = muscles
        WHERE primary_muscles = '[]' AND muscles IS NOT NULL AND muscles != '[]'
      ''');

      // Compute pace_tier from met for existing rows.
      await db.execute('''
        UPDATE exercises SET pace_tier = 'quick'
        WHERE met >= 8.0 AND pace_tier = 'moderate'
      ''');
      await db.execute('''
        UPDATE exercises SET pace_tier = 'easy'
        WHERE met < 5.0 AND pace_tier = 'moderate'
      ''');

      // Clear old exercises so seed importer will re-import the new 60.
      await db.execute('DELETE FROM exercises');

      // Add index on category for faster filtering.
      try {
        await db.execute(
          'CREATE INDEX idx_exercises_category ON exercises (category)',
        );
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN plan_category_pref TEXT NOT NULL DEFAULT 'recommended'",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN plan_pace_pref TEXT NOT NULL DEFAULT 'any'",
        );
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
          "ALTER TABLE food_catalog ADD COLUMN image_url TEXT",
        );
      } catch (_) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN unit_kg_lb TEXT NOT NULL DEFAULT 'kg'",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN week_starts_mon INTEGER NOT NULL DEFAULT 1",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN haptics_on INTEGER NOT NULL DEFAULT 1",
        );
      } catch (_) {}
    }
    if (oldVersion < 12) {
      // Add updated_at to burn_completions (required for sync pull/push).
      try {
        await db.execute(
          "ALTER TABLE burn_completions ADD COLUMN updated_at TEXT NOT NULL DEFAULT '2020-01-01T00:00:00.000Z'",
        );
      } catch (_) {}
      // Add theme_color to profile for users upgrading from older versions.
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN theme_color TEXT NOT NULL DEFAULT 'orange'",
        );
      } catch (_) {}
      // goal_weight_kg might already exist from v5 migration.
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN goal_weight_kg REAL",
        );
      } catch (_) {}
      // Create sync_metadata if missing (previously created on-the-fly).
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_metadata (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 13) {
      try {
        await db.execute(
          "ALTER TABLE profile ADD COLUMN name TEXT",
        );
      } catch (_) {}
    }
    if (oldVersion < 14) {
      try {
        await db.execute("ALTER TABLE profile ADD COLUMN active_program_id TEXT");
        await db.execute("ALTER TABLE profile ADD COLUMN active_program_week INTEGER");
        await db.execute("ALTER TABLE profile ADD COLUMN active_program_day INTEGER");
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS programs (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          goal TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS program_sessions (
          id TEXT PRIMARY KEY,
          program_id TEXT NOT NULL,
          week_number INTEGER NOT NULL,
          day_number INTEGER NOT NULL,
          exercise_id TEXT NOT NULL,
          minutes INTEGER NOT NULL
        )
      ''');
    }
  }

  static Future<void> _repairLogs(Database db) async {
    // Delete logs with impossible states to prevent breaking UI.
    await db.delete(
      'food_logs',
      where:
          "kcal_min > kcal_max OR kcal_min < 0 OR quantity <= 0 OR (food_id IS NULL AND (custom_name IS NULL OR trim(custom_name) = ''))",
    );
  }

  /// Wipes all user-specific data from the local database and resets the profile.
  /// This must be called during sign-out to prevent data bleeding between accounts.
  static Future<void> clearUserData(Database db) async {
    final batch = db.batch();
    
    batch.delete('food_logs');
    batch.delete('weight_entries');
    batch.delete('burn_completions');
    batch.delete('sync_queue');
    
    // Clear sync metadata so the next user triggers a full initial pull
    try {
      batch.delete('sync_metadata');
    } catch (_) {}

    // Reset profile to a blank guest state
    batch.delete('profile');
    batch.insert('profile', {
      'id': 1,
      'gender': 'unspecified',
      'goal': 'maintain',
      'activity_level': 'light',
      'equipment': '[]',
      'allowance_kcal': 300,
      'theme_mode': 'system',
      'theme_color': 'orange',
      'plan_category_pref': 'recommended',
      'plan_pace_pref': 'any',
      'unit_kg_lb': 'kg',
      'week_starts_mon': 1,
      'haptics_on': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await batch.commit();
  }
}
