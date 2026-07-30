import 'package:equatable/equatable.dart';

/// A single burn option (activity + duration).
class BurnOption extends Equatable {
  final String activity;
  final int minutes;
  final int kcal;
  final int? steps;
  final String? exerciseId;
  final int? difficulty;
  final String? mediaAsset;

  const BurnOption({
    required this.activity,
    required this.minutes,
    required this.kcal,
    this.steps,
    this.exerciseId,
    this.difficulty,
    this.mediaAsset,
  });

  @override
  List<Object?> get props => [activity, minutes, kcal, steps, exerciseId, difficulty, mediaAsset];

  @override
  String toString() =>
      'BurnOption($activity, ${minutes}min, ${kcal}kcal'
      '${steps != null ? ', ${steps}steps' : ''})';
}
