import 'package:sqflite/sqflite.dart';

import 'package:fitpilot/core/utils/type_readers.dart';
import 'package:fitpilot/data/sync/sync_queue_writer.dart';
import 'package:fitpilot/domain/entities/program.dart';

/// Progress through one program, derived from `program_completions`.
class ProgramProgress {
  /// Ids of the sessions this device has finished.
  final Set<String> completedSessionIds;
  final int totalKcal;
  final DateTime? lastCompletedAt;

  const ProgramProgress({
    this.completedSessionIds = const {},
    this.totalKcal = 0,
    this.lastCompletedAt,
  });

  int get completedCount => completedSessionIds.length;

  bool isDone(String sessionId) => completedSessionIds.contains(sessionId);

  double fractionOf(int totalDays) {
    if (totalDays <= 0) return 0;
    return (completedCount / totalDays).clamp(0.0, 1.0);
  }
}

/// All SQL for the training-programs feature.
///
/// `programs`, `program_sessions` and `program_session_items` are bundled seed
/// content — identical for every user, so they are never synced. But
/// `program_completions` is the user's own progress, and it IS synced: leaving
/// it per-device meant signing out abandoned whatever program you were part way
/// through, which no one expects from an account.
class ProgramRepository {
  final Database db;
  final SyncQueueWriter? sync;

  const ProgramRepository(this.db, {this.sync});

  /// Loads every program with its sessions and each session's exercise list,
  /// ordered for display. Three queries total, stitched in memory.
  Future<List<ProgramWithSessions>> all() async {
    final programRows = await db.query('programs', orderBy: 'sort_index, name');
    if (programRows.isEmpty) return const [];

    final sessionRows = await db.query(
      'program_sessions',
      orderBy: 'program_id, day_number',
    );
    final itemRows = await db.query(
      'program_session_items',
      orderBy: 'session_id, position',
    );

    final itemsBySession = <String, List<ProgramSessionItem>>{};
    for (final row in itemRows) {
      final sessionId = row['session_id'] as String;
      itemsBySession
          .putIfAbsent(sessionId, () => [])
          .add(_rowToItem(row));
    }

    final sessionsByProgram = <String, List<ProgramSession>>{};
    for (final row in sessionRows) {
      final programId = row['program_id'] as String;
      final id = row['id'] as String;
      sessionsByProgram
          .putIfAbsent(programId, () => [])
          .add(_rowToSession(row, itemsBySession[id] ?? const []));
    }

    return programRows
        .map(
          (row) => ProgramWithSessions(
            program: _rowToProgram(row),
            sessions: sessionsByProgram[row['id'] as String] ?? const [],
          ),
        )
        .toList();
  }

  Future<ProgramWithSessions?> byId(String programId) async {
    final programRows = await db.query(
      'programs',
      where: 'id = ?',
      whereArgs: [programId],
      limit: 1,
    );
    if (programRows.isEmpty) return null;

    final sessionRows = await db.query(
      'program_sessions',
      where: 'program_id = ?',
      whereArgs: [programId],
      orderBy: 'day_number',
    );
    final sessions = <ProgramSession>[];
    for (final row in sessionRows) {
      final id = row['id'] as String;
      final itemRows = await db.query(
        'program_session_items',
        where: 'session_id = ?',
        whereArgs: [id],
        orderBy: 'position',
      );
      sessions.add(_rowToSession(row, itemRows.map(_rowToItem).toList()));
    }

    return ProgramWithSessions(
      program: _rowToProgram(programRows.first),
      sessions: sessions,
    );
  }

  Future<ProgramProgress> progressFor(String programId) async {
    final rows = await db.query(
      'program_completions',
      where: 'program_id = ?',
      whereArgs: [programId],
    );
    if (rows.isEmpty) return const ProgramProgress();

    final ids = <String>{};
    var kcal = 0;
    DateTime? last;
    for (final row in rows) {
      ids.add(row['session_id'] as String);
      kcal += TolerantReader.readInt(row['kcal']) ?? 0;
      final at = DateTime.tryParse((row['completed_at'] as String?) ?? '');
      if (at != null && (last == null || at.isAfter(last))) last = at;
    }
    return ProgramProgress(
      completedSessionIds: ids,
      totalKcal: kcal,
      lastCompletedAt: last,
    );
  }

  /// Records a finished day. Returns false when the session was already
  /// recorded, which is how the UI guards a double tap on "Mark complete".
  Future<bool> recordCompletion({
    required ProgramSession session,
    required int kcal,
    required DateTime completedAt,
  }) async {
    final inserted = await db.insert('program_completions', {
      'session_id': session.id,
      'program_id': session.programId,
      'week_number': session.weekNumber,
      'day_number': session.dayNumber,
      'kcal': kcal,
      'completed_at': completedAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (inserted != 0) {
      await sync?.enqueue('program_completions', session.id, 'upsert');
    }
    return inserted != 0;
  }

  Future<bool> isCompleted(String sessionId) async {
    final rows = await db.query(
      'program_completions',
      columns: ['session_id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Wipes progress for one program. Called on enroll, switch and abandon so a
  /// re-enrolled program never shows stale ticks or a wrong percentage.
  Future<void> clearProgress(String programId) async {
    // The ids are read before the delete so each row can be tombstoned:
    // without that the cloud keeps the completions and the next pull restores
    // the ticks the user just cleared.
    final rows = await db.query(
      'program_completions',
      columns: ['session_id'],
      where: 'program_id = ?',
      whereArgs: [programId],
    );
    await db.delete(
      'program_completions',
      where: 'program_id = ?',
      whereArgs: [programId],
    );
    await sync?.enqueueAll(
      'program_completions',
      rows.map((r) => r['session_id'] as String),
      'delete',
    );
  }

  Program _rowToProgram(Map<String, Object?> row) {
    return Program(
      id: row['id'] as String,
      name: row['name'] as String,
      icon: (row['icon'] as String?) ?? '🏋️',
      goal: (row['goal'] as String?) ?? '',
      level: programLevelFrom(row['level'] as String?),
      focus: programFocusFrom(row['focus'] as String?),
      equipment: programEquipmentFrom(row['equipment'] as String?),
      durationDays: TolerantReader.readInt(row['duration_days']) ?? 0,
      daysPerWeek: TolerantReader.readInt(row['days_per_week']) ?? 0,
      heroImage: row['hero_image'] as String?,
      sortIndex: TolerantReader.readInt(row['sort_index']) ?? 100,
    );
  }

  ProgramSession _rowToSession(
    Map<String, Object?> row,
    List<ProgramSessionItem> items,
  ) {
    return ProgramSession(
      id: row['id'] as String,
      programId: row['program_id'] as String,
      weekNumber: TolerantReader.readInt(row['week_number']) ?? 1,
      dayNumber: TolerantReader.readInt(row['day_number']) ?? 1,
      exerciseId: (row['exercise_id'] as String?) ?? 'rest',
      minutes: TolerantReader.readInt(row['minutes']) ?? 0,
      title: (row['title'] as String?) ?? '',
      focus: row['focus'] as String?,
      kind: programSessionKindFrom(row['kind'] as String?),
      notes: row['notes'] as String?,
      items: items,
    );
  }

  ProgramSessionItem _rowToItem(Map<String, Object?> row) {
    return ProgramSessionItem(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      position: TolerantReader.readInt(row['position']) ?? 0,
      exerciseId: row['exercise_id'] as String,
      minutes: TolerantReader.readInt(row['minutes']) ?? 0,
      detail: row['detail'] as String?,
    );
  }
}
