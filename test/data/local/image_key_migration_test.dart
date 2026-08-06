import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';

/// The v18 shape of the two tables migration 19 touches — no `image_key`,
/// no `photo_path`.
Future<Database> _openV18(String path) async {
  return databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 18,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute('''
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
        await db.execute('''
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
      },
    ),
  );
}

Set<String> _columnNames(List<Map<String, Object?>> pragma) =>
    pragma.map((r) => r['name'] as String).toSet();

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migration 18 to 19 adds the columns, keeps data, backfills keys', () async {
    // A real file, because the upgrade has to survive a close and reopen —
    // an in-memory database would come back blank.
    final path = p.join(
      await databaseFactory.getDatabasesPath(),
      'fitpilot.db',
    );
    if (File(path).existsSync()) File(path).deleteSync();

    final v18 = await _openV18(path);
    await v18.insert('food_catalog', {
      'id': 'biryani-chicken-1',
      'name': 'Chicken Biryani',
      'portion_label': '1 plate',
      'grams': 350,
      'kcal_min': 480,
      'kcal_max': 700,
      'is_verified': 1,
    });
    await v18.insert('food_catalog', {
      'id': 'unknown-1',
      'name': 'Zorbulax Surprise',
      'portion_label': '1 plate',
      'kcal_min': 10,
      'kcal_max': 20,
      'is_verified': 1,
    });
    await v18.insert('food_logs', {
      'id': 'log-1',
      'food_id': 'biryani-chicken-1',
      'quantity': 1.0,
      'kcal_min': 480,
      'kcal_max': 700,
      'source': 'search',
      'logged_at': '2026-08-01T12:00:00.000',
      'updated_at': '2026-08-01T12:00:00.000',
    });
    await v18.close();

    // Reopening through AppDatabase runs the real _onUpgrade against the
    // v18 file we just wrote.
    final db = await AppDatabase.instance();
    addTearDown(() async {
      await db.close();
      if (File(path).existsSync()) File(path).deleteSync();
    });

    expect(
      _columnNames(await db.rawQuery('PRAGMA table_info(food_catalog)')),
      contains('image_key'),
    );
    expect(
      _columnNames(await db.rawQuery('PRAGMA table_info(food_logs)')),
      contains('photo_path'),
    );

    // The user's rows survive the upgrade.
    final logs = await db.query('food_logs');
    expect(logs.length, 1);
    expect(logs.first['id'], 'log-1');
    expect(logs.first['kcal_max'], 700);
    expect(logs.first['photo_path'], isNull);

    // Rows that predate the column get art; unmatched names stay null rather
    // than being given a wrong photo.
    final biryani = await db.query(
      'food_catalog',
      where: 'id = ?',
      whereArgs: ['biryani-chicken-1'],
    );
    expect(biryani.first['image_key'], 'biryani');
    expect(biryani.first['name'], 'Chicken Biryani');

    final unknown = await db.query(
      'food_catalog',
      where: 'id = ?',
      whereArgs: ['unknown-1'],
    );
    expect(unknown.first['image_key'], isNull);
  });

  test('the catalog name index exists after migration', () async {
    final db = await AppDatabase.inMemory();
    addTearDown(db.close);

    final indexes = await db.rawQuery('PRAGMA index_list(food_catalog)');
    expect(
      indexes.map((r) => r['name']),
      contains('idx_food_catalog_name'),
    );
  });
}
