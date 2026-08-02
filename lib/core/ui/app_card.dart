import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

enum AppCardVariant { standard, raised, hero }

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final AppCardVariant variant;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.variant = AppCardVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    BoxDecoration decoration;
    
    switch (variant) {
      case AppCardVariant.hero:
        decoration = BoxDecoration(
          color: color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          gradient: ext.nightGlow,
          border: ext.emberGradient != null ? Border.all(color: Colors.transparent, width: 0) : null,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        );
        break;
      case AppCardVariant.raised:
        decoration = BoxDecoration(
          color: color ?? ext.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ext.hairline, width: 1),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
        break;
      case AppCardVariant.standard:
        decoration = BoxDecoration(
          color: color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ext.hairline, width: 1),
        );
    }

    Widget content = Container(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );

    // Hero variant gradient border
    if (variant == AppCardVariant.hero && ext.emberGradient != null) {
      content = Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21.5),
          gradient: ext.emberGradient,
        ),
        child: content,
      );
    }

    return content;
  }
}
