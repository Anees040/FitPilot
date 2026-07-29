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
  final bool isLocal;

  OffFound({
    required this.productName,
    this.brand,
    this.netWeightGrams,
    required this.kcalPer100g,
    this.isLocal = false,
  });
}

class OffFoundMissingEnergy extends OffResult {
  final String productName;
  OffFoundMissingEnergy(this.productName);
}

class OffNotFound extends OffResult {}

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
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,brands,quantity,product_quantity,nutriments',
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
        return OffNotFound();
      }
      if (response.statusCode != 200) {
        return OffNetworkError();
      }

      final json = jsonDecode(response.body);
      if (json['status'] == 0) {
        return OffNotFound();
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

      return OffFound(
        productName: name,
        brand: brands,
        netWeightGrams: netWeight,
        kcalPer100g: kcal.round(),
      );
    } on TimeoutException {
      return OffNetworkError();
    } catch (e) {
      if (e is FormatException) return OffMalformed();
      return OffNetworkError();
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
