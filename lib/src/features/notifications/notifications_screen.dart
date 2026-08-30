import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/paging/paged_list_view.dart';
import '../../models/page.dart' as pagination;
import '../../navigation/linked_entity_navigation.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<_NotificationItem>>? _future;
  late final PagingController<_NotificationItem> _paging;

  @override
  void initState() {
    super.initState();
    _paging = PagingController<_NotificationItem>(
      _loadPage,
      itemKey: (item) => item.id,
    );
    _load();
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('היסטוריית התראות')),
      body: PagedListView<_NotificationItem>(
        future: _future,
        onRefresh: _refresh,
        canLoadMore: _paging.canLoadMore,
        onLoadMore: _loadMore,
        loadMoreLabel: 'טען עוד התראות',
        itemBuilder: (context, item) => _NotificationCard(
          item: item,
          onOpen: item.linkedType == null ? null : () => _open(item),
        ),
        empty: const _StateCard(
          icon: Icons.notifications_none,
          title: 'אין התראות עדיין',
          body: 'כאשר יהיו תזכורות או התראות מערכת הן יופיעו כאן.',
        ),
        errorBuilder: (context, error) => _StateCard(
          icon: Icons.cloud_off_outlined,
          title: 'לא הצלחנו לטעון התראות',
          body: _messageFor(error),
        ),
      ),
    );
  }

  void _load() {
    setState(() {
      _future = _paging.refresh().then((_) => _paging.items);
    });
  }

  Future<void> _refresh() async {
    final paging = _paging;
    setState(() => _future = paging.refresh().then((_) => paging.items));
    await _future;
  }

  Future<pagination.Page<_NotificationItem>> _loadPage(String? cursor) async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.notifications.list(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      limit: 50,
      cursor: cursor,
    );
    return pagination.Page(
      items: mapListValue(
        json['notifications'],
      ).map(_NotificationItem.fromJson).toList(),
      pageInfo: pagination.PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
  }

  Future<void> _open(_NotificationItem item) async {
    await openLinkedEntity(
      context: context,
      controller: widget.controller,
      type: item.linkedType,
      id: item.linkedId,
      title: item.title,
    );
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onOpen});

  final _NotificationItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.notifications_none),
              ),
              title: Text(item.title),
              subtitle: Text(
                [
                  item.body,
                  if (item.createdAt != null) formatDateTime(item.createdAt),
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
              trailing: onOpen == null ? null : const Icon(Icons.chevron_left),
              onTap: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    this.linkedType,
    this.linkedId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String status;
  final String? linkedType;
  final String? linkedId;
  final DateTime? createdAt;

  factory _NotificationItem.fromJson(Map<String, Object?> json) {
    return _NotificationItem(
      id: stringValue(json['id']),
      title: stringValue(
        json['title'] ?? json['subject'] ?? json['type'],
        fallback: 'התראה',
      ),
      body: stringValue(
        json['body'] ?? json['message'] ?? json['text'],
        fallback: 'התראה ממערכת MyClient',
      ),
      status: stringValue(json['status'], fallback: 'SENT'),
      linkedType: nullableString(
        json['itemType'] ?? (json['reminderId'] == null ? null : 'reminder'),
      ),
      linkedId: nullableString(json['itemId'] ?? json['reminderId']),
      createdAt: dateValue(json['createdAt'] ?? json['sentAt']),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
