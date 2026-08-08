import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

/// Guards the two pieces of protein data that ship with the app: the budget
/// guide content, and the seed catalog's protein figures.
void main() {
  group('protein_guide.json', () {
    late List<Map<String, dynamic>> items;

    setUpAll(() {
      final raw = File('assets/seed/protein_guide.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      items = (decoded['items'] as List).cast<Map<String, dynamic>>();
    });

    test('parses and is not empty', () {
      expect(items, isNotEmpty);
    });

    test('every item has protein above zero', () {
      // A "protein guide" entry with no protein would be noise.
      for (final item in items) {
        final protein = (item['protein'] as num).toDouble();
        expect(protein, greaterThan(0), reason: '${item['name']} has no protein');
      }
    });

    test('every item sits in tier 1-3', () {
      for (final item in items) {
        expect(
          item['tier'],
          inInclusiveRange(1, 3),
          reason: '${item['name']} has an out-of-range tier',
        );
      }
    });

    test('every item carries the fields the UI renders', () {
      for (final item in items) {
        expect(item['id'], isA<String>());
        expect(item['name'], isA<String>());
        expect(item['kcal'], isA<num>());
        expect(item['how'], isA<String>());
        expect((item['how'] as String).trim(), isNotEmpty);
      }
    });

    test('ids are unique, so the list cannot render duplicates', () {
      final ids = items.map((i) => i['id']).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all three tiers are represented', () {
      final tiers = items.map((i) => i['tier']).toSet();
      expect(tiers, containsAll([1, 2, 3]));
    });

    test('dry-weight items are flagged', () {
      // Dry vs cooked is the easiest way to overcount protein by 3x, so the
      // badge is not optional for these.
      final dryNames = items
          .where((i) => i['dry'] == true)
          .map((i) => (i['name'] as String).toLowerCase())
          .toList();
      expect(dryNames.any((n) => n.contains('soya')), isTrue);
      expect(dryNames.any((n) => n.contains('daal')), isTrue);
    });
  });

  group('seed foods protein', () {
    late List<Map<String, dynamic>> foods;

    setUpAll(() {
      final raw = File('assets/seed/foods.json').readAsStringSync();
      foods = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    });

    test('every seed food carries a protein figure', () {
      for (final food in foods) {
        expect(
          food['protein_g'],
          isNotNull,
          reason: '${food['name']} is missing protein_g',
        );
      }
    });

    test('protein figures are plausible for the portion', () {
      for (final food in foods) {
        final protein = (food['protein_g'] as num).toDouble();
        final grams = (food['grams'] as num?)?.toDouble() ?? 100;
        expect(protein, greaterThanOrEqualTo(0));
        // Nothing edible is more than ~40% protein by weight.
        expect(
          protein,
          lessThanOrEqualTo(grams * 0.4),
          reason: '${food['name']}: ${protein}g in ${grams}g is implausible',
        );
      }
    });
  });

  group('catalog pick scales protein by portion', () {
    // Mirrors what the quantity sheet does when the user picks 1.5 portions.
    double? scaled(double? perPortion, num quantity) =>
        perPortion == null ? null : perPortion * quantity;

    final food = FoodItem(
      id: 'chana',
      name: 'Boiled chana',
      portionLabel: '1 bowl',
      grams: 200,
      kcalPerPortion: KcalRange(200, 320),
      proteinPerPortionG: 10,
    );

    test('a whole portion logs the whole figure', () {
      expect(scaled(food.proteinPerPortionG, 1), 10);
    });

    test('a double portion logs double the protein', () {
      expect(scaled(food.proteinPerPortionG, 2), 20);
    });

    test('a half portion logs half the protein', () {
      expect(scaled(food.proteinPerPortionG, 0.5), 5);
    });

    test('a food with no protein figure stays unknown at any quantity', () {
      final unknown = FoodItem(
        id: 'mystery',
        name: 'Mystery dish',
        portionLabel: '1 plate',
        kcalPerPortion: KcalRange(300, 400),
      );
      expect(scaled(unknown.proteinPerPortionG, 3), isNull);
    });
  });
}
