import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/application/providers/coach_chat_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/data/ai/coach_service.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/domain/entities/chat_message.dart';

/// A CoachService that answers from a script instead of the network.
class _FakeCoachService extends CoachService {
  final List<String> replies;
  final String? throwMessage;

  /// Transcripts as received, so a test can assert what was actually sent.
  final List<List<ChatMessage>> calls = [];

  _FakeCoachService({this.replies = const ['Sure!'], this.throwMessage});

  @override
  Future<String> send({
    required List<ChatMessage> history,
    CoachContext? context,
  }) async {
    calls.add(List.of(history));
    if (throwMessage != null) throw Exception(throwMessage);
    return replies[(calls.length - 1).clamp(0, replies.length - 1)];
  }
}

/// A service that fails once, then succeeds — for the retry path.
class _FlakyCoachService extends CoachService {
  int attempts = 0;
  final List<List<ChatMessage>> calls = [];

  @override
  Future<String> send({
    required List<ChatMessage> history,
    CoachContext? context,
  }) async {
    calls.add(List.of(history));
    attempts++;
    if (attempts == 1) throw Exception('Network unreachable');
    return 'Back online.';
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// sqflite_ffi hands back the same in-memory database on every open, so the
  /// table is cleared explicitly to keep tests isolated from each other.
  Future<Database> freshDb() async {
    final db = await AppDatabase.inMemory();
    await db.delete('chat_messages');
    return db;
  }

  Future<ProviderContainer> makeContainer(CoachService service) async {
    final db = await freshDb();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        coachServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    await container.read(coachChatProvider.future);
    return container;
  }

  test('starts empty', () async {
    final container = await makeContainer(_FakeCoachService());
    final state = container.read(coachChatProvider).requireValue;

    expect(state.messages, isEmpty);
    expect(state.isTyping, isFalse);
    expect(state.error, isNull);
  });

  test('send appends the user message then the reply, in order', () async {
    final service = _FakeCoachService(replies: ['Try a brisk 30 min walk.']);
    final container = await makeContainer(service);

    await container.read(coachChatProvider.notifier).send('How do I burn 300 kcal?');

    final state = container.read(coachChatProvider).requireValue;
    expect(state.messages.length, 2);
    expect(state.messages[0].role, ChatRole.user);
    expect(state.messages[0].content, 'How do I burn 300 kcal?');
    expect(state.messages[1].role, ChatRole.model);
    expect(state.messages[1].content, 'Try a brisk 30 min walk.');
    expect(state.isTyping, isFalse);
    expect(state.error, isNull);
  });

  test('the reply request carries the user message', () async {
    final service = _FakeCoachService();
    final container = await makeContainer(service);

    await container.read(coachChatProvider.notifier).send('Hello');

    expect(service.calls, hasLength(1));
    expect(service.calls.first.last.content, 'Hello');
    expect(service.calls.first.last.role, ChatRole.user);
  });

  test('messages survive a reload — they are persisted, not in memory', () async {
    final db = await freshDb();
    final service = _FakeCoachService(replies: ['Noted.']);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        coachServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(coachChatProvider.future);
    await container.read(coachChatProvider.notifier).send('Remember this');

    // Rebuild the provider from disk.
    container.invalidate(coachChatProvider);
    final reloaded = await container.read(coachChatProvider.future);

    expect(reloaded.messages.map((m) => m.content), ['Remember this', 'Noted.']);
  });

  test('a failure keeps the user bubble and exposes the error text', () async {
    final service = _FakeCoachService(throwMessage: 'Daily coach limit reached (40 messages/day).');
    final container = await makeContainer(service);

    await container.read(coachChatProvider.notifier).send('Hi');

    final state = container.read(coachChatProvider).requireValue;
    expect(state.messages.length, 1, reason: 'the user message must not vanish');
    expect(state.messages.single.role, ChatRole.user);
    expect(state.isTyping, isFalse);
    // The server's own wording reaches the user, without the Exception prefix.
    expect(state.error, 'Daily coach limit reached (40 messages/day).');
  });

  test('retry re-sends without duplicating the user bubble', () async {
    final service = _FlakyCoachService();
    final container = await makeContainer(service);

    await container.read(coachChatProvider.notifier).send('Are you there?');
    expect(container.read(coachChatProvider).requireValue.error, isNotNull);

    await container.read(coachChatProvider.notifier).retry();

    final state = container.read(coachChatProvider).requireValue;
    expect(state.error, isNull);
    expect(state.messages.length, 2, reason: 'one user message, one reply');
    expect(
      state.messages.where((m) => m.content == 'Are you there?').length,
      1,
      reason: 'the retry must not add a second copy of the question',
    );
    expect(state.messages.last.content, 'Back online.');
  });

  test('an empty or whitespace message is ignored', () async {
    final service = _FakeCoachService();
    final container = await makeContainer(service);

    await container.read(coachChatProvider.notifier).send('   ');

    expect(container.read(coachChatProvider).requireValue.messages, isEmpty);
    expect(service.calls, isEmpty, reason: 'no request should be made');
  });

  test('clear wipes the transcript on disk as well as in state', () async {
    final service = _FakeCoachService();
    final container = await makeContainer(service);

    await container.read(coachChatProvider.notifier).send('One');
    expect(container.read(coachChatProvider).requireValue.messages, isNotEmpty);

    await container.read(coachChatProvider.notifier).clear();
    expect(container.read(coachChatProvider).requireValue.messages, isEmpty);

    container.invalidate(coachChatProvider);
    final reloaded = await container.read(coachChatProvider.future);
    expect(reloaded.messages, isEmpty, reason: 'the table itself must be empty');
  });

  test('the full transcript is replayed so the coach has context', () async {
    final service = _FakeCoachService(replies: ['First', 'Second']);
    final container = await makeContainer(service);

    final notifier = container.read(coachChatProvider.notifier);
    await notifier.send('Question one');
    await notifier.send('Question two');

    expect(service.calls, hasLength(2));
    // Second request carries: q1, a1, q2.
    expect(service.calls[1].map((m) => m.content), [
      'Question one',
      'First',
      'Question two',
    ]);
  });
}
