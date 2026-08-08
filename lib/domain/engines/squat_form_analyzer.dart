import 'dart:math' as math;

/// The landmarks the form check reads, named so the engine does not depend on
/// ML Kit's enum. Keeps this file pure Dart and testable without a camera.
enum BodyPoint {
  leftShoulder,
  rightShoulder,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

/// One detected joint position, in image coordinates.
class BodyLandmark {
  final double x;
  final double y;

  /// 0..1 from the detector. Low-confidence points are ignored rather than
  /// trusted, because a hallucinated knee produces a confident wrong verdict.
  final double likelihood;

  const BodyLandmark({
    required this.x,
    required this.y,
    this.likelihood = 1.0,
  });
}

/// How deep the current squat is.
enum SquatDepth {
  /// Standing, or barely bent.
  standing,

  /// Descending or ascending, not yet at depth.
  partial,

  /// Hip crease at or below the knee — a counted rep.
  deep,
}

/// What the form check concluded about one frame.
class FormFeedback {
  final SquatDepth depth;

  /// Knee angle in degrees: 180 is straight, ~90 is a parallel squat.
  final double? kneeAngle;

  /// True when the torso is pitched far forward, the most common fault.
  final bool torsoTooFarForward;

  /// Null when the person is not fully in frame — the UI asks them to step
  /// back rather than showing a verdict based on missing joints.
  final String? notVisibleReason;

  const FormFeedback({
    required this.depth,
    this.kneeAngle,
    this.torsoTooFarForward = false,
    this.notVisibleReason,
  });

  bool get isVisible => notVisibleReason == null;
}

/// Counts squat reps and judges depth from pose landmarks.
///
/// Scope is deliberately one exercise and two cues. Pose estimation gives joint
/// positions, not a coaching opinion — inferring "good form" in general from
/// them is guesswork, and confidently wrong advice under a loaded barbell is a
/// safety problem, not a bad UX. Depth and forward lean are the two things
/// joint angles genuinely support.
///
/// Everything here runs on-device: no video is uploaded, nothing is stored,
/// and it costs nothing per use.
class SquatFormAnalyzer {
  /// Below this knee angle the squat counts as deep enough.
  static const double deepAngle = 100;

  /// Above this the lifter is effectively standing.
  static const double standingAngle = 160;

  /// Landmarks below this likelihood are treated as missing.
  static const double minLikelihood = 0.5;

  /// Torso lean beyond this many degrees from vertical is flagged.
  static const double maxTorsoLean = 55;

  int _repCount = 0;
  bool _wasDeep = false;

  int get repCount => _repCount;

  /// Resets between sessions so a new recording starts from zero.
  void reset() {
    _repCount = 0;
    _wasDeep = false;
  }

  /// Reads one frame of landmarks.
  ///
  /// A rep is counted on the way *up* — when the lifter has been deep and then
  /// returns towards standing. Counting on the way down would credit a rep the
  /// lifter has not finished.
  FormFeedback analyze(Map<BodyPoint, BodyLandmark> pose) {
    final hip = _midpoint(pose, BodyPoint.leftHip, BodyPoint.rightHip);
    final knee = _midpoint(pose, BodyPoint.leftKnee, BodyPoint.rightKnee);
    final ankle = _midpoint(pose, BodyPoint.leftAnkle, BodyPoint.rightAnkle);
    final shoulder = _midpoint(
      pose,
      BodyPoint.leftShoulder,
      BodyPoint.rightShoulder,
    );

    if (hip == null || knee == null || ankle == null) {
      return const FormFeedback(
        depth: SquatDepth.standing,
        notVisibleReason: 'Step back so your hips, knees and feet are all in frame',
      );
    }

    final angle = _angleAt(knee, hip, ankle);
    final depth = angle <= deepAngle
        ? SquatDepth.deep
        : angle >= standingAngle
        ? SquatDepth.standing
        : SquatDepth.partial;

    // Count on the ascent: deep, then no longer deep.
    if (_wasDeep && depth != SquatDepth.deep) {
      _repCount++;
      _wasDeep = false;
    } else if (depth == SquatDepth.deep) {
      _wasDeep = true;
    }

    var leaning = false;
    if (shoulder != null) {
      leaning = _torsoLeanDegrees(shoulder, hip) > maxTorsoLean;
    }

    return FormFeedback(
      depth: depth,
      kneeAngle: angle,
      torsoTooFarForward: leaning,
    );
  }

  /// The coaching line for a frame — one cue at a time, worst first.
  ///
  /// More than one instruction mid-set is noise; a lifter can act on exactly
  /// one thing.
  static String cueFor(FormFeedback feedback) {
    if (!feedback.isVisible) return feedback.notVisibleReason!;
    if (feedback.torsoTooFarForward) {
      return 'Chest up — you are leaning too far forward';
    }
    return switch (feedback.depth) {
      SquatDepth.deep => 'Good depth',
      SquatDepth.partial => 'Keep going, a little deeper',
      SquatDepth.standing => 'Ready when you are',
    };
  }

  /// Averages a left/right pair, ignoring any point the detector was unsure
  /// about. Returns null when neither side is usable.
  static BodyLandmark? _midpoint(
    Map<BodyPoint, BodyLandmark> pose,
    BodyPoint left,
    BodyPoint right,
  ) {
    final a = pose[left];
    final b = pose[right];
    final aOk = a != null && a.likelihood >= minLikelihood;
    final bOk = b != null && b.likelihood >= minLikelihood;

    if (aOk && bOk) {
      return BodyLandmark(
        x: (a.x + b.x) / 2,
        y: (a.y + b.y) / 2,
        likelihood: math.min(a.likelihood, b.likelihood),
      );
    }
    // One side is enough when filming from the side, which is the angle the
    // UI asks for.
    if (aOk) return a;
    if (bOk) return b;
    return null;
  }

  /// Interior angle at [vertex], in degrees.
  static double _angleAt(BodyLandmark vertex, BodyLandmark a, BodyLandmark b) {
    final v1x = a.x - vertex.x;
    final v1y = a.y - vertex.y;
    final v2x = b.x - vertex.x;
    final v2y = b.y - vertex.y;

    final dot = v1x * v2x + v1y * v2y;
    final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
    if (mag1 == 0 || mag2 == 0) return 180;

    final cos = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }

  /// How far the shoulder-to-hip line tilts from vertical, in degrees.
  static double _torsoLeanDegrees(BodyLandmark shoulder, BodyLandmark hip) {
    final dx = (shoulder.x - hip.x).abs();
    final dy = (hip.y - shoulder.y).abs();
    if (dy == 0) return 90;
    return math.atan(dx / dy) * 180 / math.pi;
  }
}
