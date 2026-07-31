import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

enum SnackbarVariant { success, warning, error }

class AppSnackbar {
  static void _show(
    BuildContext context,
    String message,
    SnackbarVariant variant, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    IconData icon;
    Color iconColor;

    switch (variant) {
      case SnackbarVariant.success:
        icon = Icons.check_circle_outline;
        iconColor = ext.success;
        break;
      case SnackbarVariant.warning:
        icon = Icons.warning_amber_rounded;
        iconColor = ext.warning;
        break;
      case SnackbarVariant.error:
        icon = Icons.error_outline;
        iconColor = ext.error;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyStrong.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: ext.surfaceRaised,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 3500),
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ext.hairline, width: 0.5),
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: theme.colorScheme.primary,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(context, message, SnackbarVariant.success, actionLabel: actionLabel, onAction: onAction);
  }

  static void warning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(context, message, SnackbarVariant.warning, actionLabel: actionLabel, onAction: onAction);
  }

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(context, message, SnackbarVariant.error, actionLabel: actionLabel, onAction: onAction);
  }
}
