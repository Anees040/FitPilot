import '../entities/burn_option.dart';

/// Exercise category filter for burn plans.
enum ActivityCategory { indoor, outdoor, gym, equipment }

/// Activity entry in the internal MET table.
class _Activity {
  final String name;
  final double met;
  final ActivityCategory category;

  const _Activity(this.name, this.met, this.category);
}

/// Computes burn plan options using the MET formula.
///
/// Pure, deterministic — no side effects.
class BurnPlanner {
  const BurnPlanner();

  static const List<_Activity> _activities = [
    _Activity('Walking (brisk)', 3.5, ActivityCategory.outdoor),
    _Activity('Jump rope', 11.0, ActivityCategory.equipment),
    _Activity('Running', 9.8, ActivityCategory.outdoor),
    _Activity('Cycling', 7.5, ActivityCategory.equipment),
    _Activity('Burpees', 8.0, ActivityCategory.indoor),
    _Activity('Stair climbing', 8.8, ActivityCategory.indoor),
    _Activity('Swimming', 8.3, ActivityCategory.gym),
    _Activity('Weight training', 5.0, ActivityCategory.gym),
  ];

  /// Generates up to 4 burn options for the given [kcalOver] surplus,
  /// user [weightKg], and available [equipment].
  ///
  /// Returns an empty list when [kcalOver] <= 0.
  /// Walking is always included regardless of equipment.
  /// Options sorted by minutes ascending.
  List<BurnOption> planFor({
    required int kcalOver,
    required double weightKg,
    ActivityCategory? categoryFilter,
  }) {
    if (kcalOver <= 0) return [];

    final options = <BurnOption>[];

    for (final activity in _activities) {
      // Include if no filter is active, or the category matches,
      // or it's walking (always included).
      final isWalking = activity.name == 'Walking (brisk)';
      final categorySatisfied =
          categoryFilter == null || activity.category == categoryFilter;

      if (!isWalking && !categorySatisfied) continue;

      final rawMinutes = kcalOver * 200 / (activity.met * 3.5 * weightKg);

      // Round UP to next multiple of 5, minimum 5.
      var minutes = (rawMinutes / 5).ceil() * 5;
      if (minutes < 5) minutes = 5;

      int? steps;
      if (isWalking) {
        // steps = minutes * 100, rounded to nearest 500
        steps = ((minutes * 100) / 500).round() * 500;
      }

      options.add(
        BurnOption(
          activity: activity.name,
          minutes: minutes,
          kcal: kcalOver,
          steps: steps,
        ),
      );
    }

    if (options.length > 4) {
      final walkingOption = options.firstWhere(
        (o) => o.activity == 'Walking (brisk)',
      );
      final nonWalkingOptions = options
          .where((o) => o.activity != 'Walking (brisk)')
          .toList();
      nonWalkingOptions.sort((a, b) => a.minutes.compareTo(b.minutes));
      final finalOptions = [...nonWalkingOptions.sublist(0, 3), walkingOption];
      finalOptions.sort((a, b) => a.minutes.compareTo(b.minutes));
      return finalOptions;
    } else {
      options.sort((a, b) => a.minutes.compareTo(b.minutes));
      return options;
    }
  }
}
