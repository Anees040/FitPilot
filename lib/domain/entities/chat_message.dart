import 'package:equatable/equatable.dart';

/// Who wrote a coach message. Mirrors Gemini's own role vocabulary so the
/// transcript can be replayed to the API without translation.
enum ChatRole { user, model }

/// One message in the AI Coach conversation.
class ChatMessage extends Equatable {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == ChatRole.user;

  /// "14:32" — the timestamp shown under a bubble.
  String get clockLabel {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'role': role.name,
    'content': content,
    'created_at': createdAt.toUtc().toIso8601String(),
    // A message never changes after it is written, so updated_at starts equal
    // to created_at. Sync needs the column regardless: last-write-wins has
    // nothing to compare without it.
    'updated_at': createdAt.toUtc().toIso8601String(),
  };

  /// Returns null when the row is unreadable, so one bad record cannot break
  /// the whole transcript.
  static ChatMessage? fromRow(Map<String, Object?> row) {
    final id = row['id'];
    final content = row['content'];
    if (id is! String || content is! String) return null;

    final rawRole = row['role'];
    final role = rawRole == 'model' ? ChatRole.model : ChatRole.user;

    final rawDate = row['created_at'];
    final createdAt = rawDate is String
        ? DateTime.tryParse(rawDate)?.toLocal()
        : null;

    return ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, role, content, createdAt];
}
