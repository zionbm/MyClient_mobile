class PageInfo {
  const PageInfo({required this.hasMore, this.nextCursor});

  final bool hasMore;
  final String? nextCursor;

  factory PageInfo.fromJson(Object? value) {
    final json = value is Map<String, Object?>
        ? value
        : const <String, Object?>{};
    return PageInfo(
      hasMore: json['hasMore'] == true,
      nextCursor: json['nextCursor'] is String
          ? json['nextCursor'] as String
          : null,
    );
  }
}

class Page<T> {
  const Page({required this.items, required this.pageInfo});

  final List<T> items;
  final PageInfo pageInfo;
}
