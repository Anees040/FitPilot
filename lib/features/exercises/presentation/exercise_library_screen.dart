import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/select_chip.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/application/providers/exercise_provider.dart';
import 'package:fitpilot/features/exercises/presentation/widgets/exercise_card.dart';

class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exerciseListAsync = ref.watch(exerciseListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Exercises', style: theme.textTheme.h1),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppTextField(
                label: 'Search exercises...',
                onChanged: (val) {
                  ref.read(exerciseSearchQueryProvider.notifier).state = val;
                },
              ),
            ),

            // Category filter chips — G2.4: scrollable with fade
            _FadeScrollRow(
              child: _CategoryChips(),
            ),
            const SizedBox(height: 8),

            // Pace filter chips — G2.4: scrollable with fade
            _FadeScrollRow(
              child: _PaceChips(),
            ),
            const SizedBox(height: 12),

            // Results
            Expanded(
              child: exerciseListAsync.when(
                data: (exercises) {
                  if (exercises.isEmpty) {
                    return EmptyState(
                      message: 'No exercises match. Try removing a filter.',
                      buttonLabel: 'Clear filters',
                      illustration: 'empty_search',
                      onAction: () {
                        ref.read(exerciseCategoryFilterProvider.notifier).state = null;
                        ref.read(exercisePaceFilterProvider.notifier).state = null;
                        ref.read(exerciseSearchQueryProvider.notifier).state = '';
                      },
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${exercises.length} exercises',
                          style: theme.textTheme.caption,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            // G2.3: use mainAxisExtent so height is fixed regardless of width
                            mainAxisExtent: 200,
                          ),
                          itemCount: exercises.length,
                          itemBuilder: (context, index) {
                            return ExerciseCard(exercise: exercises[index]);
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: SkeletonList(count: 4),
                ),
                error: (e, st) => ErrorState(
                  reason: 'Failed to load exercises.\n$e',
                  onRetry: () => ref.invalidate(exerciseListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(exerciseCategoryFilterProvider);
    final categories = [
      (null, 'All'),
      ('gym', 'Gym'),
      ('indoor', 'Indoor'),
      ('outdoor', 'Outdoor'),
      ('calisthenics', 'Calisthenics'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((entry) {
          final (value, label) = entry;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SelectChip(
              label: label,
              isSelected: current == value,
              onSelected: () {
                ref.read(exerciseCategoryFilterProvider.notifier).state = value;
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PaceChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(exercisePaceFilterProvider);
    final paces = [
      (null, 'Any pace'),
      ('quick', 'Quick burn'),
      ('moderate', 'Moderate'),
      ('easy', 'Easy pace'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: paces.map((entry) {
          final (value, label) = entry;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SelectChip(
              label: label,
              isSelected: current == value,
              onSelected: () {
                ref.read(exercisePaceFilterProvider.notifier).state = value;
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Scrollable row with a trailing fade hint. G2.4.
class _FadeScrollRow extends StatelessWidget {
  final Widget child;
  const _FadeScrollRow({required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
        stops: [0.0, 0.85, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

