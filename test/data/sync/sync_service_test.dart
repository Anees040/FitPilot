import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/remote/remote_data_source.dart';
import 'package:fitpilot/data/sync/sync_service.dart';

class FakeRemoteDataSource extends RemoteDataSource {
  final List<Map<String, dynamic>> upserted = [];
  bool failNext = false;
  final List<Map<String, dynamic>> toPull = [];

  FakeRemoteDataSource() : super(null);

  @override
  Future<void> upsertRows(String table, List<Map<String, dynamic>> rows) async {
    if (failNext) {
      failNext = false;
      throw Exception('Fake network error');
    }
    upserted.addAll(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> pullSince(
    String table,
    String since,
  ) async {
    if (table == 'profile') return toPull;
    return [];
  }
}

void main() {
  late Database db;
  late FakeRemoteDataSource remote;
  late SyncService syncService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.inMemory();
    remote = FakeRemoteDataSource();
    syncService = SyncService(db: db, remote: remote, userId: 'user_123');
  });

  tearDown(() async {
    // allow pending _emitStatus to complete
    await Future.delayed(const Duration(milliseconds: 100));
    await db.close();
  });

  test('queue processing in batches of 50', () async {
    for (int i = 0; i < 120; i++) {
      await db.insert('food_logs', {
        'id': 'log_$i',
        'quantity': 1,
        'kcal_min': 100,
        'kcal_max': 200,
        'source': 'search',
        'logged_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('sync_queue', {
        'table_name': 'food_logs',
        'row_id': 'log_$i',
        'op': 'insert',
        'queued_at': DateTime.now().toIso8601String(),
      });
    }

    await syncService.syncNow();
    expect(remote.upserted.length, 120);

    final queue = await db.query('sync_queue');
    expect(queue.isEmpty, true);
  });

  test('failure increments attempts and backoff quarantine', () async {
    await db.insert('food_logs', {
      'id': 'log_1',
      'quantity': 1,
      'kcal_min': 100,
      'kcal_max': 200,
      'source': 'search',
      'logged_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.insert('sync_queue', {
      'table_name': 'food_logs',
      'row_id': 'log_1',
      'op': 'insert',
      'queued_at': DateTime.now().toIso8601String(),
    });

    remote.failNext = true;
    await syncService.syncNow();

    expect(remote.upserted.length, 0);

    var queue = await db.query('sync_queue');
    expect(queue.length, 1);
    expect(queue.first['attempts'], 1);

    for (int i = 0; i < 9; i++) {
      await db.rawUpdate(
        "UPDATE sync_queue SET queued_at = '2000-01-01T00:00:00Z'",
      );
      remote.failNext = true;
      await syncService.syncNow();
    }

    queue = await db.query('sync_queue');
    expect(queue.first['attempts'], 10);

    await db.rawUpdate(
      "UPDATE sync_queue SET queued_at = '2000-01-01T00:00:00Z'",
    );
    await syncService.syncNow();
    expect(remote.upserted.length, 0);
  });

  test('pull phase last-write-wins', () async {
    await db.insert('profile', {
      'id': 1,
      'weight_kg': 70.0,
      'height_cm': 170,
      'age': 25,
      'activity_level': 'light',
      'allowance_kcal': 300,
      'equipment': '[]',
      'updated_at': DateTime(2025).toIso8601String(),
    });

    remote.toPull.add({
      'id': 'user_123',
      'weight_kg': 75.0,
      'updated_at': DateTime(2026).toIso8601String(),
    });

    await syncService.syncNow();

    final local = await db.query('profile');
    expect(local.first['weight_kg'], 75.0);

    await db.update('profile', {
      'weight_kg': 80.0,
      'updated_at': DateTime(2027).toIso8601String(),
    });

    remote.toPull.clear();
    remote.toPull.add({
      'id': 'user_123',
      'weight_kg': 75.0,
      'updated_at': DateTime(2026).toIso8601String(),
    });

    await syncService.syncNow();
    final local2 = await db.query('profile');
    expect(local2.first['weight_kg'], 80.0);
  });
}
