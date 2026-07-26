import 'package:sqflite/sqflite.dart';

import '../../domain/entities/food_log.dart';
import '../../domain/entities/kcal_range.dart';

/// Repository for food log CRUD.
class LogRepository {
  final Database db;

  const LogRepository(this.db);

  /// Add a new food log.
  Future<void> add(FoodLog log) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('food_logs', {
      'id': log.id,
      'food_id': log.foodId,
      'custom_name': log.customName,
      'quantity': log.quantity,
      'kcal_min': log.kcal.min,
      'kcal_max': log.kcal.max,
      'source': log.source.name,
      'logged_at': log.loggedAt.toIso8601String(),
      'updated_at': now,
      'deleted_at': log.deletedAt?.toIso8601String(),
    });
    await _enqueue('food_logs', log.id, 'insert');
  }

  /// Update an existing food log.
  Future<void> update(FoodLog log) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'food_logs',
      {
        'food_id': log.foodId,
        'custom_name': log.customName,
        'quantity': log.quantity,
        'kcal_min': log.kcal.min,
        'kcal_max': log.kcal.max,
        'source': log.source.name,
        'logged_at': log.loggedAt.toIso8601String(),
        'updated_at': now,
        'deleted_at': log.deletedAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [log.id],
    );
    await _enqueue('food_logs', log.id, 'update');
  }

  /// Soft-delete a food log by setting its deleted_at timestamp.
  Future<void> softDelete(String id, DateTime now) async {
    await db.update(
      'food_logs',
      {
        'deleted_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueue('food_logs', id, 'soft_delete');
  }

  /// Returns all non-deleted logs for a given day.
  Future<List<FoodLog>> forDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day).toIso8601String();
    final dayEnd = DateTime(
      day.year,
      day.month,
      day.day,
      23,
      59,
      59,
    ).toIso8601String();
    final rows = await db.query(
      'food_logs',
      where: 'logged_at >= ? AND logged_at <= ? AND deleted_at IS NULL',
      whereArgs: [dayStart, dayEnd],
      orderBy: 'logged_at ASC',
    );
    return rows.map(_rowToFoodLog).toList();
  }

  /// Returns logs grouped by day for a date range, excluding soft-deleted.
  Future<Map<DateTime, List<FoodLog>>> forRange(
    DateTime from,
    DateTime to,
  ) async {
    final fromStr = DateTime(from.year, from.month, from.day).toIso8601String();
    final toStr = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
    ).toIso8601String();
    final rows = await db.query(
      'food_logs',
      where: 'logged_at >= ? AND logged_at <= ? AND deleted_at IS NULL',
      whereArgs: [fromStr, toStr],
      orderBy: 'logged_at ASC',
    );

    final map = <DateTime, List<FoodLog>>{};
    for (final row in rows) {
      final log = _rowToFoodLog(row);
      final dayKey = DateTime(
        log.loggedAt.year,
        log.loggedAt.month,
        log.loggedAt.day,
      );
      map.putIfAbsent(dayKey, () => []).add(log);
    }
    return map;
  }

  FoodLog _rowToFoodLog(Map<String, dynamic> row) {
    return FoodLog(
      id: row['id'] as String,
      foodId: row['food_id'] as String?,
      customName: row['custom_name'] as String?,
      quantity: (row['quantity'] as num),
      kcal: KcalRange(row['kcal_min'] as int, row['kcal_max'] as int),
      source: LogSource.values.byName(row['source'] as String),
      loggedAt: DateTime.parse(row['logged_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }

  Future<void> _enqueue(String table, String rowId, String op) async {
    await db.insert('sync_queue', {
      'table_name': table,
      'row_id': rowId,
      'op': op,
      'payload': null,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }
}
