import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

sealed class OffResult {}

class OffFound extends OffResult {
  final String productName;
  final String? brand;
  final double? netWeightGrams;
  final int kcalPer100g;
  final String? imageUrl;
  final bool isLocal;

  OffFound({
    required this.productName,
    this.brand,
    this.netWeightGrams,
    required this.kcalPer100g,
    this.imageUrl,
    this.isLocal = false,
  });
}

class OffFoundMissingEnergy extends OffResult {
  final String productName;
  OffFoundMissingEnergy(this.productName);
}

class OffNotFound extends OffResult {
  /// Product name recovered from a secondary barcode directory, when one knew
  /// the item even though no nutrition database did.
  ///
  /// Lets the "add this product" sheet prefill the name so the user only has
  /// to supply the calories.
  final String? suggestedName;

  OffNotFound({this.suggestedName});
}

class OffMalformed extends OffResult {}

class OffNetworkError extends OffResult {}

abstract class OpenFoodFactsClient {
  Future<OffResult> getProduct(String barcode);
}

class HttpOpenFoodFactsClient implements OpenFoodFactsClient {
  final http.Client client;

  HttpOpenFoodFactsClient(this.client);

  @override
  Future<OffResult> getProduct(String barcode) async {
    debugPrint('OpenFoodFacts lookup: $barcode');
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,brands,quantity,product_quantity,nutriments,image_url',
      );
      final response = await client
          .get(
            uri,
            headers: {
              'User-Agent': 'FitPilot/1.0 (COMSATS Final Year Project)',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        return OffNotFound(suggestedName: await _lookupNameOnly(barcode));
      }
      if (response.statusCode != 200) {
        return OffNetworkError();
      }

      final json = jsonDecode(response.body);
      if (json['status'] == 0) {
        return OffNotFound(suggestedName: await _lookupNameOnly(barcode));
      }

      final product = json['product'];
      if (product == null) {
        return OffMalformed();
      }

      final name = product['product_name']?.toString() ?? '';
      if (name.isEmpty) {
        return OffMalformed();
      }

      final brands = product['brands']?.toString();

      // Net weight
      double? netWeight;
      final productQuantity = product['product_quantity'];
      if (productQuantity != null && productQuantity is num) {
        netWeight = productQuantity.toDouble();
      } else {
        final q = product['quantity']?.toString();
        if (q != null && q.isNotEmpty) {
          final match = RegExp(
            r'(\d+(?:\.\d+)?)\s*(g|ml)',
            caseSensitive: false,
          ).firstMatch(q);
          if (match != null) {
            netWeight = double.tryParse(match.group(1)!);
          }
        }
      }

      final nutriments = product['nutriments'];
      if (nutriments == null) {
        return OffFoundMissingEnergy(name);
      }

      num? kcal = nutriments['energy-kcal_100g'] as num?;
      if (kcal == null) {
        num? kj = nutriments['energy-kj_100g'] as num?;
        if (kj != null) {
          kcal = kj / 4.184;
        }
      }

      if (kcal == null) {
        return OffFoundMissingEnergy(name);
      }

      final imageUrl = product['image_url']?.toString();

      return OffFound(
        productName: name,
        brand: brands,
        netWeightGrams: netWeight,
        kcalPer100g: kcal.round(),
        imageUrl: imageUrl,
      );
    } on TimeoutException {
      return OffNetworkError();
    } catch (e) {
      if (e is FormatException) return OffMalformed();
      return OffNetworkError();
    }
  }

  /// Asks a general barcode directory for the product's *name* only.
  ///
  /// Open Food Facts is nutrition-first and misses most local brands. A generic
  /// UPC directory sometimes still knows the name, which turns "unknown
  /// product" into one field to fill instead of three.
  ///
  /// Measured coverage: the directory answers for international items (a
  /// Coca-Cola EAN resolves) but NOT for Pakistani 896-prefix barcodes, which
  /// are exactly the ones Open Food Facts already missed. Those are skipped so
  /// the common local-product path reaches the "add it" sheet immediately
  /// instead of waiting out a lookup that is known to fail.
  ///
  /// Strictly best-effort: short timeout, null on any failure.
  Future<String?> _lookupNameOnly(String barcode) async {
    // GS1 prefix 890–899 is South Asia (896 = Pakistan). No public directory
    // covers these, so do not spend the user's time asking.
    if (barcode.length >= 3) {
      final prefix = int.tryParse(barcode.substring(0, 3));
      if (prefix != null && prefix >= 890 && prefix <= 899) return null;
    }

    try {
      final response = await client
          .get(Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final items = decoded['items'];
      if (items is! List || items.isEmpty) return null;

      final first = items.first;
      if (first is! Map) return null;

      final title = first['title']?.toString().trim();
      if (title == null || title.isEmpty) return null;
      return title;
    } catch (_) {
      // Directory unavailable, rate-limited, or offline — the user can still
      // type the name.
      return null;
    }
  }
}

/// A fake implementation returning fixture JSON outcomes directly without HTTP.
class FakeOpenFoodFactsClient implements OpenFoodFactsClient {
  // Mapping barcode to a JSON-like map that simulates the API product object.
  // Or just storing the direct result to return, depending on the test.
  // We'll just map barcode -> OffResult directly for easy testing.
  final Map<String, OffResult> overrides = {};

  FakeOpenFoodFactsClient() {
    assert(!const bool.fromEnvironment('dart.vm.product', defaultValue: false),
        'FakeOpenFoodFactsClient should not be used in production');
  }

  @override
  Future<OffResult> getProduct(String barcode) async {
    if (overrides.containsKey(barcode)) {
      return overrides[barcode]!;
    }
    return OffNotFound();
  }
}
