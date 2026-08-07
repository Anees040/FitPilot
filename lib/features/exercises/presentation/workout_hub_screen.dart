import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/utils/require_online.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/exercise_provider.dart';

class WorkoutHubScreen extends ConsumerWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
    
    if (exercises.isEmpty && ref.watch(seedStatusProvider) != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Hub')),
        body: SafeArea(
          child: ErrorState(
            reason: 'Exercise library didn\'t load.\n${ref.watch(seedStatusProvider)}',
            onRetry: () => ref.invalidate(databaseProvider),
          ),
        ),
      );
    }

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
            const SliverToBoxAdapter(
              child: _HeroSection(),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverToBoxAdapter(child: _MachineScannerCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _CategoryTile(
                    title: 'Training Programs',
                    subtitle: 'Structured multi-week plans with rest days',
                    color: theme.colorScheme.surfaceContainerHighest,
                    imagePath: 'assets/illustrations/athletic_hero.png',
                    onTap: () => context.go('/programs'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryTile(
                          title: 'Upper Body',
                          subtitle: 'Build strength and size',
                          color: theme.colorScheme.surfaceContainerHighest,
                          imagePath: 'assets/illustrations/upper_body_hero.png',
                          onTap: () => context.push('/workout-hub/category/upper_body'),
                          isSmall: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CategoryTile(
                          title: 'Lower Body',
                          subtitle: 'Build power and endurance',
                          color: theme.colorScheme.surfaceContainerHighest,
                          imagePath: 'assets/illustrations/lower_body_hero.png',
                          onTap: () => context.push('/workout-hub/category/lower_body'),
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
                          title: 'Chest',
                          subtitle: 'Build a stronger chest',
                          color: theme.colorScheme.surfaceContainerHighest,
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
                        color: theme.colorScheme.primary,
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
                          Text(
                            'View All Categories',
                            style: theme.textTheme.bodyStrong.copyWith(color: Colors.white, fontSize: 16),
                          ),
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

// ─────────────────────────────────────────────
// Machine Scanner entry
// ─────────────────────────────────────────────

/// Prominent entry to the AI machine scanner.
///
/// The tap is gated on connectivity here so an offline user gets the standard
/// explanation immediately, rather than discovering the problem a screen later.
class _MachineScannerCard extends ConsumerWidget {
  const _MachineScannerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      variant: AppCardVariant.hero,
      padding: const EdgeInsets.all(16),
      onTap: () {
        if (!requireOnline(context, ref, feature: 'Machine Scanner')) return;
        context.push('/machine-scanner');
      },
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.camera_alt_rounded,
              color: theme.colorScheme.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Machine Scanner',
                        style: theme.textTheme.h2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: ext.energy.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'AI',
                        style: theme.textTheme.overline.copyWith(
                          color: ext.energy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Point your camera at any gym machine to learn it',
                  style: theme.textTheme.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Animated Hero
// ─────────────────────────────────────────────
class _HeroSection extends StatefulWidget {
  const _HeroSection();

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 0.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.28 + _pulseAnimation.value,
                  ),
                  blurRadius: 18 + (_pulseAnimation.value * 12),
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Real gym photo background with slight zoom pulse
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseAnimation.value * 0.3),
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/illustrations/workout_hub_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              // Dark gradient overlay — left to right so text on left is readable
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      theme.colorScheme.shadow.withValues(alpha: 0.82),
                      theme.colorScheme.shadow.withValues(alpha: 0.35),
                      theme.colorScheme.shadow.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              // Text + chips on left
              Positioned(
                left: 20,
                top: 16,
                bottom: 14,
                right: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Primary badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'WORKOUT HUB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        'Train Smart.',
                        style: Theme.of(context).textTheme.display.copyWith(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Workouts for every goal.',
                      style: Theme.of(context).textTheme.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        _StatChip(label: '11 Categories'),
                        SizedBox(width: 6),
                        _StatChip(label: '80+ Exercises'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Category Tile
// ─────────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final String imagePath;
  final VoidCallback onTap;
  final bool isSmall;

  const _CategoryTile({
    required this.title,
    required this.subtitle,
    required this.color,
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
          color: theme.colorScheme.surface, // Or use the passed color
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
            Opacity(
              opacity: 0.75,
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: color),
              ),
            ),
            // Soft gradient overlay so text is crisp and background artwork pops
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22000000),
                    Color(0xAA000000),
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyStrong.copyWith(
                      color: Colors.white,
                      fontSize: isSmall ? 15 : 22,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 11,
                    ),
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
