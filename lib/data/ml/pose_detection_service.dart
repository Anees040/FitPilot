import 'dart:io';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:fitpilot/domain/engines/squat_form_analyzer.dart';

/// Runs Google ML Kit's pose detector and translates its output into the
/// engine's own landmark vocabulary.
///
/// Entirely on-device: the image never leaves the phone, nothing is uploaded or
/// stored, and there is no per-use cost or API key. That is the whole reason
/// this is ML Kit rather than a video upload to a model.
class PoseDetectionService {
  PoseDetector? _detector;

  /// `stream` mode tracks a person across frames, which is what makes rep
  /// counting stable; `single` would re-find the body every frame.
  PoseDetector get _instance {
    return _detector ??= PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
  }

  /// Detects a pose in a still image and maps it for [SquatFormAnalyzer].
  ///
  /// Returns an empty map when no person is found, which the analyzer reports
  /// as "not visible" rather than as a verdict.
  Future<Map<BodyPoint, BodyLandmark>> detectInFile(String path) async {
    final poses = await _instance.processImage(InputImage.fromFile(File(path)));
    if (poses.isEmpty) return const {};
    return _map(poses.first);
  }

  /// Frees the native detector. Not optional — the platform holds a model in
  /// memory until this is called.
  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }

  static Map<BodyPoint, BodyLandmark> _map(Pose pose) {
    const wanted = <PoseLandmarkType, BodyPoint>{
      PoseLandmarkType.leftShoulder: BodyPoint.leftShoulder,
      PoseLandmarkType.rightShoulder: BodyPoint.rightShoulder,
      PoseLandmarkType.leftHip: BodyPoint.leftHip,
      PoseLandmarkType.rightHip: BodyPoint.rightHip,
      PoseLandmarkType.leftKnee: BodyPoint.leftKnee,
      PoseLandmarkType.rightKnee: BodyPoint.rightKnee,
      PoseLandmarkType.leftAnkle: BodyPoint.leftAnkle,
      PoseLandmarkType.rightAnkle: BodyPoint.rightAnkle,
    };

    final out = <BodyPoint, BodyLandmark>{};
    wanted.forEach((mlKitType, point) {
      final landmark = pose.landmarks[mlKitType];
      if (landmark == null) return;
      out[point] = BodyLandmark(
        x: landmark.x,
        y: landmark.y,
        likelihood: landmark.likelihood,
      );
    });
    return out;
  }
}
