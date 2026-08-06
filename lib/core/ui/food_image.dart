import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/utils/food_image_resolver.dart';
import 'package:fitpilot/data/services/image_cache_service.dart';

/// Renders the picture for a food, resolving the best source available.
///
/// Order, first that works wins:
///   1. [photoPath]  — the user's own meal photo from an AI scan.
///   2. [imageKey]   — a bundled shared dish photo (works fully offline).
///   3. [imageUrl]   — a remote product photo, only if already cached on disk.
///   4. a tinted category icon derived from [name].
///
/// Every step soft-fails into the next, so a missing or corrupt file shows the
/// icon rather than a broken-image box. The widget itself performs no network
/// requests — step 3 reads a file that [ImageCacheService] downloaded earlier.
class FoodImage extends StatefulWidget {
  final String? photoPath;
  final String? imageKey;
  final String? imageUrl;
  final String name;

  /// Cache id for the remote photo — the barcode for scanned products.
  final String? cacheId;

  /// Rendered box size. When null the image fills its parent.
  final double? size;
  final double radius;
  final BoxFit fit;

  const FoodImage({
    super.key,
    required this.name,
    this.photoPath,
    this.imageKey,
    this.imageUrl,
    this.cacheId,
    this.size,
    this.radius = 12,
    this.fit = BoxFit.cover,
  });

  @override
  State<FoodImage> createState() => _FoodImageState();
}

class _FoodImageState extends State<FoodImage> {
  String? _cachedPath;

  /// Asset keys that failed to load — remembered so a missing file falls
  /// straight through to the icon on rebuild instead of retrying every frame.
  static final Set<String> _brokenKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _lookUpCachedImage();
  }

  @override
  void didUpdateWidget(covariant FoodImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheId != widget.cacheId) _lookUpCachedImage();
  }

  Future<void> _lookUpCachedImage() async {
    if (kIsWeb) return;
    final id = widget.cacheId;
    if (id == null || id.isEmpty) return;
    final path = await ImageCacheService.localPath(id);
    if (mounted && path != _cachedPath) setState(() => _cachedPath = path);
  }

  /// The bundled asset key: an explicit one if the row has it, otherwise
  /// resolved from the name so rows that predate `image_key` still get art.
  String? get _assetKey {
    final key = widget.imageKey ?? resolveImageKey(widget.name);
    if (key == null || _brokenKeys.contains(key)) return null;
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return SizedBox(
      width: widget.size ?? double.infinity,
      height: widget.size ?? double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: _buildImage(context, ext),
      ),
    );
  }

  Widget _buildImage(BuildContext context, AppColors ext) {
    // 1. The user's own photo of this exact meal.
    final photoPath = widget.photoPath;
    if (!kIsWeb && photoPath != null && photoPath.isNotEmpty) {
      return Image.file(
        File(photoPath),
        fit: widget.fit,
        errorBuilder: (_, _, _) => _buildAssetOrFallback(context, ext),
      );
    }
    return _buildAssetOrFallback(context, ext);
  }

  Widget _buildAssetOrFallback(BuildContext context, AppColors ext) {
    // 2. Bundled shared dish photo — the offline-first path.
    final key = _assetKey;
    if (key != null) {
      return Image.asset(
        'assets/food_images/$key.webp',
        fit: widget.fit,
        errorBuilder: (_, _, _) {
          _brokenKeys.add(key);
          return _buildCachedOrIcon(context, ext);
        },
      );
    }
    return _buildCachedOrIcon(context, ext);
  }

  Widget _buildCachedOrIcon(BuildContext context, AppColors ext) {
    // 3. A product photo already downloaded to disk by a barcode scan.
    final cached = _cachedPath;
    if (!kIsWeb && cached != null && cached.isNotEmpty) {
      return Image.file(
        File(cached),
        fit: widget.fit,
        errorBuilder: (_, _, _) => FoodCategoryArt(name: widget.name),
      );
    }
    return FoodCategoryArt(name: widget.name);
  }
}

/// The tinted category icon shown when no photograph is available.
class FoodCategoryArt extends StatelessWidget {
  final String name;

  const FoodCategoryArt({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    final nameLower = name.toLowerCase();
    IconData icon = Icons.restaurant;
    Color bgColor = ext.surfaceRaised;
    Color iconColor = theme.colorScheme.primary;

    if (nameLower.contains('rice') || nameLower.contains('biryani')) {
      icon = Icons.rice_bowl;
      bgColor = ext.accentSoft;
    } else if (nameLower.contains('bread') ||
        nameLower.contains('toast') ||
        nameLower.contains('roti') ||
        nameLower.contains('naan')) {
      icon = Icons.bakery_dining;
      bgColor = ext.energySoft;
    } else if (nameLower.contains('burger') ||
        nameLower.contains('pizza') ||
        nameLower.contains('fast food')) {
      icon = Icons.fastfood;
      bgColor = ext.error.withValues(alpha: 0.15);
      iconColor = ext.error;
    } else if (nameLower.contains('drink') ||
        nameLower.contains('juice') ||
        nameLower.contains('coffee') ||
        nameLower.contains('tea')) {
      icon = Icons.local_cafe;
      bgColor = ext.accentSoft;
    } else if (nameLower.contains('sweet') ||
        nameLower.contains('cake') ||
        nameLower.contains('chocolate') ||
        nameLower.contains('cookie')) {
      icon = Icons.cake;
      bgColor = ext.energySoft;
    } else if (nameLower.contains('fruit') ||
        nameLower.contains('apple') ||
        nameLower.contains('banana')) {
      icon = Icons.apple;
      bgColor = ext.success.withValues(alpha: 0.15);
      iconColor = ext.success;
    } else if (nameLower.contains('meat') ||
        nameLower.contains('chicken') ||
        nameLower.contains('beef')) {
      icon = Icons.kebab_dining;
      bgColor = ext.error.withValues(alpha: 0.15);
      iconColor = ext.error;
    } else if (nameLower.contains('dairy') ||
        nameLower.contains('milk') ||
        nameLower.contains('cheese')) {
      icon = Icons.egg;
      bgColor = ext.accentSoft;
    } else if (nameLower.contains('snack') || nameLower.contains('chips')) {
      icon = Icons.tapas;
      bgColor = ext.energySoft;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        final iconSize = shortest.isFinite
            ? (shortest * 0.45).clamp(16.0, 48.0)
            : 24.0;
        return Container(
          color: bgColor,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor.withValues(alpha: 0.6),
            ),
          ),
        );
      },
    );
  }
}
