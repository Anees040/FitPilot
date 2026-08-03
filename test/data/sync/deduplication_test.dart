import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/data/sync/sync_service.dart';

void main() {
  group('SyncService push-batch de-duplication', () {
    test('deduplicateRows keeps the newest entry for weight_entries based on user_id and for_date', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'a',
          'user_id': 'u1',
          'for_date': '2023-10-01',
          'weight_kg': 70.0,
          'updated_at': '2023-10-01T10:00:00Z',
        },
        {
          'id': 'b',
          'user_id': 'u1',
          'for_date': '2023-10-01',
          'weight_kg': 71.0,
          'updated_at': '2023-10-01T12:00:00Z', // Newer!
        },
        {
          'id': 'c',
          'user_id': 'u1',
          'for_date': '2023-10-02',
          'weight_kg': 69.5,
          'updated_at': '2023-10-02T08:00:00Z',
        }
      ];

      final unique = SyncService.deduplicateRows('weight_entries', rows);

      expect(unique.length, 2);
      expect(unique.containsKey('u1_2023-10-01'), true);
      expect(unique.containsKey('u1_2023-10-02'), true);

      // The 2023-10-01 entry should be the newer one (id = 'b', weight = 71.0)
      expect(unique['u1_2023-10-01']!['id'], 'b');
      expect(unique['u1_2023-10-01']!['weight_kg'], 71.0);
    });

    test('deduplicateRows keeps the newest entry for regular tables based on id', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'log1',
          'user_id': 'u1',
          'quantity': 1.0,
          'updated_at': '2023-10-01T10:00:00Z',
        },
        {
          'id': 'log1',
          'user_id': 'u1',
          'quantity': 2.0,
          'updated_at': '2023-10-01T12:00:00Z', // Newer!
        },
        {
          'id': 'log2',
          'user_id': 'u1',
          'quantity': 3.0,
          'updated_at': '2023-10-02T08:00:00Z',
        }
      ];

      final unique = SyncService.deduplicateRows('food_logs', rows);

      expect(unique.length, 2);
      expect(unique.containsKey('log1'), true);
      expect(unique.containsKey('log2'), true);

      // The log1 entry should be the newer one (quantity = 2.0)
      expect(unique['log1']!['quantity'], 2.0);
    });
  });
}
