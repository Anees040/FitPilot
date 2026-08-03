import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

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
      {'id': 'calves', 'title': 'Calves', 'subtitle': 'Lower leg strength',             'image': 'assets/illustrations/legs_hero.png'},
    ],
  },
  'cardio': {
    'title': 'Cardio',
    'subtitle': 'Burn fat and boost cardiovascular endurance.',
    'imagePath': 'assets/illustrations/cardio_hero.png',
    'muscles': [
      {'id': 'running',  'title': 'Running',   'subtitle': 'Build stamina and burn fat',   'image': 'assets/illustrations/cardio_hero.png'},
      {'id': 'cycling',  'title': 'Cycling',   'subtitle': 'Low-impact endurance training','image': 'assets/illustrations/cardio_hero.png'},
      {'id': 'rowing',   'title': 'Rowing',    'subtitle': 'Full-body cardio workout',     'image': 'assets/illustrations/cardio_hero.png'},
    ],
  },
  'calisthenics': {
    'title': 'Calisthenics',
    'subtitle': 'Master your bodyweight, no equipment needed.',
    'imagePath': 'assets/illustrations/calisthenics_hero.png',
    'muscles': [
      {'id': 'chest',     'title': 'Push',   'subtitle': 'Push-ups, dips and more',      'image': 'assets/illustrations/calisthenics_hero.png'},
      {'id': 'back',      'title': 'Pull',   'subtitle': 'Pull-ups, rows and more',      'image': 'assets/illustrations/calisthenics_hero.png'},
      {'id': 'core',      'title': 'Core',   'subtitle': 'Planks, L-sits and more',      'image': 'assets/illustrations/core_hero.png'},
      {'id': 'legs',      'title': 'Legs',   'subtitle': 'Squats, lunges and jumps',     'image': 'assets/illustrations/legs_hero.png'},
    ],
  },
  'powerlifting': {
    'title': 'Powerlifting',
    'subtitle': 'Squat, bench, deadlift — the big three.',
    'imagePath': 'assets/illustrations/powerlifting_hero.png',
    'muscles': [
      {'id': 'legs',  'title': 'Squat',     'subtitle': 'Build leg and glute power', 'image': 'assets/illustrations/lower_body_hero.png'},
      {'id': 'chest', 'title': 'Bench',     'subtitle': 'Upper body pushing power',  'image': 'assets/illustrations/chest_hero.png'},
      {'id': 'back',  'title': 'Deadlift',  'subtitle': 'Total body posterior chain', 'image': 'assets/illustrations/powerlifting_hero.png'},
    ],
  },
  'gymnastics': {
    'title': 'Gymnastics',
    'subtitle': 'Strength, balance and flexibility combined.',
    'imagePath': 'assets/illustrations/gymnastics_hero.png',
    'muscles': [
      {'id': 'shoulders', 'title': 'Handstands',   'subtitle': 'Overhead balance and strength', 'image': 'assets/illustrations/gymnastics_hero.png'},
      {'id': 'core',      'title': 'Hollow Body',  'subtitle': 'Core tension and control',      'image': 'assets/illustrations/core_hero.png'},
      {'id': 'arms',      'title': 'Ring Work',    'subtitle': 'Upper body stability',           'image': 'assets/illustrations/gymnastics_hero.png'},
    ],
  },
  'mobility': {
    'title': 'Stretching & Mobility',
    'subtitle': 'Prevent injury and improve your range of motion.',
    'imagePath': 'assets/illustrations/stretching_hero.png',
    'muscles': [
      {'id': 'legs',      'title': 'Lower Body', 'subtitle': 'Hip flexors, hamstrings, calves', 'image': 'assets/illustrations/stretching_hero.png'},
      {'id': 'shoulders', 'title': 'Upper Body', 'subtitle': 'Shoulders, chest, lats',          'image': 'assets/illustrations/stretching_hero.png'},
      {'id': 'core',      'title': 'Spine',      'subtitle': 'Thoracic and lumbar mobility',    'image': 'assets/illustrations/stretching_hero.png'},
    ],
  },
  'hiit': {
    'title': 'HIIT',
    'subtitle': 'Maximum calorie burn in minimum time.',
    'imagePath': 'assets/illustrations/hiit_hero.png',
    'muscles': [
      {'id': 'core', 'title': 'Full Body HIIT', 'subtitle': 'Burpees, mountain climbers', 'image': 'assets/illustrations/hiit_hero.png'},
      {'id': 'legs', 'title': 'Lower HIIT',     'subtitle': 'Jump squats, lunge jumps',   'image': 'assets/illustrations/hiit_hero.png'},
      {'id': 'arms', 'title': 'Upper HIIT',     'subtitle': 'Push-up variations, punches','image': 'assets/illustrations/hiit_hero.png'},
    ],
  },
  'athletic': {
    'title': 'Athletic Performance',
    'subtitle': 'Build speed, power and agility like an athlete.',
    'imagePath': 'assets/illustrations/athletic_hero.png',
    'muscles': [
      {'id': 'legs',  'title': 'Speed & Power',   'subtitle': 'Sprints, box jumps, bounds',  'image': 'assets/illustrations/athletic_hero.png'},
      {'id': 'core',  'title': 'Agility',          'subtitle': 'Ladder drills, lateral work', 'image': 'assets/illustrations/athletic_hero.png'},
      {'id': 'chest', 'title': 'Explosive Power',  'subtitle': 'Med ball, plyometric push',   'image': 'assets/illustrations/athletic_hero.png'},
    ],
  },
  'recovery': {
    'title': 'Recovery',
    'subtitle': 'Rest smart and recover faster between sessions.',
    'imagePath': 'assets/illustrations/recovery_hero.png',
    'muscles': [
      {'id': 'core', 'title': 'Foam Rolling',   'subtitle': 'Myofascial release',          'image': 'assets/illustrations/recovery_hero.png'},
      {'id': 'legs', 'title': 'Active Recovery','subtitle': 'Light movement and stretches', 'image': 'assets/illustrations/stretching_hero.png'},
      {'id': 'core', 'title': 'Breathing',      'subtitle': 'Diaphragmatic breathing work', 'image': 'assets/illustrations/recovery_hero.png'},
    ],
  },
  'ppl': {
    'title': 'Push Pull Legs',
    'subtitle': 'The classic 3-day split for balanced muscle growth.',
    'imagePath': 'assets/illustrations/arms_hero.png',
    'muscles': [
      {'id': 'chest',     'title': 'Push Day', 'subtitle': 'Chest, shoulders, triceps', 'image': 'assets/illustrations/chest_hero.png'},
      {'id': 'back',      'title': 'Pull Day', 'subtitle': 'Back, biceps, rear delts',  'image': 'assets/illustrations/back_hero.png'},
      {'id': 'legs',      'title': 'Leg Day',  'subtitle': 'Quads, hamstrings, glutes', 'image': 'assets/illustrations/legs_hero.png'},
    ],
  },
};

class CategoryDetailScreen extends ConsumerWidget {
  final String categoryId;

  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

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
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
