import 'package:equatable/equatable.dart';

import 'kcal_range.dart';

/// The state of a user's day relative to their calorie debt.
enum DayState { cleared, inProgress, unburned, noData }

/// Status of a single day — computed, never stored.
class DayStatus extends Equatable {
  /// Gross calories eaten (sum of log ranges).
  final KcalRange total;

  /// Total kcal burned via completed burn plans.
  final int burnedKcal;

  /// Net calories after burn subtraction (eaten - burned).
  final KcalRange net;

  /// Calories left to burn (max(0, net - wiggleRoom)).
  final int toBurn;

  /// Whether the user has unburned debt, cleared it, or has no data.
  final DayState state;

  /// The wiggle room (allowance) used for this calculation.
  final int wiggleRoomKcal;

  const DayStatus({
    required this.total,
    required this.burnedKcal,
    required this.net,
    required this.toBurn,
    required this.state,
    required this.wiggleRoomKcal,
  });

  @override
  List<Object?> get props => [
    total,
    burnedKcal,
    net,
    toBurn,
    state,
    wiggleRoomKcal,
  ];

  @override
  String toString() => 'DayStatus($state, net=$net, toBurn=$toBurn)';
}
