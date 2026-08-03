import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/core/utils/type_readers.dart';

void main() {
  group('TolerantReader Tests', () {
    test('readBool converts inputs properly', () {
      expect(TolerantReader.readBool(true), isTrue);
      expect(TolerantReader.readBool('true'), isTrue);
      expect(TolerantReader.readBool('True'), isTrue);
      expect(TolerantReader.readBool(1), isTrue);
      expect(TolerantReader.readBool('1'), isTrue);

      expect(TolerantReader.readBool(false), isFalse);
      expect(TolerantReader.readBool('false'), isFalse);
      expect(TolerantReader.readBool('False'), isFalse);
      expect(TolerantReader.readBool(0), isFalse);
      expect(TolerantReader.readBool('0'), isFalse);

      expect(TolerantReader.readBool(null), isNull);
      expect(TolerantReader.readBool('invalid'), isNull);
    });

    test('readInt converts inputs properly', () {
      expect(TolerantReader.readInt(42), 42);
      expect(TolerantReader.readInt(42.9), 42);
      expect(TolerantReader.readInt('42'), 42);
      expect(TolerantReader.readInt('42.9'), 42);
      expect(TolerantReader.readInt(null), isNull);
      expect(TolerantReader.readInt('invalid'), isNull);
    });

    test('readDouble converts inputs properly', () {
      expect(TolerantReader.readDouble(42.5), 42.5);
      expect(TolerantReader.readDouble(42), 42.0);
      expect(TolerantReader.readDouble('42.5'), 42.5);
      expect(TolerantReader.readDouble('42'), 42.0);
      expect(TolerantReader.readDouble(null), isNull);
      expect(TolerantReader.readDouble('invalid'), isNull);
    });

    test('toSqliteValue maps primitives and booleans properly', () {
      expect(TolerantReader.toSqliteValue(true), 1);
      expect(TolerantReader.toSqliteValue(false), 0);
      expect(TolerantReader.toSqliteValue(42), 42);
      expect(TolerantReader.toSqliteValue(42.5), 42.5);
      expect(TolerantReader.toSqliteValue('test'), 'test');
      expect(TolerantReader.toSqliteValue(null), isNull);
      
      final list = [1, 2, 3];
      expect(TolerantReader.toSqliteValue(list), '[1, 2, 3]');
    });
  });
}
