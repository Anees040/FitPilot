import 'package:sqflite/sqflite.dart';

import 'package:fitpilot/data/sync/sync_tables.dart';

/// Writes rows into `sync_queue` so the next push uploads them.
///
/// Repositories used to hand-roll this, which is how several tables ended up
/// written locally and never uploaded — the enqueue call was simply missing.
/// Sharing one writer means "is this table synced?" is answered from
/// [kSyncTables] rather than from whether someone remembered.
class SyncQueueWriter {
  final Database db;

  /// Guest mode shield. A signed-out user has nowhere to push to, and queuing
  /// their rows would upload one person's data into the next account that
  /// signs in on this device.
  final bool Function() isGuest;

  const SyncQueueWriter(this.db, {required this.isGuest});

  /// Queues one row. [op] is 'upsert', 'soft_delete' or 'delete'.
  ///
  /// Pass [txn] when the caller is inside a transaction, so the queue entry
  /// commits or rolls back with the write it describes — a queue entry for a
  /// row that never landed would push stale or missing data.
  Future<void> enqueue(
    String table,
    String rowId,
    String op, {
    DatabaseExecutor? txn,
  }) async {
    if (isGuest()) return;
    assert(
      kSyncTables.any((s) => s.local == table),
      'Table "$table" is not in kSyncTables, so the push would drop it.',
    );
    await (txn ?? db).insert('sync_queue', {
      'table_name': table,
      'row_id': rowId,
      'op': op,
      'payload': null,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> enqueueAll(
    String table,
    Iterable<String> rowIds,
    String op, {
    DatabaseExecutor? txn,
  }) async {
    if (isGuest()) return;
    for (final id in rowIds) {
      await enqueue(table, id, op, txn: txn);
    }
  }
}
