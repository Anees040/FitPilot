import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/program.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/states.dart';

// Simple provider to fetch an exercise by ID
final exerciseByIdProvider = FutureProvider.family<Exercise, String>((ref, id) async {
  final db = await ref.watch(databaseProvider.future);
  final rows = await db.query('exercises', where: 'id = ?', whereArgs: [id]);
  if (rows.isEmpty) throw Exception('Exercise not found');
  final map = rows.first;
  
  // Note: we don't fully decode muscles here because we only need basic details and MET.
  // We'll create a minimal Exercise object.
  return Exercise(
    id: map['id'] as String,
    name: map['name'] as String,
    category: ExerciseCategory.values.byName(map['category'] as String),
    subcategory: map['subcategory'] as String?,
    met: (map['met'] as num).toDouble(),
    equipment: map['equipment'] as String?,
    primaryMuscles: const [],
    secondaryMuscles: const [],
    difficulty: (map['difficulty'] as num).toInt(),
    paceTier: map['pace_tier'] as String,
    steps: const [],
    mistakes: const [],
    mediaAsset: map['media_asset'] as String?,
    videoUrl: map['video_url'] as String?,
  );
});

class SessionDetailScreen extends ConsumerWidget {
  final ProgramSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final exerciseAsync = ref.watch(exerciseByIdProvider(session.exerciseId));
    final profile = ref.watch(profileProvider).valueOrNull;
    final weightKg = profile?.weightKg ?? 70.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Week ${session.weekNumber}, Day ${session.dayNumber}'),
        backgroundColor: Colors.transparent,
      ),
      body: exerciseAsync.when(
        data: (exercise) {
          final estKcal = (exercise.met * weightKg * (session.minutes / 60)).round();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name, style: theme.textTheme.h1),
                      const SizedBox(height: 8),
                      Text('${session.minutes} minutes', style: theme.textTheme.bodyStrong.copyWith(color: theme.colorScheme.primary)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ext.energy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ext.energy.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estimated burn', style: theme.textTheme.body),
                            Text('~$estKcal kcal', style: theme.textTheme.h2.copyWith(color: ext.energy)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Intensity (MET): ${exercise.met}', style: theme.textTheme.body),
                      if (exercise.equipment != null) ...[
                        const SizedBox(height: 8),
                        Text('Equipment: ${exercise.equipmentLabel}', style: theme.textTheme.body),
                      ]
                    ],
                  ),
                ),
                PrimaryButton(
                  label: 'Mark Done',
                  onPressed: () async {
                    await ref.read(programsControllerProvider).markSessionDone(session, estKcal);
                    if (context.mounted) {
                      context.pop();
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(reason: e.toString(), onRetry: () => ref.invalidate(exerciseByIdProvider(session.exerciseId))),
      ),
    );
  }
}
