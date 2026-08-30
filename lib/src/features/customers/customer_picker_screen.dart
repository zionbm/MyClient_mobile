import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/paging/paging_controller.dart';
import '../../models/customer.dart';
import '../../models/page.dart' as pagination;
import '../auth/session_controller.dart';

class CustomerPickerScreen extends StatefulWidget {
  const CustomerPickerScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<CustomerPickerScreen> createState() => _CustomerPickerScreenState();
}

class _CustomerPickerScreenState extends State<CustomerPickerScreen> {
  final _queryController = TextEditingController();
  late PagingController<Customer> _paging;
  Future<List<Customer>>? _future;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _replacePaging(notify: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('בחירת לקוח')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'חיפוש לפי שם, טלפון או כתובת',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'נקה',
                        onPressed: () {
                          _queryController.clear();
                          _replacePaging();
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (_) {
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  _replacePaging,
                );
              },
              onSubmitted: (_) => _replacePaging(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _PickerState(
                    icon: Icons.cloud_off_outlined,
                    text: _messageFor(snapshot.error),
                    action: TextButton(
                      onPressed: _refresh,
                      child: const Text('נסה שוב'),
                    ),
                  );
                }
                final customers = snapshot.data ?? const <Customer>[];
                if (customers.isEmpty) {
                  return const _PickerState(
                    icon: Icons.person_search_outlined,
                    text: 'לא נמצאו לקוחות מתאימים',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: customers.length + (_paging.canLoadMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == customers.length) {
                        return OutlinedButton.icon(
                          onPressed: _loadMore,
                          icon: const Icon(Icons.expand_more),
                          label: const Text('טען עוד לקוחות'),
                        );
                      }
                      final customer = customers[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(customer.name),
                          subtitle: Text(
                            [
                              if (customer.phone != null) customer.phone!,
                              if (customer.address != null) customer.address!,
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.of(context).pop(customer),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _replacePaging({bool notify = true}) {
    if (notify) _paging.dispose();
    final paging = PagingController<Customer>(
      _loadPage,
      itemKey: (customer) => customer.id,
    );
    _paging = paging;
    final future = paging.refresh().then((_) => paging.items);
    if (notify) {
      setState(() => _future = future);
    } else {
      _future = future;
    }
  }

  Future<pagination.Page<Customer>> _loadPage(String? cursor) {
    final session = widget.controller.session!;
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      return widget.controller.apiClient.customers.list(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        limit: 50,
        cursor: cursor,
      );
    }
    return widget.controller.apiClient.customers.search(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      query: query,
      limit: 50,
      cursor: cursor,
    );
  }

  Future<void> _refresh() async {
    final paging = _paging;
    setState(() => _future = paging.refresh().then((_) => paging.items));
    await _future;
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (!mounted) return;
    if (_paging.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(_paging.error))));
    }
    setState(() => _future = Future.value(_paging.items));
  }

  String _messageFor(Object? error) {
    return error is ApiException ? error.message : 'לא הצלחנו לטעון לקוחות';
  }
}

class _PickerState extends StatelessWidget {
  const _PickerState({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 72),
        Icon(icon, size: 48),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
        if (action != null) Center(child: action),
      ],
    );
  }
}
