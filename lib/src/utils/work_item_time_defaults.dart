DateTime recommendedWorkItemStart({
  required DateTime selectedDate,
  required DateTime now,
}) {
  final isToday =
      selectedDate.year == now.year &&
      selectedDate.month == now.month &&
      selectedDate.day == now.day;
  if (!isToday) {
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      10,
    );
  }

  final candidate = now.add(const Duration(hours: 2));
  final roundedHour = candidate.minute >= 30
      ? candidate.add(const Duration(hours: 1))
      : candidate;
  return DateTime(
    roundedHour.year,
    roundedHour.month,
    roundedHour.day,
    roundedHour.hour,
  );
}

DateTime defaultWorkItemEnd(DateTime startsAt) {
  return startsAt.add(const Duration(minutes: 30));
}
