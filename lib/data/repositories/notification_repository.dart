import 'package:sqflite/sqflite.dart';

import 'package:fitpilot/data/sync/sync_queue_writer.dart';
import 'package:fitpilot/domain/entities/app_notification.dart';

/// Stores the in-app notification inbox.
///
/// SYNCED per account, so read state and history follow the user rather than
/// the install. Delivery is still per-device (the OS notification itself is
/// local), but the inbox row is the user's.
class NotificationRepository {
  final Database _db;
  final SyncQueueWriter? _sync;

  NotificationRepository(this._db, {SyncQueueWriter? sync}) : _sync = sync;

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
    await _sync?.enqueue('notifications', notification.id, 'upsert');
    await _trim();
    return true;
  }

  Future<void> markRead(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final changed = await _db.update(
      'notifications',
      {'read_at': now, 'updated_at': now},
      where: 'id = ? AND read_at IS NULL',
      whereArgs: [id],
    );
    if (changed > 0) await _sync?.enqueue('notifications', id, 'upsert');
  }

  Future<void> markAllRead() async {
    final unread = await _db.query(
      'notifications',
      columns: ['id'],
      where: 'read_at IS NULL',
    );
    if (unread.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'notifications',
      {'read_at': now, 'updated_at': now},
      where: 'read_at IS NULL',
    );
    await _sync?.enqueueAll(
      'notifications',
      unread.map((r) => r['id'] as String),
      'upsert',
    );
  }

  Future<void> delete(String id) async {
    await _db.delete('notifications', where: 'id = ?', whereArgs: [id]);
    await _sync?.enqueue('notifications', id, 'delete');
  }

  Future<void> clearAll() async {
    final rows = await _db.query('notifications', columns: ['id']);
    await _db.delete('notifications');
    await _sync?.enqueueAll(
      'notifications',
      rows.map((r) => r['id'] as String),
      'delete',
    );
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
    // Tombstoned, not just deleted: the cap belongs to the account, and a
    // local-only delete would be undone by the next pull.
    await _sync?.enqueueAll('notifications', ids, 'delete');
  }
}
