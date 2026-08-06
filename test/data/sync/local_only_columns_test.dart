import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/remote/remote_data_source.dart';
import 'package:fitpilot/data/repositories/food_repository.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

/// Records what would be sent to Supabase and replays a fixed pull.
class RecordingRemote extends RemoteDataSource {
  final List<Map<String, dynamic>> upserted = [];
  final Map<String, List<Map<String, dynamic>>> pullData = {};

  RecordingRemote() : super(null);

  @override
  Future<void> upsertRows(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
  }) async {
    upserted.addAll(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> pullSince(
    String table,
    String since,
  ) async => pullData[table] ?? const [];
}

void main() {
  late Database db;
  late RecordingRemote remote;
  late SyncService sync;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.inMemory();
    remote = RecordingRemote();
    sync = SyncService(db: db, remote: remote, userId: 'user_123');
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await db.close();
  });

  test('push payloads never carry the local-only column', () async {
    // `photo_path` points at a file in this device's sandbox. The column does
    // not exist in Supabase — pushing it would fail the request outright.
    await db.insert('food_logs', {
      'id': 'log-1',
      'food_id': 'biryani-chicken-1',
      'quantity': 1.0,
      'kcal_min': 480,
      'kcal_max': 700,
      'source': 'aiPhoto',
      'logged_at': '2026-08-01T12:00:00.000',
      'updated_at': '2026-08-01T12:00:00.000',
      'photo_path': '/data/user/0/app/meal_photos/abc.jpg',
    });
    await db.insert('sync_queue', {
      'table_name': 'food_logs',
      'row_id': 'log-1',
      'op': 'insert',
      'queued_at': DateTime.now().toIso8601String(),
    });

    await sync.syncNow();

    expect(remote.upserted, isNotEmpty);
    for (final row in remote.upserted) {
      expect(row.containsKey('photo_path'), isFalse, reason: '$row');
    }
  });

  test('a saved custom food queues no image_key', () async {
    final repo = FoodRepository(db, isGuest: () => false);
    await repo.addCustomFood(
      FoodItem(
        id: 'custom-1',
        name: 'Chicken Biryani',
        portionLabel: '1 plate',
        kcalPerPortion: KcalRange(480, 700),
      ),
    );

    // Stored locally so the tile can render art...
    final stored = (await db.query(
      'food_catalog',
      where: 'id = ?',
      whereArgs: ['custom-1'],
    )).single;
    expect(stored['image_key'], 'biryani');

    // ...but kept out of the payload bound for Supabase.
    final queued = (await db.query(
      'sync_queue',
      where: 'row_id = ?',
      whereArgs: ['custom-1'],
    )).single;
    final payload =
        json.decode(queued['payload'] as String) as Map<String, dynamic>;
    expect(payload.containsKey('image_key'), isFalse, reason: '$payload');
    expect(payload['name'], 'Chicken Biryani');
  });

  test('a pull does not wipe the local-only columns', () async {
    await db.insert('food_catalog', {
      'id': 'biryani-chicken-1',
      'name': 'Chicken Biryani',
      'portion_label': '1 plate',
      'kcal_min': 480,
      'kcal_max': 700,
      'image_key': 'biryani',
      'is_verified': 1,
    });
    await db.insert('food_logs', {
      'id': 'log-1',
      'food_id': 'biryani-chicken-1',
      'quantity': 1.0,
      'kcal_min': 480,
      'kcal_max': 700,
      'source': 'aiPhoto',
      'logged_at': '2026-08-01T12:00:00.000',
      'updated_at': '2026-08-01T12:00:00.000',
      'photo_path': '/data/user/0/app/meal_photos/abc.jpg',
    });

    // The cloud sends a newer copy of both rows. Since the remote schema has
    // no image_key/photo_path, the INSERT OR REPLACE would null them unless
    // they are carried across.
    remote.pullData['food_catalog'] = [
      {
        'id': 'biryani-chicken-1',
        'name': 'Chicken Biryani',
        'portion_label': '1 plate',
        'kcal_min': 500,
        'kcal_max': 720,
        'is_verified': 1,
        'updated_at': '2026-08-02T12:00:00.000',
      },
    ];
    remote.pullData['food_logs'] = [
      {
        'id': 'log-1',
        'food_id': 'biryani-chicken-1',
        'quantity': 2.0,
        'kcal_min': 960,
        'kcal_max': 1400,
        'source': 'aiPhoto',
        'logged_at': '2026-08-01T12:00:00.000',
        'updated_at': '2026-08-02T12:00:00.000',
      },
    ];

    await sync.syncNow();

    final food = (await db.query(
      'food_catalog',
      where: 'id = ?',
      whereArgs: ['biryani-chicken-1'],
    )).single;
    // The remote edit landed...
    expect(food['kcal_min'], 500);
    // ...without taking the photo with it.
    expect(food['image_key'], 'biryani');

    final log = (await db.query(
      'food_logs',
      where: 'id = ?',
      whereArgs: ['log-1'],
    )).single;
    expect(log['quantity'], 2.0);
    expect(log['photo_path'], '/data/user/0/app/meal_photos/abc.jpg');
  });
}
