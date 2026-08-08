import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/engines/squat_form_analyzer.dart';

/// Builds a side-on pose. Screen coordinates: y grows downward.
///
/// [kneeBend] 0 = standing straight, 1 = deep squat. The hip drops and travels
/// forward as it increases, which is what a real squat looks like from the side.
Map<BodyPoint, BodyLandmark> _pose({
  required double kneeBend,
  double torsoLeanX = 0,
  double likelihood = 1.0,
}) {
  const ankleY = 400.0;
  const kneeY = 300.0;
  // Hip starts high and descends toward knee height.
  final hipY = 200.0 + (kneeY - 200.0) * kneeBend;
  // Hip also shifts back behind the knee as depth increases.
  final hipX = 100.0 - 40.0 * kneeBend;

  return {
    BodyPoint.leftHip: BodyLandmark(x: hipX, y: hipY, likelihood: likelihood),
    BodyPoint.rightHip: BodyLandmark(x: hipX, y: hipY, likelihood: likelihood),
    BodyPoint.leftKnee: BodyLandmark(x: 100, y: kneeY, likelihood: likelihood),
    BodyPoint.rightKnee: BodyLandmark(x: 100, y: kneeY, likelihood: likelihood),
    BodyPoint.leftAnkle: BodyLandmark(x: 100, y: ankleY, likelihood: likelihood),
    BodyPoint.rightAnkle: BodyLandmark(x: 100, y: ankleY, likelihood: likelihood),
    BodyPoint.leftShoulder:
        BodyLandmark(x: hipX + torsoLeanX, y: hipY - 120, likelihood: likelihood),
    BodyPoint.rightShoulder:
        BodyLandmark(x: hipX + torsoLeanX, y: hipY - 120, likelihood: likelihood),
  };
}

void main() {
  late SquatFormAnalyzer analyzer;

  setUp(() => analyzer = SquatFormAnalyzer());

  group('depth', () {
    test('standing tall reads as standing', () {
      final result = analyzer.analyze(_pose(kneeBend: 0));
      expect(result.depth, SquatDepth.standing);
      expect(result.kneeAngle, greaterThan(SquatFormAnalyzer.standingAngle));
    });

    test('a deep squat reads as deep', () {
      final result = analyzer.analyze(_pose(kneeBend: 1));
      expect(result.depth, SquatDepth.deep);
      expect(result.kneeAngle, lessThanOrEqualTo(SquatFormAnalyzer.deepAngle));
    });

    test('a half squat is partial, not a counted rep', () {
      final result = analyzer.analyze(_pose(kneeBend: 0.5));
      expect(result.depth, SquatDepth.partial);
    });

    test('the knee angle decreases as the squat deepens', () {
      final tall = analyzer.analyze(_pose(kneeBend: 0)).kneeAngle!;
      final half = analyzer.analyze(_pose(kneeBend: 0.5)).kneeAngle!;
      final deep = analyzer.analyze(_pose(kneeBend: 1)).kneeAngle!;
      expect(half, lessThan(tall));
      expect(deep, lessThan(half));
    });
  });

  group('rep counting', () {
    test('counts a rep on the way up, not on the way down', () {
      analyzer.analyze(_pose(kneeBend: 0));
      analyzer.analyze(_pose(kneeBend: 0.5));
      analyzer.analyze(_pose(kneeBend: 1));
      // Deep but not yet returned — the rep is not finished.
      expect(analyzer.repCount, 0);

      analyzer.analyze(_pose(kneeBend: 0.5));
      expect(analyzer.repCount, 1);
    });

    test('counts three separate reps', () {
      for (var i = 0; i < 3; i++) {
        analyzer.analyze(_pose(kneeBend: 0));
        analyzer.analyze(_pose(kneeBend: 1));
        analyzer.analyze(_pose(kneeBend: 0));
      }
      expect(analyzer.repCount, 3);
    });

    test('holding at the bottom does not inflate the count', () {
      analyzer.analyze(_pose(kneeBend: 0));
      for (var i = 0; i < 20; i++) {
        analyzer.analyze(_pose(kneeBend: 1));
      }
      expect(analyzer.repCount, 0);

      analyzer.analyze(_pose(kneeBend: 0));
      expect(analyzer.repCount, 1);
    });

    test('half squats never count', () {
      for (var i = 0; i < 5; i++) {
        analyzer.analyze(_pose(kneeBend: 0));
        analyzer.analyze(_pose(kneeBend: 0.5));
      }
      expect(analyzer.repCount, 0);
    });

    test('reset clears the count between sessions', () {
      analyzer.analyze(_pose(kneeBend: 0));
      analyzer.analyze(_pose(kneeBend: 1));
      analyzer.analyze(_pose(kneeBend: 0));
      expect(analyzer.repCount, 1);

      analyzer.reset();
      expect(analyzer.repCount, 0);
    });
  });

  group('forward lean', () {
    test('an upright torso is not flagged', () {
      final result = analyzer.analyze(_pose(kneeBend: 0.5, torsoLeanX: 5));
      expect(result.torsoTooFarForward, isFalse);
    });

    test('a heavily pitched torso is flagged', () {
      // 200 px forward over a 120 px torso is far past the threshold.
      final result = analyzer.analyze(_pose(kneeBend: 0.5, torsoLeanX: 200));
      expect(result.torsoTooFarForward, isTrue);
    });
  });

  group('visibility', () {
    test('missing legs produce a step-back prompt, not a verdict', () {
      final result = analyzer.analyze({
        BodyPoint.leftShoulder: const BodyLandmark(x: 100, y: 100),
        BodyPoint.leftHip: const BodyLandmark(x: 100, y: 200),
      });
      expect(result.isVisible, isFalse);
      expect(result.notVisibleReason, contains('Step back'));
    });

    test('low-confidence landmarks are treated as missing', () {
      // A hallucinated joint would otherwise yield a confident wrong answer.
      final result = analyzer.analyze(_pose(kneeBend: 1, likelihood: 0.2));
      expect(result.isVisible, isFalse);
    });

    test('one visible side is enough when filming side-on', () {
      final pose = _pose(kneeBend: 1);
      pose.remove(BodyPoint.rightHip);
      pose.remove(BodyPoint.rightKnee);
      pose.remove(BodyPoint.rightAnkle);

      final result = analyzer.analyze(pose);
      expect(result.isVisible, isTrue);
      expect(result.depth, SquatDepth.deep);
    });

    test('an empty pose does not throw', () {
      final result = analyzer.analyze({});
      expect(result.isVisible, isFalse);
    });
  });

  group('cues', () {
    test('one cue at a time, lean before depth', () {
      final leaning = analyzer.analyze(_pose(kneeBend: 0.5, torsoLeanX: 200));
      expect(SquatFormAnalyzer.cueFor(leaning), contains('Chest up'));
    });

    test('depth is praised when reached', () {
      final deep = analyzer.analyze(_pose(kneeBend: 1));
      expect(SquatFormAnalyzer.cueFor(deep), 'Good depth');
    });

    test('a partial squat is encouraged deeper', () {
      final partial = analyzer.analyze(_pose(kneeBend: 0.5));
      expect(SquatFormAnalyzer.cueFor(partial), contains('deeper'));
    });

    test('visibility trouble outranks every other cue', () {
      final hidden = analyzer.analyze({});
      expect(SquatFormAnalyzer.cueFor(hidden), contains('Step back'));
    });
  });
}
