import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class WorkoutHubScreen extends ConsumerWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('Workout Hub'),
              centerTitle: false,
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: _HeroSection(),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildListDelegate([
                  _CategoryTile(
                    title: 'Upper Body',
                    subtitle: 'Build strength and size',
                    color: Colors.deepOrange.shade800,
                    imagePath: 'assets/illustrations/upper_body_hero.png',
                    onTap: () => context.push('/workout-hub/category/upper_body'),
                  ),
                  _CategoryTile(
                    title: 'Lower Body',
                    subtitle: 'Build power and endurance',
                    color: Colors.green.shade800,
                    imagePath: 'assets/illustrations/lower_body_hero.png',
                    onTap: () => context.push('/workout-hub/category/lower_body'),
                  ),
                  _CategoryTile(
                    title: 'Chest',
                    subtitle: 'Build a stronger chest',
                    color: Colors.orange.shade100,
                    textColor: Colors.black87,
                    imagePath: 'assets/illustrations/chest_hero.png',
                    onTap: () => context.push('/workout-hub/muscle/chest'),
                  ),
                  _CategoryTile(
                    title: 'Back',
                    subtitle: 'Stronger back, better posture',
                    color: Colors.blue.shade100,
                    textColor: Colors.black87,
                    imagePath: 'assets/illustrations/back_hero.png',
                    onTap: () => context.push('/workout-hub/muscle/back'),
                  ),
                  _CategoryTile(
                    title: 'Shoulders',
                    subtitle: '3D shoulder development',
                    color: Colors.purple.shade100,
                    textColor: Colors.black87,
                    imagePath: 'assets/illustrations/shoulders_hero.png',
                    onTap: () => context.push('/workout-hub/muscle/shoulders'),
                  ),
                  _CategoryTile(
                    title: 'Arms',
                    subtitle: 'Biceps, triceps and forearms',
                    color: Colors.orangeAccent.shade100,
                    textColor: Colors.black87,
                    imagePath: 'assets/illustrations/arms_hero.png',
                    onTap: () => context.push('/workout-hub/muscle/arms'),
                  ),
                  _CategoryTile(
                    title: 'Core & Abs',
                    subtitle: 'Stronger core, better performance',
                    color: Colors.green.shade100,
                    textColor: Colors.black87,
                    imagePath: 'assets/illustrations/core_hero.png',
                    onTap: () => context.push('/workout-hub/muscle/core'),
                  ),
                  _CategoryTile(
                    title: 'Legs',
                    subtitle: 'Powerful legs, better mobility',
                    color: Colors.pink.shade100,
                    textColor: Colors.black87,
                    imagePath: 'assets/illustrations/legs_hero.png',
                    onTap: () => context.push('/workout-hub/muscle/legs'),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/workout-hub/all'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View All', style: theme.textTheme.bodyStrong.copyWith(color: theme.colorScheme.onSurface)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurface),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.surface, theme.colorScheme.surface.withValues(alpha: 0.8), Colors.grey.shade200.withValues(alpha: 0.5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: 0,
            child: Image.asset(
              'assets/illustrations/actor_standing.png',
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          Positioned(
            left: 20,
            top: 20,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workout Hub',
                    style: theme.textTheme.display.copyWith(fontSize: 32, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Find the perfect workout for your goal.',
                    style: theme.textTheme.body.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Color textColor;
  final String imagePath;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.title,
    required this.subtitle,
    required this.color,
    this.textColor = Colors.white,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -10,
              child: Image.asset(
                imagePath,
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyStrong.copyWith(color: textColor, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.caption.copyWith(color: textColor.withValues(alpha: 0.8), fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
