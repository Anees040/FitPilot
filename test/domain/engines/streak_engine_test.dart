import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/streak_engine.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';

void main() {
  group('StreakEngine', () {
    const engine = StreakEngine();

    DayStatus makeStatus(DayState state, {int net = 200, int wiggleRoom = 300}) {
      final toBurn = (net - wiggleRoom).clamp(0, double.infinity).toInt();
      return DayStatus(
        total: KcalRange.exact(net),
        burnedKcal: 0,
        net: KcalRange.exact(net),
        toBurn: toBurn,
        state: state,
        wiggleRoomKcal: wiggleRoom,
      );
    }

    test('NEUTRAL when no logs today, streak counts from yesterday', () {
      final now = DateTime(2026, 7, 27, 10, 0); // 10 AM
      final history = {
        DateTime(2026, 7, 26): makeStatus(DayState.cleared),
        DateTime(2026, 7, 25): makeStatus(DayState.cleared),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.neutral);
      expect(state.currentStreak, 2);
    });

    test('SAFE when today is cleared, streak counts from today', () {
      final now = DateTime(2026, 7, 27, 10, 0);
      final history = {
        DateTime(2026, 7, 27): makeStatus(DayState.cleared),
        DateTime(2026, 7, 26): makeStatus(DayState.cleared),
        DateTime(2026, 7, 25): makeStatus(DayState.cleared),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.safe);
      expect(state.currentStreak, 3);
    });

    test('OVER_PENDING when unburned today and inside grace window', () {
      final now = DateTime(2026, 7, 27, 22, 0); // 10 PM today
      final history = {
        DateTime(2026, 7, 27): makeStatus(
          DayState.unburned,
          net: 400,
          wiggleRoom: 300,
        ),
        DateTime(2026, 7, 26): makeStatus(DayState.cleared),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.overPending);
      expect(state.currentStreak, 1); // Counts from yesterday
      expect(state.kcalStillToBurn, 100);
      expect(state.graceDeadline?.hour, 11);
      expect(state.graceDeadline?.day, 28);
    });

    test('BROKEN when unburned yesterday and grace window expired', () {
      final now = DateTime(2026, 7, 27, 12, 0); // Noon today
      final history = {
        DateTime(2026, 7, 27): makeStatus(DayState.noData),
        DateTime(2026, 7, 26): makeStatus(
          DayState.unburned,
          net: 400,
          wiggleRoom: 300,
        ),
        DateTime(2026, 7, 25): makeStatus(DayState.cleared),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.broken);
      expect(state.currentStreak, 0);
      expect(state.kcalStillToBurn, 100);
    });

    test('CLEARED when unburned yesterday but it is now cleared (DayState.cleared fallback)', () {
      // If yesterday was unburned originally, but later burned, RangeCalculator would
      // emit DayState.cleared. But if StreakEngine evaluates a DayState.cleared,
      // it treats it as SAFE. 
      // If today is unburned, but grace expired AND toBurn is 0 (impossible edge case test).
      final now = DateTime(2026, 7, 27, 12, 0); // Noon today
      final history = {
        DateTime(2026, 7, 27): makeStatus(DayState.unburned, net: 200, wiggleRoom: 300), // toBurn = 0, but state unburned (impossible in reality)
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      // Falls through to CLEARED fallback
      expect(state.phase, StreakPhase.cleared);
      expect(state.kcalStillToBurn, 0);
    });

    test('noData days neither break nor extend the streak in past', () {
      final now = DateTime(2026, 7, 27, 10, 0);
      final history = {
        DateTime(2026, 7, 27): makeStatus(DayState.cleared),
        DateTime(2026, 7, 26): makeStatus(DayState.noData),
        DateTime(2026, 7, 25): makeStatus(DayState.cleared),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.safe);
      expect(state.currentStreak, 2); // 27th and 25th are cleared. 26th is noData.
    });

    test('unburned day in past with enough burn counts as cleared', () {
      final now = DateTime(2026, 7, 27, 10, 0);
      final history = {
        DateTime(2026, 7, 27): makeStatus(DayState.cleared),
        // This simulates a day that was unburned but now has toBurn = 0
        DateTime(2026, 7, 26): makeStatus(DayState.unburned, net: 200, wiggleRoom: 300),
      };

      final state = engine.evaluate(dayHistory: history, now: now);

      expect(state.phase, StreakPhase.safe);
      expect(state.currentStreak, 2); // Both days count
    });
  });
}
