import '../entities/burn_option.dart';
import '../entities/exercise.dart';

/// Computes burn plan options using the MET formula.
///
/// Pure, deterministic — no side effects.
class BurnPlanner {
  const BurnPlanner();

  /// Generates up to 5 burn options (Walking + up to 4 others) for the given
  /// [kcalOver] surplus, user [weightKg], and list of filtered [candidates].
  ///
  /// The [candidates] should already be filtered by equipment availability.
  /// 
  /// Selection modes:
  /// - 'recommended': 2 fastest overall, 1 easy-pace, plus Walking.
  /// - Specific category ('gym', 'indoor', 'outdoor', 'calisthenics'): up to 4 fastest in category, plus Walking.
  /// 
  /// Walking ALWAYS appears, naturally sorted by minutes.
  List<BurnOption> planFor({
    required int kcalOver,
    required double weightKg,
    required List<Exercise> candidates,
    String categoryPref = 'recommended',
    String pacePref = 'any',
  }) {
    if (kcalOver <= 0 || candidates.isEmpty) return [];

    // Find walking
    final walkingEx = candidates.firstWhere(
      (e) => e.name.toLowerCase().contains('walk'),
      orElse: () => candidates.first,
    );
    final walkingOpt = _createOption(walkingEx, kcalOver, weightKg, true);

    // Filter out walking for the pool
    var pool = candidates.where((e) => !e.name.toLowerCase().contains('walk')).toList();
    if (pool.isEmpty) pool = List<Exercise>.from(candidates);

    // Apply pace filter (with fallback if no exercises match pace)
    if (pacePref != 'any') {
      final paceFiltered = pool.where((e) => e.paceTier == pacePref).toList();
      if (paceFiltered.isNotEmpty) {
        pool = paceFiltered;
      }
    }

    final options = <BurnOption>[];

    if (categoryPref == 'recommended') {
      // 2 fastest overall, 1 easy-pace
      var sortedBySpeed = List<Exercise>.from(pool)
        ..sort((a, b) => b.met.compareTo(a.met)); // highest MET = fastest
      var fastExercises = sortedBySpeed.take(2).toList();
      var easyExercises = pool
          .where((e) => e.paceTier == 'easy' && !fastExercises.contains(e))
          .toList();

      for (var ex in fastExercises) {
        options.add(_createOption(ex, kcalOver, weightKg, false));
      }
      if (easyExercises.isNotEmpty) {
        options.add(_createOption(easyExercises.first, kcalOver, weightKg, false));
      }
    } else {
      final pref = categoryPref.toLowerCase().trim();
      var catPool = pool.where((e) {
        final catName = e.category.name.toLowerCase();
        if (catName == pref) return true;
        if (pref == 'cardio' && (catName == 'outdoor' || e.met >= 7.0)) return true;
        if (pref == 'strength' && (catName == 'gym' || catName == 'calisthenics')) return true;
        if (pref == 'fun' && (catName == 'outdoor' || catName == 'indoor')) return true;
        if (pref == 'core' && (catName == 'calisthenics' || e.primaryMuscles.contains('Core') || e.secondaryMuscles.contains('Core'))) return true;
        return false;
      }).toList();

      if (catPool.isEmpty) {
        catPool = List<Exercise>.from(pool);
      }
      catPool.sort((a, b) => b.met.compareTo(a.met)); // fastest first

      for (var ex in catPool.take(4)) {
        options.add(_createOption(ex, kcalOver, weightKg, false));
      }
    }

    options.add(walkingOpt);
    
    // Sort all by minutes ascending
    options.sort((a, b) => a.minutes.compareTo(b.minutes));

    // Deduplicate by activity name in case walking was used twice (fallback case)
    final seen = <String>{};
    final uniqueOptions = <BurnOption>[];
    for (var opt in options) {
      if (seen.add(opt.activity)) {
        uniqueOptions.add(opt);
      }
    }

    // Guarantee fallback if pool filtering yielded nothing
    if (uniqueOptions.isEmpty && candidates.isNotEmpty) {
      final fallbackEx = candidates.take(3);
      for (var ex in fallbackEx) {
        uniqueOptions.add(_createOption(ex, kcalOver, weightKg, false));
      }
    }

    return uniqueOptions;
  }

  BurnOption _createOption(
    Exercise exercise,
    int kcalOver,
    double weightKg,
    bool isWalking,
  ) {
    int minutes = exercise.minutesToBurn(weightKg, kcalOver);
    int sessions = 1;
    int minutesPerSession = minutes;

    if (minutes > 90) {
      sessions = (minutes / 90.0).ceil();
      minutesPerSession = ((minutes / sessions) / 5.0).round() * 5;
      minutes = sessions * minutesPerSession;
    }

    int? steps;
    if (isWalking) {
      steps = ((minutes * 100) / 500).round() * 500;
    }
    return BurnOption(
      activity: exercise.name,
      minutes: minutes,
      kcal: kcalOver,
      steps: steps,
      exerciseId: exercise.id,
      difficulty: exercise.difficulty,
      mediaAsset: exercise.mediaAsset,
      sessions: sessions,
      minutesPerSession: minutesPerSession,
      met: exercise.met,
    );
  }
}
