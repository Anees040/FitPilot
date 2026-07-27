import 'package:equatable/equatable.dart';

class WeightEntry extends Equatable {
  final String id;
  final DateTime date;
  final double weightKg;
  final DateTime updatedAt;

  const WeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, date, weightKg, updatedAt];

  WeightEntry copyWith({
    String? id,
    DateTime? date,
    double? weightKg,
    DateTime? updatedAt,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
