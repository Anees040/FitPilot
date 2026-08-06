import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fitpilot/data/repositories/log_repository.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        row_id TEXT NOT NULL,
        op TEXT NOT NULL,
        payload TEXT,
        attempts INTEGER DEFAULT 0,
        queued_at TEXT NOT NULL,
        last_attempt_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE food_logs (
        id TEXT PRIMARY KEY,
        food_id TEXT,
        food_name TEXT NOT NULL,
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
  });

  tearDown(() async {
    await db.close();
  });

  test('Guest Mode Shield prevents enqueueing to sync_queue', () async {
    final logRepo = LogRepository(db, isGuest: () => true);

    final log = FoodLog(
      id: 'test_123',
      foodName: 'Apple',
      customName: 'Apple',
      quantity: 1.0,
      kcal: KcalRange(50, 60),
      source: LogSource.search,
      loggedAt: DateTime.now(),
    );

    await logRepo.add(log);

    final queueRows = await db.query('sync_queue');
    expect(queueRows.isEmpty, true, reason: 'Guest mode shield failed: row was enqueued.');
  });
  
  test('Account Mode allows enqueueing to sync_queue', () async {
    final logRepo = LogRepository(db, isGuest: () => false);

    final log = FoodLog(
      id: 'test_456',
      foodName: 'Banana',
      customName: 'Banana',
      quantity: 1.0,
      kcal: KcalRange(90, 105),
      source: LogSource.search,
      loggedAt: DateTime.now(),
    );

    await logRepo.add(log);

    final queueRows = await db.query('sync_queue');
    expect(queueRows.length, 1, reason: 'Account mode failed to enqueue.');
    expect(queueRows.first['table_name'], 'food_logs');
  });
}
