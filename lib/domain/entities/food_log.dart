import 'package:equatable/equatable.dart';

import 'kcal_range.dart';

/// How the food log was created.
enum LogSource { search, manual, aiPhoto, labelScan }

/// A single food log entry.
class FoodLog extends Equatable {
  final String id;
  final String? foodId;
  final String? foodName;
  final String? customName;
  final num quantity;
  final KcalRange kcal;
  final LogSource source;
  final DateTime loggedAt;
  final DateTime? deletedAt;

  /// Absolute path to the user's own meal photo, set only for AI photo scans.
  /// Local-only — never synced (the file lives in app documents).
  final String? photoPath;

  /// Protein in grams for this entry, already multiplied by [quantity].
  ///
  /// Null means unknown, which is deliberately different from zero: most of the
  /// food catalog has no protein figure, and counting those as 0 g would make
  /// the day's total look like a shortfall the user could not fix. The UI
  /// reports unknowns separately instead. Local-only — never synced.
  final double? proteinG;

  FoodLog({
    required this.id,
    this.foodId,
    this.foodName,
    this.customName,
    required this.quantity,
    required this.kcal,
    required this.source,
    required this.loggedAt,
    this.deletedAt,
    this.photoPath,
    this.proteinG,
  }) {
    if (foodId == null && customName == null && foodName == null) {
      throw ArgumentError(
        'A food log must identify its food: '
        'provide foodId, foodName, or customName',
      );
    }
    if (quantity <= 0 || quantity > 20) {
      throw ArgumentError('quantity must be positive up to 20, got $quantity');
    }
  }

  /// Returns the display name — customName if present, otherwise foodName.
  String? get displayName => customName ?? foodName;

  @override
  List<Object?> get props => [
    id,
    foodId,
    foodName,
    customName,
    quantity,
    kcal,
    source,
    loggedAt,
    deletedAt,
    proteinG,
    photoPath,
  ];

  @override
  String toString() =>
      'FoodLog($id, ${displayName ?? foodId}, qty=$quantity, $kcal)';

  FoodLog copyWith({
    String? id,
    String? foodId,
    String? foodName,
    String? customName,
    num? quantity,
    KcalRange? kcal,
    LogSource? source,
    DateTime? loggedAt,
    DateTime? deletedAt,
    String? photoPath,
    double? proteinG,
  }) {
    return FoodLog(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      customName: customName ?? this.customName,
      quantity: quantity ?? this.quantity,
      kcal: kcal ?? this.kcal,
      source: source ?? this.source,
      loggedAt: loggedAt ?? this.loggedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      photoPath: photoPath ?? this.photoPath,
      proteinG: proteinG ?? this.proteinG,
    );
  }
}
