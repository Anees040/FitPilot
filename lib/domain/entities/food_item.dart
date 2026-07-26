import 'package:equatable/equatable.dart';

import 'kcal_range.dart';

/// A food item from the seed catalog or user-added.
class FoodItem extends Equatable {
  final String id;
  final String name;
  final String? nameUr;
  final String portionLabel;
  final int? grams;
  final KcalRange kcalPerPortion;
  final bool isVerified;

  FoodItem({
    required this.id,
    required this.name,
    this.nameUr,
    required this.portionLabel,
    this.grams,
    required this.kcalPerPortion,
    this.isVerified = true,
  }) {
    if (id.isEmpty) {
      throw ArgumentError('id must not be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError('name must not be empty');
    }
    if (portionLabel.isEmpty) {
      throw ArgumentError('portionLabel must not be empty');
    }
    if (grams != null && grams! <= 0) {
      throw ArgumentError('grams must be > 0 if provided, got $grams');
    }
  }

  @override
  List<Object?> get props =>
      [id, name, nameUr, portionLabel, grams, kcalPerPortion, isVerified];

  @override
  String toString() => 'FoodItem($id, $name)';
}
