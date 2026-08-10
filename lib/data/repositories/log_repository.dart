import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:fitpilot/core/utils/type_readers.dart';

import '../../domain/entities/food_log.dart';
import '../../domain/entities/kcal_range.dart';

/// Repository for food log CRUD.
class LogRepository {
  final Database db;
  final bool Function() isGuest;

  const LogRepository(this.db, {required this.isGuest});

  /// Add a new food log.
  Future<void> add(FoodLog log) async {
    _validateLog(log);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('food_logs', {
      'id': log.id,
      'food_id': log.foodId,
      'food_name': log.foodName,
      'custom_name': log.customName,
      'quantity': log.quantity,
      'kcal_min': log.kcal.min,
      'kcal_max': log.kcal.max,
      'source': log.source.name,
      'logged_at': log.loggedAt.toIso8601String(),
      'updated_at': now,
      'deleted_at': log.deletedAt?.toIso8601String(),
      'photo_path': log.photoPath,
      'protein_g': log.proteinG,
    });
    await _enqueue('food_logs', log.id, 'insert');
  }

  /// Update an existing food log.
  Future<void> update(FoodLog log) async {
    _validateLog(log);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'food_logs',
      {
        'food_id': log.foodId,
        'food_name': log.foodName,
        'custom_name': log.customName,
        'quantity': log.quantity,
        'kcal_min': log.kcal.min,
        'kcal_max': log.kcal.max,
        'source': log.source.name,
        'logged_at': log.loggedAt.toIso8601String(),
        'updated_at': now,
        'deleted_at': log.deletedAt?.toIso8601String(),
        'photo_path': log.photoPath,
        'protein_g': log.proteinG,
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
        'deleted_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
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
    final rows = await db.rawQuery(
      '''
      SELECT food_logs.*, food_catalog.name as catalog_name
      FROM food_logs
      LEFT JOIN food_catalog ON food_logs.food_id = food_catalog.id
      WHERE logged_at >= ? AND logged_at <= ? AND deleted_at IS NULL
      ORDER BY logged_at ASC
      ''',
      [dayStart, dayEnd],
    );
    return rows.map(_rowToFoodLog).whereType<FoodLog>().toList();
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
    
    final rows = await db.rawQuery(
      '''
      SELECT food_logs.*, food_catalog.name as catalog_name
      FROM food_logs
      LEFT JOIN food_catalog ON food_logs.food_id = food_catalog.id
      WHERE logged_at >= ? AND logged_at <= ? AND deleted_at IS NULL
      ORDER BY logged_at ASC
      ''',
      [fromStr, toStr],
    );

    final map = <DateTime, List<FoodLog>>{};
    for (final row in rows) {
      final log = _rowToFoodLog(row);
      if (log == null) continue;
      final dayKey = DateTime(
        log.loggedAt.year,
        log.loggedAt.month,
        log.loggedAt.day,
      );
      map.putIfAbsent(dayKey, () => []).add(log);
    }
    return map;
  }

  FoodLog? _rowToFoodLog(Map<String, dynamic> row) {
    try {
      final foodName = row['food_name'] as String? ?? row['catalog_name'] as String?;
      return FoodLog(
        id: row['id'] as String,
        foodId: row['food_id'] as String?,
        foodName: foodName,
        customName: row['custom_name'] as String?,
        quantity: TolerantReader.readDouble(row['quantity']) ?? 1.0,
        kcal: KcalRange(
          TolerantReader.readInt(row['kcal_min']) ?? 0,
          TolerantReader.readInt(row['kcal_max']) ?? 0,
        ),
        source: LogSource.values.byName(row['source'] as String),
        loggedAt: DateTime.parse(row['logged_at'] as String),
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
        photoPath: row['photo_path'] as String?,
        proteinG: TolerantReader.readDouble(row['protein_g']),
      );
    } catch (e) {
      assert(() {
        debugPrint('Skipping corrupt row ${row['id']}: $e');
        return true;
      }());
      return null;
    }
  }

  void _validateLog(FoodLog log) {
    if (log.kcal.min > log.kcal.max) throw ArgumentError('min > max');
    if (log.kcal.min < 0) throw ArgumentError('min < 0');
    if (log.quantity <= 0) throw ArgumentError('quantity <= 0');
    if (log.foodId == null && (log.customName == null || log.customName!.trim().isEmpty)) {
      throw ArgumentError('Custom name required if no foodId');
    }
  }

  Future<void> _enqueue(String table, String rowId, String op) async {
    if (isGuest()) return; // Guest Mode Shield
    await db.insert('sync_queue', {
      'table_name': table,
      'row_id': rowId,
      'op': op,
      'payload': null,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }
}
