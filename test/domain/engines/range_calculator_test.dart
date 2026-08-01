import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/range_calculator.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

void main() {
  group('RangeCalculator', () {
    const calc = RangeCalculator();
    final now = DateTime(2026, 7, 27);

    test('empty logs returns zero total and net, state noData', () {
      final status = calc.dayStatus(
        logs: [],
        burnedKcal: 0,
        wiggleRoomKcal: 300,
      );

      expect(status.total, KcalRange(0, 0));
      expect(status.net, KcalRange(0, 0));
      expect(status.toBurn, 0);
      expect(status.state, DayState.noData);
    });

    test('ignores soft-deleted logs', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(100, 200),
          source: LogSource.manual,
          loggedAt: now,
        ),
        FoodLog(
          id: '2',
          customName: 'B',
          quantity: 1,
          kcal: KcalRange(50, 100),
          source: LogSource.manual,
          loggedAt: now,
          deletedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 0,
        wiggleRoomKcal: 300,
      );

      expect(status.total, KcalRange(100, 200));
    });

    test('net correctly subtracts burnedKcal clamping at 0', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(100, 200),
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 150,
        wiggleRoomKcal: 300,
      );

      expect(status.total, KcalRange(100, 200));
      // 100-150 -> 0, 200-150 -> 50
      expect(status.net, KcalRange(0, 50));
    });

    test('cleared state when toBurn is 0 (within wiggle room)', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(200, 250), // midpoint 225
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 0,
        wiggleRoomKcal: 300,
      );

      expect(status.state, DayState.cleared);
      expect(status.toBurn, 0);
    });

    test('unburned state when toBurn > 0 and no burnedKcal', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(300, 500), // midpoint 400
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 0,
        wiggleRoomKcal: 300,
      );

      // net midpoint is 400, wiggle room is 300 -> toBurn 100
      expect(status.state, DayState.unburned);
      expect(status.toBurn, 100);
    });

    test('inProgress state when toBurn > 0 and burnedKcal > 0', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(600, 600), // midpoint 600
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 100, // burns 100, net midpoint 500
        wiggleRoomKcal: 300,
      );

      // net midpoint 500 - wiggle 300 = 200 toBurn
      expect(status.state, DayState.inProgress);
      expect(status.toBurn, 200);
    });

    test('cleared state when toBurn becomes 0 after burning', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(600, 600), // midpoint 600
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 400, // net midpoint 200
        wiggleRoomKcal: 300,
      );

      // net midpoint 200 - wiggle 300 = -100 -> 0 toBurn
      expect(status.state, DayState.cleared);
      expect(status.toBurn, 0);
    });
  });
}
