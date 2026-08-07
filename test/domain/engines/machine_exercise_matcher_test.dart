import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/engines/machine_exercise_matcher.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';

Exercise _ex(
  String id,
  String name, {
  ExerciseCategory category = ExerciseCategory.gym,
  List<String> primary = const [],
  List<String> secondary = const [],
}) {
  return Exercise(
    id: id,
    name: name,
    category: category,
    met: 5.0,
    difficulty: 1,
    primaryMuscles: primary,
    secondaryMuscles: secondary,
  );
}

/// Mirrors the real seed's shape and vocabulary.
final _catalog = <Exercise>[
  _ex('lat-pulldown', 'Lat pulldown', primary: ['Back']),
  _ex('seated-cable-row', 'Seated cable row', primary: ['Back']),
  _ex('chest-press-machine', 'Chest press machine', primary: ['Chest']),
  _ex('bench-press', 'Bench press', primary: ['Chest']),
  _ex('leg-press', 'Leg press', primary: ['Legs']),
  _ex('barbell-squat', 'Barbell squat', primary: ['Quads', 'Glutes']),
  _ex('ab-crunch-machine', 'Ab crunch machine', primary: ['Core']),
  _ex('pull-up', 'Pull-up', category: ExerciseCategory.calisthenics, primary: ['Back']),
  _ex('push-up', 'Push-up (vigorous sets)',
      category: ExerciseCategory.calisthenics, primary: ['Chest']),
  _ex('plank', 'Plank', category: ExerciseCategory.calisthenics, primary: ['Core']),
  _ex('burpees', 'Burpees', category: ExerciseCategory.calisthenics, primary: ['Full body']),
];

MachineAnalysis _analysis({
  bool isGymMachine = true,
  String name = 'Lat Pulldown Machine',
  List<String> primary = const [],
  List<String> keywords = const [],
  List<String> secondary = const [],
}) {
  return MachineAnalysis(
    isGymMachine: isGymMachine,
    machineName: name,
    confidence: 0.9,
    primaryMuscles: primary,
    secondaryMuscles: secondary,
    suggestedExerciseKeywords: keywords,
  );
}

void main() {
  group('keyword matching', () {
    test('an exact keyword finds that exercise first', () {
      final result = MachineExerciseMatcher.match(
        _analysis(keywords: ['lat pulldown'], primary: ['Lats']),
        _catalog,
      );

      expect(result.first.id, 'lat-pulldown');
    });

    test('the machine name alone matches when no keywords are given', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Leg Press', primary: ['Quads']),
        _catalog,
      );

      expect(result.first.id, 'leg-press');
    });

    test('"Machine" in the name does not drag in every machine exercise', () {
      // "machine" is a stop word: it must not be the thing that matches.
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Chest Press Machine', keywords: ['chest press']),
        _catalog,
      );

      expect(result.first.id, 'chest-press-machine');
    });
  });

  group('muscle matching through the synonym map', () {
    test('"Lats" finds Back exercises even though the seed never says "lats"', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Pec Deck', keywords: const [], primary: ['Lats']),
        _catalog,
      );

      expect(result, isNotEmpty);
      expect(result.map((e) => e.id), contains('lat-pulldown'));
      expect(result.map((e) => e.primaryMuscles.first), everyElement('Back'));
    });

    test('"Quadriceps" resolves to the Legs group', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Leg Extension Machine', primary: ['Quadriceps']),
        _catalog,
      );

      expect(result, isNotEmpty);
      expect(result.map((e) => e.id), contains('barbell-squat'));
    });

    test('"Abs" resolves to the Core group', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Roman Chair', primary: ['Abs']),
        _catalog,
      );

      expect(result.map((e) => e.id), contains('ab-crunch-machine'));
    });

    test('gym exercises rank above bodyweight ones for a machine', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Pec Deck', primary: ['Pecs']),
        _catalog,
      );

      final chestPress = result.indexWhere((e) => e.id == 'chest-press-machine');
      final pushUp = result.indexWhere((e) => e.id == 'push-up');
      expect(chestPress, greaterThanOrEqualTo(0));
      if (pushUp >= 0) expect(chestPress, lessThan(pushUp));
    });

    test('full-body exercises are not suggested for a specific machine', () {
      // Diverges from the hub rule on purpose: the hub counts "Full body" work
      // toward every major tile so no tile is empty, but Burpees next to a
      // scanned lat pulldown is noise. See MuscleSynonyms.matches.
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Pec Deck', primary: ['Lats']),
        _catalog,
      );

      expect(result.map((e) => e.id), isNot(contains('burpees')));
      expect(
        result.map((e) => e.primaryMuscles.first),
        everyElement(isNot('Full body')),
      );
    });
  });

  group('ordering and limits', () {
    test('keyword hits outrank muscle-only hits', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Lat Pulldown Machine', keywords: ['lat pulldown'], primary: ['Back']),
        _catalog,
      );

      expect(result.first.id, 'lat-pulldown');
    });

    test('never returns more than the limit', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Cable Machine', primary: ['Back', 'Chest', 'Legs', 'Core']),
        _catalog,
      );

      expect(result.length, lessThanOrEqualTo(5));
    });

    test('respects a custom limit', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Cable Machine', primary: ['Back']),
        _catalog,
        limit: 2,
      );

      expect(result.length, lessThanOrEqualTo(2));
    });

    test('never repeats an exercise', () {
      final result = MachineExerciseMatcher.match(
        _analysis(
          name: 'Lat Pulldown Machine',
          keywords: ['lat pulldown', 'lat pulldown', 'pull-up'],
          primary: ['Back', 'Lats'],
        ),
        _catalog,
      );

      final ids = result.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('edge cases', () {
    test('returns nothing when the photo was not a machine', () {
      final result = MachineExerciseMatcher.match(
        _analysis(isGymMachine: false, name: 'A cat', primary: ['Chest']),
        _catalog,
      );

      expect(result, isEmpty);
    });

    test('returns nothing for an empty catalog', () {
      expect(
        MachineExerciseMatcher.match(_analysis(primary: ['Back']), const []),
        isEmpty,
      );
    });

    test('an unrecognised muscle yields no false positives', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: 'Mystery Device', primary: ['Gizzard']),
        _catalog,
      );

      expect(result, isEmpty);
    });

    test('an analysis with no muscles or keywords still degrades safely', () {
      final result = MachineExerciseMatcher.match(
        _analysis(name: '', keywords: const [], primary: const []),
        _catalog,
      );

      expect(result, isEmpty);
    });
  });
}
