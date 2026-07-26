import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('V1 to V2 migration preserves existing profile and sets safe defaults', () async {
    final dbPath = join(await databaseFactory.getDatabasesPath(), 'migration_test.db');
    if (File(dbPath).existsSync()) {
      File(dbPath).deleteSync();
    }

    // 1. Open V1 database
    final dbV1 = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
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
        },
      ),
    );

    // Insert V1 profile
    await dbV1.insert('profile', {
      'id': 1,
      'weight_kg': 75.0,
      'height_cm': 180,
      'age': 30,
      'gender': 'male',
      'goal': 'lose',
      'allowance_kcal': 400,
      'equipment': '["gym"]',
      'updated_at': '2026-07-26T00:00:00.000',
    });
    
    await dbV1.close();

    // 2. Open as V2 database to trigger onUpgrade
    final dbV2 = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE profile ADD COLUMN activity_level TEXT NOT NULL DEFAULT 'light'",
            );
            await db.execute(
              "ALTER TABLE profile ADD COLUMN target_override INTEGER",
            );
          }
        },
      ),
    );

    // 3. Assert row integrity
    final rows = await dbV2.query('profile');
    expect(rows.length, 1);
    final row = rows.first;
    
    // Existing fields preserved
    expect(row['weight_kg'], 75.0);
    expect(row['height_cm'], 180);
    expect(row['age'], 30);
    expect(row['gender'], 'male');
    expect(row['goal'], 'lose');
    expect(row['allowance_kcal'], 400);
    expect(row['equipment'], '["gym"]');
    
    // New fields populated with safe defaults
    expect(row['activity_level'], 'light');
    expect(row['target_override'], isNull);

    await dbV2.close();
    
    // Clean up
    if (File(dbPath).existsSync()) {
      File(dbPath).deleteSync();
    }
  });
}
