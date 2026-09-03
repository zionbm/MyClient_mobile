import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/paging/paging_controller.dart';
import '../../models/page.dart' as pagination;
import '../../navigation/linked_entity_navigation.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class V2SearchScreen extends StatefulWidget {
  const V2SearchScreen({super.key, required this.controller});
  final SessionController controller;

  @override
  State<V2SearchScreen> createState() => _V2SearchScreenState();
}

class _V2SearchScreenState extends State<V2SearchScreen> {
  Timer? _debounce;
  Future<List<_SearchResult>>? _future;
  late final PagingController<_SearchResult> _paging;
  String _target = 'all';
  String _status = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _paging = PagingController<_SearchResult>(
      _loadPage,
      itemKey: (result) => '${result.type}:${result.id}',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('חיפוש בעסק')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'שם לקוח, משימה או פעילות',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _changed,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('הכול')),
                    ButtonSegment(value: 'customers', label: Text('לקוחות')),
                    ButtonSegment(value: 'tasks', label: Text('משימות')),
                    ButtonSegment(value: 'jobs', label: Text('עבודות')),
                    ButtonSegment(value: 'visits', label: Text('ביקורים')),
                  ],
                  selected: {_target},
                  onSelectionChanged: (value) {
                    setState(() => _target = value.single);
                    _search();
                  },
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'מצב',
                  prefixIcon: Icon(Icons.filter_alt_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('כל המצבים')),
                  DropdownMenuItem(value: 'open', child: Text('פתוחים')),
                  DropdownMenuItem(value: 'closed', child: Text('הושלמו')),
                  DropdownMenuItem(value: 'cancelled', child: Text('בוטלו')),
                ],
                onChanged: (value) {
                  if (value == null || value == _status) return;
                  setState(() => _status = value);
                  _search();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<_SearchResult>>(
            future: _future,
            builder: (context, snapshot) {
              if (_query.length < 2) {
                return const Center(child: Text('אפשר להתחיל להקליד'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('לא הצלחנו לבצע חיפוש'));
              }
              final items = snapshot.data ?? const <_SearchResult>[];
              if (items.isEmpty) {
                return const Center(child: Text('לא נמצאו תוצאות'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length + (_paging.canLoadMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  if (index == items.length) {
                    return OutlinedButton.icon(
                      onPressed: _paging.isLoading ? null : _loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('טען תוצאות נוספות'),
                    );
                  }
                  final result = items[index];
                  final item = result.item;
                  final type = result.type;
                  return Card(
                    child: ListTile(
                      leading: Icon(_icon(type)),
                      title: Text(
                        stringValue(
                          item[type == 'customer' ? 'name' : 'title'],
                        ),
                      ),
                      subtitle: Text(_label(type, item)),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => openLinkedEntity(
                        context: context,
                        controller: widget.controller,
                        type: type,
                        id: nullableString(item['id']),
                        customer: item['customer'],
                        title: nullableString(item['title']),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  void _changed(String value) {
    _query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
    setState(() {});
  }

  void _search() {
    if (_query.length < 2) return;
    setState(() {
      _future = _paging.refresh().then((_) => _paging.items);
    });
  }

  Future<pagination.Page<_SearchResult>> _loadPage(String? cursor) async {
    final session = widget.controller.session!;
    final response = await widget.controller.apiClient.v2Search.search(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      query: _query,
      target: _target,
      status: _status,
      cursor: cursor,
    );
    return pagination.Page(
      items: mapListValue(
        response['items'],
      ).map(_SearchResult.fromJson).toList(growable: false),
      pageInfo: pagination.PageInfo.fromJson(response['pageInfo']),
    );
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
  }

  IconData _icon(String type) => switch (type) {
    'customer' => Icons.person_outline,
    'task' => Icons.task_alt_outlined,
    'visit' => Icons.home_work_outlined,
    _ => Icons.work_outline,
  };

  String _label(String type, Map<String, Object?> item) {
    if (type == 'customer') return 'לקוח';
    final customer = mapValue(item['customer']);
    return [
      switch (type) {
        'task' => 'משימה',
        'visit' => 'ביקור',
        _ => 'עבודה',
      },
      nullableString(customer['name']),
    ].whereType<String>().join(' · ');
  }
}

class _SearchResult {
  const _SearchResult({required this.type, required this.item});
  final String type;
  final Map<String, Object?> item;

  String get id => nullableString(item['id']) ?? '';

  factory _SearchResult.fromJson(Map<String, Object?> json) => _SearchResult(
    type: stringValue(json['type']),
    item: mapValue(json['item']),
  );
}
