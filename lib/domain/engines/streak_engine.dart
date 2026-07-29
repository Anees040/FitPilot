import '../entities/day_status.dart';
import '../entities/streak_state.dart';

/// Evaluates the streak state machine from day history.
///
/// Pure, deterministic — all time comes in as parameters.
class StreakEngine {
  const StreakEngine();

  /// Returns the grace deadline for a day that went over:
  /// the next day at [graceHour]:59:59.
  DateTime graceDeadlineFor(DateTime overDay, int graceHour) {
    final nextDay = DateTime(overDay.year, overDay.month, overDay.day + 1);
    return DateTime(
      nextDay.year,
      nextDay.month,
      nextDay.day,
      graceHour,
      59,
      59,
    );
  }

  /// Normalizes a DateTime to date-only (year/month/day).
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Evaluates the streak state from day history.
  ///
  /// [dayHistory] maps dates to their [DayStatus].
  /// [now] is the current time.
  /// [graceHour] defaults to 11 (grace deadline = next day at 11:59 AM).
  StreakState evaluate({
    required Map<DateTime, DayStatus> dayHistory,
    required DateTime now,
    int graceHour = 11,
  }) {
    // Normalize all keys to date-only.
    final history = <DateTime, DayStatus>{};
    for (final entry in dayHistory.entries) {
      history[_dateOnly(entry.key)] = entry.value;
    }

    final today = _dateOnly(now);
    final todayStatus = history[today];
    final yesterdayStatus = history[today.subtract(const Duration(days: 1))];

    // First check if yesterday was OVER and grace expired without clearing.
    if (yesterdayStatus != null && yesterdayStatus.state == DayState.over) {
      final yesterdayDeadline = graceDeadlineFor(
        today.subtract(const Duration(days: 1)),
        graceHour,
      );
      final kcalStillToBurn =
          (yesterdayStatus.net.midpoint - yesterdayStatus.allowanceKcal)
              .clamp(0, double.infinity)
              .toInt();

      if (kcalStillToBurn > 0) {
        if (now.isAfter(yesterdayDeadline)) {
          // Grace expired without enough burn. BROKEN.
          return StreakState(
            phase: StreakPhase.broken,
            currentStreak: 0,
            kcalStillToBurn: kcalStillToBurn,
          );
        }
      }
    }

    // NEUTRAL: no logs today (or no data).
    if (todayStatus == null || todayStatus.state == DayState.noData) {
      final streak = _countStreak(history, today, lookFromYesterday: true);
      return StreakState(
        phase: StreakPhase.neutral,
        currentStreak: streak,
        kcalStillToBurn: 0,
      );
    }

    // SAFE: today's state is under or near.
    if (todayStatus.state == DayState.under ||
        todayStatus.state == DayState.near) {
      final streak = _countStreak(history, today, lookFromYesterday: false);
      return StreakState(
        phase: StreakPhase.safe,
        currentStreak: streak,
        kcalStillToBurn: 0,
      );
    }

    // Today is OVER — check grace window.
    final deadline = graceDeadlineFor(today, graceHour);
    final kcalStillToBurn =
        (todayStatus.net.midpoint - todayStatus.allowanceKcal)
            .clamp(0, double.infinity)
            .toInt();

    if (now.isAfter(deadline)) {
      // Grace expired.
      if (kcalStillToBurn > 0) {
        // BROKEN.
        return StreakState(
          phase: StreakPhase.broken,
          currentStreak: 0,
          kcalStillToBurn: kcalStillToBurn,
        );
      } else {
        // Was over but burned enough — CLEARED.
        final streak = _countStreak(history, today, lookFromYesterday: false);
        return StreakState(
          phase: StreakPhase.cleared,
          currentStreak: streak,
          kcalStillToBurn: 0,
        );
      }
    } else {
      // Still within grace window.
      if (kcalStillToBurn <= 0) {
        // Already burned enough — CLEARED.
        final streak = _countStreak(history, today, lookFromYesterday: false);
        return StreakState(
          phase: StreakPhase.cleared,
          currentStreak: streak,
          kcalStillToBurn: 0,
        );
      }

      // OVER_PENDING.
      return StreakState(
        phase: StreakPhase.overPending,
        currentStreak: _countStreak(history, today, lookFromYesterday: true),
        graceDeadline: deadline,
        kcalStillToBurn: kcalStillToBurn,
      );
    }
  }

  /// Counts consecutive safe/cleared/under/near days ending at
  /// [referenceDate] (or yesterday if [lookFromYesterday] is true).
  int _countStreak(
    Map<DateTime, DayStatus> history,
    DateTime referenceDate, {
    required bool lookFromYesterday,
  }) {
    var count = 0;
    var day = lookFromYesterday
        ? referenceDate.subtract(const Duration(days: 1))
        : referenceDate;

    for (int i = 0; i < 365; i++) {
      final status = history[_dateOnly(day)];
      if (status == null) break;

      if (status.state == DayState.under || status.state == DayState.near) {
        count++;
      } else if (status.state == DayState.noData) {
        // noData days neither break nor extend the streak
        // keep counting through them
        // the loop update step will decrement day
      } else if (status.state == DayState.over) {
        // Over but has enough burn = cleared → counts.
        final kcalStillToBurn = (status.net.midpoint - status.allowanceKcal)
            .clamp(0, double.infinity)
            .toInt();
        if (kcalStillToBurn <= 0) {
          count++;
        } else {
          break;
        }
      } else {
        break;
      }

      day = day.subtract(const Duration(days: 1));
    }

    // If not looking from yesterday, include today in count only if
    // today was safe/near or cleared.
    if (!lookFromYesterday) {
      // Today is already included in the loop above.
      return count;
    }

    return count;
  }
}
