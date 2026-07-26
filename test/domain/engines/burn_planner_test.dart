import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/burn_planner.dart';

void main() {
  group('BurnPlanner', () {
    const planner = BurnPlanner();

    test('returns empty list if kcalOver is <= 0', () {
      expect(planner.planFor(kcalOver: 0, weightKg: 70), isEmpty);
      expect(planner.planFor(kcalOver: -100, weightKg: 70), isEmpty);
    });

    test('always includes walking, even with no equipment', () {
      final options = planner.planFor(kcalOver: 200, weightKg: 70, equipment: []);
      final walking = options.firstWhere((o) => o.activity == 'Walking (brisk)');
      expect(walking, isNotNull);
      expect(walking.steps, isNotNull);
    });

    test('filters exercises by equipment', () {
      final noEqOptions = planner.planFor(kcalOver: 300, weightKg: 70, equipment: []);
      expect(
        noEqOptions.any((o) => o.activity == 'Jump rope'),
        isFalse,
      );

      final withRopeOptions =
          planner.planFor(kcalOver: 300, weightKg: 70, equipment: ['rope']);
      expect(
        withRopeOptions.any((o) => o.activity == 'Jump rope'),
        isTrue,
      );
    });

    test('rounds minutes UP to next 5, minimum 5', () {
      // Small kcal surplus should clamp to 5 mins.
      final options = planner.planFor(kcalOver: 10, weightKg: 70, equipment: []);
      expect(options.every((o) => o.minutes == 5), isTrue);

      // walking: 3.5 MET
      // kcal/min = 3.5 * 3.5 * 70 / 200 = 4.2875 kcal/min
      // minutes for 100 kcal = 100 / 4.2875 = 23.32 mins.
      // Round UP to nearest 5 = 25 mins.
      final ops = planner.planFor(kcalOver: 100, weightKg: 70, equipment: []);
      final walking = ops.firstWhere((o) => o.activity == 'Walking (brisk)');
      expect(walking.minutes, 25);
    });

    test('sorts by minutes ascending and caps at 4 options', () {
      final options = planner.planFor(
        kcalOver: 500,
        weightKg: 70,
        equipment: ['rope', 'cycle'],
      );

      expect(options.length, lessThanOrEqualTo(4));

      for (int i = 0; i < options.length - 1; i++) {
        expect(
          options[i].minutes <= options[i + 1].minutes,
          isTrue,
        );
      }
    });

    test('walking steps calculation is correct', () {
      // 25 mins of walking * 100 = 2500 steps. Nearest 500 is 2500.
      final ops = planner.planFor(kcalOver: 100, weightKg: 70, equipment: []);
      final walking = ops.firstWhere((o) => o.activity == 'Walking (brisk)');
      expect(walking.minutes, 25);
      expect(walking.steps, 2500);

      // Let's find an option that would give e.g. 17 mins -> rounded to 20.
      // 20 mins * 100 = 2000 steps.
      final ops2 = planner.planFor(kcalOver: 80, weightKg: 70, equipment: []);
      final walking2 = ops2.firstWhere((o) => o.activity == 'Walking (brisk)');
      expect(walking2.minutes, 20); // 80 / 4.2875 = 18.66 -> 20
      expect(walking2.steps, 2000);
    });
  });
}
