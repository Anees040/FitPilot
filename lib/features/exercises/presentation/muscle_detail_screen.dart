import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/exercise_provider.dart';

class MuscleDetailScreen extends ConsumerWidget {
  final String muscleId;

  const MuscleDetailScreen({super.key, required this.muscleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final exercisesAsync = ref.watch(exerciseListProvider);
    
    // Map muscleId to Title and Image
    String title = muscleId.substring(0, 1).toUpperCase() + muscleId.substring(1);
    String imagePath = 'assets/illustrations/${muscleId}_hero.png';
    // Fallback if image doesn't exist
    if (muscleId != 'chest' && muscleId != 'back' && muscleId != 'shoulders' && muscleId != 'arms' && muscleId != 'core' && muscleId != 'legs') {
      imagePath = 'assets/illustrations/workout_hub_bg.png';
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(title),
            centerTitle: false,
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build a stronger and bigger $muscleId.',
                    style: theme.textTheme.body.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: ext.surfaceRaised,
                      image: DecorationImage(
                        image: AssetImage(imagePath),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          exercisesAsync.when(
            data: (allExercises) {
              // Filter exercises by primary muscle
              final targetExercises = allExercises.where((e) => e.primaryMuscles.contains(muscleId)).toList();
              
              if (targetExercises.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(child: Text('No exercises found for $title.')),
                  ),
                );
              }

              // Categorize them by equipment or type
              final barbellCount = targetExercises.where((e) => e.name.toLowerCase().contains('barbell') || e.equipment == 'barbell').length;
              final dumbbellCount = targetExercises.where((e) => e.name.toLowerCase().contains('dumbbell') || e.equipment == 'dumbbell').length;
              final machineCount = targetExercises.where((e) => e.name.toLowerCase().contains('machine') || e.equipment == 'machine').length;
              final bodyweightCount = targetExercises.where((e) => e.equipment == 'body_only' || e.equipment == null).length;
              final cableCount = targetExercises.where((e) => e.name.toLowerCase().contains('cable') || e.equipment == 'cable').length;

              final List<Map<String, dynamic>> subCategories = [
                {'title': 'All $title Exercises', 'count': targetExercises.length, 'color': ext.energy},
                if (barbellCount > 0) {'title': 'Barbell Exercises', 'count': barbellCount, 'color': theme.colorScheme.onSurface.withValues(alpha: 0.6)},
                if (dumbbellCount > 0) {'title': 'Dumbbell Exercises', 'count': dumbbellCount, 'color': theme.colorScheme.onSurface.withValues(alpha: 0.6)},
                if (machineCount > 0) {'title': 'Machine Exercises', 'count': machineCount, 'color': theme.colorScheme.onSurface.withValues(alpha: 0.6)},
                if (bodyweightCount > 0) {'title': 'Bodyweight Exercises', 'count': bodyweightCount, 'color': theme.colorScheme.onSurface.withValues(alpha: 0.6)},
                if (cableCount > 0) {'title': 'Cable Exercises', 'count': cableCount, 'color': theme.colorScheme.onSurface.withValues(alpha: 0.6)},
              ];

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final subCat = subCategories[index];
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(subCat['title'], style: theme.textTheme.bodyStrong),
                            trailing: Text(
                              '${subCat['count']} Exercises',
                              style: theme.textTheme.caption.copyWith(color: subCat['color'], fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              // We could route to a filtered list view in ExerciseLibraryScreen here
                              // For now, route to the general exercises list and set a search query or filter.
                              if (index == 0) {
                                ref.read(exerciseSearchQueryProvider.notifier).state = muscleId;
                              } else {
                                final keyword = subCat['title'].toString().split(' ')[0].toLowerCase();
                                ref.read(exerciseSearchQueryProvider.notifier).state = '$muscleId $keyword';
                              }
                              context.push('/exercises');
                            },
                          ),
                          if (index < subCategories.length - 1)
                            Divider(color: ext.hairline),
                        ],
                      );
                    },
                    childCount: subCategories.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Error: $e'))),
            ),
          ),
        ],
      ),
    );
  }
}
