import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/protein_guide_provider.dart';
import 'package:fitpilot/application/providers/protein_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/features/log/presentation/manual_entry_sheet.dart';
import 'package:fitpilot/features/log/presentation/widgets/protein_info_sheet.dart';

/// Cheap protein from local food, offline.
///
/// The premise: most users cannot afford whey powder, and telling them to buy
/// it is useless advice. Everything here is daal, chana, eggs and dahi, with
/// honest numbers — dry weights marked, calorie-dense items flagged.
class ProteinGuideScreen extends ConsumerWidget {
  const ProteinGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final guideAsync = ref.watch(proteinGuideProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Protein on a budget'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: guideAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonList(count: 5),
          ),
          error: (e, _) => ErrorState(
            reason: "Couldn't load the guide.",
            onRetry: () => ref.invalidate(proteinGuideProvider),
          ),
          data: (foods) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const _HeaderCard(),
              const SizedBox(height: 20),
              for (final tier in const [1, 2, 3]) ...[
                _TierHeading(tier: tier),
                const SizedBox(height: 10),
                for (final food in foods.where((f) => f.tier == tier))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FoodTile(food: food),
                  ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 8),
              const _HowItWorks(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final protein = ref.watch(proteinTodayProvider);

    return AppCard(
      variant: AppCardVariant.hero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Protein without powder', style: theme.textTheme.h1),
              ),
              IconButton(
                tooltip: 'How much protein?',
                icon: Icon(Icons.info_outline, size: 20, color: ext.textDisabled),
                onPressed: () => ProteinInfoSheet.show(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You do not need supplements. Daal, chana, eggs and dahi will do '
            'the job for a fraction of the price.',
            style: theme.textTheme.caption,
          ),
          if (protein.hasTarget) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Today', style: theme.textTheme.caption),
                const Spacer(),
                Text(
                  '${protein.consumedG.round()} / ${protein.targetG} g',
                  style: theme.textTheme.bodyStrong.copyWith(
                    color: protein.isMet ? ext.success : ext.energy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: protein.progress ?? 0,
                minHeight: 6,
                backgroundColor: ext.hairline,
                valueColor: AlwaysStoppedAnimation(
                  protein.isMet ? ext.success : ext.energy,
                ),
              ),
            ),
            if (!protein.isMet) ...[
              const SizedBox(height: 8),
              Text(
                '${protein.remainingG} g to go — about '
                '${(protein.remainingG / 6.5).ceil()} eggs, or a bowl of daal '
                'and a glass of doodh.',
                style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TierHeading extends StatelessWidget {
  final int tier;

  const _TierHeading({required this.tier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    final (label, note) = switch (tier) {
      1 => ('Cheapest', 'Best protein per rupee'),
      2 => ('Cheap', 'Still very affordable'),
      _ => ('Worth it', 'Costs more, earns its place'),
    };

    return Row(
      children: [
        Text(label, style: theme.textTheme.h2),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            note,
            style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
          ),
        ),
      ],
    );
  }
}

/// Expands to show how to use it, then offers to log it — the guide has to be
/// actionable, not just reading material.
class _FoodTile extends StatefulWidget {
  final ProteinFood food;

  const _FoodTile({required this.food});

  @override
  State<_FoodTile> createState() => _FoodTileState();
}

class _FoodTileState extends State<_FoodTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final food = widget.food;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Glyph avatar: the fastest way to find a food in a long list.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ext.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ext.hairline),
                ),
                child: Center(
                  child: Text(food.glyph, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            food.name,
                            style: theme.textTheme.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (food.isDry) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ext.warning.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DRY',
                              style: theme.textTheme.overline.copyWith(
                                color: ext.warning,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${food.kcalPer100g} kcal per 100 g',
                      style: theme.textTheme.caption,
                    ),
                    const SizedBox(height: 7),
                    // Density bar, scaled against the best item in the guide
                    // (soya at 52 g). Turns a column of numbers into something
                    // you can compare at a glance.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (food.proteinPer100g / 52).clamp(0.04, 1.0),
                        minHeight: 5,
                        backgroundColor: ext.hairline,
                        valueColor: AlwaysStoppedAnimation(ext.energy),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_trim(food.proteinPer100g)} g',
                    style: theme.textTheme.h2.copyWith(color: ext.energy),
                  ),
                  Text(
                    'per 100 g',
                    style: theme.textTheme.overline.copyWith(
                      color: ext.textDisabled,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 12),
            Divider(color: ext.hairline, height: 1),
            const SizedBox(height: 12),
            Text(food.how, style: theme.textTheme.body),
            if (food.caution != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: ext.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      food.caution!,
                      style: theme.textTheme.caption.copyWith(
                        color: ext.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => AppBottomSheet.show(
                  context,
                  child: ManualEntrySheet(
                    initialName: food.name,
                    initialKcal: food.kcalPer100g,
                    initialProteinG: food.proteinPer100g,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Log it'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    const points = [
      'Spread it across the day. Your body uses protein better in several '
          'meals than in one big hit at dinner.',
      'Mix plant and animal, or use the classics: daal with roti, or chana '
          'with doodh, together make a complete protein.',
      'Dry and cooked weights are not the same. 100 g of dry daal is not '
          '100 g of cooked daal — the DRY badge above tells you which is which.',
      'Visible results take 8-12 consistent weeks. Protein is fuel, not magic.',
    ];

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How protein actually works', style: theme.textTheme.h2),
          const SizedBox(height: 14),
          for (var i = 0; i < points.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == points.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: ext.energy,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(points[i], style: theme.textTheme.body)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'General fitness guidance, not medical advice.',
            style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
          ),
        ],
      ),
    );
  }
}
