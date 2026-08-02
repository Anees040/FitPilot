import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/program.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_card.dart';

class ProgramDetailScreen extends ConsumerWidget {
  final ProgramWithSessions program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    final activeProgram = ref.watch(activeProgramProvider);
    final isEnrolled = activeProgram?.program.id == program.program.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Details'),
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        program.program.icon,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    program.program.name,
                    style: theme.textTheme.h1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    program.program.goal,
                    style: theme.textTheme.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (isEnrolled)
                    PrimaryButton(
                      label: 'Leave Program',
                      onPressed: () {
                        ref.read(programsControllerProvider).leaveProgram();
                        context.pop();
                      },
                    )
                  else
                    PrimaryButton(
                      label: 'Start Program',
                      onPressed: () {
                        ref.read(programsControllerProvider).enroll(program.program.id);
                        context.pop();
                      },
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final week = index + 1;
                  final sessions = program.getSessionsForWeek(week);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      variant: AppCardVariant.standard,
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          title: Text('Week $week', style: theme.textTheme.bodyStrong),
                          subtitle: Text('${sessions.length} sessions', style: theme.textTheme.caption),
                          children: sessions.map((s) {
                            return ListTile(
                              title: Text('Day ${s.dayNumber}'),
                              subtitle: Text('${s.minutes} min'),
                              trailing: Icon(Icons.fitness_center, color: ext.textDisabled),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
                childCount: program.totalWeeks,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}
