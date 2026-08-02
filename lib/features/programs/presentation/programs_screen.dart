import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/states.dart';

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final programsAsync = ref.watch(programsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programs'),
        backgroundColor: Colors.transparent,
      ),
      body: programsAsync.when(
        data: (programs) {
          if (programs.isEmpty) {
            return EmptyState(
              illustration: 'empty_programs',
              message: 'Check back later for curated plans.',
              buttonLabel: 'Refresh',
              onAction: () => ref.invalidate(programsProvider),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final prog = programs[index];
              return AppCard(
                variant: AppCardVariant.raised,
                padding: const EdgeInsets.all(16),
                onTap: () => context.push('/programs/detail', extra: prog),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          prog.program.icon,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prog.program.name,
                            style: theme.textTheme.bodyStrong,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${prog.totalWeeks} weeks • ${prog.sessions.length} sessions',
                            style: theme.textTheme.caption,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: ext.textDisabled),
                  ],
                ),
              );
            },
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
