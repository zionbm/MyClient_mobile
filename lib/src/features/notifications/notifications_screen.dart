import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/paging/paged_list_view.dart';
import '../../models/page.dart' as pagination;
import '../../navigation/linked_entity_navigation.dart';
import '../../theme/app_theme.dart';
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
  final Set<String> _readIds = {};
  bool _markingAll = false;

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
      body: Column(
        children: [
          _NotificationsHero(
            markingAll: _markingAll,
            onMarkAllRead: _markAllRead,
          ),
          Expanded(
            child: PagedListView<_NotificationItem>(
              future: _future,
              onRefresh: _refresh,
              canLoadMore: _paging.canLoadMore,
              onLoadMore: _loadMore,
              loadMoreLabel: 'טען עוד התראות',
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              itemBuilder: (context, item) => _NotificationCard(
                item: item,
                isRead: item.isRead || _readIds.contains(item.id),
                onOpen: item.canOpen ? () => _open(item) : null,
              ),
              empty: const _StateCard(
                icon: Icons.notifications_none,
                title: 'הכול שקט כרגע',
                body: 'תזכורות, עדכונים והתראות חשובות יופיעו כאן כשיגיעו.',
              ),
              errorBuilder: (context, error) => _StateCard(
                icon: Icons.cloud_off_outlined,
                title: 'לא הצלחנו לטעון התראות',
                body: _messageFor(error),
              ),
            ),
          ),
        ],
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
    if (!item.isRead && _readIds.add(item.id)) {
      setState(() {});
      unawaited(_markRead(item.id));
    }
    await openLinkedEntity(
      context: context,
      controller: widget.controller,
      type: item.linkedType,
      id: item.linkedId,
      title: item.title,
    );
  }

  Future<void> _markRead(String notificationId) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.notifications.markRead(
        businessId: session.businessId!,
        notificationId: notificationId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
    } catch (_) {
      if (mounted) setState(() => _readIds.remove(notificationId));
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    final session = widget.controller.session!;
    final previouslyReadIds = Set<String>.of(_readIds);
    setState(() {
      _markingAll = true;
      _readIds.addAll(_paging.items.map((item) => item.id));
    });
    try {
      await widget.controller.apiClient.notifications.markAllRead(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא הצלחנו לסמן את ההתראות כנקראו.')),
        );
        setState(() {
          _readIds
            ..clear()
            ..addAll(previouslyReadIds);
        });
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({
    required this.markingAll,
    required this.onMarkAllRead,
  });

  final bool markingAll;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        25,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            top: 0,
            start: 0,
            child: IconButton(
              tooltip: 'חזרה',
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(
                Icons.arrow_forward,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton(
              tooltip: 'סימון הכול כנקרא',
              onPressed: markingAll ? null : onMarkAllRead,
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white54,
              ),
              icon: markingAll
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.done_all_rounded),
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 33,
                backgroundColor: AppColors.primarySoft,
                foregroundColor: Colors.white,
                child: Icon(Icons.notifications_none_rounded, size: 36),
              ),
              SizedBox(height: 14),
              Text(
                'התראות',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'עדכונים שדורשים תשומת לב ופתיחה ישירה לפריט',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD4E6E4), fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isRead,
    required this.onOpen,
  });

  final _NotificationItem item;
  final bool isRead;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onOpen != null,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFFFFBF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead
                  ? AppColors.border
                  : item.accentColor.withValues(alpha: 0.38),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.displayIcon, color: item.accentColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.typeLabel,
                          style: TextStyle(
                            color: item.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 7),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: item.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (item.createdAt != null)
                          Text(
                            formatDateTime(item.createdAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                      ),
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (onOpen != null) ...[
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Text(
                            'פתיחת ${item.typeLabel}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_back_rounded,
                            size: 17,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
  bool get isRead => status.toUpperCase() == 'READ';
  bool get canOpen =>
      linkedType != null && linkedId != null && linkedId!.isNotEmpty;

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

extension on _NotificationItem {
  IconData get displayIcon {
    return switch (linkedType?.toLowerCase()) {
      'reminder' => Icons.notifications_active_outlined,
      'appointment' => Icons.event_outlined,
      'home_visit' => Icons.home_work_outlined,
      'quote' => Icons.request_quote_outlined,
      'customer' => Icons.person_outline,
      _ => Icons.notifications_none_rounded,
    };
  }

  Color get accentColor {
    return switch (linkedType?.toLowerCase()) {
      'appointment' || 'home_visit' => AppColors.visit,
      'quote' => AppColors.quote,
      _ => AppColors.accent,
    };
  }

  String get typeLabel {
    return switch (linkedType?.toLowerCase()) {
      'reminder' => 'תזכורת',
      'appointment' => 'פגישה',
      'home_visit' => 'ביקור בית',
      'quote' => 'הצעת מחיר',
      'customer' => 'לקוח',
      _ => 'עדכון',
    };
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFDDEEE9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
