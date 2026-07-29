import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

void confirmSnackbar(BuildContext context, String message, {VoidCallback? onUndo}) {
  final theme = Theme.of(context);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: theme.textTheme.bodyStrong.copyWith(color: theme.colorScheme.surface),
      ),
      backgroundColor: theme.colorScheme.onSurface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      action: onUndo != null
          ? SnackBarAction(
              label: 'Undo',
              textColor: theme.colorScheme.primary,
              onPressed: onUndo,
            )
          : null,
    ),
  );
}
