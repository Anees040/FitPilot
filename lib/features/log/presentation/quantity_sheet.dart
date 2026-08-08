import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'widgets/quantity_stepper.dart';
import 'widgets/kcal_range_text.dart';

class QuantitySheet extends ConsumerStatefulWidget {
  final FoodItem food;

  const QuantitySheet({super.key, required this.food});

  @override
  ConsumerState<QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends ConsumerState<QuantitySheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multipliedRange = widget.food.kcalPerPortion.times(_quantity);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.food.name,
              style: theme.textTheme.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.food.portionLabel,
              style: theme.textTheme.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                QuantityStepper(
                  value: _quantity,
                  onChanged: (val) {
                    setState(() {
                      _quantity = val;
                    });
                  },
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: KcalRangeText(
                        range: multipliedRange,
                        style: theme.textTheme.display.copyWith(fontSize: 32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Kcal range visual bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                // Simple visual heuristic: max range 1000 for full width
                widthFactor: (multipliedRange.midpoint / 1000).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Add & see burn',
              onPressed: () {
                final logId = const Uuid().v4();
                final proteinPerPortion = widget.food.proteinPerPortionG;
                final log = FoodLog(
                  id: logId,
                  foodId: widget.food.id,
                  quantity: _quantity,
                  kcal: multipliedRange,
                  source: LogSource.search,
                  loggedAt: DateTime.now(),
                  // Scales with quantity exactly like kcal. Stays null when the
                  // catalog has no figure, so "unknown" is never shown as 0 g.
                  proteinG: proteinPerPortion == null
                      ? null
                      : proteinPerPortion * _quantity,
                );
                ref.read(todayProvider.notifier).addLog(log);
                
                // Set the selected meal in the burn plan state and navigate
                ref.read(burnPlanMealIdProvider.notifier).state = logId;
                Navigator.pop(context); // close sheet
                context.go('/plan'); // go to plan
              },
            ),
          ],
        ),
      ),
    );
  }
}
