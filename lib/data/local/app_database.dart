import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:fitpilot/core/utils/food_image_resolver.dart';

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
/// 15 — added some features
/// 16 — recreated exercises table to remove equipment NOT NULL constraint
/// 17 — added avatar_url to profile
/// 18 — removed exercises with missing media from the seed
/// 19 — added image_key to food_catalog and photo_path to food_logs
///      (both LOCAL-ONLY: never pushed to or pulled from Supabase)
/// 20 — goal-based training programs: metadata columns on programs, title/
///      focus/kind/notes on program_sessions, new program_session_items
///      (multi-exercise days) and program_completions tables. Both new tables
///      are LOCAL-ONLY — bundled seed content and per-device plan progress,
///      never pushed to or pulled from Supabase. Seed-owned program rows are
///      cleared so the reworked importer reseeds them with the new shape.
class AppDatabase {
  static Database? _db;

  /// Returns the singleton database instance.
  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'fitpilot.db');
    _db = await openDatabase(
      path,
      version: 20,
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
      version: 20,
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
        image_key TEXT,
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
        deleted_at TEXT,
        photo_path TEXT
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
        onboarding_complete INTEGER NOT NULL DEFAULT 0,
        avatar_url TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE programs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        goal TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT 'beginner',
        focus TEXT NOT NULL DEFAULT 'full_body',
        equipment TEXT NOT NULL DEFAULT 'none',
        duration_days INTEGER NOT NULL DEFAULT 0,
        days_per_week INTEGER NOT NULL DEFAULT 0,
        hero_image TEXT,
        sort_index INTEGER NOT NULL DEFAULT 100
      )
    ''');

    batch.execute('''
      CREATE TABLE program_sessions (
        id TEXT PRIMARY KEY,
        program_id TEXT NOT NULL,
        week_number INTEGER NOT NULL,
        day_number INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        minutes INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        focus TEXT,
        kind TEXT NOT NULL DEFAULT 'workout',
        notes TEXT
      )
    ''');

    // Ordered exercise list for a session. A rest day has zero items.
    // LOCAL-ONLY: bundled seed content, never synced.
    batch.execute('''
      CREATE TABLE program_session_items (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        minutes INTEGER NOT NULL,
        detail TEXT
      )
    ''');

    // Per-device record of which program days the user finished.
    // LOCAL-ONLY: deliberately absent from the Supabase schema, like the
    // profile's active_program_* columns. Never enqueued to sync_queue.
    batch.execute('''
      CREATE TABLE program_completions (
        session_id TEXT PRIMARY KEY,
        program_id TEXT NOT NULL,
        week_number INTEGER NOT NULL,
        day_number INTEGER NOT NULL,
        kcal INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT NOT NULL
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
    batch.execute(
      'CREATE INDEX idx_program_sessions_program ON program_sessions (program_id)',
    );
    batch.execute(
      'CREATE INDEX idx_program_session_items_session ON program_session_items (session_id)',
    );
    batch.execute(
      'CREATE INDEX idx_program_completions_program ON program_completions (program_id)',
    );

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
    if (oldVersion < 15) {
      try {
        await db.execute("ALTER TABLE profile ADD COLUMN onboarding_complete INTEGER NOT NULL DEFAULT 0");
      } catch (_) {}
    }
    if (oldVersion < 16) {
      // Recreate exercises table to drop equipment NOT NULL constraint
      await db.execute('DROP TABLE IF EXISTS exercises');
      await db.execute('''
        CREATE TABLE exercises (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          muscle_group TEXT NOT NULL,
          equipment TEXT,
          burn_rate_per_min REAL NOT NULL,
          video_url TEXT,
          thumbnail_url TEXT
        )
      ''');
    }
    if (oldVersion < 17) {
      try {
        await db.execute("ALTER TABLE profile ADD COLUMN avatar_url TEXT");
      } catch (_) {}
    }
    if (oldVersion < 18) {
      await db.execute('''
        DELETE FROM exercises WHERE id IN ('dancing-vigorous', 'air-squats', 'weighted-hula-hoop')
      ''');
    }
    if (oldVersion < 19) {
      // Both columns are LOCAL-ONLY. They are deliberately absent from the
      // Supabase schema, so they must never appear in a sync push payload and
      // a pull must never overwrite them. See sync_service.dart, which builds
      // payloads from explicit column lists.
      try {
        await db.execute('ALTER TABLE food_catalog ADD COLUMN image_key TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE food_logs ADD COLUMN photo_path TEXT');
      } catch (_) {}
      // Present in _onCreate since v1, but older upgrade paths may lack it and
      // catalog search depends on it once the catalog grows past a few hundred.
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_food_catalog_name ON food_catalog (name)',
        );
      } catch (_) {}
      await _backfillImageKeys(db);
    }
    if (oldVersion < 20) {
      // Goal-based training programs.
      //
      // `programs` and `program_sessions` hold bundled seed content only — no
      // user data — so widening them and dropping the old session rows is safe;
      // the reworked importer reseeds every program on the next launch with
      // titles, rest days and globally-numbered plan days.
      //
      // `program_session_items` and `program_completions` are LOCAL-ONLY. They
      // are deliberately absent from the Supabase schema, so they must never
      // appear in a sync push payload and a pull must never write them. See
      // sync_service.dart, which builds payloads from explicit column lists and
      // pulls from a fixed table list that excludes both.
      //
      // Created first so an upgrade path that never ran the v14 step (or a
      // partial schema) still ends up with the tables before they are altered.
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
      for (final column in const [
        "level TEXT NOT NULL DEFAULT 'beginner'",
        "focus TEXT NOT NULL DEFAULT 'full_body'",
        "equipment TEXT NOT NULL DEFAULT 'none'",
        'duration_days INTEGER NOT NULL DEFAULT 0',
        'days_per_week INTEGER NOT NULL DEFAULT 0',
        'hero_image TEXT',
        'sort_index INTEGER NOT NULL DEFAULT 100',
      ]) {
        try {
          await db.execute('ALTER TABLE programs ADD COLUMN $column');
        } catch (_) {}
      }
      for (final column in const [
        "title TEXT NOT NULL DEFAULT ''",
        'focus TEXT',
        "kind TEXT NOT NULL DEFAULT 'workout'",
        'notes TEXT',
      ]) {
        try {
          await db.execute('ALTER TABLE program_sessions ADD COLUMN $column');
        } catch (_) {}
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS program_session_items (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          position INTEGER NOT NULL,
          exercise_id TEXT NOT NULL,
          minutes INTEGER NOT NULL,
          detail TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS program_completions (
          session_id TEXT PRIMARY KEY,
          program_id TEXT NOT NULL,
          week_number INTEGER NOT NULL,
          day_number INTEGER NOT NULL,
          kcal INTEGER NOT NULL DEFAULT 0,
          completed_at TEXT NOT NULL
        )
      ''');
      for (final index in const [
        'CREATE INDEX IF NOT EXISTS idx_program_sessions_program ON program_sessions (program_id)',
        'CREATE INDEX IF NOT EXISTS idx_program_session_items_session ON program_session_items (session_id)',
        'CREATE INDEX IF NOT EXISTS idx_program_completions_program ON program_completions (program_id)',
      ]) {
        try {
          await db.execute(index);
        } catch (_) {}
      }
      // Old rows use per-week day numbers and carry no title/kind; drop them so
      // the importer rebuilds every program in the v20 shape.
      await db.delete('program_sessions');
      // Until v20 no route reached the programs feature, so an active pointer
      // can only be stale test data — and it would now point at a day number
      // that no longer exists. Clear it rather than strand the user mid-plan.
      try {
        await db.update('profile', {
          'active_program_id': null,
          'active_program_week': null,
          'active_program_day': null,
        });
      } catch (_) {}
    }
  }

  /// Populates `image_key` for catalog rows that predate the column, using the
  /// same resolver the seed importer and custom-food save path use.
  static Future<void> _backfillImageKeys(Database db) async {
    final rows = await db.query(
      'food_catalog',
      columns: ['id', 'name'],
      where: 'image_key IS NULL',
    );
    if (rows.isEmpty) return;

    final batch = db.batch();
    for (final row in rows) {
      final key = resolveImageKey(row['name'] as String?);
      if (key == null) continue;
      batch.update(
        'food_catalog',
        {'image_key': key},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await batch.commit(noResult: true);
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
