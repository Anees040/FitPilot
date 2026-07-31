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
                        widget.food.name,
                        style: theme.textTheme.bodyStrong,
                        maxLines: 2,
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
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _fallbackIcon(context, ext),
      );
    }
    // 2. Try network URL (only when local not available)
    final url = widget.food.imageUrl;
    if (!kIsWeb && _imageChecked && url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: double.infinity,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _fallbackIcon(context, ext),
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
