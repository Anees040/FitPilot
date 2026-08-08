import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/protein_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

/// Today's protein progress, shown under the calorie summary.
///
/// Calories tell you whether to stop eating; protein tells you what to eat.
/// Someone in a deficit without enough protein loses muscle alongside fat, so
/// this sits directly beneath the ring rather than buried in a submenu.
class ProteinRow extends ConsumerWidget {
  const ProteinRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final protein = ref.watch(proteinTodayProvider);

    // No weight on file means no honest target — ask for one instead of
    // inventing a number from a default body.
    if (!protein.hasTarget) {
      return InkWell(
        onTap: () => context.push('/profile'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.egg_alt_outlined, size: 17, color: ext.textDisabled),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Set your weight to get a protein target',
                  style: theme.textTheme.caption,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: ext.textDisabled),
            ],
          ),
        ),
      );
    }

    final consumed = protein.consumedG.round();

    return InkWell(
      onTap: () => context.push('/protein-guide'),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.egg_alt_outlined,
                  size: 17,
                  color: protein.isMet ? ext.success : ext.energy,
                ),
                const SizedBox(width: 8),
                Text('Protein', style: theme.textTheme.bodyStrong),
                const Spacer(),
                Text(
                  '$consumed / ${protein.targetG} g',
                  style: theme.textTheme.bodyStrong.copyWith(
                    color: protein.isMet ? ext.success : ext.energy,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ext.textDisabled,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: protein.progress ?? 0,
                minHeight: 6,
                backgroundColor: ext.hairline,
                valueColor: AlwaysStoppedAnimation(
                  protein.isMet ? ext.success : ext.energy,
                ),
              ),
            ),
            if (protein.unknownMeals > 0) ...[
              const SizedBox(height: 6),
              Text(
                protein.unknownMeals == 1
                    ? '1 meal has no protein info'
                    : '${protein.unknownMeals} meals have no protein info',
                style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
