import 'dart:async';
import 'dart:convert';
import 'package:fitpilot/core/utils/type_readers.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/data/remote/remote_data_source.dart';
import 'package:fitpilot/data/sync/sync_tables.dart';

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

  /// Spec lookup for a local table name, or null if the table does not sync.
  static SyncTableSpec? _spec(String localTable) {
    for (final s in kSyncTables) {
      if (s.local == localTable) return s;
    }
    return null;
  }

  /// Maps local SQLite table names to their Supabase counterparts.
  /// The local table is named 'profile' (singleton row) but Supabase
  /// uses 'profiles' (multi-user table).
  String _remoteTable(String localTable) =>
      _spec(localTable)?.remote ?? localTable;

  /// The value a row's primary key takes in the cloud.
  ///
  /// Singleton tables (`profile`, `notification_prefs`) hold one row keyed
  /// `id = 1` on the device; in the cloud that row is keyed by the user's uuid,
  /// because one row per *account* is the only thing that makes sense there.
  /// Everything else keeps whatever id the device generated.
  String _remoteId(SyncTableSpec spec, String localRowId) =>
      spec.singleton ? userId : localRowId;

  /// Converts one local SQLite row into the payload Supabase expects.
  Map<String, dynamic> _toRemote(SyncTableSpec spec, Map<String, Object?> local) {
    final out = <String, dynamic>{
      'id': _remoteId(spec, local[spec.localPk]?.toString() ?? ''),
      'user_id': userId,
      'updated_at': local['updated_at'],
    };
    for (final column in spec.columns) {
      final raw = local[column.name];
      out[column.name] = switch (column.kind) {
        // SQLite has no boolean; Postgres will not take 0/1 for one.
        SyncColumnKind.boolean => TolerantReader.readBool(raw),
        SyncColumnKind.plain || SyncColumnKind.json => raw,
      };
    }
    return out;
  }

  /// Converts one Supabase row back into a local SQLite row.
  Map<String, dynamic> _toLocal(SyncTableSpec spec, Map<String, dynamic> remote) {
    final out = <String, dynamic>{
      // A singleton always lands on local row 1 regardless of the cloud key.
      spec.localPk: spec.singleton ? 1 : remote['id'],
      'updated_at': remote['updated_at'],
    };
    for (final column in spec.columns) {
      out[column.name] = TolerantReader.toSqliteValue(remote[column.name]);
    }
    return out;
  }

  /// Forces a timestamp to UTC before it crosses the wire.
  ///
  /// Postgres stores `timestamptz` in UTC, so a naive local-time string
  /// (`2026-08-11T14:00:00.000`, no offset) is read back as if it were already
  /// UTC. From UTC+5 that makes every local row look five hours newer than it
  /// is, so it wins every last-write-wins comparison and the cloud copy is
  /// never applied — which is exactly how edits made on another device
  /// silently failed to arrive.
  static String? _normalizeUtc(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return parsed.toUtc().toIso8601String();
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

  Future<void>? _activeSync;

  Future<int> getPendingQueueCount() async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as c FROM sync_queue'),
    );
    return count ?? 0;
  }

  /// The main entry point to trigger a sync (push then pull).
  Future<void> syncNow() {
    if (_activeSync != null) return _activeSync!;
    _activeSync = _syncInternal();
    return _activeSync!;
  }

  Future<void> drain() async {
    await _activeSync;
  }

  Future<void> _syncInternal() async {
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
      _activeSync = null;
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

  @visibleForTesting
  static Map<String, Map<String, dynamic>> deduplicateRows(String table, List<Map<String, dynamic>> rowsToUpsert) {
    final uniqueRows = <String, Map<String, dynamic>>{};
    for (final row in rowsToUpsert) {
      final String conflictKey;
      if (table == 'weight_entries') {
        final uid = row['user_id'] ?? 'user';
        conflictKey = '${uid}_${row['for_date']}';
      } else {
        conflictKey = row['id'].toString();
      }
      
      if (uniqueRows.containsKey(conflictKey)) {
        final existing = uniqueRows[conflictKey]!;
        final existingUpdated = DateTime.parse(existing['updated_at'] as String);
        final currentUpdated = DateTime.parse(row['updated_at'] as String);
        if (currentUpdated.isAfter(existingUpdated)) {
          uniqueRows[conflictKey] = row;
        }
      } else {
        uniqueRows[conflictKey] = row;
      }
    }
    return uniqueRows;
  }

  Future<void> _processPushBatch(
    String table,
    List<Map<String, dynamic>> chunk,
  ) async {
    final spec = _spec(table);
    if (spec == null) {
      // A table that does not sync should never have been queued. Drop the
      // entries rather than retrying them forever against a table Supabase
      // does not have.
      debugPrint('Sync push: dropping queue entries for unsynced table $table');
      await _removeFromQueue(chunk.map((q) => q['id'] as int).toList());
      return;
    }

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
          'id': _remoteId(spec, rowId),
          'user_id': userId,
          'deleted': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        // Query the local table. A singleton's queue row carries '1'; every
        // other table carries whatever id the device generated.
        final pkVal = spec.singleton ? 1 : rowId;

        final localData = await db.query(
          table,
          where: '${spec.localPk} = ?',
          whereArgs: [pkVal],
        );
        if (localData.isNotEmpty) {
          if (table == 'weight_entries' &&
              localData.first['weight_kg'] == null) {
            continue;
          }
          final data = _toRemote(spec, localData.first);
          if (table == 'profile') {
            // equipment is text[] in Postgres but a JSON string in SQLite.
            _fixProfileArrayFields(data);
          }
          data['updated_at'] = _normalizeUtc(data['updated_at']);
          if (data['updated_at'] == null) {
            // Nothing to order this row by, so the conflict rule cannot run.
            // Stamp it now rather than pushing a row that can never win or lose.
            data['updated_at'] = DateTime.now().toIso8601String();
          }
          rowsToUpsert.add(data);
        } else if (op == 'soft_delete') {
          // It might have been physically deleted, let's tombstone
          rowsToUpsert.add({
            'id': _remoteId(spec, rowId),
            'user_id': userId,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }
    }

    if (rowsToUpsert.isEmpty) {
      // Nothing to push (maybe local rows were deleted?), just remove from queue
      await _removeFromQueue(queueIds);
      return;
    }

    final uniqueRows = deduplicateRows(table, rowsToUpsert);

    // Conflict Rule: last-write-wins by updated_at (Cloud wins if newer)
    final idsToCheck = uniqueRows.values.map((r) => r['id'].toString()).toList();
    final cloudUpdatedAts = await remote.fetchCloudUpdatedAts(_remoteTable(table), idsToCheck);
    
    final finalRows = <Map<String, dynamic>>[];
    for (final row in uniqueRows.values) {
      final id = row['id'].toString();
      final localUpdatedStr = row['updated_at'] as String;
      final localUpdated = DateTime.parse(localUpdatedStr);
      
      final cloudUpdated = cloudUpdatedAts[id];
      if (cloudUpdated != null && cloudUpdated.isAfter(localUpdated)) {
        // Cloud is newer, skip pushing this row. The pull phase will get the newer row.
        continue;
      }
      finalRows.add(row);
    }

    if (finalRows.isEmpty) {
      // Everything was skipped (cloud is newer), so we just remove these from the queue
      await _removeFromQueue(queueIds);
      return;
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

  Future<void> _pullPhase({bool throwOnFailure = false}) async {
    final failures = <String>[];

    for (final spec in kSyncTables) {
      final table = spec.local;
      final lastPull = await _getLastPull(table);
      try {
        // Pull from the Supabase table (which may have a different name).
        final remoteRows = await remote.pullSince(spec.remote, lastPull);
        if (remoteRows.isEmpty) continue;

        DateTime maxUpdated = DateTime.parse(lastPull);

        await db.transaction((txn) async {
          for (final row in remoteRows) {
            final remoteUpdatedStr = row['updated_at'] as String;
            final remoteUpdated = DateTime.parse(remoteUpdatedStr);
            if (remoteUpdated.isAfter(maxUpdated)) {
              maxUpdated = remoteUpdated;
            }

            final rowId = spec.singleton ? 1 : row['id'];

            // Conflict resolution: last write wins
            final localRows = await txn.query(
              table,
              where: '${spec.localPk} = ?',
              whereArgs: [rowId],
            );
            if (localRows.isNotEmpty) {
              final rawUpdated = localRows.first['updated_at'];
              final localUpdatedStr = rawUpdated is String
                  ? rawUpdated
                  : DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
              final localUpdated = DateTime.parse(localUpdatedStr);
              if (localUpdated.isAfter(remoteUpdated)) {
                // Local is newer, ignore remote
                continue;
              }
            }

            // Remote is newer or row doesn't exist locally.
            final dataToInsert = _toLocal(spec, row);

            // A tombstone arrives either as the `deleted` flag the push writes
            // or, for food_logs, as a `deleted_at` timestamp. Both are read
            // from the remote row directly: `deleted` is structural and so is
            // never part of a spec's column list.
            final isDeleted =
                TolerantReader.readBool(row['deleted']) == true ||
                dataToInsert['deleted_at'] != null;

            if (isDeleted && table != 'food_logs') {
              // physical delete
              await txn.delete(
                table,
                where: '${spec.localPk} = ?',
                whereArgs: [rowId],
              );
            } else {
              // ConflictAlgorithm.replace is INSERT OR REPLACE, which deletes
              // the existing row and reinserts it — any column missing from
              // dataToInsert would be reset to NULL. Carry local-only columns
              // (which the remote schema does not have) across the replace.
              await _preserveLocalOnly(txn, spec, rowId, dataToInsert);
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
        failures.add(table);
      }
    }

    if (throwOnFailure && failures.isNotEmpty) {
      throw Exception('Pull failed for tables: ${failures.join(", ")}');
    }
  }

  /// Reads the local-only column values for [rowId] and merges them into
  /// [dataToInsert] so the INSERT OR REPLACE writes them back unchanged.
  Future<void> _preserveLocalOnly(
    DatabaseExecutor txn,
    SyncTableSpec spec,
    Object? rowId,
    Map<String, dynamic> dataToInsert,
  ) async {
    if (spec.localOnly.isEmpty || rowId == null) return;
    try {
      final existing = await txn.query(
        spec.local,
        columns: spec.localOnly,
        where: '${spec.localPk} = ?',
        whereArgs: [rowId],
        limit: 1,
      );
      if (existing.isEmpty) return;
      for (final column in spec.localOnly) {
        final value = existing.first[column];
        if (value != null) dataToInsert[column] = value;
      }
    } catch (_) {
      // Column may not exist yet on a partially-migrated db — never block a pull.
    }
  }

  /// Pulls every table from scratch, after first pushing whatever is queued.
  ///
  /// The push is not optional. Sign-in queues the guest's rows and then calls
  /// this, and a pull-only version overwrote them with the cloud copy before
  /// they were ever uploaded — which is precisely how "keep my data" lost the
  /// user's enrolled program and reset their profile to defaults while the
  /// food logs (already pushed by an earlier background sync) survived.
  Future<void> forcePullAll() async {
    try {
      await _pushPhase();
    } catch (e) {
      // A failed push must not block the pull: the queue survives and retries,
      // so the worst case is that local data uploads a little later.
      debugPrint('forcePullAll: push phase failed, continuing to pull: $e');
    }
    // Only the per-table pull cursors, not the whole table: sync_metadata also
    // holds the data-owner stamp that tells sign-in whose rows are on disk, and
    // wiping that would make the next sign-in treat another account's leftovers
    // as guest data to merge.
    await db.delete(
      'sync_metadata',
      where: 'key LIKE ?',
      whereArgs: ['last_pull_%'],
    );
    await _pullPhase(throwOnFailure: true);
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
    // Create and query a simple key-value metadata table on the fly to track sync timestamps.
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
