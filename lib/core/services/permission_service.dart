import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wrapper around permission_handler for runtime permissions.
/// Only needed on Android/iOS — skipped on web.
class PermissionService {
  /// Requests camera permission and returns true if granted.
  /// On web or non-mobile platforms, always returns true.
  static Future<bool> requestCamera() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final status = await Permission.camera.request();
    if (kDebugMode) {
      debugPrint('[PermissionService] camera → $status');
    }
    return status.isGranted;
  }

  /// Returns true if camera permission is already granted (no prompt).
  static Future<bool> hasCameraPermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    return Permission.camera.isGranted;
  }
}
