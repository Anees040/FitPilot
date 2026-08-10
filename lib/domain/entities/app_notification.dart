import 'package:equatable/equatable.dart';

/// What a notification is about.
///
/// The category drives three things at once: the icon and accent in the inbox,
/// which preference toggle silences it, and which filter chip it appears under.
/// Adding a category means adding it in exactly one place.
enum NotificationCategory {
  mealReminder,
  burnReminder,
  streakRisk,
  milestone,
  programDay,
  weighIn,
  water,
  system;

  /// Stable database value. Never rename these — stored rows depend on them.
  String get storageKey => switch (this) {
    NotificationCategory.mealReminder => 'meal_reminder',
    NotificationCategory.burnReminder => 'burn_reminder',
    NotificationCategory.streakRisk => 'streak_risk',
    NotificationCategory.milestone => 'milestone',
    NotificationCategory.programDay => 'program_day',
    NotificationCategory.weighIn => 'weigh_in',
    NotificationCategory.water => 'water',
    NotificationCategory.system => 'system',
  };

  /// Shown on the filter chips and in the settings list.
  String get label => switch (this) {
    NotificationCategory.mealReminder => 'Meals',
    NotificationCategory.burnReminder => 'Burn',
    NotificationCategory.streakRisk => 'Streak',
    NotificationCategory.milestone => 'Milestones',
    NotificationCategory.programDay => 'Programs',
    NotificationCategory.weighIn => 'Weigh-in',
    NotificationCategory.water => 'Water',
    NotificationCategory.system => 'App',
  };

  /// Unknown values decay to [system] rather than throwing, so a row written by
  /// a newer build can still be read by an older one.
  static NotificationCategory fromStorage(String? value) {
    for (final category in NotificationCategory.values) {
      if (category.storageKey == value) return category;
    }
    return NotificationCategory.system;
  }
}

/// One entry in the in-app notification inbox.
///
/// The id is deterministic (`category:date[:slot]`) so the feed builder can be
/// re-run as often as it likes — re-inserting an existing id is ignored, which
/// is what keeps the inbox free of duplicates without any "last run" bookkeeping.
class AppNotification extends Equatable {
  final String id;
  final NotificationCategory category;
  final String title;
  final String body;

  /// Route to open when tapped, e.g. `/plan`. Null means "no destination".
  final String? payload;

  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.payload,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    category: category,
    title: title,
    body: body,
    createdAt: createdAt,
    payload: payload,
    readAt: readAt ?? this.readAt,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'category': category.storageKey,
    'title': title,
    'body': body,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
    'read_at': readAt?.toIso8601String(),
    // Bumped whenever read state changes, which is the only mutable part.
    // UTC because Postgres stores timestamptz in UTC: a naive local-time
    // string is read back as if it were already UTC, which from UTC+5 makes
    // every local row look five hours newer than it is and win every
    // last-write-wins comparison against the cloud.
    'updated_at': (readAt ?? createdAt).toUtc().toIso8601String(),
  };

  factory AppNotification.fromRow(Map<String, Object?> row) {
    final createdRaw = row['created_at'] as String?;
    final readRaw = row['read_at'] as String?;
    return AppNotification(
      id: row['id'] as String,
      category: NotificationCategory.fromStorage(row['category'] as String?),
      title: (row['title'] as String?) ?? '',
      body: (row['body'] as String?) ?? '',
      payload: row['payload'] as String?,
      // A malformed timestamp must not sink the whole inbox.
      createdAt: DateTime.tryParse(createdRaw ?? '') ?? DateTime.now(),
      readAt: readRaw == null ? null : DateTime.tryParse(readRaw),
    );
  }

  @override
  List<Object?> get props => [id, category, title, body, payload, createdAt, readAt];
}
