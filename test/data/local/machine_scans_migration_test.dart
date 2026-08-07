import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/repositories/machine_scan_repository.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';

/// Guards the v20 -> v21 upgrade path that every existing install takes.
///
/// Unlike a fresh `_onCreate`, this is the path that could lose user data, so
/// it runs the REAL production migration rather than a copy of it: the database
/// is created at v20 with user rows, closed, then reopened through
/// [AppDatabase] so `_onUpgrade` runs for real.
void main() {
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbPath = join(
      await databaseFactory.getDatabasesPath(),
      'machine_scans_migration_test.db',
    );
    if (File(dbPath).existsSync()) File(dbPath).deleteSync();
  });

  tearDown(() {
    if (File(dbPath).existsSync()) File(dbPath).deleteSync();
  });

  test('v20 -> v21 adds machine_scans and preserves existing user data', () async {
    // A minimal v20-shaped database holding real user rows.
    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 20,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE food_logs (
              id TEXT PRIMARY KEY,
              food_name TEXT,
              kcal_min INTEGER NOT NULL,
              kcal_max INTEGER NOT NULL,
              logged_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE profile (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              weight_kg REAL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    await oldDb.insert('food_logs', {
      'id': 'log-1',
      'food_name': 'Chicken biryani',
      'kcal_min': 600,
      'kcal_max': 800,
      'logged_at': '2026-08-01T12:00:00.000Z',
    });
    await oldDb.insert('profile', {
      'id': 1,
      'weight_kg': 78.5,
      'updated_at': '2026-08-01T12:00:00.000Z',
    });

    expect(await oldDb.getVersion(), 20);
    await oldDb.close();

    // Reopen at the current version, running the real _onUpgrade.
    final upgraded = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 21,
        onUpgrade: AppDatabase.runUpgradeForTest,
      ),
    );

    expect(await upgraded.getVersion(), 21);

    // The new table exists...
    final tables = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='machine_scans'",
    );
    expect(tables, hasLength(1), reason: 'machine_scans must be created by the v21 step');

    // ...and is usable through the repository.
    final repo = MachineScanRepository(upgraded);
    await repo.save(
      'scan-1',
      const MachineAnalysis(
        isGymMachine: true,
        machineName: 'Lat Pulldown Machine',
        confidence: 0.9,
        primaryMuscles: ['Back'],
      ),
    );
    final scans = await repo.recent();
    expect(scans, hasLength(1));
    expect(scans.first.machineName, 'Lat Pulldown Machine');

    // Pre-existing user data survived untouched.
    final logs = await upgraded.query('food_logs');
    expect(logs, hasLength(1));
    expect(logs.first['food_name'], 'Chicken biryani');
    expect(logs.first['kcal_min'], 600);
    expect(logs.first['kcal_max'], 800);

    final profile = await upgraded.query('profile');
    expect(profile, hasLength(1));
    expect(profile.first['weight_kg'], 78.5);

    await upgraded.close();
  });

  test('the v21 step is idempotent when the table already exists', () async {
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 20,
        onCreate: (db, version) async {
          // Simulate a partial/retried upgrade that already created the table.
          await db.execute('''
            CREATE TABLE machine_scans (
              id TEXT PRIMARY KEY,
              machine_name TEXT NOT NULL,
              response_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.insert('machine_scans', {
            'id': 'pre-existing',
            'machine_name': 'Leg Press',
            'response_json': '{"isGymMachine":true,"machineName":"Leg Press","confidence":0.8}',
            'created_at': '2026-08-01T12:00:00.000Z',
          });
        },
      ),
    );
    await db.close();

    final upgraded = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 21,
        onUpgrade: AppDatabase.runUpgradeForTest,
      ),
    );

    // CREATE TABLE IF NOT EXISTS must not wipe the existing row.
    final rows = await upgraded.query('machine_scans');
    expect(rows, hasLength(1));
    expect(rows.first['id'], 'pre-existing');

    await upgraded.close();
  });
}
