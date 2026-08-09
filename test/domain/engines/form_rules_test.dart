import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/engines/form_rules.dart';
import 'package:fitpilot/domain/engines/squat_form_analyzer.dart';

/// Places three landmarks so the angle at [vertex] is [degrees].
///
/// Screen coordinates: y grows downward. One arm of the angle points straight
/// up from the vertex, the other is rotated by [degrees] from it, so the
/// interior angle is exactly what the test asked for.
Map<BodyPoint, BodyLandmark> _jointAt(
  FormExercise exercise,
  double degrees, {
  double likelihood = 1.0,
}) {
  final (vertex, a, b) = FormRules.jointsFor(exercise);
  const len = 100.0;
  final rad = degrees * math.pi / 180;

  return {
    vertex: BodyLandmark(x: 200, y: 300, likelihood: likelihood),
    a: BodyLandmark(x: 200, y: 300 - len, likelihood: likelihood),
    b: BodyLandmark(
      x: 200 + len * math.sin(rad),
      y: 300 - len * math.cos(rad),
      likelihood: likelihood,
    ),
  };
}

/// Adds a shoulder leaning [leanX] pixels ahead of the existing hip.
///
/// Keeps the pose's own hip landmark, so the working-joint angle the exercise
/// is judged on stays exactly as [_jointAt] built it.
Map<BodyPoint, BodyLandmark> _leaning(
  Map<BodyPoint, BodyLandmark> pose, {
  required double leanX,
}) {
  final hip = pose[BodyPoint.leftHip] ?? const BodyLandmark(x: 200, y: 300);
  return {
    ...pose,
    BodyPoint.leftHip: hip,
    BodyPoint.leftShoulder: BodyLandmark(x: hip.x + leanX, y: hip.y - 120),
  };
}

void main() {
  group('every exercise has a coherent rule set', () {
    for (final exercise in FormExercise.values) {
      test('${exercise.label}: thresholds point the right way', () {
        final rules = FormRules.forExercise(exercise);
        // The target must be on the "working" side of resting, or the movement
        // would be judged complete before it started.
        if (rules.smallerIsDeeper) {
          expect(rules.targetAngle, lessThan(rules.restingAngle));
        } else {
          expect(rules.targetAngle, greaterThan(rules.restingAngle));
        }
        expect(rules.goodCue, isNotEmpty);
        expect(rules.shortCue, isNotEmpty);
      });

      test('${exercise.label}: labels exist for every position', () {
        for (final depth in SquatDepth.values) {
          expect(exercise.positionLabel(depth), isNotEmpty);
        }
        expect(exercise.setupHint, isNotEmpty);
        expect(exercise.measures, isNotEmpty);
      });

      test('${exercise.label}: torso note matches whether lean is measured', () {
        // A note without a measurement would render a verdict never taken.
        expect(exercise.torsoNote != null, exercise.measuresTorsoLean);
      });
    }
  });

  group('reaching the target', () {
    test('a deep squat reads as deep', () {
      final result = FormChecker.check(
        FormExercise.squat,
        _jointAt(FormExercise.squat, 90),
      );
      expect(result.depth, SquatDepth.deep);
      expect(FormChecker.cueFor(FormExercise.squat, result), 'Good depth');
    });

    test('a straight leg reads as standing, not deep', () {
      final result = FormChecker.check(
        FormExercise.squat,
        _jointAt(FormExercise.squat, 175),
      );
      expect(result.depth, SquatDepth.standing);
    });

    test('half way down reads as partial', () {
      final result = FormChecker.check(
        FormExercise.squat,
        _jointAt(FormExercise.squat, 130),
      );
      expect(result.depth, SquatDepth.partial);
    });

    test('a locked-out press reads as complete, where larger is the goal', () {
      final result = FormChecker.check(
        FormExercise.overheadPress,
        _jointAt(FormExercise.overheadPress, 170),
      );
      expect(result.depth, SquatDepth.deep);
    });

    test('a bent-arm press is short of lockout', () {
      final result = FormChecker.check(
        FormExercise.overheadPress,
        _jointAt(FormExercise.overheadPress, 95),
      );
      expect(result.depth, SquatDepth.standing);
      expect(
        FormChecker.cueFor(FormExercise.overheadPress, result),
        'Press all the way to lockout',
      );
    });

    test('a straight plank passes; a piked one does not', () {
      final straight = FormChecker.check(
        FormExercise.plank,
        _jointAt(FormExercise.plank, 175),
      );
      expect(straight.depth, SquatDepth.deep);

      final piked = FormChecker.check(
        FormExercise.plank,
        _jointAt(FormExercise.plank, 140),
      );
      expect(piked.depth, SquatDepth.partial);
    });
  });

  group('missing joints', () {
    test('an empty pose asks the user to reframe rather than guessing', () {
      final result = FormChecker.check(FormExercise.squat, const {});
      expect(result.isVisible, isFalse);
      expect(result.notVisibleReason, contains('in frame'));
    });

    test('low-likelihood joints are treated as missing', () {
      final result = FormChecker.check(
        FormExercise.squat,
        _jointAt(FormExercise.squat, 90, likelihood: 0.1),
      );
      expect(result.isVisible, isFalse);
    });

    test('the mirrored side is used when the near side is hidden', () {
      final pose = _jointAt(FormExercise.squat, 90);
      final mirrored = {
        BodyPoint.rightKnee: pose[BodyPoint.leftKnee]!,
        BodyPoint.rightHip: pose[BodyPoint.leftHip]!,
        BodyPoint.rightAnkle: pose[BodyPoint.leftAnkle]!,
      };
      final result = FormChecker.check(FormExercise.squat, mirrored);
      expect(result.isVisible, isTrue);
      expect(result.depth, SquatDepth.deep);
    });
  });

  group('torso lean', () {
    test('a far-forward torso is flagged on a squat', () {
      final pose = _leaning(_jointAt(FormExercise.squat, 90), leanX: 300);
      final result = FormChecker.check(FormExercise.squat, pose);
      expect(result.torsoTooFarForward, isTrue);
      // Lean outranks depth: it is the fault worth saying first.
      expect(
        FormChecker.cueFor(FormExercise.squat, result),
        contains('Chest up'),
      );
    });

    test('an upright torso is not flagged', () {
      final pose = _leaning(_jointAt(FormExercise.squat, 90), leanX: 5);
      final result = FormChecker.check(FormExercise.squat, pose);
      expect(result.torsoTooFarForward, isFalse);
    });

    test('a push-up never reports lean, since its rules do not measure it', () {
      final pose = _leaning(_jointAt(FormExercise.pushUp, 90), leanX: 300);
      final result = FormChecker.check(FormExercise.pushUp, pose);
      expect(result.torsoTooFarForward, isFalse);
    });
  });
}
