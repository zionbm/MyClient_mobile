import 'dart:async';

import 'package:flutter/material.dart';

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
  Future<Map<String, Object?>>? _future;
  String _target = 'all';
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
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
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('הכול')),
                  ButtonSegment(value: 'customers', label: Text('לקוחות')),
                  ButtonSegment(value: 'jobs', label: Text('עבודות')),
                  ButtonSegment(value: 'visits', label: Text('ביקורים')),
                ],
                selected: {_target},
                onSelectionChanged: (value) {
                  setState(() => _target = value.single);
                  _search();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, Object?>>(
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
              final items = mapListValue(snapshot.data?['items']);
              if (items.isEmpty) {
                return const Center(child: Text('לא נמצאו תוצאות'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final result = items[index];
                  final item = mapValue(result['item']);
                  final type = stringValue(result['type']);
                  return Card(
                    child: ListTile(
                      leading: Icon(_icon(type)),
                      title: Text(
                        stringValue(
                          item[type == 'customer' ? 'name' : 'title'],
                        ),
                      ),
                      subtitle: Text(_label(type, item)),
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
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient.v2Search.search(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        query: _query,
        target: _target,
      );
    });
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
