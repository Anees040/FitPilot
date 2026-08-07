import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/entities/machine_analysis.dart';

void main() {
  group('MachineAnalysis.fromJson', () {
    test('parses a complete server payload', () {
      final analysis = MachineAnalysis.fromJson({
        'isGymMachine': true,
        'machineName': 'Lat Pulldown Machine',
        'confidence': 0.92,
        'primaryMuscles': ['Lats', 'Back'],
        'secondaryMuscles': ['Biceps'],
        'howToUse': ['Sit down', 'Grip the bar', 'Pull to your chest'],
        'commonMistakes': ['Using momentum', 'Pulling behind the neck', 'Too much weight'],
        'safetyTips': ['Keep your back straight', 'Control the return'],
        'suggestedExerciseKeywords': ['lat pulldown', 'pull-up'],
      });

      expect(analysis.isGymMachine, isTrue);
      expect(analysis.machineName, 'Lat Pulldown Machine');
      expect(analysis.confidence, 0.92);
      expect(analysis.isHighConfidence, isTrue);
      expect(analysis.confidenceLabel, 'High');
      expect(analysis.primaryMuscles, ['Lats', 'Back']);
      expect(analysis.secondaryMuscles, ['Biceps']);
      expect(analysis.howToUse, hasLength(3));
      expect(analysis.commonMistakes, hasLength(3));
      expect(analysis.safetyTips, hasLength(2));
      expect(analysis.suggestedExerciseKeywords, ['lat pulldown', 'pull-up']);
      expect(analysis.hasGuidance, isTrue);
    });

    test('missing lists become empty rather than throwing', () {
      final analysis = MachineAnalysis.fromJson({
        'isGymMachine': false,
        'machineName': 'A domestic cat',
        'confidence': 0.4,
      });

      expect(analysis.isGymMachine, isFalse);
      expect(analysis.primaryMuscles, isEmpty);
      expect(analysis.howToUse, isEmpty);
      expect(analysis.suggestedExerciseKeywords, isEmpty);
      expect(analysis.hasGuidance, isFalse);
      expect(analysis.confidenceLabel, 'Medium');
    });

    test('survives an entirely empty object', () {
      final analysis = MachineAnalysis.fromJson({});

      expect(analysis.isGymMachine, isFalse);
      expect(analysis.machineName, isEmpty);
      expect(analysis.confidence, 0);
      expect(analysis.primaryMuscles, isEmpty);
    });

    test('coerces wrong-typed fields instead of crashing', () {
      final analysis = MachineAnalysis.fromJson({
        'isGymMachine': 'true',
        'machineName': 42,
        'confidence': '0.55',
        // Not a list — must degrade to empty, not throw.
        'primaryMuscles': 'Chest',
        'howToUse': ['Sit', null, '  ', 'Press'],
      });

      expect(analysis.isGymMachine, isTrue);
      expect(analysis.machineName, '42');
      expect(analysis.confidence, closeTo(0.55, 0.0001));
      expect(analysis.primaryMuscles, isEmpty);
      // Nulls and blank entries are dropped.
      expect(analysis.howToUse, ['Sit', 'Press']);
    });

    test('clamps confidence and rescales a percentage', () {
      expect(MachineAnalysis.fromJson({'confidence': 85}).confidence, closeTo(0.85, 0.0001));
      expect(MachineAnalysis.fromJson({'confidence': -3}).confidence, 0);
      expect(MachineAnalysis.fromJson({'confidence': 250}).confidence, 1);
      expect(MachineAnalysis.fromJson({'confidence': 'nonsense'}).confidence, 0);
    });

    test('confidence below 0.7 reads as Medium', () {
      expect(MachineAnalysis.fromJson({'confidence': 0.69}).confidenceLabel, 'Medium');
      expect(MachineAnalysis.fromJson({'confidence': 0.7}).confidenceLabel, 'High');
    });
  });

  group('round-trip', () {
    test('toJson -> tryDecode preserves every field', () {
      const original = MachineAnalysis(
        isGymMachine: true,
        machineName: 'Leg Press',
        confidence: 0.81,
        primaryMuscles: ['Quads'],
        secondaryMuscles: ['Glutes'],
        howToUse: ['Sit', 'Press'],
        commonMistakes: ['Locking knees'],
        safetyTips: ['Use the safety catch'],
        suggestedExerciseKeywords: ['leg press'],
      );

      final restored = MachineAnalysis.tryDecode(jsonEncode(original.toJson()));

      expect(restored, isNotNull);
      expect(restored, equals(original));
      expect(restored!.machineName, 'Leg Press');
      expect(restored.primaryMuscles, ['Quads']);
    });

    test('tryDecode returns null on unreadable stored JSON', () {
      expect(MachineAnalysis.tryDecode('not json at all'), isNull);
      expect(MachineAnalysis.tryDecode('[1,2,3]'), isNull);
      expect(MachineAnalysis.tryDecode(''), isNull);
    });

    test('equal analyses compare equal so the Riverpod family key is stable', () {
      const a = MachineAnalysis(
        isGymMachine: true,
        machineName: 'Chest Press',
        confidence: 0.9,
        primaryMuscles: ['Chest'],
      );
      const b = MachineAnalysis(
        isGymMachine: true,
        machineName: 'Chest Press',
        confidence: 0.9,
        primaryMuscles: ['Chest'],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
