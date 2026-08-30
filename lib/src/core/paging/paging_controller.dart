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
  bool _refreshQueued = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _activeLoad;

  List<T> get items => List.unmodifiable(_items);
  PageInfo get pageInfo => _pageInfo;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get canLoadMore => _pageInfo.hasMore && !_loading;

  Future<void> refresh() => _load(reset: true, throwOnError: true);
  Future<void> loadMore() =>
      canLoadMore ? _load(reset: false, throwOnError: false) : Future.value();

  Future<void> _load({required bool reset, required bool throwOnError}) async {
    if (_disposed) return;
    if (_loading) {
      if (reset) _refreshQueued = true;
      await _activeLoad;
      if (throwOnError && _error != null) {
        Error.throwWithStackTrace(_error!, StackTrace.current);
      }
      return;
    }

    _activeLoad = _runLoads(initialReset: reset);
    await _activeLoad;
    if (throwOnError && _error != null) {
      Error.throwWithStackTrace(_error!, StackTrace.current);
    }
  }

  Future<void> _runLoads({required bool initialReset}) async {
    var reset = initialReset;
    _loading = true;
    _notify();

    do {
      _refreshQueued = false;
      _error = null;
      final requestGeneration = ++_generation;
      try {
        final page = await _loadPage(reset ? null : _pageInfo.nextCursor);
        if (_disposed || requestGeneration != _generation) return;
        if (reset) _items.clear();
        final existingKeys = _items.map(_itemKey).toSet();
        _items.addAll(
          page.items.where((item) => existingKeys.add(_itemKey(item))),
        );
        _pageInfo = page.pageInfo;
      } catch (error) {
        if (_disposed || requestGeneration != _generation) return;
        _error = error;
      }
      reset = _refreshQueued;
    } while (_refreshQueued && !_disposed);

    _loading = false;
    _activeLoad = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    super.dispose();
  }
}
