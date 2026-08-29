import 'package:flutter/foundation.dart';

import '../../models/page.dart';

typedef PageLoader<T> = Future<Page<T>> Function(String? cursor);

/// Owns one cursor-based collection and prevents overlapping page requests.
class PagingController<T> extends ChangeNotifier {
  PagingController(this._loadPage, {required Object? Function(T item) itemKey})
    : _itemKey = itemKey;

  final PageLoader<T> _loadPage;
  final Object? Function(T item) _itemKey;
  final List<T> _items = [];
  PageInfo _pageInfo = const PageInfo(hasMore: false);
  Object? _error;
  bool _loading = false;

  List<T> get items => List.unmodifiable(_items);
  PageInfo get pageInfo => _pageInfo;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get canLoadMore => _pageInfo.hasMore && !_loading;

  Future<void> refresh() => _load(reset: true);
  Future<void> loadMore() => canLoadMore ? _load(reset: false) : Future.value();

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _loadPage(reset ? null : _pageInfo.nextCursor);
      if (reset) _items.clear();
      final existingKeys = _items.map(_itemKey).toSet();
      _items.addAll(
        page.items.where((item) => existingKeys.add(_itemKey(item))),
      );
      _pageInfo = page.pageInfo;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
