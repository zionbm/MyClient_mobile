import 'package:dev_mobile/src/utils/home_week_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home week keeps today in the middle with three days on each side', () {
    final dates = centeredHomeWeek(DateTime(2026, 8, 30, 18, 45));

    expect(dates, <DateTime>[
      DateTime(2026, 8, 27),
      DateTime(2026, 8, 28),
      DateTime(2026, 8, 29),
      DateTime(2026, 8, 30),
      DateTime(2026, 8, 31),
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 2),
    ]);
  });

  test('calendar day comparison ignores the time of day', () {
    expect(
      isSameCalendarDay(DateTime(2026, 8, 30, 8), DateTime(2026, 8, 30, 22)),
      isTrue,
    );
  });
}
