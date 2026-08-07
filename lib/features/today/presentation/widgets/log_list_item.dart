import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/food_image.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/features/log/presentation/widgets/kcal_range_text.dart';

/// One logged meal: photo, name, kcal range, time, and a "Burn it" shortcut
/// that targets this meal on the Plan screen.
///
/// Swipe end-to-start deletes with an UNDO snackbar; tapping opens
/// [FoodLogDetailSheet] to edit the portion or delete.
class LogListItem extends ConsumerWidget {
  final FoodLog log;
  final double weightKg;

  const LogListItem({super.key, required this.log, required this.weightKg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    // Estimate min brisk walk (MET 4.3): min = Kcal * 60 / (4.3 * weight)
    const double met = 4.3;
    final int minWalk =
        (log.kcal.midpoint * 60 / (met * weightKg)).clamp(1, 999).round();

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: ext.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        child: Icon(Icons.delete, color: theme.colorScheme.onPrimary),
      ),
      onDismissed: (_) {
        final container = ProviderScope.containerOf(context);
        final notifier = ref.read(todayProvider.notifier);
        notifier.deleteLog(log.id);
        AppSnackbar.success(
          context,
          'Meal deleted',
          actionLabel: 'UNDO',
          onAction: () {
            container.read(todayProvider.notifier).restoreLog(log);
          },
        );
      },
      child: AppCard(
        variant: AppCardVariant.raised,
        padding: const EdgeInsets.all(12),
        onTap: () {
          AppBottomSheet.show(
            context,
            child: FoodLogDetailSheet(log: log),
          );
        },
        child: Row(
          children: [
            FoodImage(
              name: log.displayName ?? '',
              photoPath: log.photoPath,
              cacheId: log.foodId,
              size: 56,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.displayName ?? 'Unknown',
                    style: theme.textTheme.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // A wide range ("200–240 kcal") plus the time overruns the
                  // row on narrow phones, so the time yields space first.
                  Row(
                    children: [
                      Flexible(
                        child: KcalRangeText(
                          range: log.kcal,
                          style: theme.textTheme.caption.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          ' • ${DateFormat.jm().format(log.loggedAt)}',
                          style: theme.textTheme.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                ref.read(burnPlanMealIdProvider.notifier).state = log.id;
                context.go('/plan');
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Burn it →',
                      style: theme.textTheme.bodyStrong
                          .copyWith(color: ext.energy),
                    ),
                    Text(
                      '~$minWalk min',
                      style: theme.textTheme.caption.copyWith(color: ext.energy),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// Portion editor / delete for a single logged meal.
class FoodLogDetailSheet extends ConsumerStatefulWidget {
  final FoodLog log;

  const FoodLogDetailSheet({super.key, required this.log});

  @override
  ConsumerState<FoodLogDetailSheet> createState() => _FoodLogDetailSheetState();
}

class _FoodLogDetailSheetState extends ConsumerState<FoodLogDetailSheet> {
  late double _quantity;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _quantity = widget.log.quantity.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = widget.log;

    final unitKcal = log.kcal.times(1 / (log.quantity == 0 ? 1 : log.quantity));
    final currentKcal = unitKcal.times(_quantity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FoodImage(
              name: log.displayName ?? '',
              photoPath: log.photoPath,
              cacheId: log.foodId,
              size: 64,
              radius: 16,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.displayName ?? 'Unknown Food',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Logged at ${DateFormat.jm().format(log.loggedAt.toLocal())}',
                    style: theme.textTheme.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Calories', style: theme.textTheme.bodyMedium),
                  KcalRangeText(
                    range: currentKcal,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Portion', style: theme.textTheme.bodyMedium),
                  Text(
                    '${_quantity.toStringAsFixed(1)} x portion',
                    style: theme.textTheme.bodyStrong,
                  ),
                ],
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _quantity <= 0.25
                          ? null
                          : () => setState(() =>
                              _quantity = (_quantity - 0.25).clamp(0.25, 20.0)),
                    ),
                    Text(
                      _quantity
                          .toStringAsFixed(2)
                          .replaceAll(RegExp(r'\.?0+$'), ''),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(
                          () => _quantity = (_quantity + 0.25).clamp(0.25, 20.0)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (!_isEditing) ...[
          PrimaryButton(
            label: 'Edit Portion',
            onPressed: () => setState(() => _isEditing = true),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Delete Log',
            onPressed: () async {
              await ref.read(todayProvider.notifier).deleteLog(log.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                AppSnackbar.success(context, 'Meal deleted');
              }
            },
          ),
        ] else ...[
          PrimaryButton(
            label: 'Save Changes',
            onPressed: () async {
              await ref
                  .read(todayProvider.notifier)
                  .updateLogQuantity(log.id, _quantity);
              if (context.mounted) {
                Navigator.of(context).pop();
                AppSnackbar.success(context, 'Portion updated');
              }
            },
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => setState(() {
              _quantity = log.quantity.toDouble();
              _isEditing = false;
            }),
          ),
        ],
      ],
    );
  }
}
