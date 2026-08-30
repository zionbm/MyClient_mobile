import 'package:flutter_test/flutter_test.dart';
import 'package:dev_mobile/src/utils/work_item_time_defaults.dart';

void main() {
  group('recommendedWorkItemStart', () {
    test('uses the nearest full hour about two hours ahead for today', () {
      final now = DateTime(2026, 8, 30, 8, 20);

      final result = recommendedWorkItemStart(
        selectedDate: DateTime(2026, 8, 30),
        now: now,
      );

      expect(result, DateTime(2026, 8, 30, 10));
    });

    test('rounds upward when the two-hour candidate passed half hour', () {
      final now = DateTime(2026, 8, 30, 8, 40);

      final result = recommendedWorkItemStart(
        selectedDate: DateTime(2026, 8, 30),
        now: now,
      );

      expect(result, DateTime(2026, 8, 30, 11));
    });

    test('uses ten in the morning for a later date', () {
      final result = recommendedWorkItemStart(
        selectedDate: DateTime(2026, 9, 3),
        now: DateTime(2026, 8, 30, 8, 40),
      );

      expect(result, DateTime(2026, 9, 3, 10));
    });

    test('moves to tomorrow when the two-hour default crosses midnight', () {
      final result = recommendedWorkItemStart(
        selectedDate: DateTime(2026, 8, 30),
        now: DateTime(2026, 8, 30, 23, 40),
      );

      expect(result, DateTime(2026, 8, 31, 2));
    });
  });

  test('default end time is thirty minutes after the start', () {
    final start = DateTime(2026, 8, 30, 10);

    expect(defaultWorkItemEnd(start), DateTime(2026, 8, 30, 10, 30));
  });
}
