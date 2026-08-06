import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Stores the user's own meal photos from the AI scan flow.
///
/// Distinct from [ImageCacheService], which caches *product* photos downloaded
/// from Open Food Facts and is keyed by barcode. These files are the user's
/// content: they are written once when a scanned meal is logged, referenced by
/// `food_logs.photo_path`, and deleted when that log is deleted.
///
/// The path is stored local-only and never pushed to Supabase — it points at
/// this device's sandbox and means nothing anywhere else.
class MealPhotoService {
  static const _dirName = 'meal_photos';
  static const _uuid = Uuid();

  /// Writes [bytes] as a new jpeg and returns its absolute path.
  /// Returns null on web or if the write fails — callers log without a photo.
  static Future<String?> save(Uint8List bytes) async {
    if (kIsWeb || bytes.isEmpty) return null;
    try {
      final dir = await _photoDir();
      final file = File('${dir.path}/${_uuid.v4()}.jpg');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('[MealPhotoService] save failed: $e');
      return null;
    }
  }

  /// Best-effort delete of a photo whose log has been removed.
  static Future<void> delete(String? path) async {
    if (kIsWeb || path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[MealPhotoService] delete failed: $e');
    }
  }

  static Future<Directory> _photoDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
