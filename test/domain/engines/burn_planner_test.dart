import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/burn_planner.dart';

void main() {
  group('BurnPlanner', () {
    const planner = BurnPlanner();

    test('returns empty list if kcalOver is <= 0', () {
      expect(planner.planFor(kcalOver: 0, weightKg: 70), isEmpty);
      expect(planner.planFor(kcalOver: -100, weightKg: 70), isEmpty);
    });

    test('always includes walking regardless of category filter', () {
      // Test without filter
      final noFilterOptions = planner.planFor(kcalOver: 200, weightKg: 70);
      expect(noFilterOptions.any((o) => o.activity == 'Walking (brisk)'), isTrue);
      
      // Test with each filter
      for (final cat in ActivityCategory.values) {
        final options = planner.planFor(kcalOver: 200, weightKg: 70, categoryFilter: cat);
        expect(options.any((o) => o.activity == 'Walking (brisk)'), isTrue);
      }
    });

    test('filters exercises by category', () {
      // Equipment filter
      final eqOptions = planner.planFor(kcalOver: 300, weightKg: 70, categoryFilter: ActivityCategory.equipment);
      expect(eqOptions.any((o) => o.activity == 'Jump rope'), isTrue);
      expect(eqOptions.any((o) => o.activity == 'Burpees'), isFalse); // Indoor

      // Indoor filter
      final indoorOptions = planner.planFor(kcalOver: 300, weightKg: 70, categoryFilter: ActivityCategory.indoor);
      expect(indoorOptions.any((o) => o.activity == 'Burpees'), isTrue);
      expect(indoorOptions.any((o) => o.activity == 'Jump rope'), isFalse);
    });

    test('rounds minutes UP to next 5, minimum 5', () {
      final options = planner.planFor(kcalOver: 10, weightKg: 70);
      expect(options.every((o) => o.minutes == 5), isTrue);

      final ops = planner.planFor(kcalOver: 100, weightKg: 70);
      final walking = ops.firstWhere((o) => o.activity == 'Walking (brisk)');
      expect(walking.minutes, 25);
    });

    test('sorts by minutes ascending and caps at 4 options', () {
      final options = planner.planFor(kcalOver: 500, weightKg: 70);
      expect(options.length, lessThanOrEqualTo(4));
      for (int i = 0; i < options.length - 1; i++) {
        expect(options[i].minutes <= options[i + 1].minutes, isTrue);
      }
    });

    test('walking steps calculation is correct', () {
      final ops = planner.planFor(kcalOver: 100, weightKg: 70);
      final walking = ops.firstWhere((o) => o.activity == 'Walking (brisk)');
      expect(walking.minutes, 25);
      expect(walking.steps, 2500);
    });
  });
}
