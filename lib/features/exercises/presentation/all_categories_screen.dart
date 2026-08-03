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
      {'title': 'Upper Body', 'icon': Icons.accessibility_new, 'color': Colors.deepOrange.shade100, 'route': '/workout-hub/category/upper_body'},
      {'title': 'Lower Body', 'icon': Icons.directions_run, 'color': Colors.green.shade100, 'route': '/workout-hub/category/lower_body'},
      {'title': 'Push Pull Legs', 'icon': Icons.fitness_center, 'color': Colors.purple.shade100, 'route': '/workout-hub/category/ppl'},
      {'title': 'Cardio', 'icon': Icons.directions_bike, 'color': Colors.blue.shade100, 'route': '/workout-hub/category/cardio'},
      {'title': 'Calisthenics', 'icon': Icons.sports_gymnastics, 'color': Colors.orangeAccent.shade100, 'route': '/workout-hub/category/calisthenics'},
      {'title': 'Powerlifting', 'icon': Icons.sports_martial_arts, 'color': Colors.red.shade100, 'route': '/workout-hub/category/powerlifting'},
      {'title': 'Gymnastics', 'icon': Icons.self_improvement, 'color': Colors.teal.shade100, 'route': '/workout-hub/category/gymnastics'},
      {'title': 'Stretching & Mobility', 'icon': Icons.accessibility, 'color': Colors.cyan.shade100, 'route': '/workout-hub/category/mobility'},
      {'title': 'HIIT', 'icon': Icons.whatshot, 'color': Colors.pink.shade100, 'route': '/workout-hub/category/hiit'},
      {'title': 'Athletic Performance', 'icon': Icons.sports_basketball, 'color': Colors.indigo.shade100, 'route': '/workout-hub/category/athletic'},
      {'title': 'Recovery', 'icon': Icons.spa, 'color': Colors.lightGreen.shade100, 'route': '/workout-hub/category/recovery'},
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.color.withValues(alpha: 0.8), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(widget.icon, color: widget.color.withValues(alpha: 1.0), size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.bodyStrong.copyWith(fontSize: 18),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
