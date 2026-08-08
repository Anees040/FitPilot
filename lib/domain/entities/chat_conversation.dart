import 'package:equatable/equatable.dart';

/// One coach thread.
///
/// Threads exist so a question about tonight's dinner does not end up buried
/// under three weeks of unrelated chat, and so the model is not fed a
/// transcript where the topic changed six times.
class ChatConversation extends Equatable {
  final String id;

  /// Shown in the sidebar. Auto-derived from the first message, and renameable.
  final String title;

  final DateTime createdAt;

  /// Last activity. The sidebar sorts on this, so the thread you were just in
  /// is always at the top.
  final DateTime updatedAt;

  /// Filled in when the list is loaded, for the sidebar preview. Not stored.
  final String? preview;
  final int messageCount;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.preview,
    this.messageCount = 0,
  });

  bool get isEmpty => messageCount == 0;

  /// Relative age for the sidebar row.
  String relativeAge({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(updatedAt);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '${weeks}w';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }

  /// A title derived from the first thing the user said.
  ///
  /// Trimmed at a word boundary so the sidebar shows "How do I burn 300 kcal…"
  /// rather than a hard cut mid-word.
  static String titleFromMessage(String text, {int maxLength = 38}) {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'New chat';
    if (cleaned.length <= maxLength) return cleaned;

    final cut = cleaned.substring(0, maxLength);
    final lastSpace = cut.lastIndexOf(' ');
    final base = lastSpace > maxLength ~/ 2 ? cut.substring(0, lastSpace) : cut;
    return '$base…';
  }

  ChatConversation copyWith({
    String? title,
    DateTime? updatedAt,
    String? preview,
    int? messageCount,
  }) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preview: preview ?? this.preview,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static ChatConversation? fromRow(Map<String, Object?> row) {
    final id = row['id'];
    if (id is! String) return null;

    DateTime parse(Object? value) {
      if (value is String) {
        return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    return ChatConversation(
      id: id,
      title: (row['title'] as String?)?.trim().isNotEmpty == true
          ? row['title'] as String
          : 'New chat',
      createdAt: parse(row['created_at']),
      updatedAt: parse(row['updated_at']),
      preview: (row['preview'] as String?)?.trim(),
      messageCount: (row['message_count'] as int?) ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, title, createdAt, updatedAt, messageCount];
}
