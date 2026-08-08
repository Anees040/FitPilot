import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/services/data_export_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> freshDb() async {
    final db = await AppDatabase.inMemory();
    for (final table in DataExportService.userTables) {
      await db.delete(table);
    }
    return db;
  }

  test('exports the user rows it finds', () async {
    final db = await freshDb();
    await db.insert('weight_entries', {
      'id': 'w1',
      'for_date': '2026-08-01',
      'weight_kg': 82.5,
      'updated_at': '2026-08-01T09:00:00.000',
    });
    await db.insert('food_logs', {
      'id': 'f1',
      'food_name': 'Chicken biryani',
      'quantity': 1.0,
      'kcal_min': 600,
      'kcal_max': 750,
      'source': 'catalog',
      'logged_at': '2026-08-01T13:00:00.000',
      'updated_at': '2026-08-01T13:00:00.000',
    });

    final export = await DataExportService(db).build();

    expect(export['app'], 'FitPilot');
    expect(export['formatVersion'], 1);
    expect(export['rowCount'], 2);

    final data = export['data'] as Map<String, Object?>;
    final weights = data['weight_entries'] as List;
    expect(weights.single['weight_kg'], 82.5);

    final logs = data['food_logs'] as List;
    expect(logs.single['food_name'], 'Chicken biryani');
  });

  test('leaves out the bundled seed content', () async {
    final db = await freshDb();
    final export = await DataExportService(db).build();
    final data = export['data'] as Map<String, Object?>;

    // These ship with the app and would dwarf the user's own rows.
    expect(data.containsKey('food_catalog'), isFalse);
    expect(data.containsKey('exercises'), isFalse);
    expect(data.containsKey('programs'), isFalse);
    expect(data.containsKey('program_session_items'), isFalse);
    // Transport bookkeeping, not user data.
    expect(data.containsKey('sync_queue'), isFalse);
  });

  test('the output is valid JSON', () async {
    final db = await freshDb();
    await db.insert('weight_entries', {
      'id': 'w1',
      'for_date': '2026-08-02',
      'weight_kg': 81.0,
      'updated_at': '2026-08-02T09:00:00.000',
    });

    final json = await DataExportService(db).buildJson();
    final decoded = jsonDecode(json) as Map<String, Object?>;

    expect(decoded['rowCount'], 1);
    expect(json, contains('  '), reason: 'should be pretty-printed');
  });

  test('an empty database still produces a usable export', () async {
    final db = await freshDb();
    final export = await DataExportService(db).build();

    expect(export['rowCount'], 0);
    expect(export['exportedAt'], isA<String>());
    expect(export['data'], isNotEmpty, reason: 'tables present, just empty');
  });

  test('summary counts rows per table', () async {
    final db = await freshDb();
    await db.insert('weight_entries', {
      'id': 'w1',
      'for_date': '2026-08-03',
      'weight_kg': 80.0,
      'updated_at': '2026-08-03T09:00:00.000',
    });
    await db.insert('weight_entries', {
      'id': 'w2',
      'for_date': '2026-08-04',
      'weight_kg': 79.5,
      'updated_at': '2026-08-04T09:00:00.000',
    });

    final counts = await DataExportService(db).summary();

    expect(counts['weight_entries'], 2);
    expect(counts['food_logs'], 0);
  });
}
