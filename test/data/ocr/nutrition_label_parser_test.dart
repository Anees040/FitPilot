import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/data/ocr/nutrition_label_parser.dart';

void main() {
  group('NutritionLabelParser', () {
    late NutritionLabelParser parser;

    setUp(() {
      parser = NutritionLabelParser();
    });

    test('parses simple english label', () {
      final text = '''
Nutrition Facts
Serving Size 30g
Servings Per Container 4
Calories 150 kcal
Protein 2g
      ''';
      final result = parser.parse(text);
      expect(result.kcal?.value, 150);
      expect(result.kcal?.confidence, 0.9);
      expect(result.servingSizeGrams?.value, 30.0);
      expect(result.servingsPerPack?.value, 4.0);
    });

    test('parses urdu transliterated label', () {
      final text = '''
Tawanai 120 kcal
fi 100g
kul hissay 5
hissa 25g
      ''';
      final result = parser.parse(text);
      expect(result.kcal?.value, 120);
      expect(result.kcal?.confidence, 0.9);
      expect(result.basis?.value, NutritionBasis.per100g);
      expect(result.servingsPerPack?.value, 5.0);
      expect(result.servingSizeGrams?.value, 25.0);
    });

    test('converts kj to kcal', () {
      final text = '''
Energy 418.4 kJ
per 100ml
      ''';
      final result = parser.parse(text);
      expect(result.kcal?.value, 100); // 418.4 / 4.184 = 100
      expect(result.basis?.value, NutritionBasis.per100ml);
    });

    test('handles decimal commas', () {
      final text = '''
Serving size 30,5g
Energy 150,5 kcal
      ''';
      final result = parser.parse(text);
      expect(result.servingSizeGrams?.value, 30.5);
      expect(result.kcal?.value, 151); // rounded
    });

    test('handles per serving basis', () {
      final text = 'energy 200 kcal per serving';
      final result = parser.parse(text);
      expect(result.basis?.value, NutritionBasis.perServing);
      expect(result.kcal?.value, 200);
    });

    test('handles per piece basis', () {
      final text = 'calories 50 cal per piece';
      final result = parser.parse(text);
      expect(result.basis?.value, NutritionBasis.perPiece);
      expect(result.kcal?.value, 50);
    });

    test('falls back to low confidence energy', () {
      final text = 'Energy: 100\nFat: 5g';
      final result = parser.parse(text);
      expect(result.kcal?.value, 100);
      expect(result.kcal?.confidence, 0.5);
    });

    test('handles garbled text gracefully', () {
      final text = 'sdflkj sdlfkj serving 30 g sdf lkcal 100';
      final result = parser.parse(text);
      expect(result.servingSizeGrams?.value, 30.0);
    });

    test('handles missing energy entirely', () {
      final text = 'Fat 10g\nCarbs 20g\nServing size 50g';
      final result = parser.parse(text);
      expect(result.kcal, isNull);
      expect(result.servingSizeGrams?.value, 50.0);
    });

    test('handles fi hissa (urdu per serving)', () {
      final text = 'fi hissa\ntawanai 500 kj';
      final result = parser.parse(text);
      expect(result.basis?.value, NutritionBasis.perServing);
      expect(result.kcal?.value, (500 / 4.184).round());
    });

    test('handles missing everything', () {
      final text = 'just some random text';
      final result = parser.parse(text);
      expect(result.kcal, isNull);
      expect(result.basis, isNull);
      expect(result.servingSizeGrams, isNull);
      expect(result.servingsPerPack, isNull);
    });

    test('handles fi dana (urdu per piece)', () {
      final text = 'hararay 50\nfi dana';
      final result = parser.parse(text);
      expect(result.kcal?.value, 50);
      expect(result.kcal?.confidence, 0.5);
      expect(result.basis?.value, NutritionBasis.perPiece);
    });
  });
}
