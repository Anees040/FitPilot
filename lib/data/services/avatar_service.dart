import 'dart:io';

import 'package:flutter/foundation.dart';
// For FileImage.evict: Flutter caches decoded images by path, so overwriting
// the same file leaves the previous photo on screen until the entry is dropped.
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Stores the profile photo the user picks for themselves.
///
/// The file lives in the app sandbox and the profile keeps its absolute path.
/// That path is local-only and is never pushed to Supabase — it means nothing
/// on another device, which is why `avatar_url` may hold either an https URL
/// (from Google) or a path (from here), and [ProfileAvatar] picks the loader.
///
/// Exactly one avatar is kept: picking a new one replaces the old file, so the
/// sandbox cannot fill up with abandoned photos.
class AvatarService {
  static const _fileName = 'profile_avatar.jpg';

  /// Opens the picker and stores the chosen image.
  ///
  /// Returns the new absolute path, or null if the user cancelled, the platform
  /// has no filesystem (web), or the write failed.
  static Future<String?> pick({
    ImageSource source = ImageSource.gallery,
  }) async {
    if (kIsWeb) return null;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // An avatar is never rendered above ~120 logical pixels, so a full
        // camera frame would be several megabytes for no visible gain.
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final target = File('${dir.path}/$_fileName');

      // Written via bytes rather than File.copy: the source may sit on a
      // provider path that cannot be copied directly on Android.
      await target.writeAsBytes(await picked.readAsBytes(), flush: true);

      // Flutter caches decoded images by file path, so overwriting the same
      // path leaves the old picture on screen. A unique query-free copy is not
      // possible with a fixed name, so evict the cache entry instead.
      await FileImage(target).evict();

      return target.path;
    } catch (e) {
      if (kDebugMode) debugPrint('[AvatarService] pick failed: $e');
      return null;
    }
  }

  /// Removes the stored avatar, if any.
  static Future<void> clear() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (await file.exists()) {
        await FileImage(file).evict();
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AvatarService] clear failed: $e');
    }
  }

  /// True when [value] points at a file this service wrote, rather than at a
  /// remote URL supplied by an identity provider.
  static bool isLocal(String? value) {
    if (value == null || value.isEmpty) return false;
    return !value.startsWith('http://') && !value.startsWith('https://');
  }
}
