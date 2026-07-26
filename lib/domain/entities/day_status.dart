import 'package:equatable/equatable.dart';

import 'kcal_range.dart';

/// The state of a user's day relative to their calorie allowance.
enum DayState { under, near, over }

/// Status of a single day — computed, never stored.
class DayStatus extends Equatable {
  /// Gross calories eaten (sum of log ranges).
  final KcalRange total;

  /// Total kcal burned via completed burn plans.
  final int burnedKcal;

  /// Net calories after burn subtraction.
  final KcalRange net;

  /// Remaining kcal before hitting allowance (may be negative).
  final int remainingKcal;

  /// Whether the user is under, near, or over their allowance.
  final DayState state;

  /// The allowance used for this calculation.
  final int allowanceKcal;

  const DayStatus({
    required this.total,
    required this.burnedKcal,
    required this.net,
    required this.remainingKcal,
    required this.state,
    required this.allowanceKcal,
  });

  @override
  List<Object?> get props => [
    total,
    burnedKcal,
    net,
    remainingKcal,
    state,
    allowanceKcal,
  ];

  @override
  String toString() => 'DayStatus($state, net=$net, remaining=$remainingKcal)';
}
