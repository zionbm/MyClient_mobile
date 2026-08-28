import 'package:flutter/material.dart';

import '../../api/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('היסטוריית התראות')),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<List<_NotificationItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _StateCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'לא הצלחנו לטעון התראות',
                    body: _messageFor(snapshot.error),
                  );
                }
                final items = snapshot.data ?? const <_NotificationItem>[];
                if (items.isEmpty) {
                  return const _StateCard(
                    icon: Icons.notifications_none,
                    title: 'אין התראות עדיין',
                    body: 'כאשר יהיו תזכורות או התראות מערכת הן יופיעו כאן.',
                  );
                }
                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NotificationCard(
                            item: item,
                            onOpen: item.linkedType == null
                                ? null
                                : () => _open(item),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _load() {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient
          .listNotifications(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          )
          .then(
            (json) => mapListValue(
              json['notifications'],
            ).map(_NotificationItem.fromJson).toList(),
          );
    });
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
        json['itemType'] ?? (json['taskId'] == null ? null : 'callback'),
      ),
      linkedId: nullableString(json['itemId'] ?? json['taskId']),
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
