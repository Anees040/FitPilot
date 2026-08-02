import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/data/services/image_cache_service.dart';
import 'kcal_range_text.dart';

class FoodResultCard extends StatefulWidget {
  final FoodItem food;
  final VoidCallback onTap;

  const FoodResultCard({super.key, required this.food, required this.onTap});

  @override
  State<FoodResultCard> createState() => _FoodResultCardState();
}

class _FoodResultCardState extends State<FoodResultCard> {
  String? _localImagePath;
  bool _imageChecked = false;

  @override
  void initState() {
    super.initState();
    _checkLocalImage();
  }

  Future<void> _checkLocalImage() async {
    if (kIsWeb) {
      setState(() => _imageChecked = true);
      return;
    }
    // Only check local cache if the food was from a barcode scan (id looks like a barcode)
    final id = widget.food.id;
    if (id.isNotEmpty) {
      final path = await ImageCacheService.localPath(id);
      if (mounted) {
        setState(() {
          _localImagePath = path;
          _imageChecked = true;
        });
      }
    } else {
      if (mounted) setState(() => _imageChecked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Media area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildImage(context, ext),
                ),
              ),
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
                        widget.food.name,
                        style: theme.textTheme.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.food.isVerified)
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
                    range: widget.food.kcalPerPortion,
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
    // 1. Try locally cached file (downloaded when barcode was scanned)
    if (!kIsWeb && _localImagePath != null) {
      return Image.file(
        File(_localImagePath!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _buildCategoryArt(context, ext),
      );
    }
    // 2. Try network URL (only when local not available)
    final url = widget.food.imageUrl;
    if (!kIsWeb && _imageChecked && url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _buildCategoryArt(context, ext),
      );
    }
    return _buildCategoryArt(context, ext);
  }

  Widget _buildCategoryArt(BuildContext context, AppColors ext) {
    final theme = Theme.of(context);
    
    final nameLower = widget.food.name.toLowerCase();
    IconData icon = Icons.restaurant;
    Color bgColor = ext.surfaceRaised;
    Color iconColor = theme.colorScheme.primary;

    if (nameLower.contains('rice') || nameLower.contains('biryani')) {
      icon = Icons.rice_bowl;
      bgColor = ext.accentSoft;
    } else if (nameLower.contains('bread') || nameLower.contains('toast') || nameLower.contains('roti') || nameLower.contains('naan')) {
      icon = Icons.bakery_dining;
      bgColor = ext.energySoft;
    } else if (nameLower.contains('burger') || nameLower.contains('pizza') || nameLower.contains('fast food')) {
      icon = Icons.fastfood;
      bgColor = ext.error.withValues(alpha: 0.15);
      iconColor = ext.error;
    } else if (nameLower.contains('drink') || nameLower.contains('juice') || nameLower.contains('coffee') || nameLower.contains('tea')) {
      icon = Icons.local_cafe;
      bgColor = ext.accentSoft;
    } else if (nameLower.contains('sweet') || nameLower.contains('cake') || nameLower.contains('chocolate') || nameLower.contains('cookie')) {
      icon = Icons.cake;
      bgColor = ext.energySoft;
    } else if (nameLower.contains('fruit') || nameLower.contains('apple') || nameLower.contains('banana')) {
      icon = Icons.apple;
      bgColor = ext.success.withValues(alpha: 0.15);
      iconColor = ext.success;
    } else if (nameLower.contains('meat') || nameLower.contains('chicken') || nameLower.contains('beef')) {
      icon = Icons.kebab_dining;
      bgColor = ext.error.withValues(alpha: 0.15);
      iconColor = ext.error;
    } else if (nameLower.contains('dairy') || nameLower.contains('milk') || nameLower.contains('cheese')) {
      icon = Icons.egg;
      bgColor = ext.accentSoft;
    } else if (nameLower.contains('snack') || nameLower.contains('chips')) {
      icon = Icons.tapas;
      bgColor = ext.energySoft;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 48,
          color: iconColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
