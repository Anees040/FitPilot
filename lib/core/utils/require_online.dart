import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/network_provider.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';

/// Checks if the device is currently online.
/// If not, displays a standard offline snackbar with the [feature] name and returns false.
/// If online, returns true.
bool requireOnline(BuildContext context, WidgetRef ref, {required String feature}) {
  final isOnline = ref.read(isOnlineProvider).value ?? true;
  if (!isOnline) {
    AppSnackbar.error(
      context,
      "You're offline - $feature needs an internet connection.",
    );
    return false;
  }
  return true;
}
