import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/domain/engines/protein_target.dart';

/// Today's protein, split into what is known and what is not.
///
/// [unknownMeals] matters as much as [consumedG]: most catalog foods carry no
/// protein figure, so a low total often means "we do not know" rather than
/// "you did not eat any". Showing both stops the bar from lying.
class ProteinToday {
  final double consumedG;
  final int unknownMeals;
  final int? targetG;

  const ProteinToday({
    required this.consumedG,
    required this.unknownMeals,
    required this.targetG,
  });

  bool get hasTarget => targetG != null && targetG! > 0;

  /// 0..1 for the progress bar, or null when there is no target to fill.
  double? get progress {
    if (!hasTarget) return null;
    final ratio = consumedG / targetG!;
    return ratio.clamp(0.0, 1.0);
  }

  int get remainingG {
    if (!hasTarget) return 0;
    final left = targetG! - consumedG;
    return left <= 0 ? 0 : left.round();
  }

  bool get isMet => hasTarget && consumedG >= targetG!;
}

/// The protein target in force: the user's own goal if set, else the
/// weight-based recommendation. Null when no weight is known.
final proteinTargetProvider = Provider<int?>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null) return null;

  return ProteinTarget.effectiveTarget(profile);
});

/// What the recommendation would be, ignoring any override — used by the
/// "reset to recommended" affordance.
final recommendedProteinProvider = Provider<int?>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null) return null;
  return ProteinTarget.recommend(profile);
});

/// Today's protein progress.
final proteinTodayProvider = Provider<ProteinToday>((ref) {
  final today = ref.watch(todayProvider).valueOrNull;
  final target = ref.watch(proteinTargetProvider);

  if (today == null) {
    return ProteinToday(consumedG: 0, unknownMeals: 0, targetG: target);
  }

  var consumed = 0.0;
  var unknown = 0;
  for (final log in today.logs) {
    final protein = log.proteinG;
    if (protein == null) {
      unknown++;
    } else {
      consumed += protein;
    }
  }

  return ProteinToday(
    consumedG: consumed,
    unknownMeals: unknown,
    targetG: target,
  );
});
