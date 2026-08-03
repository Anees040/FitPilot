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
              backgroundColor: theme.colorScheme.surface,
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
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _CategoryTile(
                    title: 'Upper Body',
                    subtitle: 'Build strength and size',
                    color: theme.colorScheme.surfaceContainerHighest,
                    imagePath: 'assets/illustrations/upper_body_hero.png',
                    onTap: () => context.push('/workout-hub/category/upper_body'),
                  ),
                  const SizedBox(height: 16),
                  _CategoryTile(
                    title: 'Lower Body',
                    subtitle: 'Build power and endurance',
                    color: theme.colorScheme.surfaceContainerHighest,
                    imagePath: 'assets/illustrations/lower_body_hero.png',
                    onTap: () => context.push('/workout-hub/category/lower_body'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryTile(
                          title: 'Chest',
                          subtitle: 'Build a stronger chest',
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurface,
                          imagePath: 'assets/illustrations/chest_hero.png',
                          onTap: () => context.push('/workout-hub/muscle/chest'),
                          isSmall: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CategoryTile(
                          title: 'Back',
                          subtitle: 'Stronger back, better posture',
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurface,
                          imagePath: 'assets/illustrations/back_hero.png',
                          onTap: () => context.push('/workout-hub/muscle/back'),
                          isSmall: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryTile(
                          title: 'Shoulders',
                          subtitle: '3D shoulder development',
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurface,
                          imagePath: 'assets/illustrations/shoulders_hero.png',
                          onTap: () => context.push('/workout-hub/muscle/shoulders'),
                          isSmall: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CategoryTile(
                          title: 'Arms',
                          subtitle: 'Biceps, triceps and forearms',
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurface,
                          imagePath: 'assets/illustrations/arms_hero.png',
                          onTap: () => context.push('/workout-hub/muscle/arms'),
                          isSmall: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryTile(
                          title: 'Core & Abs',
                          subtitle: 'Stronger core, better performance',
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurface,
                          imagePath: 'assets/illustrations/core_hero.png',
                          onTap: () => context.push('/workout-hub/muscle/core'),
                          isSmall: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CategoryTile(
                          title: 'Legs',
                          subtitle: 'Powerful legs, better mobility',
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurface,
                          imagePath: 'assets/illustrations/legs_hero.png',
                          onTap: () => context.push('/workout-hub/muscle/legs'),
                          isSmall: true,
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => context.push('/workout-hub/all'),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View All Categories', style: theme.textTheme.bodyStrong.copyWith(color: Colors.white, fontSize: 16)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                        ],
                      ),
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
          colors: [theme.colorScheme.surface, theme.colorScheme.surface.withValues(alpha: 0.8), theme.colorScheme.surface.withValues(alpha: 0.0)],
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
  final bool isSmall;

  const _CategoryTile({
    required this.title,
    required this.subtitle,
    required this.color,
    this.textColor = Colors.white,
    required this.imagePath,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isSmall ? 140 : 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: color),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.shadow.withValues(alpha: 0.0),
                    theme.colorScheme.shadow.withValues(alpha: 0.8),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyStrong.copyWith(color: Colors.white, fontSize: isSmall ? 16 : 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.caption.copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
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
