String stringValue(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value;
  if (value is num || value is bool) return value.toString();
  return fallback;
}

String? nullableString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

DateTime? dateValue(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, Object?> mapValue(Object? value) {
  return value is Map<String, Object?> ? value : const <String, Object?>{};
}

List<Map<String, Object?>> mapListValue(Object? value) {
  return (value as List?)?.whereType<Map<String, Object?>>().toList() ??
      const <Map<String, Object?>>[];
}
