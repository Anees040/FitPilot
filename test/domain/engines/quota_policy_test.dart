import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/quota_policy.dart';

void main() {
  group('QuotaPolicy', () {
    const policy = QuotaPolicy(dailyLimit: 3);

    test('canUsePhoto is true when used < limit', () {
      expect(policy.canUsePhoto(0), isTrue);
      expect(policy.canUsePhoto(2), isTrue);
    });

    test('canUsePhoto is false when used >= limit', () {
      expect(policy.canUsePhoto(3), isFalse);
      expect(policy.canUsePhoto(4), isFalse);
    });

    test('remaining clamps at 0', () {
      expect(policy.remaining(0), 3);
      expect(policy.remaining(3), 0);
      expect(policy.remaining(5), 0);
    });

    test('nextResetAt is local midnight tomorrow', () {
      final now = DateTime(2026, 7, 27, 15, 30);
      final reset = policy.nextResetAt(now);

      expect(reset.year, 2026);
      expect(reset.month, 7);
      expect(reset.day, 28);
      expect(reset.hour, 0);
      expect(reset.minute, 0);
    });
  });
}
