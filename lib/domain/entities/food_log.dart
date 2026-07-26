import 'package:equatable/equatable.dart';

import 'kcal_range.dart';

/// How the food log was created.
enum LogSource { search, manual, aiPhoto, labelScan }

/// A single food log entry.
class FoodLog extends Equatable {
  final String id;
  final String? foodId;
  final String? customName;
  final num quantity;
  final KcalRange kcal;
  final LogSource source;
  final DateTime loggedAt;
  final DateTime? deletedAt;

  FoodLog({
    required this.id,
    this.foodId,
    this.customName,
    required this.quantity,
    required this.kcal,
    required this.source,
    required this.loggedAt,
    this.deletedAt,
  }) {
    if (foodId == null && customName == null) {
      throw ArgumentError(
        'A food log must identify its food: '
        'provide either foodId or customName (or both)',
      );
    }
    if (quantity < 1 || quantity > 20) {
      throw ArgumentError('quantity must be 1–20 inclusive, got $quantity');
    }
  }

  /// Returns the display name — customName when present, otherwise null.
  String? get displayName => customName;

  @override
  List<Object?> get props => [
    id,
    foodId,
    customName,
    quantity,
    kcal,
    source,
    loggedAt,
    deletedAt,
  ];

  @override
  String toString() =>
      'FoodLog($id, ${displayName ?? foodId}, qty=$quantity, $kcal)';

  FoodLog copyWith({
    String? id,
    String? foodId,
    String? customName,
    num? quantity,
    KcalRange? kcal,
    LogSource? source,
    DateTime? loggedAt,
    DateTime? deletedAt,
  }) {
    return FoodLog(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      customName: customName ?? this.customName,
      quantity: quantity ?? this.quantity,
      kcal: kcal ?? this.kcal,
      source: source ?? this.source,
      loggedAt: loggedAt ?? this.loggedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
