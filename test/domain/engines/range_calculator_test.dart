import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/range_calculator.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

void main() {
  group('RangeCalculator', () {
    const calc = RangeCalculator();
    final now = DateTime(2026, 7, 27);

    test('empty logs returns zero total and net, state under', () {
      final status = calc.dayStatus(
        logs: [],
        burnedKcal: 0,
        targetKcal: 2000, allowanceKcal: 300,
      );

      expect(status.total, KcalRange(0, 0));
      expect(status.net, KcalRange(0, 0));
      expect(status.remainingKcal, 300);
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
        targetKcal: 2000, allowanceKcal: 300,
      );

      expect(status.total, KcalRange(100, 200));
    });

    test('net correctly subtracts burnedKcal clamping at 0', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(200, 300),
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 250,
        targetKcal: 2000, allowanceKcal: 300,
      );

      expect(status.total, KcalRange(200, 300));
      // 200 - 250 = 0 (clamped), 300 - 250 = 50
      expect(status.net, KcalRange(0, 50));
      // Midpoint of 0-50 is 25. Remaining = 300 - 25 = 275.
      expect(status.remainingKcal, 275);
    });

    test('state is under when net midpoint <= allowance * 0.8', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(200, 200),
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 0,
        targetKcal: 2000, allowanceKcal: 300,
      );

      // Midpoint 200. Allowance * 0.8 = 240. Under.
      expect(status.state, DayState.under);
    });

    test('state is near when allowance * 0.8 < net midpoint <= allowance', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(250, 250),
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 0,
        targetKcal: 2000, allowanceKcal: 300,
      );

      // Midpoint 250. Allowance * 0.8 = 240. Near.
      expect(status.state, DayState.near);
    });

    test('state is over when net midpoint > allowance', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(350, 350),
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 0,
        targetKcal: 2000, allowanceKcal: 300,
      );

      // Midpoint 350 > 300. Over.
      expect(status.state, DayState.over);
    });

    test('remainingKcal is negative when over allowance', () {
      final logs = [
        FoodLog(
          id: '1',
          customName: 'A',
          quantity: 1,
          kcal: KcalRange(400, 500),
          source: LogSource.manual,
          loggedAt: now,
        ),
      ];

      final status = calc.dayStatus(
        logs: logs,
        burnedKcal: 0,
        targetKcal: 2000, allowanceKcal: 300,
      );

      // Midpoint 450. Remaining = 300 - 450 = -150.
      expect(status.remainingKcal, -150);
    });
  });
}
