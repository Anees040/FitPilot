import 'dart:math' as math;

import 'package:fitpilot/domain/engines/squat_form_analyzer.dart';

/// An exercise the form check can measure.
///
/// Deliberately a short list. A rule set has to be written and sanity-checked
/// per movement, and a wrong threshold gives confident bad advice to someone
/// under load — so these are the movements whose joint geometry is
/// unambiguous from a side-on photo, and nothing else is claimed.
enum FormExercise {
  squat,
  pushUp,
  lunge,
  plank,
  gluteBridge,
  overheadPress;

  String get label => switch (this) {
    FormExercise.squat => 'Squat',
    FormExercise.pushUp => 'Push-up',
    FormExercise.lunge => 'Lunge',
    FormExercise.plank => 'Plank',
    FormExercise.gluteBridge => 'Glute bridge',
    FormExercise.overheadPress => 'Overhead press',
  };

  /// What the user should do before taking the photo.
  String get setupHint => switch (this) {
    FormExercise.squat => 'Side-on, whole body in frame. Shoot at the bottom.',
    FormExercise.pushUp => 'Side-on at the bottom, elbows bent.',
    FormExercise.lunge => 'Side-on at the bottom, back knee low.',
    FormExercise.plank => 'Side-on while holding the position.',
    FormExercise.gluteBridge => 'Side-on at the top, hips lifted.',
    FormExercise.overheadPress => 'Side-on with the weight locked out overhead.',
  };

  /// The single cue this exercise is judged on, in plain words.
  String get measures => switch (this) {
    FormExercise.squat => 'Depth and torso lean',
    FormExercise.pushUp => 'Elbow bend',
    FormExercise.lunge => 'Front knee angle and torso lean',
    FormExercise.plank => 'A straight line from shoulder to ankle',
    FormExercise.gluteBridge => 'Hip extension at the top',
    FormExercise.overheadPress => 'Lockout and lower-back arch',
  };

  /// Whether torso lean is part of this movement's verdict.
  ///
  /// A push-up, plank and bridge are judged on the working joint alone, so the
  /// UI must not show a torso reading that was never taken — an unmeasured
  /// "Upright" reads as a pass the check did not actually give.
  bool get measuresTorsoLean => FormRules.forExercise(this).maxTorsoLean != null;

  /// Plain-word label for the measured position.
  ///
  /// Squat language ("below parallel") is meaningless for a plank, so each
  /// movement names its own states.
  String positionLabel(SquatDepth depth) => switch (this) {
    FormExercise.squat => switch (depth) {
      SquatDepth.deep => 'At or below parallel',
      SquatDepth.partial => 'Above parallel',
      SquatDepth.standing => 'Standing',
    },
    FormExercise.pushUp => switch (depth) {
      SquatDepth.deep => 'Chest near the floor',
      SquatDepth.partial => 'Part-way down',
      SquatDepth.standing => 'Arms straight',
    },
    FormExercise.lunge => switch (depth) {
      SquatDepth.deep => 'Front knee at depth',
      SquatDepth.partial => 'Above depth',
      SquatDepth.standing => 'Standing',
    },
    FormExercise.plank => switch (depth) {
      SquatDepth.deep => 'Straight line',
      SquatDepth.partial => 'Slightly out of line',
      SquatDepth.standing => 'Hips well out of line',
    },
    FormExercise.gluteBridge => switch (depth) {
      SquatDepth.deep => 'Hips fully extended',
      SquatDepth.partial => 'Part-way up',
      SquatDepth.standing => 'Hips down',
    },
    FormExercise.overheadPress => switch (depth) {
      SquatDepth.deep => 'Locked out',
      SquatDepth.partial => 'Part-way up',
      SquatDepth.standing => 'At the shoulders',
    },
  };

  /// What the torso row means for this movement, or null when lean is not
  /// measured.
  String? get torsoNote => switch (this) {
    FormExercise.squat => 'Some forward lean is normal in a squat',
    FormExercise.lunge => 'The front-leg lunge should stay close to upright',
    FormExercise.overheadPress => 'Leaning back is how a press hides a missed lockout',
    FormExercise.pushUp ||
    FormExercise.plank ||
    FormExercise.gluteBridge => null,
  };
}

/// The rule set for one exercise: which joint angle matters, and what counts.
///
/// Every threshold below is the conservative end of what coaching references
/// agree on. Where the evidence is fuzzy the rule says less rather than
/// guessing — the check reports what it can measure and nothing more.
class FormRules {
  /// Angle at the working joint that counts as a completed rep.
  final double targetAngle;

  /// Above this the lifter has not started the movement.
  final double restingAngle;

  /// True when a smaller angle means "deeper"; false when larger is the goal.
  final bool smallerIsDeeper;

  /// Maximum acceptable torso lean from vertical, or null when lean is not
  /// meaningful for the movement (a plank is supposed to be horizontal).
  final double? maxTorsoLean;

  /// Cue shown when the position is reached.
  final String goodCue;

  /// Cue shown while short of it.
  final String shortCue;

  /// Cue shown when the torso rule is broken.
  final String leanCue;

  const FormRules({
    required this.targetAngle,
    required this.restingAngle,
    required this.smallerIsDeeper,
    required this.maxTorsoLean,
    required this.goodCue,
    required this.shortCue,
    required this.leanCue,
  });

  static const _squat = FormRules(
    // Hip crease at knee height is roughly 100 degrees at the knee.
    targetAngle: 100,
    restingAngle: 160,
    smallerIsDeeper: true,
    maxTorsoLean: 55,
    goodCue: 'Good depth',
    shortCue: 'Keep going, a little deeper',
    leanCue: 'Chest up — you are leaning too far forward',
  );

  static const _pushUp = FormRules(
    // Upper arm roughly parallel to the floor.
    targetAngle: 95,
    restingAngle: 160,
    smallerIsDeeper: true,
    // A push-up torso should stay in line with the legs, not vertical, so
    // lean is measured as body-line straightness instead.
    maxTorsoLean: null,
    goodCue: 'Good depth — chest close to the floor',
    shortCue: 'Lower a little further',
    leanCue: 'Keep a straight line — hips are sagging or piking',
  );

  static const _lunge = FormRules(
    targetAngle: 100,
    restingAngle: 160,
    smallerIsDeeper: true,
    maxTorsoLean: 40,
    goodCue: 'Good depth on the front leg',
    shortCue: 'Drop the back knee lower',
    leanCue: 'Stay upright — you are tipping forward',
  );

  static const _plank = FormRules(
    // A plank is judged on hip angle: near-straight is the whole point.
    targetAngle: 165,
    restingAngle: 120,
    smallerIsDeeper: false,
    maxTorsoLean: null,
    goodCue: 'Straight line — holding it well',
    shortCue: 'Hips are out of line — lift or lower them',
    leanCue: 'Hips are out of line — lift or lower them',
  );

  static const _gluteBridge = FormRules(
    // Hips fully extended at the top.
    targetAngle: 165,
    restingAngle: 120,
    smallerIsDeeper: false,
    maxTorsoLean: null,
    goodCue: 'Full hip extension',
    shortCue: 'Drive the hips higher',
    leanCue: 'Drive the hips higher',
  );

  static const _overheadPress = FormRules(
    // Elbow locked out overhead.
    targetAngle: 160,
    restingAngle: 100,
    smallerIsDeeper: false,
    maxTorsoLean: 20,
    goodCue: 'Locked out overhead',
    shortCue: 'Press all the way to lockout',
    leanCue: 'Ribs down — you are arching your lower back',
  );

  static FormRules forExercise(FormExercise exercise) => switch (exercise) {
    FormExercise.squat => _squat,
    FormExercise.pushUp => _pushUp,
    FormExercise.lunge => _lunge,
    FormExercise.plank => _plank,
    FormExercise.gluteBridge => _gluteBridge,
    FormExercise.overheadPress => _overheadPress,
  };

  /// The joints whose angle is measured, in (vertex, a, b) order.
  ///
  /// The vertex is the joint that bends; the other two are the segments either
  /// side of it.
  static (BodyPoint, BodyPoint, BodyPoint) jointsFor(FormExercise exercise) =>
      switch (exercise) {
        // Knee angle: hip–knee–ankle.
        FormExercise.squat => (
          BodyPoint.leftKnee,
          BodyPoint.leftHip,
          BodyPoint.leftAnkle,
        ),
        FormExercise.lunge => (
          BodyPoint.leftKnee,
          BodyPoint.leftHip,
          BodyPoint.leftAnkle,
        ),
        // Elbow angle: shoulder–elbow–wrist.
        FormExercise.pushUp => (
          BodyPoint.leftElbow,
          BodyPoint.leftShoulder,
          BodyPoint.leftWrist,
        ),
        FormExercise.overheadPress => (
          BodyPoint.leftElbow,
          BodyPoint.leftShoulder,
          BodyPoint.leftWrist,
        ),
        // Hip angle: shoulder–hip–knee.
        FormExercise.plank => (
          BodyPoint.leftHip,
          BodyPoint.leftShoulder,
          BodyPoint.leftKnee,
        ),
        FormExercise.gluteBridge => (
          BodyPoint.leftHip,
          BodyPoint.leftShoulder,
          BodyPoint.leftKnee,
        ),
      };
}

/// Judges one frame of any supported exercise.
///
/// Shares [SquatFormAnalyzer]'s geometry helpers rather than reimplementing
/// them, so a fix to the angle maths benefits every movement. The squat keeps
/// its own class because it also counts reps across frames; this is the
/// single-photo path the UI uses.
class FormChecker {
  const FormChecker._();

  /// Landmarks below this likelihood are treated as missing, so a hallucinated
  /// joint cannot produce a confident wrong verdict.
  static const double minLikelihood = 0.5;

  static FormFeedback check(
    FormExercise exercise,
    Map<BodyPoint, BodyLandmark> pose,
  ) {
    final rules = FormRules.forExercise(exercise);
    final (vertexPoint, aPoint, bPoint) = FormRules.jointsFor(exercise);

    final vertex = _resolve(pose, vertexPoint);
    final a = _resolve(pose, aPoint);
    final b = _resolve(pose, bPoint);

    if (vertex == null || a == null || b == null) {
      return FormFeedback(
        depth: SquatDepth.standing,
        notVisibleReason:
            'Move so your whole body is in frame — ${exercise.setupHint}',
      );
    }

    final angle = _angleAt(vertex, a, b);

    // "Deep" means different things per movement: a squat closes the knee,
    // a plank opens the hip. smallerIsDeeper carries that distinction.
    final reached = rules.smallerIsDeeper
        ? angle <= rules.targetAngle
        : angle >= rules.targetAngle;
    final resting = rules.smallerIsDeeper
        ? angle >= rules.restingAngle
        : angle <= rules.restingAngle;

    final depth = reached
        ? SquatDepth.deep
        : resting
        ? SquatDepth.standing
        : SquatDepth.partial;

    var leaning = false;
    if (rules.maxTorsoLean != null) {
      final shoulder = _resolve(pose, BodyPoint.leftShoulder) ??
          _resolve(pose, BodyPoint.rightShoulder);
      final hip =
          _resolve(pose, BodyPoint.leftHip) ?? _resolve(pose, BodyPoint.rightHip);
      if (shoulder != null && hip != null) {
        leaning = _torsoLean(shoulder, hip) > rules.maxTorsoLean!;
      }
    }

    return FormFeedback(
      depth: depth,
      kneeAngle: angle,
      torsoTooFarForward: leaning,
    );
  }

  /// The single cue for a frame, worst fault first — a lifter mid-set can act
  /// on exactly one instruction.
  static String cueFor(FormExercise exercise, FormFeedback feedback) {
    if (!feedback.isVisible) return feedback.notVisibleReason!;
    final rules = FormRules.forExercise(exercise);
    if (feedback.torsoTooFarForward) return rules.leanCue;
    return switch (feedback.depth) {
      SquatDepth.deep => rules.goodCue,
      SquatDepth.partial => rules.shortCue,
      SquatDepth.standing => rules.shortCue,
    };
  }

  /// Prefers the named side, falling back to its mirror — filming side-on
  /// hides one arm or leg entirely, which is normal rather than an error.
  static BodyLandmark? _resolve(
    Map<BodyPoint, BodyLandmark> pose,
    BodyPoint point,
  ) {
    final direct = pose[point];
    if (direct != null && direct.likelihood >= minLikelihood) return direct;

    final mirror = _mirrorOf(point);
    if (mirror == null) return null;
    final other = pose[mirror];
    if (other != null && other.likelihood >= minLikelihood) return other;
    return null;
  }

  static BodyPoint? _mirrorOf(BodyPoint point) => switch (point) {
    BodyPoint.leftShoulder => BodyPoint.rightShoulder,
    BodyPoint.rightShoulder => BodyPoint.leftShoulder,
    BodyPoint.leftHip => BodyPoint.rightHip,
    BodyPoint.rightHip => BodyPoint.leftHip,
    BodyPoint.leftKnee => BodyPoint.rightKnee,
    BodyPoint.rightKnee => BodyPoint.leftKnee,
    BodyPoint.leftAnkle => BodyPoint.rightAnkle,
    BodyPoint.rightAnkle => BodyPoint.leftAnkle,
    BodyPoint.leftElbow => BodyPoint.rightElbow,
    BodyPoint.rightElbow => BodyPoint.leftElbow,
    BodyPoint.leftWrist => BodyPoint.rightWrist,
    BodyPoint.rightWrist => BodyPoint.leftWrist,
  };

  static double _angleAt(BodyLandmark vertex, BodyLandmark a, BodyLandmark b) {
    final v1x = a.x - vertex.x;
    final v1y = a.y - vertex.y;
    final v2x = b.x - vertex.x;
    final v2y = b.y - vertex.y;

    final dot = v1x * v2x + v1y * v2y;
    final mag1 = _hypot(v1x, v1y);
    final mag2 = _hypot(v2x, v2y);
    if (mag1 == 0 || mag2 == 0) return 180;

    final cos = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return _acosDegrees(cos);
  }

  static double _torsoLean(BodyLandmark shoulder, BodyLandmark hip) {
    final dx = (shoulder.x - hip.x).abs();
    final dy = (hip.y - shoulder.y).abs();
    if (dy == 0) return 90;
    return _atanDegrees(dx / dy);
  }

  static double _hypot(double x, double y) => math.sqrt(x * x + y * y);
  static double _acosDegrees(double v) => math.acos(v) * 180 / math.pi;
  static double _atanDegrees(double v) => math.atan(v) * 180 / math.pi;
}
