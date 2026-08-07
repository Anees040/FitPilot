import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';
import 'package:fitpilot/features/plan/presentation/widgets/burn_log_sheet.dart';

void main() {
  group('kcalForBurnMinutes', () {
    test('uses the MET formula when the option carries a MET', () {
      const option = BurnOption(
        activity: 'Running',
        minutes: 25,
        kcal: 300,
        met: 7.0,
      );

      // kcal/min = MET x 3.5 x weightKg / 200 = 7 x 3.5 x 70 / 200 = 8.575
      expect(kcalForBurnMinutes(option, 70.0, 30), 257); // 257.25
      expect(kcalForBurnMinutes(option, 70.0, 60), 515); // 514.5, rounds up
    });

    test('scales with body weight', () {
      const option = BurnOption(
        activity: 'Running',
        minutes: 30,
        kcal: 300,
        met: 7.0,
      );

      final light = kcalForBurnMinutes(option, 50.0, 30);
      final heavy = kcalForBurnMinutes(option, 100.0, 30);

      expect(heavy, greaterThan(light));
      expect(heavy, (light * 2).round());
    });

    test('half the suggested duration credits about half the kcal', () {
      const option = BurnOption(
        activity: 'Cycling',
        minutes: 40,
        kcal: 400,
        met: 6.0,
      );

      final full = kcalForBurnMinutes(option, 70.0, 40);
      final half = kcalForBurnMinutes(option, 70.0, 20);

      expect(half, closeTo(full / 2, 1));
    });

    test('falls back to proportional scaling with no MET', () {
      const option = BurnOption(activity: 'Program session', minutes: 20, kcal: 200);

      expect(kcalForBurnMinutes(option, 70.0, 20), 200);
      expect(kcalForBurnMinutes(option, 70.0, 10), 100);
      expect(kcalForBurnMinutes(option, 70.0, 40), 400);
    });

    test('returns zero for a zero-length session', () {
      const option = BurnOption(
        activity: 'Running',
        minutes: 25,
        kcal: 300,
        met: 7.0,
      );

      expect(kcalForBurnMinutes(option, 70.0, 0), 0);
    });

    test('a zero-minute suggestion without MET does not divide by zero', () {
      const option = BurnOption(activity: 'Odd', minutes: 0, kcal: 150);

      expect(kcalForBurnMinutes(option, 70.0, 30), 150);
    });
  });
}
