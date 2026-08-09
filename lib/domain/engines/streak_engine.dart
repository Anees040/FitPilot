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

    // First check if yesterday was pending unburned/inProgress and grace expired without clearing.
    if (yesterdayStatus != null &&
        (yesterdayStatus.state == DayState.unburned ||
         yesterdayStatus.state == DayState.inProgress)) {
      final yesterdayDeadline = graceDeadlineFor(
        today.subtract(const Duration(days: 1)),
        graceHour,
      );
      final kcalStillToBurn = yesterdayStatus.toBurn;

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

    // NEUTRAL: no logs today (noData).
    if (todayStatus == null || todayStatus.state == DayState.noData) {
      final streak = _countStreak(history, today, lookFromYesterday: true);
      return StreakState(
        phase: StreakPhase.neutral,
        currentStreak: streak,
        kcalStillToBurn: 0,
      );
    }

    // SAFE: today's state is cleared.
    if (todayStatus.state == DayState.cleared) {
      final streak = _countStreak(history, today, lookFromYesterday: false);
      return StreakState(
        phase: StreakPhase.safe,
        currentStreak: streak,
        kcalStillToBurn: 0,
      );
    }

    // Today has unburned debt — check grace window.
    final deadline = graceDeadlineFor(today, graceHour);
    final kcalStillToBurn = todayStatus.toBurn;

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
        // Was over but burned enough — CLEARED. (Should be DayState.cleared anyway, but fallback).
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

  /// Counts consecutive safe/cleared days ending at
  /// [referenceDate] (or yesterday if [lookFromYesterday] is true).
  int _countStreak(
    Map<DateTime, DayStatus> history,
    DateTime referenceDate, {
    required bool lookFromYesterday,
  }) {
    var count = 0;
    var pendingNoDataCount = 0;
    var day = lookFromYesterday
        ? referenceDate.subtract(const Duration(days: 1))
        : referenceDate;

    for (int i = 0; i < 365; i++) {
      final status = history[_dateOnly(day)];
      if (status == null) break;

      if (status.state == DayState.cleared) {
        count++;
        count += pendingNoDataCount;
        pendingNoDataCount = 0;
      } else if (status.state == DayState.noData) {
        // noData days extend the streak, but we only add them if we 
        // eventually find a cleared/active day (so we don't count pre-install days).
        // Wait, if today is noData, and yesterday is noData, and they have an active streak,
        // it SHOULD count. If the user is active, we just accumulate.
        pendingNoDataCount++;
      } else if (status.state == DayState.unburned || status.state == DayState.inProgress) {
        // Unburned but has enough burn = cleared → counts.
        final kcalStillToBurn = status.toBurn;
        if (kcalStillToBurn <= 0) {
          count++;
          count += pendingNoDataCount;
          pendingNoDataCount = 0;
        } else {
          break;
        }
      } else {
        break;
      }

      day = day.subtract(const Duration(days: 1));
    }

    // If we are looking from today and the first day(s) were noData,
    // and we NEVER hit an active day (count is 0), then the streak is 0 
    // because they haven't started. But if count > 0, we should add the pending 
    // noData days because they are just "Clean" days since the last active day.
    // Wait! If they had an active day in the past, `pendingNoDataCount` would be 0 
    // when that active day was processed, but what if they haven't been active for 3 days?
    // Today, Yesterday, Day-2 are noData. Day-3 is cleared.
    // Day-3 adds the pending (which was 3), so count becomes 4.
    // Then we go to Day-4 (noData), pending becomes 1. Day-5 (noData), pending becomes 2.
    // If the loop ends, the remaining pending are pre-install days. So we DON'T add them!
    
    // Thus, we DO NOT add pendingNoDataCount here. It only gets added when anchored 
    // by a cleared/active day in the future (which we process first since we go backwards).
    // So if today is noData, it's pending. Then yesterday is cleared. Yesterday anchors it, 
    // we add pending (today) to the count! Perfect.

    return count;
  }
}
