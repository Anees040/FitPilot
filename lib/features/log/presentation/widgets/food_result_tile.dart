import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'kcal_range_text.dart';

class FoodResultCard extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;

  const FoodResultCard({super.key, required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildImage(context, ext),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        food.name,
                        style: theme.textTheme.bodyStrong,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (food.isVerified)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, top: 2.0),
                        child: Icon(Icons.verified, color: ext.success, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Kcal chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: KcalRangeText(
                    range: food.kcalPerPortion,
                    style: theme.textTheme.caption.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, AppColors ext) {
    if (food.imageUrl != null && food.imageUrl!.isNotEmpty) {
      return Image.network(
        food.imageUrl!,
        width: double.infinity,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackIcon(context, ext),
      );
    }
    return _fallbackIcon(context, ext);
  }

  Widget _fallbackIcon(BuildContext context, AppColors ext) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: ext.accentSoft.withValues(alpha: 0.5),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 40,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
