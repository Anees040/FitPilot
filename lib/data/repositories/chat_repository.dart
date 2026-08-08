import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:fitpilot/domain/entities/chat_conversation.dart';
import 'package:fitpilot/domain/entities/chat_message.dart';

/// Stores coach threads and their messages.
///
/// LOCAL-ONLY: nothing here ever leaves the device, so this repository never
/// enqueues anything to `sync_queue`.
class ChatRepository {
  final Database db;

  const ChatRepository(this.db);

  /// Messages loaded per thread. The coach replays only the recent tail anyway,
  /// and a thread longer than this is a sign it should have been a new one.
  static const int maxLoaded = 200;

  // ── Conversations ────────────────────────────────────────────────────────

  /// Every thread, most recently used first.
  ///
  /// The preview and message count come from one grouped query rather than a
  /// query per row, so opening the sidebar is a single database round trip
  /// regardless of how many threads exist.
  Future<List<ChatConversation>> conversations() async {
    final rows = await db.rawQuery('''
      SELECT
        c.id,
        c.title,
        c.created_at,
        c.updated_at,
        COUNT(m.id) AS message_count,
        (
          SELECT content FROM chat_messages
          WHERE conversation_id = c.id
          ORDER BY created_at DESC, rowid DESC LIMIT 1
        ) AS preview
      FROM chat_conversations c
      LEFT JOIN chat_messages m ON m.conversation_id = c.id
      GROUP BY c.id
      ORDER BY c.updated_at DESC
    ''');

    final out = <ChatConversation>[];
    for (final row in rows) {
      final conversation = ChatConversation.fromRow(row);
      if (conversation != null) out.add(conversation);
    }
    return out;
  }

  Future<ChatConversation> createConversation({String title = 'New chat'}) async {
    final now = DateTime.now();
    final conversation = ChatConversation(
      id: const Uuid().v4(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('chat_conversations', conversation.toRow());
    return conversation;
  }

  Future<void> renameConversation(String id, String title) async {
    final cleaned = title.trim();
    if (cleaned.isEmpty) return;
    await db.update(
      'chat_conversations',
      {'title': cleaned, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a thread and its messages.
  ///
  /// Done in a transaction so a failure cannot leave messages orphaned against
  /// a thread that no longer exists.
  Future<void> deleteConversation(String id) async {
    await db.transaction((txn) async {
      await txn.delete('chat_messages', where: 'conversation_id = ?', whereArgs: [id]);
      await txn.delete('chat_conversations', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteAllConversations() async {
    await db.transaction((txn) async {
      await txn.delete('chat_messages');
      await txn.delete('chat_conversations');
    });
  }

  /// Removes threads that were opened but never used.
  ///
  /// Tapping the coach icon starts a thread immediately, so without this the
  /// sidebar fills with empty "New chat" rows from people who opened it and
  /// backed out.
  Future<void> pruneEmpty({String? except}) async {
    await db.rawDelete(
      '''
      DELETE FROM chat_conversations
      WHERE id NOT IN (SELECT DISTINCT conversation_id FROM chat_messages)
        AND id != ?
      ''',
      [except ?? ''],
    );
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  /// Oldest first, so the list renders top-to-bottom without reversing.
  Future<List<ChatMessage>> messagesIn(
    String conversationId, {
    int limit = maxLoaded,
  }) async {
    // rowid breaks ties: two messages written in the same millisecond have
    // identical created_at, and ISO-8601 strings sort equal, so ordering by
    // timestamp alone can put a reply above the question it answers.
    final rows = await db.rawQuery(
      '''
      SELECT * FROM chat_messages
      WHERE conversation_id = ?
      ORDER BY created_at DESC, rowid DESC
      LIMIT ?
      ''',
      [conversationId, limit],
    );

    final messages = <ChatMessage>[];
    for (final row in rows) {
      final message = ChatMessage.fromRow(row);
      if (message != null) messages.add(message);
    }
    return messages.reversed.toList();
  }

  /// Inserts a message and bumps its thread's `updated_at`.
  ///
  /// The bump is what keeps the sidebar ordered by recent activity; doing it
  /// here means no caller can forget.
  Future<void> insert(String conversationId, ChatMessage message) async {
    await db.transaction((txn) async {
      await txn.insert(
        'chat_messages',
        {...message.toRow(), 'conversation_id': conversationId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'chat_conversations',
        {'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    });
  }

  Future<void> deleteMessage(String id) async {
    await db.delete('chat_messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearMessagesIn(String conversationId) async {
    await db.delete(
      'chat_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<int> messageCount() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM chat_messages');
    final value = result.isEmpty ? null : result.first['c'];
    return value is int ? value : 0;
  }
}
