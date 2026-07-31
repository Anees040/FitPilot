import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class SelectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const SelectChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? ext.accentSoft : theme.colorScheme.primary)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? (isDark ? theme.colorScheme.primary : Colors.transparent)
                : ext.hairline,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.caption.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? (isDark ? theme.colorScheme.primary : theme.colorScheme.onPrimary)
                : theme.textTheme.caption.color,
          ),
        ),
      ),
    );
  }
}
