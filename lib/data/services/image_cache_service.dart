import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads and caches product images locally by barcode.
/// Never fetches at scroll/list time — only fetches once when a product is logged.
class ImageCacheService {
  static const _dirName = 'product_images';

  /// Returns the local cached path for [barcode] if it exists, otherwise null.
  static Future<String?> localPath(String barcode) async {
    if (kIsWeb) return null;
    try {
      final dir = await _imageDir();
      final file = File('${dir.path}/$barcode.jpg');
      if (await file.exists()) return file.path;
    } catch (_) {}
    return null;
  }

  /// Downloads [imageUrl] and saves it under the barcode key.
  /// Safe to call multiple times — no-ops if already cached.
  static Future<void> save(String barcode, String? imageUrl) async {
    if (kIsWeb) return;
    if (imageUrl == null || imageUrl.isEmpty) return;
    if (barcode == 'ai_scan') return;

    try {
      // Skip if already cached
      final existing = await localPath(barcode);
      if (existing != null) return;

      final dir = await _imageDir();
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final file = File('${dir.path}/$barcode.jpg');
        await file.writeAsBytes(response.bodyBytes);
        if (kDebugMode) {
          debugPrint('[ImageCacheService] cached $barcode → ${file.path}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ImageCacheService] failed to cache $barcode: $e');
      }
      // Non-fatal — placeholder will show
    }
  }

  static Future<Directory> _imageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
