import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Attribution for one bundled food photo, as recorded by
/// `tool/fetch_food_images.mjs` from the live Wikimedia API response.
class ImageCredit {
  final String imageKey;
  final String file;
  final String license;
  final String author;
  final String source;

  const ImageCredit({
    required this.imageKey,
    required this.file,
    required this.license,
    required this.author,
    required this.source,
  });

  /// True for CC0 / public-domain files, which need no author credit.
  bool get isPublicDomain {
    final l = license.toLowerCase();
    return l.startsWith('cc0') ||
        l.contains('public domain') ||
        l.startsWith('pd');
  }

  String get displayAuthor => isPublicDomain ? 'Public domain' : author;
}

/// The keys that actually have a bundled photo. Read from the generated
/// manifest so the app never guesses at what shipped.
final foodImageManifestProvider = FutureProvider<Set<String>>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/food_images/manifest.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final keys = (decoded['keys'] as List<dynamic>? ?? const [])
        .whereType<String>();
    return keys.toSet();
  } catch (_) {
    // Missing or malformed manifest is not fatal — FoodImage falls back to
    // category icons on its own.
    return const <String>{};
  }
});

/// Attribution list for the bundled photos, sorted by dish name.
final imageCreditsProvider = FutureProvider<List<ImageCredit>>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/food_images/credits.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final credits = <ImageCredit>[];
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      credits.add(
        ImageCredit(
          imageKey: entry.key,
          file: value['file'] as String? ?? '',
          license: value['license'] as String? ?? 'Unknown',
          author: value['author'] as String? ?? 'Unknown',
          source: value['source'] as String? ?? '',
        ),
      );
    }
    credits.sort((a, b) => a.imageKey.compareTo(b.imageKey));
    return credits;
  } catch (_) {
    return const <ImageCredit>[];
  }
});
