import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/notification_inbox_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/domain/entities/app_notification.dart';

/// Which categories the inbox is showing. Empty means "everything".
final _filterProvider = StateProvider.autoDispose<Set<NotificationCategory>>(
  (ref) => {},
);

/// Shows only unread when true.
final _unreadOnlyProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Shows only entries from today when true.
///
/// The commonest question of an inbox is "what happened since I last looked",
/// and scrolling a week of history to answer it is the thing that makes people
/// stop opening it.
final _todayOnlyProvider = StateProvider.autoDispose<bool>((ref) => false);

/// The in-app notification centre.
///
/// Read, delete, filter by category, and jump to whatever the notification is
/// about. Entirely offline — the feed is derived from local app state.
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inboxAsync = ref.watch(notificationInboxProvider);
    final filters = ref.watch(_filterProvider);
    final unreadOnly = ref.watch(_unreadOnlyProvider);
    final todayOnly = ref.watch(_todayOnlyProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/settings/notifications'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final notifier = ref.read(notificationInboxProvider.notifier);
              if (value == 'read_all') {
                await notifier.markAllRead();
              } else if (value == 'clear') {
                await notifier.clearAll();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'read_all', child: Text('Mark all as read')),
              PopupMenuItem(value: 'clear', child: Text('Clear all')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: inboxAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonList(count: 4),
          ),
          error: (error, _) => ErrorState(
            reason: "Couldn't load your notifications.",
            onRetry: () => ref.invalidate(notificationInboxProvider),
          ),
          data: (all) {
            final visible = all.where((n) {
              if (unreadOnly && !n.isUnread) return false;
              if (todayOnly && !_isToday(n.createdAt)) return false;
              if (filters.isNotEmpty && !filters.contains(n.category)) {
                return false;
              }
              return true;
            }).toList();

            // Only offer chips for categories that actually have entries — a
            // filter that can only ever return nothing is clutter.
            final present = all.map((n) => n.category).toSet().toList()
              ..sort((a, b) => a.label.compareTo(b.label));

            return Column(
              children: [
                if (all.isNotEmpty)
                  _FilterBar(
                    present: present,
                    unreadCount: all.where((n) => n.isUnread).length,
                  ),
                Expanded(
                  child: all.isEmpty
                      ? _EmptyInbox(
                          onOpenSettings: () =>
                              context.push('/settings/notifications'),
                        )
                      : visible.isEmpty
                      ? _NoMatches(
                          onClear: () {
                            ref.read(_filterProvider.notifier).state = {};
                            ref.read(_unreadOnlyProvider.notifier).state = false;
                            ref.read(_todayOnlyProvider.notifier).state = false;
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref
                              .read(notificationInboxProvider.notifier)
                              .refresh(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: visible.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _NotificationTile(
                                notification: visible[i],
                                onTap: () async {
                                  final route = visible[i].payload;
                                  await ref
                                      .read(notificationInboxProvider.notifier)
                                      .markRead(visible[i].id);
                                  if (route != null && context.mounted) {
                                    context.go(route);
                                  }
                                },
                                onDelete: () => ref
                                    .read(notificationInboxProvider.notifier)
                                    .delete(visible[i].id),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

bool _isToday(DateTime at) {
  final now = DateTime.now();
  return at.year == now.year && at.month == now.month && at.day == now.day;
}

class _FilterBar extends ConsumerWidget {
  final List<NotificationCategory> present;
  final int unreadCount;

  const _FilterBar({required this.present, required this.unreadCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final filters = ref.watch(_filterProvider);
    final unreadOnly = ref.watch(_unreadOnlyProvider);
    final todayOnly = ref.watch(_todayOnlyProvider);

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread',
            selected: unreadOnly,
            onTap: () =>
                ref.read(_unreadOnlyProvider.notifier).state = !unreadOnly,
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Today',
            selected: todayOnly,
            onTap: () =>
                ref.read(_todayOnlyProvider.notifier).state = !todayOnly,
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 13),
            color: ext.hairline,
          ),
          const SizedBox(width: 8),
          for (final category in present) ...[
            _Chip(
              label: category.label,
              selected: filters.contains(category),
              onTap: () {
                final next = Set<NotificationCategory>.from(filters);
                if (!next.remove(category)) next.add(category);
                ref.read(_filterProvider.notifier).state = next;
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.16)
                : ext.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : ext.hairline,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.caption.copyWith(
              color: selected ? theme.colorScheme.primary : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final unread = notification.isUnread;
    final accent = _accent(notification.category, theme, ext);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: ext.error.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline_rounded, color: ext.error),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_icon(notification.category), size: 19, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.bodyStrong.copyWith(
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notification.body, style: theme.textTheme.caption),
                  const SizedBox(height: 6),
                  Text(
                    _age(notification.createdAt),
                    style: theme.textTheme.caption.copyWith(
                      color: ext.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(NotificationCategory c) => switch (c) {
    NotificationCategory.mealReminder => Icons.restaurant_rounded,
    NotificationCategory.burnReminder => Icons.local_fire_department_rounded,
    NotificationCategory.streakRisk => Icons.whatshot_rounded,
    NotificationCategory.milestone => Icons.emoji_events_rounded,
    NotificationCategory.programDay => Icons.fitness_center_rounded,
    NotificationCategory.weighIn => Icons.monitor_weight_rounded,
    NotificationCategory.water => Icons.water_drop_rounded,
    NotificationCategory.system => Icons.info_outline_rounded,
  };

  static Color _accent(NotificationCategory c, ThemeData theme, AppColors ext) =>
      switch (c) {
        NotificationCategory.streakRisk => ext.warning,
        NotificationCategory.milestone => ext.success,
        NotificationCategory.water => ext.energy,
        _ => theme.colorScheme.primary,
      };

  static String _age(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${at.day}/${at.month}/${at.year}';
  }
}

class _EmptyInbox extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _EmptyInbox({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    // Deliberately not the shared EmptyState: that renders a chart
    // illustration, which says nothing about notifications. A bell in a soft
    // halo reads as "nothing waiting", and naming the categories gives the
    // settings button an obvious purpose.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              "You're all caught up",
              style: theme.textTheme.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Meal and burn reminders, streak warnings, weigh-in days and '
              'milestones will appear here once you switch them on.',
              style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SecondaryButton(
              label: 'Choose your reminders',
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  final VoidCallback onClear;

  const _NoMatches({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      message: 'Nothing matches these filters.',
      illustration: 'empty_search',
      buttonLabel: 'Clear filters',
      onAction: onClear,
    );
  }
}
