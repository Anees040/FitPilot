import 'package:flutter/material.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';

@Deprecated('Use AppSnackbar.success directly')
void confirmSnackbar(BuildContext context, String message, {VoidCallback? onUndo}) {
  AppSnackbar.success(
    context,
    message,
    actionLabel: onUndo != null ? 'Undo' : null,
    onAction: onUndo,
  );
}
