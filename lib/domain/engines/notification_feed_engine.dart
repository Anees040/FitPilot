import 'package:fitpilot/domain/entities/app_notification.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';

/// Everything the feed engine needs to decide what is worth telling the user.
///
/// A plain snapshot rather than provider access, so the rules below stay pure
/// and fully testable without a database or a clock.
class NotificationContext {
  final DateTime now;
  final NotificationPreferences prefs;
  final DayStatus dayStatus;
  final StreakState streak;

  /// Number of food logs recorded today.
  final int loggedMealsToday;

  /// Title of today's programme session, when the user is enrolled and today
  /// is a training day.
  final String? todaysProgramSession;

  /// True when that session is already ticked off.
  final bool programSessionDone;

  /// When the user last recorded a weight, if ever.
  final DateTime? lastWeighIn;

  const NotificationContext({
    required this.now,
    required this.prefs,
    required this.dayStatus,
    required this.streak,
    this.loggedMealsToday = 0,
    this.todaysProgramSession,
    this.programSessionDone = false,
    this.lastWeighIn,
  });
}

/// Decides which notifications are due right now.
///
/// Pure and idempotent: given the same context it returns the same rows, and
/// each row carries a deterministic `category:date` id. The repository inserts
/// with `ignore`, so running this on every app resume can never duplicate an
/// entry — no "last delivered" bookkeeping is needed anywhere.
///
/// Every rule earns its place by being actionable. A notification that only
/// says "you have not logged" without telling the user what to do is noise, and
/// noise is how apps get their notifications switched off for good.
class NotificationFeedEngine {
  const NotificationFeedEngine();

  List<AppNotification> generate(NotificationContext context) {
    final prefs = context.prefs;
    final now = context.now;

    // Global mute and quiet hours are checked once, here, rather than in each
    // rule — so a new rule cannot accidentally bypass them.
    if (prefs.globalMute) return const [];
    if (prefs.isQuiet(now)) return const [];

    final out = <AppNotification>[];
    final day = _dayKey(now);

    void add(
      NotificationCategory category,
      String idSuffix,
      String title,
      String body, {
      String? payload,
    }) {
      if (!prefs.allows(category)) return;
      out.add(
        AppNotification(
          id: '${category.storageKey}:$day:$idSuffix',
          category: category,
          title: title,
          body: body,
          payload: payload,
          createdAt: now,
        ),
      );
    }

    _addMealReminder(context, add);
    _addBurnReminder(context, add);
    _addStreakRisk(context, add);
    _addMilestone(context, add);
    _addProgramDay(context, add);
    _addWeighIn(context, add);
    _addWater(context, add);

    return out;
  }

  /// Nudges only at the meal windows the user chose, and only when nothing has
  /// been logged in that window yet.
  void _addMealReminder(NotificationContext c, _Add add) {
    if (c.loggedMealsToday > 0 && c.now.hour < 12) return;

    final slot = _mealSlot(c.now);
    if (slot == null) return;

    // Someone who has already logged three meals does not need a fourth nudge.
    if (c.loggedMealsToday >= 3) return;

    add(
      NotificationCategory.mealReminder,
      slot,
      'Log your ${_slotLabel(slot)}',
      c.loggedMealsToday == 0
          ? "Nothing logged yet today — add a meal to keep your numbers honest."
          : 'Add your ${_slotLabel(slot)} so today\'s total stays accurate.',
      payload: '/log',
    );
  }

  /// Fires in the evening only when there is a real surplus left to work off,
  /// and names the size of it so the ask is concrete.
  void _addBurnReminder(NotificationContext c, _Add add) {
    if (c.now.hour < 17 || c.now.hour > 21) return;
    if (c.dayStatus.toBurn <= 0) return;

    add(
      NotificationCategory.burnReminder,
      'evening',
      '${c.dayStatus.toBurn} kcal left to burn',
      'A short session now clears today. Open your plan to pick one.',
      payload: '/plan',
    );
  }

  /// The most valuable alert in the app: the streak is live and about to lapse.
  void _addStreakRisk(NotificationContext c, _Add add) {
    if (c.streak.phase != StreakPhase.overPending) return;
    final deadline = c.streak.graceDeadline;
    if (deadline == null || !deadline.isAfter(c.now)) return;

    final hoursLeft = deadline.difference(c.now).inHours;
    if (hoursLeft > 8) return;

    add(
      NotificationCategory.streakRisk,
      'grace',
      'Your ${c.streak.currentStreak}-day streak is at risk',
      c.streak.kcalStillToBurn > 0
          ? 'Burn ${c.streak.kcalStillToBurn} kcal in the next ${hoursLeft}h to keep it alive.'
          : 'Log today to keep it alive — ${hoursLeft}h left.',
      payload: '/plan',
    );
  }

  /// Celebrates weekly milestones only, so it stays meaningful.
  void _addMilestone(NotificationContext c, _Add add) {
    final streak = c.streak.currentStreak;
    if (streak == 0 || streak % 7 != 0) return;

    add(
      NotificationCategory.milestone,
      'streak-$streak',
      '$streak-day streak',
      streak >= 28
          ? "${streak ~/ 7} weeks without breaking it. That is the hard part done."
          : 'A full ${streak ~/ 7 == 1 ? 'week' : '${streak ~/ 7} weeks'} on plan. Keep going.',
      payload: '/progress',
    );
  }

  /// Reminds about today's programme session, unless it is already done.
  void _addProgramDay(NotificationContext c, _Add add) {
    final session = c.todaysProgramSession;
    if (session == null || c.programSessionDone) return;
    if (c.now.hour < 8) return;

    add(
      NotificationCategory.programDay,
      'session',
      "Today's session: $session",
      'Your programme is waiting. It takes one tap to start.',
      payload: '/programs',
    );
  }

  /// Weekly weigh-in on the chosen day, skipped if already weighed today.
  void _addWeighIn(NotificationContext c, _Add add) {
    if (c.now.weekday != c.prefs.weighInDay) return;

    final target = _minutes(c.prefs.weighInTime);
    if (target == null) return;
    final nowMinutes = c.now.hour * 60 + c.now.minute;
    if (nowMinutes < target) return;

    final last = c.lastWeighIn;
    if (last != null && _isSameDay(last, c.now)) return;

    add(
      NotificationCategory.weighIn,
      'weekly',
      'Weekly weigh-in',
      'Same day, same time, before breakfast — that is what makes the trend readable.',
      payload: '/progress',
    );
  }

  /// A single mid-afternoon prompt. Hourly water pings are the fastest way to
  /// get an app muted, so there is deliberately only one.
  void _addWater(NotificationContext c, _Add add) {
    if (c.now.hour != 15) return;

    add(
      NotificationCategory.water,
      'afternoon',
      'Drink some water',
      'Thirst is often mistaken for hunger. A glass now saves a snack later.',
    );
  }

  /// Which meal window [now] falls in, or null between windows.
  static String? _mealSlot(DateTime now) {
    final h = now.hour;
    if (h >= 7 && h < 11) return 'breakfast';
    if (h >= 12 && h < 15) return 'lunch';
    if (h >= 18 && h < 22) return 'dinner';
    return null;
  }

  static String _slotLabel(String slot) => slot;

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int? _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}

typedef _Add =
    void Function(
      NotificationCategory category,
      String idSuffix,
      String title,
      String body, {
      String? payload,
    });
