import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitpilot/data/remote/open_food_facts_client.dart';
import 'dart:convert';

void main() {
  group('HttpOpenFoodFactsClient', () {
    test('found with complete nutrition data', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name': 'Test Biscuit',
              'brands': 'TestBrand',
              'product_quantity': 150,
              'nutriments': {'energy-kcal_100g': 450},
            },
          }),
          200,
        );
      });

      final client = HttpOpenFoodFactsClient(mockClient);
      final result = await client.getProduct('12345');

      expect(result, isA<OffFound>());
      final found = result as OffFound;
      expect(found.productName, 'Test Biscuit');
      expect(found.brand, 'TestBrand');
      expect(found.netWeightGrams, 150.0);
      expect(found.kcalPer100g, 450);
    });

    test('found but missing energy data', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {'product_name': 'Test Drink', 'nutriments': {}},
          }),
          200,
        );
      });

      final client = HttpOpenFoodFactsClient(mockClient);
      final result = await client.getProduct('12345');

      expect(result, isA<OffFoundMissingEnergy>());
      expect((result as OffFoundMissingEnergy).productName, 'Test Drink');
    });

    test('found energy in kJ only, converts to kcal', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name': 'Test Snack',
              'nutriments': {'energy-kj_100g': 1000},
            },
          }),
          200,
        );
      });

      final client = HttpOpenFoodFactsClient(mockClient);
      final result = await client.getProduct('12345');

      expect(result, isA<OffFound>());
      final found = result as OffFound;
      expect(found.kcalPer100g, (1000 / 4.184).round()); // ~239
    });

    test('not found', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 0}),
          200, // OFF sometimes returns 200 with status 0 for not found
        );
      });

      final client = HttpOpenFoodFactsClient(mockClient);
      final result = await client.getProduct('12345');

      expect(result, isA<OffNotFound>());
    });

    test('network unavailable', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = HttpOpenFoodFactsClient(mockClient);
      final result = await client.getProduct('12345');

      expect(result, isA<OffNetworkError>());
    });

    test('malformed response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not json', 200);
      });

      final client = HttpOpenFoodFactsClient(mockClient);
      final result = await client.getProduct('12345');

      expect(result, isA<OffMalformed>());
    });
  });

  group('FakeOpenFoodFactsClient', () {
    test('returns overrides correctly', () async {
      final fake = FakeOpenFoodFactsClient();
      fake.overrides['111'] = OffFound(
        productName: 'Fake Food',
        kcalPer100g: 100,
      );

      final found = await fake.getProduct('111');
      expect(found, isA<OffFound>());
      expect((found as OffFound).productName, 'Fake Food');

      final notFound = await fake.getProduct('222');
      expect(notFound, isA<OffNotFound>());
    });
  });
}
