import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
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
    final multipliedRange = widget.food.kcalPerPortion.times(_quantity);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.food.name,
              style: AppTheme.lightTheme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.food.portionLabel,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
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
                KcalRangeText(
                  range: multipliedRange,
                  style: AppTheme.lightTheme.textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                final log = FoodLog(
                  id: const Uuid().v4(),
                  foodId: widget.food.id,
                  quantity: _quantity,
                  kcal: multipliedRange,
                  source: LogSource.search,
                  loggedAt: DateTime.now(),
                );
                ref.read(todayProvider.notifier).addLog(log);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Added to today'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Add to today',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
