import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/fade_scroll_row.dart';
import 'package:fitpilot/core/ui/select_chip.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/domain/entities/program.dart';
import 'package:fitpilot/features/programs/presentation/widgets/program_progress_bar.dart';
import 'package:fitpilot/features/programs/presentation/widgets/training_program_card.dart';

/// Selected focus filter, or null for "All".
final programFocusFilterProvider = StateProvider<ProgramFocus?>((ref) => null);

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final programsAsync = ref.watch(programsProvider);
    final filter = ref.watch(programFocusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Programs'),
        backgroundColor: Colors.transparent,
      ),
      body: programsAsync.when(
        data: (programs) {
          if (programs.isEmpty) {
            return EmptyState(
              illustration: 'empty_plan',
              message: 'Check back later for curated plans.',
              buttonLabel: 'Refresh',
              onAction: () => ref.invalidate(programsProvider),
            );
          }

          // Only offer chips for focuses that actually have programs, so the
          // filter row can never show an empty bucket.
          final focuses = <ProgramFocus>{for (final p in programs) p.program.focus}
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label));

          final visible = filter == null
              ? programs
              : programs.where((p) => p.program.focus == filter).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const TrainingProgramCard(),
              const SizedBox(height: 20),
              Text('PICK YOUR GOAL', style: theme.textTheme.overline),
              const SizedBox(height: 10),
              FadeScrollRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectChip(
                      label: 'All',
                      isSelected: filter == null,
                      onSelected: () => ref
                          .read(programFocusFilterProvider.notifier)
                          .state = null,
                    ),
                  ),
                  ...focuses.map(
                    (focus) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectChip(
                        label: focus.label,
                        isSelected: filter == focus,
                        onSelected: () => ref
                            .read(programFocusFilterProvider.notifier)
                            .state = focus,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...visible.map(
                (program) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProgramCard(program: program),
                ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: SkeletonList(count: 5),
        ),
        error: (e, st) => ErrorState(
          reason: 'Failed to load programs.',
          onRetry: () => ref.invalidate(programsProvider),
        ),
      ),
    );
  }
}

class _ProgramCard extends ConsumerWidget {
  final ProgramWithSessions program;

  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final meta = program.program;
    final active = ref.watch(activeProgramProvider);
    final isActive = active?.program.id == meta.id;
    final progress = ref.watch(programProgressProvider(meta.id)).valueOrNull;
    final done = progress?.completedCount ?? 0;

    return AppCard(
      variant: AppCardVariant.raised,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/programs/${meta.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (meta.heroImage != null)
            // 16:9 rather than a fixed 120 px: the artwork is photographic, and
            // a short box cropped most of it away.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    meta.heroImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        Container(color: ext.surfaceRaised),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.shadow.withValues(alpha: 0.15),
                          theme.colorScheme.shadow.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: theme.textTheme.overline.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.name,
                          style: theme.textTheme.h2.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // The two facts that decide whether a plan fits, read
                        // straight off the artwork instead of the chip row.
                        Text(
                          '${program.totalDays} days · ${meta.level.label}',
                          style: theme.textTheme.caption.copyWith(
                            color: theme.colorScheme.onPrimary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta.heroImage == null) ...[
                  Row(
                    children: [
                      Text(meta.icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meta.name,
                          style: theme.textTheme.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  meta.goal,
                  style: theme.textTheme.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Days and level already sit on the hero, so repeating
                    // them here would be noise. These two are what the image
                    // cannot say.
                    ProgramMetaChip(
                      label: meta.daysPerWeek > 0
                          ? '${meta.daysPerWeek}×/week'
                          : '${program.workoutDays} workouts',
                      icon: Icons.repeat,
                    ),
                    ProgramMetaChip(
                      label: meta.equipment.label,
                      icon: Icons.fitness_center,
                    ),
                    if (meta.heroImage == null)
                      ProgramMetaChip(
                        label: '${program.totalDays} days',
                        icon: Icons.event_outlined,
                      ),
                    if (meta.heroImage == null)
                      ProgramMetaChip(
                        label: meta.level.label,
                        icon: Icons.signal_cellular_alt,
                      ),
                  ],
                ),
                if (done > 0) ...[
                  const SizedBox(height: 12),
                  ProgramProgressBar(
                    fraction: program.totalDays == 0
                        ? 0
                        : done / program.totalDays,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$done of ${program.totalDays} days complete',
                    style: theme.textTheme.caption,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
