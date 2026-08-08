import 'package:sqflite/sqflite.dart';

import 'package:fitpilot/domain/entities/app_notification.dart';

/// Stores the in-app notification inbox.
///
/// LOCAL-ONLY: this table records what this device delivered and what the user
/// read. It is deliberately absent from the Supabase schema and must never
/// appear in a sync push payload.
class NotificationRepository {
  final Database _db;

  NotificationRepository(this._db);

  /// Hard ceiling on stored rows. The inbox is a convenience, not an archive —
  /// without a cap it would grow for the life of the install.
  static const int maxRows = 100;

  /// Newest first, which is the order the inbox renders in.
  Future<List<AppNotification>> all() async {
    final rows = await _db.query('notifications', orderBy: 'created_at DESC');
    return rows.map(AppNotification.fromRow).toList();
  }

  Future<int> unreadCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE read_at IS NULL',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Inserts only if the id is new.
  ///
  /// Deterministic ids plus `ignore` are what make the feed builder idempotent:
  /// it can run on every app resume without ever duplicating an entry, and
  /// without needing to remember when it last ran. Returns true when a row was
  /// actually added, so callers can decide whether to also fire a system
  /// notification.
  Future<bool> add(AppNotification notification) async {
    final id = await _db.insert(
      'notifications',
      notification.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id == 0) return false;
    await _trim();
    return true;
  }

  Future<void> markRead(String id) async {
    await _db.update(
      'notifications',
      {'read_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND read_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead() async {
    await _db.update(
      'notifications',
      {'read_at': DateTime.now().toIso8601String()},
      where: 'read_at IS NULL',
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    await _db.delete('notifications');
  }

  /// Drops the oldest rows once the table exceeds [maxRows].
  Future<void> _trim() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM notifications');
    final count = (rows.first['c'] as int?) ?? 0;
    if (count <= maxRows) return;

    final doomed = await _db.query(
      'notifications',
      columns: ['id'],
      orderBy: 'created_at ASC',
      limit: count - maxRows,
    );
    if (doomed.isEmpty) return;

    final ids = doomed.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    await _db.delete(
      'notifications',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }
}
