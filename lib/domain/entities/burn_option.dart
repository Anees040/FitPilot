import 'package:equatable/equatable.dart';

/// A single burn option (activity + duration).
class BurnOption extends Equatable {
  final String activity;
  final int minutes;
  final int kcal;
  final int? steps;

  const BurnOption({
    required this.activity,
    required this.minutes,
    required this.kcal,
    this.steps,
  });

  @override
  List<Object?> get props => [activity, minutes, kcal, steps];

  @override
  String toString() =>
      'BurnOption($activity, ${minutes}min, ${kcal}kcal'
      '${steps != null ? ', ${steps}steps' : ''})';
}
