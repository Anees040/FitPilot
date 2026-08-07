import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/local/seed_importer.dart';
import 'package:fitpilot/data/repositories/program_repository.dart';
import 'package:fitpilot/domain/entities/program.dart';

/// Guards the bundled program catalogue. Every assertion here protects the
/// hand-authored JSON: a typo'd exercise id or a gap in the day numbering only
/// shows up at runtime as a broken session screen otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late ProgramRepository repo;
  late List<ProgramWithSessions> programs;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    db = await AppDatabase.inMemory();
    await SeedImporter(db).importAll();
    repo = ProgramRepository(db);
    programs = await repo.all();
  });

  tearDownAll(() async => db.close());

  test('seeds every program in the asset', () {
    expect(programs, isNotEmpty);
    for (final p in programs) {
      expect(p.sessions, isNotEmpty, reason: '${p.program.id} has no sessions');
    }
  });

  test('every session exercise id resolves to a real exercise', () async {
    final rows = await db.query('exercises', columns: ['id', 'met']);
    final mets = {
      for (final row in rows) row['id'] as String: (row['met'] as num).toDouble(),
    };

    for (final p in programs) {
      for (final session in p.sessions) {
        for (final item in session.items) {
          expect(
            mets.containsKey(item.exerciseId),
            isTrue,
            reason:
                '${session.id} references unknown exercise "${item.exerciseId}"',
          );
          // A zero/negative MET would silently make a session worth 0 kcal.
          expect(
            mets[item.exerciseId]!,
            greaterThan(0),
            reason: '${item.exerciseId} has a non-positive MET',
          );
        }
      }
    }
  });

  test('rest days carry no exercises and workouts always do', () {
    for (final p in programs) {
      for (final session in p.sessions) {
        if (session.isRest) {
          expect(session.items, isEmpty, reason: '${session.id} is a rest day');
          expect(session.exerciseId, 'rest');
        } else {
          expect(
            session.items,
            isNotEmpty,
            reason: '${session.id} is a workout with no exercises',
          );
        }
      }
    }
  });

  test('day numbers run 1..durationDays with no gaps or duplicates', () {
    for (final p in programs) {
      final days = p.sessions.map((s) => s.dayNumber).toList()..sort();
      expect(
        days,
        List.generate(days.length, (i) => i + 1),
        reason: '${p.program.id} has gaps or duplicates in its day numbering',
      );
      expect(
        p.program.durationDays,
        days.isEmpty ? 0 : days.last,
        reason: '${p.program.id}: durationDays must equal the highest day',
      );
    }
  });

  test('session ids follow {programId}-w{week}-d{day}', () {
    for (final p in programs) {
      for (final session in p.sessions) {
        expect(
          session.id,
          '${p.program.id}-w${session.weekNumber}-d${session.dayNumber}',
        );
      }
    }
  });

  test('every program carries browse metadata — no unknown bucket', () {
    for (final p in programs) {
      final meta = p.program;
      expect(meta.durationDays, greaterThan(0), reason: meta.id);
      expect(meta.goal, isNotEmpty, reason: meta.id);
      expect(meta.name, isNotEmpty, reason: meta.id);
      // focus/level/equipment are non-nullable enums, so the real risk is a
      // program whose row never got upserted. Sort order proves it was seeded
      // through the metadata path rather than defaulted.
      expect(meta.sortIndex, greaterThan(0), reason: meta.id);
    }
  });

  test('the goal programs are present and shaped as advertised', () {
    final byId = {for (final p in programs) p.program.id: p};

    // id -> advertised duration. Guards the JSON against silent drift.
    const expected = {
      'six-pack-30': 30,
      'full-body-30': 30,
      'strength-conditioning-28': 28,
      'lower-body-28': 28,
      'belly-burn-14': 14,
      'lose-weight-30': 30,
      'kegel-core-14': 14,
      'pushup-power-21': 21,
    };

    for (final entry in expected.entries) {
      final program = byId[entry.key];
      expect(program, isNotNull, reason: '${entry.key} is missing');
      expect(program!.totalDays, entry.value, reason: entry.key);
      expect(
        program.restDays,
        greaterThan(0),
        reason: '${entry.key} must schedule rest days',
      );
    }
  });

  test('kegel-core-14 uses the new kegel-hold exercise', () async {
    final rows = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: ['kegel-hold'],
    );
    expect(rows, hasLength(1), reason: 'kegel-hold must reach existing installs');
    expect((rows.single['met'] as num).toDouble(), greaterThan(0));
    // The only catalogue entry with no artwork — ExerciseMedia falls back to an
    // icon, which is what the session and detail screens rely on.
    expect(rows.single['media_asset'], isNull);

    final kegel = programs.firstWhere((p) => p.program.id == 'kegel-core-14');
    final usesKegel = kegel.sessions
        .expand((s) => s.items)
        .any((i) => i.exerciseId == 'kegel-hold');
    expect(usesKegel, isTrue);
  });

  test('weight-loss programs avoid spot-reduction claims', () {
    // The catalogue must not promise something training cannot deliver.
    final banned = RegExp(
      r'melt (belly|fat)|burn belly fat|target(s|ed)? belly fat|'
      r'spot[- ]reduce(?! )|lose belly fat fast',
      caseSensitive: false,
    );
    for (final p in programs) {
      final goal = p.program.goal;
      // "cannot spot-reduce" is the honest phrasing and is expected.
      final claims = banned.allMatches(goal).where(
            (m) => !goal
                .substring((m.start - 12).clamp(0, goal.length), m.start)
                .toLowerCase()
                .contains('cannot'),
          );
      expect(claims, isEmpty, reason: '${p.program.id}: "$goal"');
    }

    final belly = programs.firstWhere((p) => p.program.id == 'belly-burn-14');
    expect(belly.program.goal.toLowerCase(), contains('cannot spot-reduce'));
  });

  test('the legacy air-squats reference is gone', () async {
    final rows = await db.query(
      'program_session_items',
      where: 'exercise_id = ?',
      whereArgs: ['air-squats'],
    );
    expect(rows, isEmpty);
  });

  test('re-running the importer does not duplicate sessions', () async {
    final before = await db.query('program_sessions');
    await SeedImporter(db).importAll();
    final after = await db.query('program_sessions');
    expect(after.length, before.length);
  });

  test('metadata upsert refreshes a legacy program row', () async {
    // Simulate an install seeded before v20: metadata wiped back to defaults.
    await db.update(
      'programs',
      {
        'level': 'beginner',
        'focus': 'full_body',
        'duration_days': 0,
        'sort_index': 100,
      },
      where: 'id = ?',
      whereArgs: ['gym-strength-basics'],
    );

    await SeedImporter(db).importAll();

    final row = (await db.query(
      'programs',
      where: 'id = ?',
      whereArgs: ['gym-strength-basics'],
    )).single;
    expect(row['focus'], 'strength');
    expect(row['duration_days'], 16);
    expect(row['sort_index'], 60);
  });

  test('program tables never enqueue sync work', () async {
    await db.delete('sync_queue');
    await SeedImporter(db).importAll();

    final session = programs.first.sessions.first;
    await repo.recordCompletion(
      session: session,
      kcal: 120,
      completedAt: DateTime(2026, 8, 7),
    );
    await repo.clearProgress(session.programId);

    final queued = await db.query('sync_queue');
    expect(
      queued.where(
        (row) => (row['table_name'] as String).startsWith('program'),
      ),
      isEmpty,
      reason: 'program tables are local-only and must never sync',
    );
    expect(queued, isEmpty);
  });

  test('recordCompletion is idempotent per session', () async {
    final session = programs.first.sessions.first;
    await repo.clearProgress(session.programId);

    final first = await repo.recordCompletion(
      session: session,
      kcal: 100,
      completedAt: DateTime(2026, 8, 7),
    );
    final second = await repo.recordCompletion(
      session: session,
      kcal: 100,
      completedAt: DateTime(2026, 8, 7),
    );

    expect(first, isTrue);
    expect(second, isFalse, reason: 'a repeat tap must not count twice');

    final progress = await repo.progressFor(session.programId);
    expect(progress.completedCount, 1);
    expect(progress.totalKcal, 100);

    await repo.clearProgress(session.programId);
  });

  test('clearProgress wipes only the given program', () async {
    final a = programs[0].sessions.first;
    final b = programs[1].sessions.first;

    await repo.recordCompletion(
      session: a,
      kcal: 50,
      completedAt: DateTime(2026, 8, 7),
    );
    await repo.recordCompletion(
      session: b,
      kcal: 60,
      completedAt: DateTime(2026, 8, 7),
    );

    await repo.clearProgress(a.programId);

    expect((await repo.progressFor(a.programId)).completedCount, 0);
    expect((await repo.progressFor(b.programId)).completedCount, 1);

    await repo.clearProgress(b.programId);
  });
}
