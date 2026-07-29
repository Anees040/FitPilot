import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/features/log/presentation/widgets/kcal_range_text.dart';

void main() {
  group('KcalRange Format', () {
    test('format() appends kcal and is not duplicated in KcalRangeText', () {
      final range = KcalRange(100, 200);
      final exact = KcalRange.exact(150);

      expect(range.format(), '100\u2013200 kcal');
      expect(exact.format(), '150 kcal');
      
      expect(range.format().contains('kcal kcal'), isFalse);
      expect(exact.format().contains('kcal kcal'), isFalse);

      final widget = KcalRangeText(range: KcalRange(10, 20));
      expect(widget.suffix, '');
    });
  });
}
