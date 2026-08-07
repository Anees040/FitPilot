import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A gym machine identified from a photo by the Gemini proxy, plus the coaching
/// content that goes with it.
///
/// Every field is defensive: the model can omit any list, return a number where
/// a string was asked for, or answer with `isGymMachine=false` and nothing else.
/// [fromJson] never throws — a malformed payload degrades to empty lists rather
/// than crashing the result screen.
/// Value equality matters: this type is used as a Riverpod family key, so two
/// equal analyses must resolve to the same provider rather than leaking a new
/// one on every rebuild.
class MachineAnalysis extends Equatable {
  /// False when the photo isn't gym equipment. The UI shows a "retake" state.
  final bool isGymMachine;
  final String machineName;

  /// 0..1. Anything below 0.7 is surfaced to the user as "Medium" confidence.
  final double confidence;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> howToUse;
  final List<String> commonMistakes;
  final List<String> safetyTips;

  /// Generic exercise names ("lat pulldown") used to find catalog exercises.
  final List<String> suggestedExerciseKeywords;

  const MachineAnalysis({
    required this.isGymMachine,
    required this.machineName,
    required this.confidence,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.howToUse = const [],
    this.commonMistakes = const [],
    this.safetyTips = const [],
    this.suggestedExerciseKeywords = const [],
  });

  /// True when the model was sure enough that we don't warn the user.
  bool get isHighConfidence => confidence >= 0.7;

  /// "High" / "Medium" — the label shown in the confidence chip.
  String get confidenceLabel => isHighConfidence ? 'High' : 'Medium';

  /// Whether there is any coaching content worth rendering.
  bool get hasGuidance =>
      howToUse.isNotEmpty || commonMistakes.isNotEmpty || safetyTips.isNotEmpty;

  factory MachineAnalysis.fromJson(Map<String, dynamic> json) {
    return MachineAnalysis(
      isGymMachine: _readBool(json['isGymMachine']),
      machineName: _readString(json['machineName']),
      confidence: _readConfidence(json['confidence']),
      primaryMuscles: _readStringList(json['primaryMuscles']),
      secondaryMuscles: _readStringList(json['secondaryMuscles']),
      howToUse: _readStringList(json['howToUse']),
      commonMistakes: _readStringList(json['commonMistakes']),
      safetyTips: _readStringList(json['safetyTips']),
      suggestedExerciseKeywords: _readStringList(json['suggestedExerciseKeywords']),
    );
  }

  Map<String, dynamic> toJson() => {
    'isGymMachine': isGymMachine,
    'machineName': machineName,
    'confidence': confidence,
    'primaryMuscles': primaryMuscles,
    'secondaryMuscles': secondaryMuscles,
    'howToUse': howToUse,
    'commonMistakes': commonMistakes,
    'safetyTips': safetyTips,
    'suggestedExerciseKeywords': suggestedExerciseKeywords,
  };

  /// Rebuilds an analysis from a stored `response_json` row. Returns null when
  /// the row is unreadable, so one corrupt scan can't break the history list.
  static MachineAnalysis? tryDecode(String source) {
    try {
      final decoded = json.decode(source);
      if (decoded is Map<String, dynamic>) return MachineAnalysis.fromJson(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static String _readString(Object? value) {
    if (value is String) return value.trim();
    if (value == null) return '';
    return value.toString().trim();
  }

  /// Clamps to 0..1 and accepts a 0-100 style percentage, which the model
  /// occasionally returns despite the schema asking for a fraction.
  static double _readConfidence(Object? value) {
    double? raw;
    if (value is num) {
      raw = value.toDouble();
    } else if (value is String) {
      raw = double.tryParse(value.replaceAll('%', '').trim());
    }
    if (raw == null || raw.isNaN) return 0;
    if (raw > 1) raw = raw / 100;
    if (raw < 0) return 0;
    if (raw > 1) return 1;
    return raw;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const [];
    final out = <String>[];
    for (final item in value) {
      if (item == null) continue;
      final text = item is String ? item.trim() : item.toString().trim();
      if (text.isNotEmpty) out.add(text);
    }
    return out;
  }

  @override
  List<Object?> get props => [
    isGymMachine,
    machineName,
    confidence,
    primaryMuscles,
    secondaryMuscles,
    howToUse,
    commonMistakes,
    safetyTips,
    suggestedExerciseKeywords,
  ];
}
