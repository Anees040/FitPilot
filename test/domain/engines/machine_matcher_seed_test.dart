import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/engines/machine_exercise_matcher.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';

/// Matching quality against the *real* seed catalog, driven by payloads shaped
/// the way gemini-2.0-flash actually answers. Fixture-based tests prove the
/// algorithm; this proves the feature is useful to someone standing at a
/// machine.
void main() {
  late List<Exercise> catalog;

  setUpAll(() {
    final raw = File('assets/seed/exercises.json').readAsStringSync();
    final decoded = jsonDecode(raw);
    final list = decoded is List ? decoded : (decoded['exercises'] as List);
    catalog = list
        .cast<Map<String, dynamic>>()
        .map(
          (json) => Exercise(
            id: json['id'] as String,
            name: json['name'] as String,
            category: ExerciseCategory.values.firstWhere(
              (c) => c.name == (json['category'] as String? ?? 'gym'),
              orElse: () => ExerciseCategory.gym,
            ),
            met: (json['met'] as num?)?.toDouble() ?? 5.0,
            difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
            equipment: json['equipment'] as String?,
            primaryMuscles:
                (json['primary_muscles'] as List?)?.cast<String>() ?? const [],
            secondaryMuscles:
                (json['secondary_muscles'] as List?)?.cast<String>() ?? const [],
          ),
        )
        .toList();
  });

  List<String> idsFor(MachineAnalysis analysis) =>
      MachineExerciseMatcher.match(analysis, catalog).map((e) => e.id).toList();

  group('machines the catalog carries are matched exactly', () {
    test('lat pulldown ranks the seeded lat pulldown first', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Lat Pulldown Machine',
          confidence: 0.95,
          primaryMuscles: ['Lats', 'Upper Back'],
          secondaryMuscles: ['Biceps'],
          suggestedExerciseKeywords: ['lat pulldown', 'seated cable row'],
        ),
      );

      expect(ids.first, 'lat-pulldown');
      expect(ids, contains('seated-cable-row'));
      expect(ids.length, lessThanOrEqualTo(5));
    });

    test('leg press ranks the seeded leg press first', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Leg Press Machine',
          confidence: 0.9,
          primaryMuscles: ['Quadriceps', 'Glutes'],
          suggestedExerciseKeywords: ['leg press', 'squat'],
        ),
      );

      expect(ids.first, 'leg-press');
    });

    test('chest press machine ranks the seeded chest press first', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Seated Chest Press Machine',
          confidence: 0.88,
          primaryMuscles: ['Pectorals'],
          secondaryMuscles: ['Triceps'],
          suggestedExerciseKeywords: ['chest press', 'bench press'],
        ),
      );

      expect(ids.first, 'chest-press-machine');
      expect(ids, contains('bench-press'));
    });

    test('a treadmill matches the treadmill entries', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Treadmill',
          confidence: 0.97,
          primaryMuscles: ['Legs'],
          suggestedExerciseKeywords: ['treadmill running', 'incline walk'],
        ),
      );

      expect(ids.any((id) => id.startsWith('treadmill')), isTrue);
    });

    test('a rowing machine matches the rowing entries', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Rowing Machine',
          confidence: 0.94,
          primaryMuscles: ['Back', 'Legs'],
          suggestedExerciseKeywords: ['rowing machine', 'seated cable row'],
        ),
      );

      expect(ids.any((id) => id.startsWith('rowing')), isTrue);
    });
  });

  group('machines the catalog does not carry still give useful work', () {
    test('a pec deck falls back to chest exercises', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Pec Deck / Butterfly Machine',
          confidence: 0.85,
          primaryMuscles: ['Chest'],
          secondaryMuscles: ['Shoulders'],
          suggestedExerciseKeywords: ['pec deck fly', 'chest fly'],
        ),
      );

      expect(ids, isNotEmpty, reason: 'an unseeded machine must still suggest something');
      final matched = catalog.where((e) => ids.contains(e.id));
      expect(
        matched.any((e) => e.primaryMuscles.any((m) => m.toLowerCase().contains('chest'))),
        isTrue,
        reason: 'fallback suggestions should train the muscle the machine trains',
      );
    });

    test('a leg extension machine falls back to leg work', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Leg Extension Machine',
          confidence: 0.9,
          primaryMuscles: ['Quadriceps'],
          suggestedExerciseKeywords: ['leg extension'],
        ),
      );

      expect(ids, isNotEmpty);
      // The catalog's closest equivalent leads: sharing "leg" with the machine
      // outranks an unrelated quad exercise like a kettlebell swing.
      expect(ids.first, 'leg-press');
      final matched = catalog.where((e) => ids.contains(e.id));
      expect(
        matched.any(
          (e) => e.primaryMuscles.any(
            (m) => m.toLowerCase().contains('quad') || m.toLowerCase().contains('leg'),
          ),
        ),
        isTrue,
      );
    });

    test('an unseeded chest machine leads with the gym chest press', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Cable Crossover Machine',
          confidence: 0.86,
          primaryMuscles: ['Chest'],
          suggestedExerciseKeywords: ['cable crossover', 'chest fly'],
        ),
      );

      // "chest" is shared with the machine's keywords, so the machine-based
      // chest exercise ranks above the barbell and bodyweight alternatives.
      expect(ids.first, 'chest-press-machine');
      final pushUp = ids.indexOf('push-up');
      if (pushUp >= 0) {
        expect(ids.indexOf('chest-press-machine'), lessThan(pushUp));
      }
    });

    test('a shoulder press machine falls back to shoulder work', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Shoulder Press Machine',
          confidence: 0.87,
          primaryMuscles: ['Deltoids'],
          suggestedExerciseKeywords: ['shoulder press', 'overhead press'],
        ),
      );

      expect(ids, contains('overhead-press'));
    });
  });

  group('guardrails', () {
    test('a generic name never floods the list with unrelated work', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: 'Exercise Machine',
          confidence: 0.4,
          primaryMuscles: ['Chest'],
          suggestedExerciseKeywords: ['machine'],
        ),
      );

      // Stop-words must not turn "machine" into a catalog-wide match; the cap
      // still holds and everything returned relates to the stated muscle.
      expect(ids.length, lessThanOrEqualTo(5));
      final matched = catalog.where((e) => ids.contains(e.id));
      for (final e in matched) {
        final muscles = [...e.primaryMuscles, ...e.secondaryMuscles]
            .map((m) => m.toLowerCase())
            .join(' ');
        expect(
          muscles.contains('chest') || muscles.contains('tricep'),
          isTrue,
          reason: '${e.name} is unrelated to a chest machine',
        );
      }
    });

    test('a non-machine photo matches nothing', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: false,
          machineName: 'a bicycle parked outdoors',
          confidence: 0.8,
          primaryMuscles: ['Legs'],
          suggestedExerciseKeywords: ['cycling'],
        ),
      );

      expect(ids, isEmpty);
    });

    test('an empty AI answer degrades quietly', () {
      final ids = idsFor(
        const MachineAnalysis(
          isGymMachine: true,
          machineName: '',
          confidence: 0.0,
        ),
      );

      expect(ids, isEmpty);
    });
  });
}
