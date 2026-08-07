import 'package:flutter/material.dart';

import 'package:fitpilot/core/theme/app_theme.dart';

/// Thin completion bar shared by the program cards and the detail header.
class ProgramProgressBar extends StatelessWidget {
  final double fraction;
  final double height;

  const ProgramProgressBar({super.key, required this.fraction, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: ext.hairline,
        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
      ),
    );
  }
}

/// Small pill used for level / duration / equipment metadata.
class ProgramMetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const ProgramMetaChip({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ext.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ext.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: theme.textTheme.caption.color),
            const SizedBox(width: 4),
          ],
          Text(label, style: theme.textTheme.caption),
        ],
      ),
    );
  }
}
