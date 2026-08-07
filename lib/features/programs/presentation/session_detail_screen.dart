import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/exercise_media.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/domain/entities/program.dart';

class SessionDetailScreen extends ConsumerWidget {
  final String programId;
  final String sessionId;

  const SessionDetailScreen({
    super.key,
    required this.programId,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(programsProvider);

    return programsAsync.when(
      loading: () => const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: SkeletonList(count: 4),
        ),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: ErrorState(
          reason: 'Failed to load this session.',
          onRetry: () => ref.invalidate(programsProvider),
        ),
      ),
      data: (programs) {
        ProgramWithSessions? program;
        for (final p in programs) {
          if (p.program.id == programId) program = p;
        }
        ProgramSession? session;
        if (program != null) {
          for (final s in program.sessions) {
            if (s.id == sessionId) session = s;
          }
        }
        if (program == null || session == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: ErrorState(
              reason: 'That session is no longer available.',
              onRetry: () => context.pop(),
            ),
          );
        }

        final resolvedAsync = ref.watch(resolvedSessionProvider(session));
        return resolvedAsync.when(
          loading: () => const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16.0),
              child: SkeletonList(count: 4),
            ),
          ),
          error: (e, st) => Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: ErrorState(
              reason: 'Failed to load this session.',
              onRetry: () =>
                  ref.invalidate(resolvedSessionProvider(session!)),
            ),
          ),
          data: (resolved) =>
              _SessionBody(program: program!, resolved: resolved),
        );
      },
    );
  }
}

class _SessionBody extends ConsumerStatefulWidget {
  final ProgramWithSessions program;
  final ResolvedSession resolved;

  const _SessionBody({required this.program, required this.resolved});

  @override
  ConsumerState<_SessionBody> createState() => _SessionBodyState();
}

class _SessionBodyState extends ConsumerState<_SessionBody> {
  /// Guards a double tap while the write is in flight. The repository's
  /// primary key makes a repeat insert a no-op anyway; this stops the second
  /// tap from queuing a second burn entry before the first returns.
  bool _isSaving = false;

  Future<void> _complete() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    final session = widget.resolved.session;
    final meta = widget.program.program;
    final result = await ref
        .read(programsControllerProvider)
        .completeSession(widget.resolved);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!result.recorded) {
      AppSnackbar.warning(context, 'This day is already marked complete');
      return;
    }

    if (result.programFinished) {
      context.pushReplacement(
        '/programs/complete/${meta.id}'
        '?sessions=${result.completedSessions}&kcal=${result.totalKcal}',
      );
      return;
    }

    context.pop();
    AppSnackbar.success(
      context,
      session.isRest
          ? 'Rest day logged — next up Day ${session.dayNumber + 1}'
          : '+${result.kcal} kcal logged — next up Day ${session.dayNumber + 1}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final resolved = widget.resolved;
    final session = resolved.session;

    final profile = ref.watch(profileProvider).valueOrNull;
    final weightKg = profile?.weightKg ?? 70.0;
    final kcal = resolved.estimatedKcal(weightKg);

    final progress = ref.watch(programProgressProvider(widget.program.program.id));
    final isDone =
        progress.valueOrNull?.isDone(session.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${session.dayNumber} of ${widget.program.totalDays}'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(session.displayTitle, style: theme.textTheme.h1),
          const SizedBox(height: 6),
          Text(
            [
              'Week ${session.weekNumber}',
              if (session.focus != null) session.focus!,
              if (!session.isRest) '${resolved.totalMinutes} min',
            ].join(' · '),
            style: theme.textTheme.caption,
          ),
          const SizedBox(height: 20),
          if (isDone) ...[
            AppCard(
              color: ext.success.withValues(alpha: 0.12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: ext.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Completed. Repeat it any time — it only counts once.',
                      style: theme.textTheme.caption
                          .copyWith(color: ext.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (session.isRest)
            _RestCard(notes: session.notes)
          else ...[
            AppCard(
              color: ext.energy.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated burn', style: theme.textTheme.body),
                      Text(
                        'at ${weightKg.round()} kg',
                        style: theme.textTheme.caption,
                      ),
                    ],
                  ),
                  Text(
                    '~$kcal kcal',
                    style: theme.textTheme.h2.copyWith(color: ext.energy),
                  ),
                ],
              ),
            ),
            if (session.notes != null) ...[
              const SizedBox(height: 12),
              AppCard(
                color: ext.surfaceRaised,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        session.notes!,
                        style: theme.textTheme.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('THIS SESSION', style: theme.textTheme.overline),
            const SizedBox(height: 10),
            ...resolved.exercises.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExerciseRow(entry: entry, weightKg: weightKg),
              ),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: _isSaving
                ? 'Saving…'
                : session.isRest
                    ? 'Mark rest day done'
                    : 'Mark session complete',
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _complete,
          ),
          const SizedBox(height: 8),
          Text(
            session.isRest
                ? 'Rest days advance your plan without logging a burn.'
                : 'Logs one burn entry so Progress counts this session.',
            style: theme.textTheme.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RestCard extends StatelessWidget {
  final String? notes;

  const _RestCard({this.notes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      variant: AppCardVariant.raised,
      child: Column(
        children: [
          Icon(Icons.self_improvement, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Rest day — recovery counts too', style: theme.textTheme.h2),
          const SizedBox(height: 8),
          Text(
            notes ??
                'Your body rebuilds between sessions. Keep logging meals and '
                    'come back stronger tomorrow.',
            style: theme.textTheme.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No calories are logged for a rest day.',
            style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ProgramSessionExercise entry;
  final double weightKg;

  const _ExerciseRow({required this.entry, required this.weightKg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final exercise = entry.exercise;

    return AppCard(
      variant: AppCardVariant.raised,
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/exercises/${exercise.id}'),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            // Handles a missing/absent media asset itself, which is what an
            // exercise with no artwork (e.g. kegel-hold) relies on.
            child: ExerciseMedia(exercise: exercise, borderRadius: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: theme.textTheme.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  entry.item.detail ?? '${entry.item.minutes} min',
                  style: theme.textTheme.caption
                      .copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.item.minutes} min · ~${entry.estimatedKcal(weightKg)} kcal',
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
