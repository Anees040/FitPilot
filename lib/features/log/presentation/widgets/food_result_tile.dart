import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'kcal_range_text.dart';

class FoodResultTile extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;

  const FoodResultTile({super.key, required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (food.isVerified)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.verified, color: ext.success, size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          food.portionLabel,
                          style: theme.textTheme.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!food.isVerified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ext.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'ESTIMATE',
                            style: theme.textTheme.overline.copyWith(
                              color: ext.warning,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            KcalRangeText(
              range: food.kcalPerPortion,
              style: theme.textTheme.bodyStrong,
            ),
          ],
        ),
      ),
    );
  }
}
