import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/exercise_provider.dart';
import 'package:fitpilot/features/exercises/presentation/widgets/exercise_card.dart';

/// Maps each category route ID → its hero image and display data.
const _categoryData = <String, Map<String, dynamic>>{
  'upper_body': {
    'title': 'Upper Body',
    'subtitle': 'Target your upper body muscles and build strength.',
    'imagePath': 'assets/illustrations/upper_body_hero.png',
    'muscles': [
      {'id': 'chest',     'title': 'Chest',     'subtitle': 'Build a stronger chest',        'image': 'assets/illustrations/chest_hero.png'},
      {'id': 'back',      'title': 'Back',      'subtitle': 'Stronger back, better posture', 'image': 'assets/illustrations/back_hero.png'},
      {'id': 'shoulders', 'title': 'Shoulders', 'subtitle': '3D shoulder development',       'image': 'assets/illustrations/shoulders_hero.png'},
      {'id': 'arms',      'title': 'Arms',      'subtitle': 'Biceps, triceps and forearms',  'image': 'assets/illustrations/arms_hero.png'},
    ],
  },
  'lower_body': {
    'title': 'Lower Body',
    'subtitle': 'Target your lower body muscles and build power.',
    'imagePath': 'assets/illustrations/lower_body_hero.png',
    'muscles': [
      {'id': 'legs',   'title': 'Legs',   'subtitle': 'Powerful legs, better mobility', 'image': 'assets/illustrations/legs_hero.png'},
      {'id': 'glutes', 'title': 'Glutes', 'subtitle': 'Stronger glutes and hips',       'image': 'assets/illustrations/legs_hero.png'},
    ],
  },
  // Discipline categories: no muscle sub-tiles, the exercise list is the content.
  'calisthenics': {
    'title': 'Calisthenics',
    'subtitle': 'Bodyweight strength — no equipment, train anywhere.',
    'imagePath': 'assets/illustrations/calisthenics_hero.png',
    'muscles': <Map<String, dynamic>>[],
  },
  'cardio': {
    'title': 'Cardio',
    'subtitle': 'Get your heart rate up and burn the surplus.',
    'imagePath': 'assets/illustrations/cardio_hero.png',
    'muscles': <Map<String, dynamic>>[],
  },
  'stretching': {
    'title': 'Stretching & Mobility',
    'subtitle': 'Loosen up, move better, recover faster.',
    'imagePath': 'assets/illustrations/stretching_hero.png',
    'muscles': <Map<String, dynamic>>[],
  },
  'home': {
    'title': 'Home Workouts',
    'subtitle': 'Everything you can do in a room, no gym needed.',
    'imagePath': 'assets/illustrations/recovery_hero.png',
    'muscles': <Map<String, dynamic>>[],
  },
  'machines': {
    'title': 'Machines',
    'subtitle': 'Guided movement — the easiest place to start.',
    'imagePath': 'assets/illustrations/equip_gym.png',
    'muscles': <Map<String, dynamic>>[],
  },
  'free_weights': {
    'title': 'Free Weights',
    'subtitle': 'Barbells and dumbbells for real strength.',
    'imagePath': 'assets/illustrations/powerlifting_hero.png',
    'muscles': <Map<String, dynamic>>[],
  },
  'outdoor': {
    'title': 'Outdoor',
    'subtitle': 'Run, cycle, hike — training outside the four walls.',
    'imagePath': 'assets/illustrations/athletic_hero.png',
    'muscles': <Map<String, dynamic>>[],
  },
};

class CategoryDetailScreen extends ConsumerWidget {
  final String categoryId;

  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final exercisesAsync = ref.watch(hubCategoryExercisesProvider(categoryId));

    final data = _categoryData[categoryId] ?? {
      'title': categoryId[0].toUpperCase() + categoryId.substring(1),
      'subtitle': 'Explore exercises in this category.',
      'imagePath': 'assets/illustrations/workout_hub_bg.png',
      'muscles': <Map<String, dynamic>>[],
    };

    final title = data['title'] as String;
    final subtitle = data['subtitle'] as String;
    final imagePath = data['imagePath'] as String;
    final muscles = data['muscles'] as List<Map<String, dynamic>>;

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
                    subtitle,
                    style: theme.textTheme.body.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Hero image matching the list item
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: ext.surfaceRaised,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  theme.colorScheme.shadow.withValues(alpha: 0.0),
                                  theme.colorScheme.shadow.withValues(alpha: 0.55),
                                ],
                                stops: const [0.4, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            bottom: 20,
                            child: Text(
                              title,
                              style: theme.textTheme.display.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (muscles.isNotEmpty) ...[
                    Text('Target Areas', style: theme.textTheme.bodyStrong),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          if (muscles.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final muscle = muscles[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: GestureDetector(
                        onTap: () => context.push(
                          '/workout-hub/muscle/${muscle['id']}',
                          extra: {'title': muscle['title'], 'image': muscle['image']},
                        ),
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: ext.surfaceRaised,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ext.hairline),
                          ),
                          child: Row(
                            children: [
                              // Left thumbnail using the same image from list
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                                child: SizedBox(
                                  width: 80,
                                  height: 72,
                                  child: Image.asset(
                                    muscle['image'] as String,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: ext.surfaceRaised,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      muscle['title'] as String,
                                      style: theme.textTheme.bodyStrong.copyWith(fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      muscle['subtitle'] as String,
                                      style: theme.textTheme.caption.copyWith(
                                        color: ext.textDisabled,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 22,
                                  color: ext.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: muscles.length,
                ),
              ),
            ),
          
          exercisesAsync.when(
            data: (allExercises) {
              if (allExercises.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              
              return SliverPadding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 32.0),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text('All $title Exercises', style: theme.textTheme.bodyStrong),
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 200,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return ExerciseCard(exercise: allExercises[index]);
                        },
                        childCount: allExercises.length,
                      ),
                    ),
                  ],
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
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
