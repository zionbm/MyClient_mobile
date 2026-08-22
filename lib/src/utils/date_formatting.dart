String formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String formatShortTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime? date) {
  if (date == null) return '';
  return '${formatShortDate(date.toLocal())} ${formatShortTime(date.toLocal())}';
}

DateTime combineDateAndTime(DateTime date, int hour, int minute) {
  return DateTime(date.year, date.month, date.day, hour, minute);
}
