import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/data/repositories/program_repository.dart';
import 'package:fitpilot/domain/entities/program.dart';
import 'package:fitpilot/features/programs/presentation/widgets/program_progress_bar.dart';

class ProgramDetailScreen extends ConsumerWidget {
  final String programId;

  const ProgramDetailScreen({super.key, required this.programId});

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
          reason: 'Failed to load this program.',
          onRetry: () => ref.invalidate(programsProvider),
        ),
      ),
      data: (programs) {
        ProgramWithSessions? program;
        for (final p in programs) {
          if (p.program.id == programId) program = p;
        }
        if (program == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: ErrorState(
              reason: 'That program is no longer available.',
              onRetry: () => context.pop(),
            ),
          );
        }
        return _ProgramDetailBody(program: program);
      },
    );
  }
}

class _ProgramDetailBody extends ConsumerWidget {
  final ProgramWithSessions program;

  const _ProgramDetailBody({required this.program});

  Future<void> _enroll(BuildContext context, WidgetRef ref) async {
    final active = ref.read(activeProgramProvider);
    final controller = ref.read(programsControllerProvider);
    final meta = program.program;

    if (active != null && active.program.id != meta.id) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Switch programs?'),
          content: Text(
            'Your progress in ${active.program.name} will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await controller.switchTo(meta.id);
    } else {
      await controller.enroll(meta.id);
    }

    if (!context.mounted) return;
    AppSnackbar.success(context, 'Started ${meta.name} — Day 1 is ready');
  }

  Future<void> _abandon(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this program?'),
        content: Text(
          'Your progress in ${program.program.name} will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(programsControllerProvider).abandon();
    if (!context.mounted) return;
    AppSnackbar.success(context, 'Left ${program.program.name}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final meta = program.program;

    final active = ref.watch(activeProgramProvider);
    final isEnrolled = active?.program.id == meta.id;
    final profile = ref.watch(profileProvider).valueOrNull;
    final currentDay = isEnrolled ? (profile?.activeProgramDay ?? 1) : null;
    final progress =
        ref.watch(programProgressProvider(meta.id)).valueOrNull ??
            const ProgramProgress();

    return Scaffold(
      appBar: AppBar(
        title: Text(meta.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.transparent,
        actions: [
          if (isEnrolled)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'abandon') _abandon(context, ref);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'abandon',
                  child: Text('Leave program'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          if (meta.heroImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.asset(
                  meta.heroImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      Container(color: ext.surfaceRaised),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(meta.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(child: Text(meta.name, style: theme.textTheme.h1)),
            ],
          ),
          const SizedBox(height: 10),
          Text(meta.goal, style: theme.textTheme.body),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ProgramMetaChip(
                label: '${program.totalDays} days',
                icon: Icons.event_outlined,
              ),
              ProgramMetaChip(
                label: '${program.workoutDays} workouts',
                icon: Icons.fitness_center,
              ),
              if (program.restDays > 0)
                ProgramMetaChip(
                  label: '${program.restDays} rest days',
                  icon: Icons.self_improvement,
                ),
              ProgramMetaChip(
                label: meta.level.label,
                icon: Icons.signal_cellular_alt,
              ),
              ProgramMetaChip(
                label: meta.equipment.label,
                icon: Icons.backpack_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (progress.completedCount > 0) ...[
            ProgramProgressBar(
              fraction: progress.fractionOf(program.totalDays),
              height: 8,
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.completedCount} of ${program.totalDays} days done · '
              '${progress.totalKcal} kcal burned',
              style: theme.textTheme.caption,
            ),
            const SizedBox(height: 20),
          ],
          if (isEnrolled)
            PrimaryButton(
              label: currentDay == null
                  ? 'Continue'
                  : 'Go to Day $currentDay',
              onPressed: () {
                final session = program.sessionForDay(currentDay ?? 1);
                if (session == null) return;
                context.push(
                  '/programs/${meta.id}/session/${session.id}',
                );
              },
            )
          else
            PrimaryButton(
              label: active == null ? 'Start Program' : 'Switch to this program',
              onPressed: () => _enroll(context, ref),
            ),
          const SizedBox(height: 24),
          Text('THE PLAN', style: theme.textTheme.overline),
          const SizedBox(height: 12),
          ...List.generate(program.totalWeeks, (index) {
            final week = index + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WeekCard(
                programId: meta.id,
                week: week,
                sessions: program.getSessionsForWeek(week),
                completed: progress.completedSessionIds,
                currentDay: currentDay,
                initiallyExpanded: currentDay == null
                    ? index == 0
                    : program.getSessionsForWeek(week).any(
                        (s) => s.dayNumber == currentDay,
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _WeekCard extends StatefulWidget {
  final String programId;
  final int week;
  final List<ProgramSession> sessions;
  final Set<String> completed;
  final int? currentDay;
  final bool initiallyExpanded;

  const _WeekCard({
    required this.programId,
    required this.week,
    required this.sessions,
    required this.completed,
    required this.currentDay,
    required this.initiallyExpanded,
  });

  @override
  State<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<_WeekCard> {
  late bool _isExpanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final doneInWeek =
        widget.sessions.where((s) => widget.completed.contains(s.id)).length;

    return AppCard(
      variant: AppCardVariant.standard,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Week ${widget.week}',
                          style: theme.textTheme.bodyStrong,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$doneInWeek / ${widget.sessions.length} days done',
                          style: theme.textTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: ext.textDisabled,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: ext.hairline),
            ...widget.sessions.map((session) {
              final isDone = widget.completed.contains(session.id);
              final isCurrent = session.dayNumber == widget.currentDay;

              return ListTile(
                onTap: () => context.push(
                  '/programs/${widget.programId}/session/${session.id}',
                ),
                leading: Icon(
                  isDone
                      ? Icons.check_circle
                      : session.isRest
                          ? Icons.self_improvement
                          : Icons.radio_button_unchecked,
                  color: isDone
                      ? ext.success
                      : isCurrent
                          ? theme.colorScheme.primary
                          : ext.textDisabled,
                ),
                title: Text(
                  'Day ${session.dayNumber} · ${session.displayTitle}',
                  style: isCurrent
                      ? theme.textTheme.bodyStrong
                          .copyWith(color: theme.colorScheme.primary)
                      : theme.textTheme.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  session.isRest
                      ? 'Rest & recover'
                      : '${session.totalMinutes} min · '
                          '${session.items.length} exercises',
                  style: theme.textTheme.caption,
                ),
                trailing: Icon(Icons.chevron_right, color: ext.textDisabled),
              );
            }),
          ],
        ],
      ),
    );
  }
}
