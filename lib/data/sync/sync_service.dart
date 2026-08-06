import 'dart:async';
import 'dart:convert';
import 'package:fitpilot/core/utils/type_readers.dart';
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
            data.remove('onboarding_complete');
            data['id'] = userId;
            // Convert equipment JSON string → Dart List for Postgres text[] column
            _fixProfileArrayFields(data);
          } else if (table == 'weight_entries') {
            if (data['weight_kg'] == null) continue;
            data['user_id'] = userId;
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
              final rawUpdated = localRows.first['updated_at'];
              final localUpdatedStr = rawUpdated is String ? rawUpdated : DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
              final localUpdated = DateTime.parse(localUpdatedStr);
              if (localUpdated.isAfter(remoteUpdated)) {
                // Local is newer, ignore remote
                continue;
              }
            }

            // Remote is newer or row doesn't exist locally
            // Explicit Mappers
            Map<String, dynamic> dataToInsert = {};
            if (table == 'profile') {
              dataToInsert = {
                'id': 1,
                'weight_kg': row['weight_kg'],
                'height_cm': row['height_cm'],
                'age': row['age'],
                'gender': row['gender'],
                'activity_level': row['activity_level'],
                'goal': row['goal'],
                'allowance_kcal': row['allowance_kcal'],
                'target_override': row['target_override'],
                'equipment': row['equipment'] != null ? jsonEncode(row['equipment']) : null,
                'name': row['name'],
                'goal_weight_kg': row['goal_weight_kg'],
                'theme_mode': row['theme_mode'],
                'theme_color': row['theme_color'],
                'plan_category_pref': row['plan_category_pref'],
                'plan_pace_pref': row['plan_pace_pref'],
                'unit_kg_lb': row['unit_kg_lb'],
                'week_starts_mon': TolerantReader.toSqliteValue(row['week_starts_mon']),
                'haptics_on': TolerantReader.toSqliteValue(row['haptics_on']),
                'active_program_id': row['active_program_id'],
                'active_program_week': row['active_program_week'],
                'active_program_day': row['active_program_day'],
                'avatar_url': row['avatar_url'],
                'updated_at': row['updated_at'],
              };
            } else if (table == 'food_logs') {
              dataToInsert = {
                'id': row['id'],
                'food_id': row['food_id'],
                'food_name': row['food_name'],
                'custom_name': row['custom_name'],
                'quantity': row['quantity'],
                'kcal_min': row['kcal_min'],
                'kcal_max': row['kcal_max'],
                'source': row['source'],
                'logged_at': row['logged_at'],
                'deleted_at': row['deleted_at'],
                'updated_at': row['updated_at'],
              };
            } else if (table == 'weight_entries') {
              dataToInsert = {
                'id': row['id'],
                'weight_kg': row['weight_kg'],
                'for_date': row['for_date'],
                'updated_at': row['updated_at'],
              };
            } else if (table == 'burn_completions') {
              dataToInsert = {
                'id': row['id'],
                'activity': row['activity'],
                'minutes': row['minutes'],
                'kcal': row['kcal'],
                'for_date': row['for_date'],
                'completed_at': row['completed_at'],
                'updated_at': row['updated_at'],
              };
            } else if (table == 'food_catalog') {
              dataToInsert = {
                'id': row['id'],
                'name': row['name'],
                'name_ur': row['name_ur'],
                'portion_label': row['portion_label'],
                'grams': row['grams'],
                'kcal_min': row['kcal_min'],
                'kcal_max': row['kcal_max'],
                'image_url': row['image_url'],
                'is_verified': TolerantReader.toSqliteValue(row['is_verified']),
              };
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
        failures.add(table);
      }
    }

    if (throwOnFailure && failures.isNotEmpty) {
      throw Exception('Pull failed for tables: ${failures.join(", ")}');
    }
  }

  Future<void> forcePullAll() async {
    await db.delete('sync_metadata');
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
