import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class AllCategoriesScreen extends ConsumerWidget {
  const AllCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    final List<Map<String, dynamic>> categories = [
      {'title': 'Upper Body', 'icon': Icons.accessibility_new, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/upper_body'},
      {'title': 'Lower Body', 'icon': Icons.directions_run, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/lower_body'},
      {'title': 'Push Pull Legs', 'icon': Icons.fitness_center, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/ppl'},
      {'title': 'Cardio', 'icon': Icons.directions_bike, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/cardio'},
      {'title': 'Calisthenics', 'icon': Icons.sports_gymnastics, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/calisthenics'},
      {'title': 'Powerlifting', 'icon': Icons.sports_martial_arts, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/powerlifting'},
      {'title': 'Gymnastics', 'icon': Icons.self_improvement, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/gymnastics'},
      {'title': 'Stretching & Mobility', 'icon': Icons.accessibility, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/mobility'},
      {'title': 'HIIT', 'icon': Icons.whatshot, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/hiit'},
      {'title': 'Athletic Performance', 'icon': Icons.sports_basketball, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/athletic'},
      {'title': 'Recovery', 'icon': Icons.spa, 'color': theme.colorScheme.surfaceContainerHighest, 'route': '/workout-hub/category/recovery'},
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Workout Categories'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a category to continue',
                style: theme.textTheme.caption,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _InteractiveCategoryCard(
                      title: cat['title'],
                      icon: cat['icon'],
                      color: cat['color'],
                      onTap: () => context.push(cat['route']),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveCategoryCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InteractiveCategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_InteractiveCategoryCard> createState() => _InteractiveCategoryCardState();
}

class _InteractiveCategoryCardState extends State<_InteractiveCategoryCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: theme.colorScheme.primary, size: 40),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyStrong.copyWith(fontSize: 16, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
