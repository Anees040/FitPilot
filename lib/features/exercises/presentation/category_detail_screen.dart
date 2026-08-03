import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class CategoryDetailScreen extends ConsumerWidget {
  final String categoryId;

  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    // Map category to data
    String title = 'Category';
    String subtitle = '';
    String imagePath = 'assets/illustrations/workout_hub_bg.png';
    List<Map<String, dynamic>> muscles = [];

    if (categoryId == 'upper_body') {
      title = 'Upper Body';
      subtitle = 'Target your upper body muscles and build strength.';
      imagePath = 'assets/illustrations/upper_body_hero.png';
      muscles = [
        {'id': 'chest', 'title': 'Chest', 'subtitle': 'Build a stronger chest', 'image': 'assets/illustrations/chest_hero.png'},
        {'id': 'back', 'title': 'Back', 'subtitle': 'Stronger back, better posture', 'image': 'assets/illustrations/back_hero.png'},
        {'id': 'shoulders', 'title': 'Shoulders', 'subtitle': '3D shoulder development', 'image': 'assets/illustrations/shoulders_hero.png'},
        {'id': 'arms', 'title': 'Arms', 'subtitle': 'Biceps, triceps and forearms', 'image': 'assets/illustrations/arms_hero.png'},
      ];
    } else if (categoryId == 'lower_body') {
      title = 'Lower Body';
      subtitle = 'Target your lower body muscles and build power.';
      imagePath = 'assets/illustrations/lower_body_hero.png';
      muscles = [
        {'id': 'legs', 'title': 'Legs', 'subtitle': 'Powerful legs, better mobility', 'image': 'assets/illustrations/legs_hero.png'},
        {'id': 'glutes', 'title': 'Glutes', 'subtitle': 'Stronger glutes and hips', 'image': 'assets/illustrations/legs_hero.png'},
        {'id': 'calves', 'title': 'Calves', 'subtitle': 'Lower leg strength', 'image': 'assets/illustrations/legs_hero.png'},
      ];
    } else {
      title = categoryId.toUpperCase();
      muscles = [
        {'id': 'core', 'title': 'Core', 'subtitle': 'Build a solid core', 'image': 'assets/illustrations/core_hero.png'}
      ];
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
                    subtitle,
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
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final muscle = muscles[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () => context.push('/workout-hub/muscle/${muscle['id']}'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ext.surfaceRaised,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ext.hairline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: ext.surfaceRaised,
                                image: DecorationImage(
                                  image: AssetImage(muscle['image']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(muscle['title'], style: theme.textTheme.bodyStrong),
                                  const SizedBox(height: 4),
                                  Text(muscle['subtitle'], style: theme.textTheme.caption),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
        ],
      ),
    );
  }
}
