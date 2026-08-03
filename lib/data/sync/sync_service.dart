import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/data/remote/remote_data_source.dart';

enum SyncState { idle, syncing, error }

class SyncStatus {
  final SyncState state;
  final int pendingCount;
  final DateTime? lastSuccessfulSync;
  final String? error;

  const SyncStatus({
    this.state = SyncState.idle,
    this.pendingCount = 0,
    this.lastSuccessfulSync,
    this.error,
  });
}

class SyncService {
  final Database db;
  final RemoteDataSource remote;
  final String userId;

  bool _isSyncing = false;
  DateTime? _lastSuccess;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _statusController.stream;

  SyncService({required this.db, required this.remote, required this.userId}) {
    _emitStatus();
  }

  /// Maps local SQLite table names to their Supabase counterparts.
  /// The local table is named 'profile' (singleton row) but Supabase
  /// uses 'profiles' (multi-user table).
  String _remoteTable(String localTable) {
    if (localTable == 'profile') return 'profiles';
    return localTable;
  }

  void _emitStatus({SyncState? state, String? error}) async {
    final countRes = await db.rawQuery(
      'SELECT COUNT(*) as c FROM sync_queue WHERE attempts < 10',
    );
    final count = Sqflite.firstIntValue(countRes) ?? 0;

    _statusController.add(
      SyncStatus(
        state: state ?? (_isSyncing ? SyncState.syncing : SyncState.idle),
        pendingCount: count,
        lastSuccessfulSync: _lastSuccess,
        error: error,
      ),
    );
  }

  /// The main entry point to trigger a sync (push then pull).
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _emitStatus();
    try {
      await _pushPhase();
      await _pullPhase();
      _lastSuccess = DateTime.now();
      _emitStatus();
    } catch (e) {
      _emitStatus(state: SyncState.error, error: e.toString());
    } finally {
      _isSyncing = false;
      if (!_statusController.isClosed) {
        _emitStatus();
      }
    }
  }

  Future<void> _pushPhase() async {
    final queue = await db.query(
      'sync_queue',
      where: 'attempts < 10',
      orderBy: 'id ASC',
    );

    if (queue.isEmpty) return;

    final now = DateTime.now();
    final toProcess = <Map<String, dynamic>>[];

    for (final q in queue) {
      final attempts = q['attempts'] as int;
      if (attempts > 0) {
        final queuedAt = DateTime.parse(q['queued_at'] as String);
        // Exponential backoff: 2s, 4s, 8s, 16s... up to 300s (5 min)
        final backoffSeconds = math
            .min(300, 2 * math.pow(2, attempts - 1))
            .toInt();
        if (now.difference(queuedAt).inSeconds < backoffSeconds) {
          continue; // wait for backoff
        }
      }
      toProcess.add(q);
    }

    if (toProcess.isEmpty) return;

    final byTable = <String, List<Map<String, dynamic>>>{};
    for (final q in toProcess) {
      byTable.putIfAbsent(q['table_name'] as String, () => []).add(q);
    }

    for (final entry in byTable.entries) {
      final table = entry.key;
      final items = entry.value;

      for (var i = 0; i < items.length; i += 50) {
        final chunk = items.skip(i).take(50).toList();
        await _processPushBatch(table, chunk);
      }
    }
  }

  Future<void> _processPushBatch(
    String table,
    List<Map<String, dynamic>> chunk,
  ) async {
    final rowsToUpsert = <Map<String, dynamic>>[];
    final queueIds = <int>[];

    for (final q in chunk) {
      final rowId = q['row_id'] as String;
      final op = q['op'] as String;
      final id = q['id'] as int;
      queueIds.add(id);

      // Fetch actual data from local table
      if (op == 'delete') {
        // We push a tombstone instead of actual delete
        rowsToUpsert.add({
          'id': table == 'profile' ? userId : rowId, // profiles pk is user_id
          'user_id': userId,
          'deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Query the local table.
        // For profile, row_id is '1', but in the local DB it's integer 1.
        final pkVal = table == 'profile' ? 1 : rowId;

        final localData = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [pkVal],
        );
        if (localData.isNotEmpty) {
          final data = Map<String, dynamic>.from(localData.first);

          if (table == 'profile') {
            // Supabase 'profiles' table uses a UUID id (the user's auth id).
            data.remove('id');
            data.remove('active_program_id');
            data.remove('active_program_week');
            data.remove('active_program_day');
            data['id'] = userId;
            // Convert equipment JSON string → Dart List for Postgres text[] column
            _fixProfileArrayFields(data);
          } else {
            data['user_id'] = userId;
          }

          rowsToUpsert.add(data);
        } else if (op == 'soft_delete') {
          // It might have been physically deleted, let's tombstone
          rowsToUpsert.add({
            'id': rowId,
            'user_id': userId,
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    if (rowsToUpsert.isEmpty) {
      // Nothing to push (maybe local rows were deleted?), just remove from queue
      await _removeFromQueue(queueIds);
      return;
    }

    // Deduplicate by ID so we don't send multiple updates for the same row in one batch
    final uniqueRows = <String, Map<String, dynamic>>{};
    for (final row in rowsToUpsert) {
      final pk = row['id'].toString();
      uniqueRows[pk] = row;
    }
    final finalRows = uniqueRows.values.toList();

    // Fallback for older DB schema constraints
    if (table == 'food_logs') {
      for (final row in finalRows) {
        if (row['source'] != null) {
          final src = row['source'] as String;
          const valid = ['catalog', 'search', 'manual', 'photo', 'label', 'labelScan', 'barcode', 'ai', 'custom'];
          if (!valid.contains(src) || src == 'search' || src == 'labelScan' || src == 'label' || src == 'ai' || src == 'custom') {
            row['source'] = 'manual';
          }
        }
      }
    }

    try {
      // For weight_entries, use the composite unique constraint to handle offline conflicts
      final onConflict = table == 'weight_entries' ? 'user_id, for_date' : null;
      
      // Use the remote table name (e.g. 'profiles' instead of 'profile').
      await remote.upsertRows(_remoteTable(table), finalRows, onConflict: onConflict);
      // On success, delete these from queue
      await _removeFromQueue(queueIds);
    } catch (e) {
      // On failure, increment attempts and record error
      debugPrint('Sync push batch failed for $table: $e');
      await _incrementQueueAttempts(queueIds, e.toString());
    }
  }

  Future<void> _pullPhase() async {
    // Local SQLite table names — _remoteTable() maps them to Supabase names.
    final tables = [
      'profile',
      'food_logs',
      'burn_completions',
      'weight_entries',
      'food_catalog',
    ];

    for (final table in tables) {
      final lastPull = await _getLastPull(table);
      try {
        // Pull from the Supabase table (which may have a different name).
        final remoteRows = await remote.pullSince(_remoteTable(table), lastPull);
        if (remoteRows.isEmpty) continue;

        DateTime maxUpdated = DateTime.parse(lastPull);

        await db.transaction((txn) async {
          for (final row in remoteRows) {
            final remoteUpdatedStr = row['updated_at'] as String;
            final remoteUpdated = DateTime.parse(remoteUpdatedStr);
            if (remoteUpdated.isAfter(maxUpdated)) {
              maxUpdated = remoteUpdated;
            }

            final rowId = table == 'profile' ? 1 : row['id'];

            // Conflict resolution: last write wins
            final localRows = await txn.query(
              table,
              where: 'id = ?',
              whereArgs: [rowId],
            );
            if (localRows.isNotEmpty) {
              final localUpdatedStr = localRows.first['updated_at'] as String;
              final localUpdated = DateTime.parse(localUpdatedStr);
              if (localUpdated.isAfter(remoteUpdated)) {
                // Local is newer, ignore remote
                continue;
              }
            }

            // Remote is newer or row doesn't exist locally
            final dataToInsert = Map<String, dynamic>.from(row);

            // Handle table differences
            if (table == 'profile') {
              dataToInsert['id'] = 1; // back to local singleton id
              // SQLite stores arrays as JSON text
              if (dataToInsert['equipment'] is List) {
                dataToInsert['equipment'] = jsonEncode(dataToInsert['equipment']);
              }
            } else {
              dataToInsert.remove('user_id'); // SQLite doesn't have user_id
            }

            // Convert booleans to integers for SQLite
            for (final key in dataToInsert.keys.toList()) {
              if (dataToInsert[key] is bool) {
                dataToInsert[key] = (dataToInsert[key] as bool) ? 1 : 0;
              }
            }

            // If it's a tombstone, we can physically delete or soft delete
            final isDeleted =
                (dataToInsert['deleted'] == true) ||
                (dataToInsert['deleted_at'] != null);
            dataToInsert.remove('deleted');

            if (isDeleted && table != 'food_logs') {
              // physical delete
              await txn.delete(table, where: 'id = ?', whereArgs: [rowId]);
            } else {
              // Upsert directly into local db (bypasses queue)
              await txn.insert(
                table,
                dataToInsert,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        });

        // Record successful pull
        await _setLastPull(table, maxUpdated.toIso8601String());
      } catch (e) {
        debugPrint('Sync pull failed for $table: $e');
      }
    }
  }

  /// Forces a complete fresh pull of all data from Supabase, ignoring local sync state.
  /// Call this when overriding local guest data with a cloud account.
  Future<void> forcePullAll() async {
    try {
      await db.delete('sync_metadata');
      await _pullPhase();
    } catch (e) {
      debugPrint('Force pull failed: $e');
    }
  }

  Future<void> _removeFromQueue(List<int> ids) async {
    if (ids.isEmpty) return;
    await db.delete('sync_queue', where: 'id IN (${ids.join(',')})');
  }

  Future<void> _incrementQueueAttempts(List<int> ids, String error) async {
    if (ids.isEmpty) return;
    final idList = ids.join(',');
    final nowStr = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE sync_queue 
      SET attempts = attempts + 1, last_error = ?, queued_at = ? 
      WHERE id IN ($idList)
    ''',
      [error, nowStr],
    );
  }

  Future<String> _getLastPull(String table) async {
    // A simple metadata table could store this, but to avoid DDL changes,
    // we can just query the max updated_at in the local table!
    // But what if local table is empty? We default to epoch.
    // Wait, if local table is empty because everything was deleted, max(updated_at) would be null,
    // so we'd re-pull everything. It's safer to use an actual sync_metadata table.
    // Did I create sync_metadata? No.
    // Let's create it on the fly if it doesn't exist, or just use a small local shared_prefs-like table.
    // Actually, SQLite allows creating tables on the fly.
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_metadata (key TEXT PRIMARY KEY, value TEXT)',
    );
    final res = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: ['last_pull_$table'],
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
  }

  Future<void> _setLastPull(String table, String iso8601) async {
    await db.insert('sync_metadata', {
      'key': 'last_pull_$table',
      'value': iso8601,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Converts JSON-encoded array fields (stored as text in SQLite) to Dart
  /// lists of strings so Supabase can insert them into PostgreSQL `text[]` columns.
  void _fixProfileArrayFields(Map<String, dynamic> data) {
    const arrayFields = ['equipment'];
    for (final field in arrayFields) {
      final raw = data[field];
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            data[field] = decoded.cast<String>();
          } else {
            data[field] = <String>[];
          }
        } catch (_) {
          data[field] = <String>[];
        }
      } else if (raw == null) {
        data[field] = <String>[];
      }
    }
  }
}
