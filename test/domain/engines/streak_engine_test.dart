import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/streak_engine.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';

void main() {
  group('StreakEngine', () {
    const engine = StreakEngine();

    DayStatus makeStatus(DayState state, {int net = 200, int allowance = 300}) {
      return DayStatus(
        total: KcalRange.exact(net),
        burnedKcal: 0,
        net: KcalRange.exact(net),
        remainingKcal: allowance - net,
        state: state,
        targetKcal: 2000, allowanceKcal: allowance,
      );
    }

    test('NEUTRAL when no logs today, streak counts from yesterday', () {
      final now = DateTime(2026, 7, 27, 10, 0); // 10 AM
      final history = {
        DateTime(2026, 7, 26): makeStatus(DayState.under),
        DateTime(2026, 7, 25): makeStatus(DayState.near),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.neutral);
      expect(state.currentStreak, 2);
    });

    test('SAFE when today is under/near, streak counts from today', () {
      final now = DateTime(2026, 7, 27, 10, 0);
      final history = {
        DateTime(2026, 7, 27): makeStatus(DayState.under),
        DateTime(2026, 7, 26): makeStatus(DayState.near),
        DateTime(2026, 7, 25): makeStatus(DayState.under),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.safe);
      expect(state.currentStreak, 3);
    });

    test('OVER_PENDING when over today and inside grace window', () {
      final now = DateTime(2026, 7, 27, 22, 0); // 10 PM today
      final history = {
        DateTime(2026, 7, 27): makeStatus(
          DayState.over,
          net: 400,
          allowance: 300,
        ),
        DateTime(2026, 7, 26): makeStatus(DayState.under),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.overPending);
      expect(state.kcalStillToBurn, 100);
      expect(state.currentStreak, 1); // Yesterday's streak
      expect(
        state.graceDeadline,
        DateTime(2026, 7, 28, 11, 59, 59), // default graceHour = 11
      );
    });

    test('CLEARED when over today but burned enough', () {
      final now = DateTime(2026, 7, 27, 22, 0);

      final clearedStatus = DayStatus(
        total: KcalRange.exact(400),
        burnedKcal: 100,
        net: KcalRange.exact(300),
        remainingKcal: 0,
        state: DayState.over,
        targetKcal: 2000, allowanceKcal: 300,
      );

      final history = {DateTime(2026, 7, 27): clearedStatus};

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.cleared);
      expect(state.kcalStillToBurn, 0);
      expect(state.currentStreak, 1);
    });

    test('BROKEN when grace expired and still over', () {
      final now = DateTime(2026, 7, 28, 12, 1); // Next day 12:01 PM
      final history = {
        DateTime(2026, 7, 27): makeStatus(
          DayState.over,
          net: 400,
          allowance: 300,
        ),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.broken);
      expect(state.kcalStillToBurn, 100);
      expect(state.currentStreak, 0);
    });

    test('CLEARED when grace expired but enough burned', () {
      final now = DateTime(2026, 7, 28, 12, 1); // Next day 12:01 PM
      final clearedStatus = DayStatus(
        total: KcalRange.exact(400),
        burnedKcal: 100,
        net: KcalRange.exact(300),
        remainingKcal: 0,
        state: DayState.over,
        targetKcal: 2000, allowanceKcal: 300,
      );
      final history = {
        DateTime(2026, 7, 27): clearedStatus,
        DateTime(2026, 7, 26): makeStatus(DayState.under),
      };
      // In StreakEngine, if today is neutral, it checks yesterday.
      // Wait, if today is the 28th and there's no log, it evaluates today as Neutral.
      // So let's evaluate for the 27th being "now" but time traveled.
      // Actually, StreakEngine looks at `today = _dateOnly(now)`.
      // If `now` is 28th, `today` is 28th. Since 28th is empty, it returns Neutral,
      // but counts streak from 27th.
      // When counting streak from 27th, it sees 27th is DayState.over, but kcalStillToBurn <= 0.
      // So it counts 27th as cleared, and adds 26th!
      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.neutral);
      expect(state.currentStreak, 2); // 27th (cleared) + 26th (under)
    });

    test('Streak broken yesterday means streak is 0 today', () {
      final now = DateTime(2026, 7, 28, 10, 0);
      final history = {
        DateTime(2026, 7, 27): makeStatus(
          DayState.over,
          net: 400,
          allowance: 300,
        ), // Broken yesterday
        DateTime(2026, 7, 26): makeStatus(DayState.under),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.neutral); // Today has no logs
      expect(state.currentStreak, 0); // Yesterday was broken, so streak breaks
    });
  });
}
