import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/data/remote/open_food_facts_client.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/data/services/image_cache_service.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

final openFoodFactsClientProvider = Provider<OpenFoodFactsClient>((ref) {
  return HttpOpenFoodFactsClient(http.Client());
});

final captureProvider = NotifierProvider<CaptureNotifier, void>(() {
  return CaptureNotifier();
});

class CaptureNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<OffResult?> lookupBarcode(String barcode) async {
    final client = ref.read(openFoodFactsClientProvider);
    final db = await ref.read(databaseProvider.future);

    // 1. Check local catalog first (airplane mode)
    final localMatches = await db.query(
      'food_catalog',
      where: 'id = ?',
      whereArgs: [barcode],
    );

    if (localMatches.isNotEmpty) {
      final match = localMatches.first;
      return OffFound(
        productName: match['name'] as String,
        kcalPer100g:
            match['kcal_min'] as int, // simplified, assuming min == max in OFF
        netWeightGrams: (match['grams'] as num?)?.toDouble(),
        isLocal: true,
      );
    }

    // Query network
    try {
      final result = await client.getProduct(barcode);
      if (result is OffFound) {
        // Cache to local DB
        await db.insert('food_catalog', {
          'id': barcode,
          'name': result.productName,
          'portion_label': '100g',
          'grams': result.netWeightGrams,
          'kcal_min': result.kcalPer100g,
          'kcal_max': result.kcalPer100g,
          'image_url': result.imageUrl,
          'is_verified': 0, // Externally sourced
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        // Download & cache image locally (fire-and-forget, non-blocking)
        if (result.imageUrl != null) {
          ImageCacheService.save(barcode, result.imageUrl);
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<double?> getSavedQuantity(String barcode) async {
    final db = await ref.read(databaseProvider.future);
    final rows = await db.query(
      'saved_products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (rows.isNotEmpty) {
      return (rows.first['quantity'] as num).toDouble();
    }
    return null;
  }

  Future<void> saveQuantity(String barcode, double quantity) async {
    final db = await ref.read(databaseProvider.future);
    await db.insert('saved_products', {
      'barcode': barcode,
      'quantity': quantity,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> logScannedItem({
    required String? barcode,
    required String name,
    required int kcal,
    required double grams,
  }) async {
    // Add a 5% spread to the exact computed kcal
    final spread = (kcal * 0.05).round();
    final kcalRange = KcalRange(kcal - spread, kcal + spread);

    final log = FoodLog(
      id: const Uuid().v4(),
      foodId: barcode, // null if OCR
      foodName: barcode != null ? name : null,
      customName: barcode == null ? name : null,
      quantity:
          1.0, // Quantity is 1 because we pre-computed the final kcal based on grams
      kcal: kcalRange,
      source: barcode == null ? LogSource.labelScan : LogSource.search,
      loggedAt: DateTime.now(),
    );

    ref.read(todayProvider.notifier).addLog(log);
  }
}
