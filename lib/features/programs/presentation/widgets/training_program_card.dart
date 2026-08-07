import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/domain/entities/program.dart';
import 'package:fitpilot/features/programs/presentation/widgets/program_progress_bar.dart';

/// Entry point card for the training-programs feature.
///
/// Renders one of two states, so Plan and Today can both drop it in without
/// duplicating the enrolled/not-enrolled branch:
///  * not enrolled — a promo that routes to the catalogue
///  * enrolled — name, Week W · Day D, a progress bar and today's session
class TrainingProgramCard extends ConsumerWidget {
  /// When true the promo variant is hidden entirely — Today already has a
  /// Programs tile, so an extra promo there would be noise.
  final bool hidePromo;

  const TrainingProgramCard({super.key, this.hidePromo = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProgramProvider);
    if (active == null) {
      return hidePromo ? const SizedBox.shrink() : const _ProgramPromoCard();
    }
    return _ActiveProgramCard(active: active);
  }
}

class _ProgramPromoCard extends StatelessWidget {
  const _ProgramPromoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      variant: AppCardVariant.raised,
      onTap: () => context.go('/programs'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ext.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Training Programs', style: theme.textTheme.bodyStrong),
                const SizedBox(height: 4),
                Text(
                  'Structured plans: Six-Pack in 30 Days, Full Body, '
                  'Strength & Conditioning and more.',
                  style: theme.textTheme.caption,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: ext.textDisabled),
        ],
      ),
    );
  }
}

class _ActiveProgramCard extends ConsumerWidget {
  final ProgramWithSessions active;

  const _ActiveProgramCard({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final profile = ref.watch(profileProvider).valueOrNull;
    final progress = ref.watch(activeProgramProgressProvider).valueOrNull;

    final day = profile?.activeProgramDay ?? 1;
    final week = profile?.activeProgramWeek ?? 1;
    final total = active.totalDays;
    final done = progress?.completedCount ?? 0;
    final session = active.sessionForDay(day);

    return AppCard(
      variant: AppCardVariant.raised,
      onTap: () => context.push('/programs/${active.program.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(active.program.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active.program.name,
                  style: theme.textTheme.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('Week $week · Day $day', style: theme.textTheme.caption),
            ],
          ),
          const SizedBox(height: 12),
          ProgramProgressBar(fraction: total == 0 ? 0 : done / total),
          const SizedBox(height: 6),
          Text('$done of $total days complete', style: theme.textTheme.caption),
          if (session != null) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: ext.hairline),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.isRest ? 'Rest day' : session.displayTitle,
                        style: theme.textTheme.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.isRest
                            ? 'Recovery counts too'
                            : '${session.totalMinutes} min · '
                                '${session.items.length} exercises',
                        style: theme.textTheme.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _SessionButton(
                  label: session.isRest ? 'View' : "Today's session",
                  onPressed: () => context.push(
                    '/programs/${active.program.id}/session/${session.id}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SessionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Material(
      color: ext.accentSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.caption.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
