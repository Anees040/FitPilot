import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/repositories/notification_repository.dart';
import 'package:fitpilot/domain/entities/app_notification.dart';

AppNotification _n(
  String id, {
  NotificationCategory category = NotificationCategory.mealReminder,
  DateTime? at,
  DateTime? read,
}) => AppNotification(
  id: id,
  category: category,
  title: 'Title $id',
  body: 'Body $id',
  payload: '/log',
  createdAt: at ?? DateTime(2026, 8, 10, 12),
  readAt: read,
);

void main() {
  late Database db;
  late NotificationRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // sqflite_ffi reuses one in-memory database, so clear for isolation.
    db = await AppDatabase.inMemory();
    repo = NotificationRepository(db);
    await repo.clearAll();
  });

  test('the v23 tables and columns exist', () async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='notifications'",
    );
    expect(tables, hasLength(1));

    final columns = await db.rawQuery('PRAGMA table_info(notification_prefs)');
    final names = columns.map((c) => c['name'] as String).toSet();
    expect(
      names,
      containsAll([
        'burn_reminders_enabled',
        'program_reminders_enabled',
        'weigh_in_enabled',
        'weigh_in_day',
        'weigh_in_time',
        'water_reminders_enabled',
        'quiet_hours_enabled',
        'quiet_from',
        'quiet_to',
      ]),
    );
  });

  test('a notification round-trips with every field intact', () async {
    await repo.add(_n('a'));

    final all = await repo.all();
    expect(all, hasLength(1));
    expect(all.single.id, 'a');
    expect(all.single.category, NotificationCategory.mealReminder);
    expect(all.single.payload, '/log');
    expect(all.single.isUnread, isTrue);
  });

  test('re-adding the same id is ignored, which is what stops duplicates',
      () async {
    expect(await repo.add(_n('same')), isTrue);
    expect(await repo.add(_n('same')), isFalse,
        reason: 'the second insert must report that nothing was added');

    expect(await repo.all(), hasLength(1));
  });

  test('a read notification is not resurrected by a repeat generate', () async {
    await repo.add(_n('once'));
    await repo.markRead('once');

    await repo.add(_n('once'));

    final all = await repo.all();
    expect(all, hasLength(1));
    expect(all.single.isUnread, isFalse,
        reason: 're-adding must not clear the read flag');
  });

  test('newest first', () async {
    await repo.add(_n('old', at: DateTime(2026, 8, 10, 8)));
    await repo.add(_n('new', at: DateTime(2026, 8, 10, 20)));

    expect((await repo.all()).map((n) => n.id).toList(), ['new', 'old']);
  });

  test('unread count tracks reads', () async {
    await repo.add(_n('a'));
    await repo.add(_n('b'));
    expect(await repo.unreadCount(), 2);

    await repo.markRead('a');
    expect(await repo.unreadCount(), 1);

    await repo.markAllRead();
    expect(await repo.unreadCount(), 0);
  });

  test('delete removes one, clearAll removes the rest', () async {
    await repo.add(_n('a'));
    await repo.add(_n('b'));

    await repo.delete('a');
    expect((await repo.all()).map((n) => n.id), ['b']);

    await repo.clearAll();
    expect(await repo.all(), isEmpty);
  });

  test('the inbox is capped, dropping the oldest', () async {
    for (var i = 0; i < NotificationRepository.maxRows + 10; i++) {
      await repo.add(
        _n('n$i', at: DateTime(2026, 8, 10).add(Duration(minutes: i))),
      );
    }

    final all = await repo.all();
    expect(all, hasLength(NotificationRepository.maxRows));
    // The newest survives, the oldest is gone.
    expect(all.first.id, 'n${NotificationRepository.maxRows + 9}');
    expect(all.map((n) => n.id), isNot(contains('n0')));
  });

  test('an unknown category decays to system instead of throwing', () async {
    await db.insert('notifications', {
      'id': 'future',
      'category': 'something_new',
      'title': 'From a newer build',
      'body': 'Body',
      'created_at': DateTime(2026, 8, 10).toIso8601String(),
    });

    final all = await repo.all();
    expect(all.single.category, NotificationCategory.system);
  });

  test('writing a notification never enqueues a sync row', () async {
    await repo.add(_n('a'));
    expect(await db.query('sync_queue'), isEmpty);
  });
}
