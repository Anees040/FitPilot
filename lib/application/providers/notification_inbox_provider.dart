import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/notification_prefs_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/data/repositories/notification_repository.dart';
import 'package:fitpilot/data/notifications/notification_service.dart';
import 'package:fitpilot/domain/engines/reminder_scheduler.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/entities/app_notification.dart';
import 'package:fitpilot/domain/engines/notification_feed_engine.dart';

final notificationRepositoryProvider = FutureProvider<NotificationRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return NotificationRepository(db, sync: ref.watch(syncQueueWriterProvider(db)));
});

final notificationInboxProvider =
    AsyncNotifierProvider<NotificationInboxNotifier, List<AppNotification>>(
      NotificationInboxNotifier.new,
    );

/// Unread count for the Today bell badge.
///
/// Derived from the inbox rather than queried separately, so the badge can
/// never disagree with the list the user is about to open.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final inbox = ref.watch(notificationInboxProvider).valueOrNull ?? const [];
  return inbox.where((n) => n.isUnread).length;
});

class NotificationInboxNotifier extends AsyncNotifier<List<AppNotification>> {
  static const _engine = NotificationFeedEngine();

  @override
  Future<List<AppNotification>> build() async {
    final repo = await ref.watch(notificationRepositoryProvider.future);
    await _generate(repo);
    return repo.all();
  }

  /// Evaluates the feed rules against current app state and stores anything new.
  ///
  /// Runs on build and on every explicit [refresh], which is what makes the
  /// inbox work without a background isolate: the app catches up the moment it
  /// is opened. Deterministic ids make repeat runs free of duplicates.
  ///
  /// Deliberately forgiving — a missing profile or an empty day must never stop
  /// the inbox from rendering, so a failure here is swallowed and the stored
  /// rows are still returned.
  Future<void> _generate(NotificationRepository repo) async {
    try {
      final prefs = await ref.read(notificationPrefsProvider.future);
      final today = await ref.read(todayProvider.future);
      final profile = await ref.read(profileProvider.future);

      // progressProvider already derives the streak and the weight history, so
      // read them rather than recomputing and risking a different answer.
      final progress = await ref.read(progressProvider.future);
      final weights = progress.weightEntries;

      final context = NotificationContext(
        now: DateTime.now(),
        prefs: prefs,
        dayStatus: today.dayStatus,
        streak: progress.streak,
        loggedMealsToday: today.logs.length,
        lastWeighIn: weights.isEmpty ? null : weights.last.date,
        todaysProgramSession: profile.activeProgramId == null
            ? null
            : 'your programme session',
        programSessionDone: false,
      );

      for (final notification in _engine.generate(context)) {
        await repo.add(notification);
      }

      // Hand the OS its schedule too. Nothing in the app called syncSchedules
      // before this, which is why reminders never actually fired: preferences
      // were saved but no alarm was ever registered.
      await _syncOsSchedule(prefs, context, profile);
    } catch (_) {
      // Feed generation is best-effort; the stored inbox still renders.
    }
  }

  /// Registers the OS-level alarms that fire while the app is closed.
  ///
  /// The in-app inbox and the system notifications are deliberately driven from
  /// the same context object, so what the user sees in the app matches what
  /// their phone shows them.
  Future<void> _syncOsSchedule(
    NotificationPreferences prefs,
    NotificationContext context,
    Profile profile,
  ) async {
    try {
      final schedules = ReminderScheduler().generate(
        now: context.now,
        prefs: prefs,
        todayStatus: context.dayStatus,
        streakState: context.streak,
        profile: profile,
      );
      await ref.read(notificationServiceProvider).syncSchedules(schedules);
    } catch (_) {
      // No notification permission, or an unsupported platform (web). The
      // in-app inbox still works, so this must never surface as an error.
    }
  }

  Future<void> refresh() async {
    final repo = await ref.read(notificationRepositoryProvider.future);
    await _generate(repo);
    state = AsyncData(await repo.all());
  }

  Future<void> markRead(String id) async {
    final repo = await ref.read(notificationRepositoryProvider.future);
    await repo.markRead(id);
    state = AsyncData(await repo.all());
  }

  Future<void> markAllRead() async {
    final repo = await ref.read(notificationRepositoryProvider.future);
    await repo.markAllRead();
    state = AsyncData(await repo.all());
  }

  Future<void> delete(String id) async {
    final repo = await ref.read(notificationRepositoryProvider.future);
    await repo.delete(id);
    state = AsyncData(await repo.all());
  }

  Future<void> clearAll() async {
    final repo = await ref.read(notificationRepositoryProvider.future);
    await repo.clearAll();
    state = const AsyncData([]);
  }
}
