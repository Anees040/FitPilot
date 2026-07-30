import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/burn_planner.dart';
import 'package:fitpilot/domain/entities/exercise.dart';

void main() {
  group('BurnPlanner', () {
    const planner = BurnPlanner();

    final testCandidates = [
      Exercise(id: '1', name: 'Walking (brisk)', category: ExerciseCategory.outdoor, met: 3.5, difficulty: 1, paceTier: 'easy'),
      Exercise(id: '2', name: 'Running', category: ExerciseCategory.outdoor, met: 9.8, difficulty: 2, paceTier: 'quick'),
      Exercise(id: '3', name: 'Burpees', category: ExerciseCategory.indoor, met: 8.0, difficulty: 3, paceTier: 'quick'),
      Exercise(id: '4', name: 'Yoga', category: ExerciseCategory.indoor, met: 3.0, difficulty: 1, paceTier: 'easy'),
      Exercise(id: '5', name: 'Weight training', category: ExerciseCategory.gym, met: 5.0, difficulty: 2, paceTier: 'moderate'),
    ];

    test('returns empty list if kcalOver is <= 0 or candidates empty', () {
      expect(planner.planFor(kcalOver: 0, weightKg: 70, candidates: testCandidates), isEmpty);
      expect(planner.planFor(kcalOver: -100, weightKg: 70, candidates: testCandidates), isEmpty);
      expect(planner.planFor(kcalOver: 100, weightKg: 70, candidates: []), isEmpty);
    });

    test('always includes walking', () {
      final options = planner.planFor(kcalOver: 200, weightKg: 70, candidates: testCandidates);
      expect(options.any((o) => o.activity.contains('Walking')), isTrue);
    });

    test('recommended mode selects fastest and easy', () {
      final options = planner.planFor(kcalOver: 300, weightKg: 70, candidates: testCandidates, categoryPref: 'recommended');
      
      expect(options.any((o) => o.activity == 'Running'), isTrue); // fastest
      expect(options.any((o) => o.activity == 'Burpees'), isTrue); // second fastest
      expect(options.any((o) => o.activity == 'Yoga'), isTrue); // easy pace
      expect(options.any((o) => o.activity == 'Walking (brisk)'), isTrue); // walking
    });

    test('category mode filters by category', () {
      final indoorOptions = planner.planFor(kcalOver: 300, weightKg: 70, candidates: testCandidates, categoryPref: 'indoor');
      
      expect(indoorOptions.any((o) => o.activity == 'Burpees'), isTrue);
      expect(indoorOptions.any((o) => o.activity == 'Yoga'), isTrue);
      expect(indoorOptions.any((o) => o.activity == 'Running'), isFalse); // outdoor
      expect(indoorOptions.any((o) => o.activity == 'Walking (brisk)'), isTrue); // walking always included
    });

    test('pace filter overrides options', () {
      final quickOptions = planner.planFor(kcalOver: 300, weightKg: 70, candidates: testCandidates, categoryPref: 'recommended', pacePref: 'quick');
      
      expect(quickOptions.any((o) => o.activity == 'Running'), isTrue);
      expect(quickOptions.any((o) => o.activity == 'Burpees'), isTrue);
      expect(quickOptions.any((o) => o.activity == 'Yoga'), isFalse); // not quick
    });

    test('rounds minutes UP to next 5, minimum 5', () {
      final options = planner.planFor(kcalOver: 10, weightKg: 70, candidates: testCandidates);
      expect(options.every((o) => o.minutes == 5), isTrue);

      final ops = planner.planFor(kcalOver: 100, weightKg: 70, candidates: testCandidates);
      final walking = ops.firstWhere((o) => o.activity.contains('Walking'));
      expect(walking.minutes, 25);
    });

    test('sorts by minutes ascending', () {
      final options = planner.planFor(kcalOver: 500, weightKg: 70, candidates: testCandidates);
      for (int i = 0; i < options.length - 1; i++) {
        expect(options[i].minutes <= options[i + 1].minutes, isTrue);
      }
    });

    test('walking steps calculation is correct', () {
      final ops = planner.planFor(kcalOver: 100, weightKg: 70, candidates: testCandidates);
      final walking = ops.firstWhere((o) => o.activity.contains('Walking'));
      expect(walking.minutes, 25);
      expect(walking.steps, 2500);
    });
  });
}
