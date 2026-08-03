import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/burn_option.dart';

/// Repository for burn completion records.
class BurnRepository {
  final Database db;
  final bool Function() isGuest;
  static const _uuid = Uuid();

  const BurnRepository(this.db, {required this.isGuest});

  /// Record a completed burn.
  Future<void> add(
    BurnOption option,
    DateTime forDate,
    DateTime completedAt,
  ) async {
    final id = _uuid.v4();
    final forDateStr = DateTime(
      forDate.year,
      forDate.month,
      forDate.day,
    ).toIso8601String().split('T').first;
    await db.insert('burn_completions', {
      'id': id,
      'for_date': forDateStr,
      'activity': option.activity,
      'minutes': option.minutes,
      'kcal': option.kcal,
      'completed_at': completedAt.toIso8601String(),
      'updated_at': completedAt.toUtc().toIso8601String(),
    });
    await _enqueue('burn_completions', id, 'insert');
  }

  /// Returns total kcal burned for a given day.
  Future<int> burnedKcalForDay(DateTime day) async {
    final dayStr = DateTime(
      day.year,
      day.month,
      day.day,
    ).toIso8601String().split('T').first;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(kcal), 0) AS total FROM burn_completions WHERE for_date = ?',
      [dayStr],
    );
    return Sqflite.firstIntValue(result) ?? 0;
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
