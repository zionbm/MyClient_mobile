import 'package:flutter/material.dart';

import '../../api/api_client.dart';
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
  String _status = 'SENT';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('התראות'),
        actions: [
          IconButton(
            tooltip: 'סמן הכל כנקרא',
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'SENT', label: Text('חדשות')),
                ButtonSegment(value: 'READ', label: Text('נקראו')),
                ButtonSegment(value: 'FAILED', label: Text('נכשלו')),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                setState(() => _status = value.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
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
                    title: 'אין התראות חדשות כרגע',
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
                            onRead: item.status == 'READ'
                                ? null
                                : () => _markRead(item),
                            onSnooze: item.status == 'READ'
                                ? null
                                : (preset) => _snooze(item, preset),
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
            status: _status,
          )
          .then(
            (json) => mapListValue(
              json['notifications'],
            ).map(_NotificationItem.fromJson).toList(),
          );
    });
  }

  Future<void> _markRead(_NotificationItem item) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.markNotificationRead(
        businessId: session.businessId!,
        notificationId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _markAllRead() async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.markAllNotificationsRead(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _snooze(_NotificationItem item, String preset) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.snoozeNotification(
        businessId: session.businessId!,
        notificationId: item.id,
        preset: preset,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onRead,
    required this.onSnooze,
  });

  final _NotificationItem item;
  final VoidCallback? onRead;
  final ValueChanged<String>? onSnooze;

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
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (onRead != null)
                  TextButton.icon(
                    onPressed: onRead,
                    icon: const Icon(Icons.check),
                    label: const Text('נקרא'),
                  ),
                if (onSnooze != null)
                  PopupMenuButton<String>(
                    tooltip: 'דחה',
                    onSelected: onSnooze,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'IN_15_MINUTES',
                        child: Text('עוד 15 דקות'),
                      ),
                      PopupMenuItem(
                        value: 'IN_2_HOURS',
                        child: Text('עוד שעתיים'),
                      ),
                      PopupMenuItem(
                        value: 'TOMORROW_09_00',
                        child: Text('מחר ב-09:00'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.snooze, size: 18),
                          SizedBox(width: 6),
                          Text('דחה'),
                        ],
                      ),
                    ),
                  ),
              ],
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
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String status;
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
