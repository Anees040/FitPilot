import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

void main() {
  group('KcalRange', () {
    group('constructor invariants', () {
      test('min > max throws ArgumentError', () {
        expect(() => KcalRange(500, 400), throwsArgumentError);
      });

      test('negative min throws ArgumentError', () {
        expect(() => KcalRange(-1, 100), throwsArgumentError);
      });

      test('valid range does not throw', () {
        expect(() => KcalRange(100, 200), returnsNormally);
      });

      test('zero-zero is valid', () {
        expect(() => KcalRange(0, 0), returnsNormally);
      });

      test('min == max is valid', () {
        expect(() => KcalRange(100, 100), returnsNormally);
      });
    });

    group('exact constructor', () {
      test('creates range where min == max', () {
        final r = KcalRange.exact(420);
        expect(r.min, 420);
        expect(r.max, 420);
        expect(r.isExact, true);
      });
    });

    group('plus', () {
      test('adds both ends', () {
        final a = KcalRange(100, 200);
        final b = KcalRange(50, 80);
        final result = a.plus(b);
        expect(result.min, 150);
        expect(result.max, 280);
      });
    });

    group('times', () {
      test('scales by integer', () {
        final r = KcalRange(100, 200);
        final result = r.times(2);
        expect(result.min, 200);
        expect(result.max, 400);
      });

      test('scales by fractional qty and rounds', () {
        final r = KcalRange(100, 200);
        final result = r.times(1.5);
        expect(result.min, 150);
        expect(result.max, 300);
      });

      test('qty <= 0 throws ArgumentError', () {
        final r = KcalRange(100, 200);
        expect(() => r.times(0), throwsArgumentError);
        expect(() => r.times(-1), throwsArgumentError);
      });
    });

    group('minus', () {
      test('subtracts from both ends', () {
        final r = KcalRange(300, 500);
        final result = r.minus(100);
        expect(result.min, 200);
        expect(result.max, 400);
      });

      test('clamps at 0, never goes negative', () {
        final r = KcalRange(50, 100);
        final result = r.minus(80);
        expect(result.min, 0);
        expect(result.max, 20);
      });

      test('both ends clamp at 0', () {
        final r = KcalRange(50, 100);
        final result = r.minus(200);
        expect(result.min, 0);
        expect(result.max, 0);
      });
    });

    group('midpoint', () {
      test('simple midpoint', () {
        expect(KcalRange(100, 200).midpoint, 150);
      });

      test('rounds to nearest int', () {
        // (100 + 201) / 2 = 150.5 → 151
        expect(KcalRange(100, 201).midpoint, 151);
      });

      test('exact range midpoint', () {
        expect(KcalRange.exact(420).midpoint, 420);
      });
    });

    group('format', () {
      test('range format uses EN DASH', () {
        final formatted = KcalRange(420, 560).format();
        expect(formatted, '420\u2013560 kcal');
        // Verify it's an EN DASH (U+2013), not a hyphen
        expect(formatted.contains('\u2013'), true);
      });

      test('exact format shows single number', () {
        expect(KcalRange.exact(420).format(), '420 kcal');
      });
    });

    group('sum', () {
      test('empty iterable returns KcalRange(0, 0)', () {
        final result = KcalRange.sum([]);
        expect(result, KcalRange(0, 0));
      });

      test('sums multiple ranges', () {
        final ranges = [
          KcalRange(100, 200),
          KcalRange(50, 80),
          KcalRange(30, 40),
        ];
        final result = KcalRange.sum(ranges);
        expect(result.min, 180);
        expect(result.max, 320);
      });
    });

    group('equality', () {
      test('two identical ranges are equal', () {
        expect(KcalRange(100, 200), KcalRange(100, 200));
      });

      test('different ranges are not equal', () {
        expect(KcalRange(100, 200), isNot(KcalRange(100, 201)));
      });
    });

    test('toString is readable', () {
      expect(KcalRange(100, 200).toString(), 'KcalRange(100, 200)');
    });
  });
}
