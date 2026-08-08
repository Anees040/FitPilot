import 'package:sqflite/sqflite.dart';

import 'package:fitpilot/domain/entities/chat_message.dart';

/// Stores the AI Coach transcript.
///
/// LOCAL-ONLY: the conversation never leaves the device, so this repository
/// never enqueues anything to `sync_queue`.
class ChatRepository {
  final Database db;

  const ChatRepository(this.db);

  /// How many messages to keep in view. Older ones stay on disk but are not
  /// loaded — the coach only ever replays the recent tail anyway.
  static const int maxLoaded = 100;

  /// Oldest first, so the list renders top-to-bottom without reversing.
  Future<List<ChatMessage>> latest({int limit = maxLoaded}) async {
    final rows = await db.query(
      'chat_messages',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final messages = <ChatMessage>[];
    for (final row in rows) {
      final message = ChatMessage.fromRow(row);
      if (message != null) messages.add(message);
    }
    return messages.reversed.toList();
  }

  Future<void> insert(ChatMessage message) async {
    await db.insert(
      'chat_messages',
      message.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await db.delete('chat_messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    await db.delete('chat_messages');
  }

  Future<int> count() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM chat_messages');
    final value = result.isEmpty ? null : result.first['c'];
    return value is int ? value : 0;
  }
}
