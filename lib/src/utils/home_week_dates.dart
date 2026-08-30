List<DateTime> centeredHomeWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(
    7,
    (index) => today.add(Duration(days: index - 3)),
    growable: false,
  );
}

bool isSameCalendarDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
