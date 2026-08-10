import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/remote/remote_data_source.dart';
import 'package:fitpilot/data/sync/guest_merge_service.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
import 'package:fitpilot/data/sync/sync_tables.dart';

/// An in-memory stand-in for Supabase that records what was pushed and serves
/// back whatever the test seeds into [pullData].
class _FakeRemote implements RemoteDataSource {
  final Map<String, List<Map<String, dynamic>>> pushed = {};
  final Map<String, List<Map<String, dynamic>>> pullData = {};

  @override
  Future<void> upsertRows(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
  }) async {
    pushed.putIfAbsent(table, () => []).addAll(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> pullSince(String table, String since) async {
    return pullData[table] ?? const [];
  }

  @override
  Future<Map<String, DateTime>> fetchCloudUpdatedAts(
    String table,
    List<String> ids,
  ) async => {};

  @override
  Future<bool> hasCloudProfile(String userId) async => false;

  @override
  Future<bool> hasCloudData(String userId) async => false;

  @override
  Future<void> upsertProfile(Map<String, dynamic> data) async {}
}

const _userId = '11111111-2222-3333-4444-555555555555';

void main() {
  late Database db;
  late _FakeRemote remote;
  late SyncService sync;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.inMemory();
    await AppDatabase.clearUserData(db);
    remote = _FakeRemote();
    sync = SyncService(db: db, remote: remote, userId: _userId);
  });

  Future<void> queue(String table, String rowId, [String op = 'upsert']) {
    return db.insert('sync_queue', {
      'table_name': table,
      'row_id': rowId,
      'op': op,
      'payload': null,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  test('every synced table has the local columns its spec names', () async {
    // The registry is the contract between SQLite and Postgres. A column named
    // there but missing locally means the push silently sends null forever.
    for (final spec in kSyncTables) {
      final info = await db.rawQuery('PRAGMA table_info(${spec.local})');
      final local = info.map((c) => c['name'] as String).toSet();

      expect(local, contains(spec.localPk), reason: '${spec.local} primary key');
      expect(
        local,
        contains('updated_at'),
        reason: '${spec.local} needs updated_at for last-write-wins',
      );
      for (final column in spec.columns) {
        expect(
          local,
          contains(column.name),
          reason: '${spec.local}.${column.name} is in the spec but not in SQLite',
        );
      }
      for (final column in spec.localOnly) {
        expect(local, contains(column), reason: '${spec.local}.$column');
      }
    }
  });

  test('program progress pushes, so it survives a sign-out', () async {
    await db.insert('program_completions', {
      'session_id': 's-1',
      'program_id': 'p-1',
      'week_number': 1,
      'day_number': 2,
      'kcal': 240,
      'completed_at': '2026-08-10T10:00:00.000Z',
      'updated_at': '2026-08-10T10:00:00.000Z',
    });
    await queue('program_completions', 's-1');

    await sync.syncNow();

    final row = remote.pushed['program_completions']!.single;
    expect(row['id'], 's-1', reason: 'the local pk becomes the remote id');
    expect(row['user_id'], _userId);
    expect(row['program_id'], 'p-1');
    expect(row['kcal'], 240);
  });

  test('a singleton pushes under the user uuid, not local row 1', () async {
    await db.update('profile', {
      'name': 'Anees',
      'active_program_id': 'p-1',
      'active_program_week': 2,
      'onboarding_complete': 1,
      'updated_at': '2026-08-10T10:00:00.000Z',
    }, where: 'id = 1');
    await queue('profile', '1');

    await sync.syncNow();

    final row = remote.pushed['profiles']!.single;
    expect(row['id'], _userId, reason: 'profiles is keyed by the auth uuid');
    expect(row['name'], 'Anees');
    // The four fields that used to be stripped from the payload entirely.
    expect(row['active_program_id'], 'p-1');
    expect(row['active_program_week'], 2);
    expect(row['onboarding_complete'], isTrue,
        reason: 'SQLite 1 must cross the wire as a Postgres boolean');
  });

  test('notification prefs round-trip through the cloud', () async {
    // Push: SQLite 0/1 has to become a real boolean.
    await db.insert('notification_prefs', {
      'id': 1,
      'meal_reminders_enabled': 1,
      'quiet_hours_enabled': 0,
      'weigh_in_day': 3,
      'updated_at': '2026-08-10T10:00:00.000Z',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await queue('notification_prefs', '1');

    await sync.syncNow();

    final pushedRow = remote.pushed['notification_prefs']!.single;
    expect(pushedRow['id'], _userId);
    expect(pushedRow['meal_reminders_enabled'], isTrue);
    expect(pushedRow['quiet_hours_enabled'], isFalse);

    // Pull: a Postgres boolean has to become SQLite 0/1, and land on row 1.
    remote.pullData['notification_prefs'] = [
      {
        'id': _userId,
        'user_id': _userId,
        'meal_reminders_enabled': false,
        'quiet_hours_enabled': true,
        'weigh_in_day': 5,
        'updated_at': '2026-08-11T10:00:00.000Z',
      },
    ];
    await db.delete('sync_queue');
    await SyncService(db: db, remote: remote, userId: _userId).syncNow();

    final local = (await db.query('notification_prefs', where: 'id = 1')).single;
    expect(local['meal_reminders_enabled'], 0);
    expect(local['quiet_hours_enabled'], 1);
    expect(local['weigh_in_day'], 5);
  });

  test('a pulled coach thread lands locally', () async {
    remote.pullData['chat_messages'] = [
      {
        'id': 'm-1',
        'user_id': _userId,
        'conversation_id': 'c-1',
        'role': 'user',
        'content': 'how many calories in a roti',
        'created_at': '2026-08-10T10:00:00.000Z',
        'updated_at': '2026-08-10T10:00:00.000Z',
      },
    ];

    await sync.syncNow();

    final row = (await db.query('chat_messages')).single;
    expect(row['id'], 'm-1');
    expect(row['conversation_id'], 'c-1');
    expect(row['content'], 'how many calories in a roti');
  });

  test('a tombstone deletes the local row rather than resurrecting it',
      () async {
    await db.insert('machine_scans', {
      'id': 'scan-1',
      'machine_name': 'Leg Press',
      'response_json': '{}',
      'created_at': '2026-08-10T10:00:00.000Z',
      'updated_at': '2026-08-10T10:00:00.000Z',
    });

    remote.pullData['machine_scans'] = [
      {
        'id': 'scan-1',
        'user_id': _userId,
        'deleted': true,
        'updated_at': '2026-08-11T10:00:00.000Z',
      },
    ];

    await sync.syncNow();

    expect(await db.query('machine_scans'), isEmpty);
  });

  test('a queued row for an unsynced table is dropped, not retried forever',
      () async {
    await queue('exercises', 'ex-1');

    await sync.syncNow();

    expect(await db.query('sync_queue'), isEmpty);
    expect(remote.pushed, isNot(contains('exercises')));
  });

  test('guest data is carried into the account, not overwritten by the pull',
      () async {
    // The exact scenario the user hit: enrol in a program and set a height as
    // a guest, then sign in. The merge queues every local row and the push
    // must run BEFORE the pull, or the cloud's empty profile lands on top and
    // the program enrolment is gone.
    await db.update('profile', {
      'height_cm': 178,
      'active_program_id': 'p-1',
      'active_program_week': 1,
      'onboarding_complete': 1,
      'updated_at': '2026-08-11T09:00:00.000Z',
    }, where: 'id = 1');
    await db.insert('program_completions', {
      'session_id': 's-1',
      'program_id': 'p-1',
      'week_number': 1,
      'day_number': 1,
      'kcal': 200,
      'completed_at': '2026-08-11T09:00:00.000Z',
      'updated_at': '2026-08-11T09:00:00.000Z',
    });

    await GuestMergeService(db).mergeGuestData(_userId);

    // The cloud holds an older, emptier profile — the state a fresh account is
    // in. It must lose to the guest row on updated_at.
    remote.pullData['profiles'] = [
      {
        'id': _userId,
        'user_id': _userId,
        'height_cm': null,
        'active_program_id': null,
        'onboarding_complete': false,
        'updated_at': '2026-08-01T00:00:00.000Z',
      },
    ];

    await sync.forcePullAll();

    // Pushed up...
    final pushedProfile = remote.pushed['profiles']!.single;
    expect(pushedProfile['height_cm'], 178);
    expect(pushedProfile['active_program_id'], 'p-1');
    expect(remote.pushed['program_completions'], hasLength(1));

    // ...and not clobbered on the way back down.
    final local = (await db.query('profile', where: 'id = 1')).single;
    expect(local['height_cm'], 178, reason: 'the older cloud row must lose');
    expect(local['active_program_id'], 'p-1');
    expect(await db.query('program_completions'), hasLength(1));
  });

  test('hasGuestData sees a program enrolment, not just food logs', () async {
    // A blank profile row always exists, so it must not read as guest data.
    expect(await GuestMergeService(db).hasGuestData(), isFalse);

    await db.insert('program_completions', {
      'session_id': 's-9',
      'program_id': 'p-9',
      'week_number': 1,
      'day_number': 1,
      'kcal': 100,
      'completed_at': '2026-08-11T09:00:00.000Z',
      'updated_at': '2026-08-11T09:00:00.000Z',
    });

    expect(await GuestMergeService(db).hasGuestData(), isTrue,
        reason: 'losing an enrolment silently is what the old version did');
  });

  test('a local-time updated_at is normalized to UTC before it is pushed',
      () async {
    // Postgres reads a naive timestamp as UTC. From UTC+5 that makes a local
    // stamp look five hours in the future, so it would win every
    // last-write-wins comparison and the cloud copy would never be applied.
    await db.insert('burn_completions', {
      'id': 'b-1',
      'for_date': '2026-08-10',
      'activity': 'Walking',
      'minutes': 30,
      'kcal': 120,
      'completed_at': '2026-08-10T15:00:00.000',
      'updated_at': '2026-08-10T15:00:00.000+05:00',
    });
    await queue('burn_completions', 'b-1');

    await sync.syncNow();

    final pushedAt = remote.pushed['burn_completions']!.single['updated_at'];
    expect(pushedAt, endsWith('Z'), reason: 'must carry an explicit UTC marker');
    expect(DateTime.parse(pushedAt as String).toUtc().hour, 10);
  });
}
