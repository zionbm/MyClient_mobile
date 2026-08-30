import 'package:flutter/material.dart';

class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.itemBuilder,
    required this.empty,
    required this.errorBuilder,
    this.canLoadMore = false,
    this.onLoadMore,
    this.loadMoreLabel = 'טען עוד',
    this.header,
    this.padding = const EdgeInsets.all(16),
  });

  final Future<List<T>>? future;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;
  final Widget Function(BuildContext context, Object? error) errorBuilder;
  final bool canLoadMore;
  final Future<void> Function()? onLoadMore;
  final String loadMoreLabel;
  final Widget? header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (header == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: padding,
              children: [
                header!,
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: padding,
              children: header == null
                  ? [errorBuilder(context, snapshot.error)]
                  : [header!, errorBuilder(context, snapshot.error)],
            ),
          );
        }
        final items = snapshot.data ?? <T>[];
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: padding,
              children: header == null ? [empty] : [header!, empty],
            ),
          );
        }
        final headerCount = header == null ? 0 : 1;
        final footerCount = canLoadMore ? 1 : 0;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: padding,
            itemCount: headerCount + items.length + footerCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (header != null && index == 0) return header!;
              final itemIndex = index - headerCount;
              if (itemIndex == items.length) {
                return OutlinedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more),
                  label: Text(loadMoreLabel),
                );
              }
              return itemBuilder(context, items[itemIndex]);
            },
          ),
        );
      },
    );
  }
}
