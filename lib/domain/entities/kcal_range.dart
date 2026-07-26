import 'package:equatable/equatable.dart';

/// Immutable calorie range — the core value object of FitPilot.
///
/// Every calorie value in the app is represented as a range (min–max),
/// never a single integer. This honesty about estimation uncertainty
/// is the product's core promise.
class KcalRange extends Equatable {
  final int min;
  final int max;

  /// Creates a [KcalRange] with the given [min] and [max].
  ///
  /// Throws [ArgumentError] if [min] < 0 or [min] > [max].
  KcalRange(this.min, this.max) {
    if (min < 0) {
      throw ArgumentError('min must be >= 0, got $min');
    }
    if (min > max) {
      throw ArgumentError('min ($min) must be <= max ($max)');
    }
  }

  /// Creates a [KcalRange] where min == max.
  KcalRange.exact(int value) : this(value, value);

  /// Adds two ranges together (both ends).
  KcalRange plus(KcalRange other) =>
      KcalRange(min + other.min, max + other.max);

  /// Scales both ends by [qty], rounding to nearest int.
  ///
  /// Throws [ArgumentError] if [qty] <= 0.
  KcalRange times(num qty) {
    if (qty <= 0) {
      throw ArgumentError('qty must be > 0, got $qty');
    }
    return KcalRange((min * qty).round(), (max * qty).round());
  }

  /// Subtracts [kcal] from both ends, clamping each at 0 (never negative).
  KcalRange minus(int kcal) {
    final newMin = (min - kcal).clamp(0, double.infinity).toInt();
    final newMax = (max - kcal).clamp(0, double.infinity).toInt();
    return KcalRange(newMin, newMax);
  }

  /// The midpoint of the range, rounded to nearest int.
  int get midpoint => ((min + max) / 2).round();

  /// Whether this range is exact (min == max).
  bool get isExact => min == max;

  /// Formats the range for display.
  ///
  /// Returns "420 kcal" when exact, or "420\u2013560 kcal" (with EN DASH) when a range.
  String format() {
    if (isExact) return '$min kcal';
    return '$min\u2013$max kcal';
  }

  /// Sums an iterable of ranges. Returns KcalRange(0, 0) for an empty iterable.
  static KcalRange sum(Iterable<KcalRange> ranges) {
    var totalMin = 0;
    var totalMax = 0;
    for (final r in ranges) {
      totalMin += r.min;
      totalMax += r.max;
    }
    return KcalRange(totalMin, totalMax);
  }

  @override
  List<Object?> get props => [min, max];

  @override
  String toString() => 'KcalRange($min, $max)';
}
