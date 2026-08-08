import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/repositories/chat_repository.dart';
import 'package:fitpilot/domain/entities/chat_conversation.dart';
import 'package:fitpilot/domain/entities/chat_message.dart';

ChatMessage _msg(String id, String text, {ChatRole role = ChatRole.user}) =>
    ChatMessage(
      id: id,
      role: role,
      content: text,
      createdAt: DateTime.now(),
    );

void main() {
  late Database db;
  late ChatRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // sqflite_ffi shares one in-memory database, so clear for isolation.
    db = await AppDatabase.inMemory();
    repo = ChatRepository(db);
    await repo.deleteAllConversations();
  });

  group('titles', () {
    test('a short question becomes the title verbatim', () {
      expect(
        ChatConversation.titleFromMessage('How do I burn 300 kcal?'),
        'How do I burn 300 kcal?',
      );
    });

    test('a long question is cut at a word boundary, not mid-word', () {
      final title = ChatConversation.titleFromMessage(
        'What should I eat for dinner if I have already had biryani at lunch',
      );
      const source =
          'What should I eat for dinner if I have already had biryani at lunch';
      expect(title.length, lessThanOrEqualTo(39));
      expect(title, endsWith('…'));
      // The kept portion must be a whole-word prefix of the original, so the
      // cut never leaves a fragment like "bir…".
      final kept = title.substring(0, title.length - 1);
      expect(source.startsWith(kept), isTrue);
      expect(source[kept.length], ' ');
    });

    test('an empty message still yields a usable title', () {
      expect(ChatConversation.titleFromMessage('   '), 'New chat');
    });
  });

  group('threads', () {
    test('messages are scoped to their own thread', () async {
      final a = await repo.createConversation(title: 'Diet');
      final b = await repo.createConversation(title: 'Training');

      await repo.insert(a.id, _msg('1', 'What should I eat?'));
      await repo.insert(b.id, _msg('2', 'How many sets?'));

      expect((await repo.messagesIn(a.id)).single.content, 'What should I eat?');
      expect((await repo.messagesIn(b.id)).single.content, 'How many sets?');
    });

    test('the sidebar lists most-recent activity first', () async {
      final older = await repo.createConversation(title: 'Older');
      final newer = await repo.createConversation(title: 'Newer');

      // Sending in the older thread must lift it back to the top.
      await repo.insert(newer.id, _msg('1', 'first'));
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await repo.insert(older.id, _msg('2', 'second'));

      final list = await repo.conversations();
      expect(list.first.id, older.id);
    });

    test('each row carries its message count and last message', () async {
      final c = await repo.createConversation(title: 'Diet');
      await repo.insert(c.id, _msg('1', 'First question'));
      await repo.insert(c.id, _msg('2', 'Latest question'));

      final row = (await repo.conversations()).single;
      expect(row.messageCount, 2);
      expect(row.preview, 'Latest question');
    });

    test('renaming sticks', () async {
      final c = await repo.createConversation(title: 'New chat');
      await repo.renameConversation(c.id, '  Cutting plan  ');

      expect((await repo.conversations()).single.title, 'Cutting plan');
    });

    test('an empty rename is ignored rather than blanking the title', () async {
      final c = await repo.createConversation(title: 'Cutting plan');
      await repo.renameConversation(c.id, '   ');

      expect((await repo.conversations()).single.title, 'Cutting plan');
    });

    test('deleting a thread takes its messages with it', () async {
      final a = await repo.createConversation(title: 'Doomed');
      final b = await repo.createConversation(title: 'Kept');
      await repo.insert(a.id, _msg('1', 'goes away'));
      await repo.insert(b.id, _msg('2', 'stays'));

      await repo.deleteConversation(a.id);

      expect((await repo.conversations()).single.id, b.id);
      // No orphaned rows left behind.
      expect(await repo.messageCount(), 1);
    });

    test('pruning clears threads that were opened but never used', () async {
      final used = await repo.createConversation(title: 'Used');
      await repo.createConversation(title: 'Abandoned');
      await repo.insert(used.id, _msg('1', 'hello'));

      await repo.pruneEmpty();

      expect((await repo.conversations()).map((c) => c.id), [used.id]);
    });

    test('pruning spares the thread currently open', () async {
      final open = await repo.createConversation(title: 'Just opened');
      await repo.pruneEmpty(except: open.id);

      expect((await repo.conversations()).single.id, open.id);
    });

    test('clearing a thread keeps the thread itself', () async {
      final c = await repo.createConversation(title: 'Diet');
      await repo.insert(c.id, _msg('1', 'hello'));

      await repo.clearMessagesIn(c.id);

      expect(await repo.messagesIn(c.id), isEmpty);
      expect((await repo.conversations()).single.id, c.id);
    });
  });

  test('chat writes never reach the sync queue', () async {
    final c = await repo.createConversation(title: 'Diet');
    await repo.insert(c.id, _msg('1', 'private question'));

    expect(await db.query('sync_queue'), isEmpty);
  });
}
