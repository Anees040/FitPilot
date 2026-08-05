import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/exercise_provider.dart';
import 'package:fitpilot/features/exercises/presentation/widgets/exercise_card.dart';

class MuscleDetailScreen extends ConsumerWidget {
  final String muscleId;
  final String? customTitle;
  final String? customImage;

  const MuscleDetailScreen({
    super.key, 
    required this.muscleId,
    this.customTitle,
    this.customImage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final exercisesAsync = ref.watch(hubMuscleExercisesProvider(muscleId));
    
    // Map muscleId to Title and Image
    String title = customTitle ?? (muscleId.substring(0, 1).toUpperCase() + muscleId.substring(1));
    String imagePath = customImage ?? 'assets/illustrations/${muscleId}_hero.png';
    // Fallback if image doesn't exist and custom not provided
    if (customImage == null && muscleId != 'chest' && muscleId != 'back' && muscleId != 'shoulders' && muscleId != 'arms' && muscleId != 'core' && muscleId != 'legs') {
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
              data: (targetExercises) {
                if (targetExercises.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(child: Text('No exercises found for $title.')),
                    ),
                  );
                }
                
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 200,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return ExerciseCard(exercise: targetExercises[index]);
                      },
                      childCount: targetExercises.length,
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
