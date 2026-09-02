import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../core/state/data_invalidator.dart';
import '../../core/paging/paging_controller.dart';
import '../../models/customer.dart';
import '../../models/page.dart' as pagination;
import '../../navigation/linked_entity_navigation.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../../widgets/pending_actions_icon_button.dart';
import '../auth/session_controller.dart';
import '../notifications/notifications_screen.dart';
import '../v2/v2_customers_screen.dart';
import '../v2/v2_pending_actions_screen.dart';
import '../v2/v2_search_screen.dart';

enum _CallFilter { all, attention, messages, handled }

class CallsScreen extends StatefulWidget {
  const CallsScreen({
    super.key,
    required this.controller,
    this.pendingActionsCountFuture,
  });

  final SessionController controller;
  final Future<int>? pendingActionsCountFuture;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  Future<List<_CallItem>>? _future;
  late final PagingController<_CallItem> _paging;
  late int _seenDataVersion;
  _CallFilter _filter = _CallFilter.all;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.calls,
    );
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _paging = PagingController<_CallItem>(
      _loadPage,
      itemKey: (item) => item.id,
    );
    _future = _paging.refresh().then((_) {
      if (mounted) setState(() {});
      return _paging.items;
    });
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    _paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CallsHero(
          attentionCount: _paging.items.where(_needsAttention).length,
          handledThisWeek: _paging.items.where(_handledThisWeek).length,
          pendingActionsCountFuture: widget.pendingActionsCountFuture,
          onSearch: _openSearch,
          onPendingActions: _openPendingActions,
          onNotifications: _openNotifications,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _CallFilterBar(
            selected: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<_CallItem>>(
              future: _future,
              builder: _buildCalls,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalls(
    BuildContext context,
    AsyncSnapshot<List<_CallItem>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        children: const [
          SizedBox(height: 72),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (snapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _InfoCard(
            icon: Icons.cloud_off_outlined,
            title: 'לא הצלחנו לטעון שיחות',
            body: snapshot.error is ApiException
                ? (snapshot.error! as ApiException).message
                : 'בדוק שהשרת המקומי זמין.',
          ),
        ],
      );
    }
    final calls = (snapshot.data ?? const []).where(_matchesFilter).toList();
    if (calls.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: const [
          _InfoCard(
            icon: Icons.call_outlined,
            title: 'אין שיחות להצגה',
            body: 'שיחות מהמזכירה הווירטואלית יופיעו כאן.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: calls.length + (_paging.canLoadMore ? 2 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            'שיחות אחרונות',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          );
        }
        final callIndex = index - 1;
        if (callIndex == calls.length) {
          return OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('טען עוד שיחות'),
          );
        }
        return _callCard(calls[callIndex]);
      },
    );
  }

  Widget _callCard(_CallItem call) {
    final color = _colorFor(call);
    final title = call.customer?.name ?? call.fromNumber ?? 'מספר לא ידוע';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          right: BorderSide(color: color, width: 5),
          top: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
          left: const BorderSide(color: AppColors.border),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openCall(call),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
                child: call.customer == null
                    ? const Icon(Icons.call_outlined)
                    : Text(
                        _initials(call.customer!.name),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _CallStatusPill(
                          label: _statusLabel(call),
                          color: color,
                        ),
                      ],
                    ),
                    if (call.customer != null && call.fromNumber != null)
                      Text(
                        call.fromNumber!,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(_intentIcon(call), size: 18, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _label(call.ivrSelection).isEmpty
                                ? _label(call.displayStatus)
                                : _label(call.ivrSelection),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (call.calledAt != null)
                          Text(
                            formatDateTime(call.calledAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    if (call.transcriptPreview != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        call.transcriptPreview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                    if (_needsAttention(call) && call.fromNumber != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: () => _callBack(call.fromNumber!),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: color,
                            side: BorderSide(color: color),
                            minimumSize: const Size(0, 42),
                          ),
                          icon: const Icon(Icons.call_outlined, size: 19),
                          label: const Text('חזרה לשיחה'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.chevron_left, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.calls,
    );
    setState(() => _future = _paging.refresh().then((_) => _paging.items));
    await _future;
    if (mounted) setState(() {});
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataInvalidator.revision(
      DataScope.calls,
    );
    if (currentVersion == _seenDataVersion) return;
    _refresh();
  }

  Future<pagination.Page<_CallItem>> _loadPage(String? cursor) async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.calls.list(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      limit: 50,
      cursor: cursor,
    );
    return pagination.Page(
      items: mapListValue(json['calls']).map(_CallItem.fromJson).toList(),
      pageInfo: pagination.PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
  }

  bool _matchesFilter(_CallItem call) => switch (_filter) {
    _CallFilter.all => true,
    _CallFilter.attention => _needsAttention(call),
    _CallFilter.messages =>
      call.ivrSelection == 'MESSAGE_RECORDED' ||
          call.ivrSelection == 'URGENT_MESSAGE',
    _CallFilter.handled => _isHandled(call),
  };

  bool _needsAttention(_CallItem call) {
    if (_isHandled(call)) return false;
    return call.urgent ||
        call.ivrSelection == 'CALLBACK_REQUESTED' ||
        call.ivrSelection == 'MESSAGE_RECORDED' ||
        call.ivrSelection == 'URGENT_MESSAGE';
  }

  bool _isHandled(_CallItem call) =>
      call.displayStatus == 'REMINDER_CREATED' ||
      call.displayStatus == 'REMINDER_DONE' ||
      call.displayStatus == 'NO_ACTION';

  bool _handledThisWeek(_CallItem call) {
    final calledAt = call.calledAt;
    if (calledAt == null || !_isHandled(call)) return false;
    return calledAt.isAfter(DateTime.now().subtract(const Duration(days: 7)));
  }

  String _statusLabel(_CallItem call) {
    if (call.urgent) return 'דחוף';
    if (_isHandled(call)) return 'טופל';
    if (call.ivrSelection == 'MESSAGE_RECORDED') return 'הודעה';
    return 'דורש טיפול';
  }

  Color _colorFor(_CallItem call) {
    if (call.urgent) return AppColors.accent;
    if (_isHandled(call)) return AppColors.success;
    if (call.ivrSelection == 'MESSAGE_RECORDED') return AppColors.visit;
    return AppColors.quote;
  }

  IconData _intentIcon(_CallItem call) => switch (call.ivrSelection) {
    'CALLBACK_REQUESTED' => Icons.phone_callback_outlined,
    'MESSAGE_RECORDED' => Icons.voicemail_outlined,
    'URGENT_MESSAGE' => Icons.priority_high,
    _ when _isHandled(call) => Icons.task_alt,
    _ => Icons.call_outlined,
  };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }

  Future<void> _openCall(_CallItem call) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _CallDetailScreen(controller: widget.controller, call: call),
      ),
    );
    _refresh();
  }

  Future<void> _callBack(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone));

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2SearchScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openPendingActions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2PendingActionsScreen(controller: widget.controller),
      ),
    );
    widget.controller.refreshPendingActions();
  }

  String _label(String? value) {
    return switch (value) {
      'CALLBACK_REQUESTED' => 'בקשת חזרה',
      'MESSAGE_RECORDED' => 'הוקלטה הודעה',
      'URGENT_MESSAGE' => 'דחוף',
      'NO_SELECTION' => 'לא נבחרה אפשרות',
      'TASK_CREATED' => 'נוצרה משימה',
      'TASK_DONE' => 'טופל',
      'NO_ACTION' => 'ללא פעולה',
      null => '',
      _ => value,
    };
  }
}

class _CallsHero extends StatelessWidget {
  const _CallsHero({
    required this.attentionCount,
    required this.handledThisWeek,
    required this.pendingActionsCountFuture,
    required this.onSearch,
    required this.onPendingActions,
    required this.onNotifications,
  });

  final int attentionCount;
  final int handledThisWeek;
  final Future<int>? pendingActionsCountFuture;
  final VoidCallback onSearch;
  final VoidCallback onPendingActions;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 10,
        18,
        16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'שיחות',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'השיחות שהמזכירה טיפלה בהן',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.search),
                tooltip: 'חיפוש',
              ),
              PendingActionsIconButton(
                countFuture: pendingActionsCountFuture,
                onPressed: onPendingActions,
              ),
              IconButton(
                onPressed: onNotifications,
                icon: const Icon(Icons.notifications_none),
                tooltip: 'התראות',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _CallSummaryCard(
                  value: '$attentionCount',
                  label: 'דורשות טיפול',
                  icon: Icons.priority_high,
                  iconColor: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CallSummaryCard(
                  value: '$handledThisWeek',
                  label: 'טופלו השבוע',
                  icon: Icons.check,
                  iconColor: AppColors.primaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallSummaryCard extends StatelessWidget {
  const _CallSummaryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconColor.withValues(alpha: 0.22),
            foregroundColor: iconColor,
            child: Icon(icon, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallFilterBar extends StatelessWidget {
  const _CallFilterBar({required this.selected, required this.onChanged});

  final _CallFilter selected;
  final ValueChanged<_CallFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _CallFilter.values
            .map((filter) {
              final isSelected = selected == filter;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(_label(filter)),
                  selected: isSelected,
                  onSelected: (_) => onChanged(filter),
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _label(_CallFilter filter) => switch (filter) {
    _CallFilter.all => 'הכול',
    _CallFilter.attention => 'דורש טיפול',
    _CallFilter.messages => 'הודעות',
    _CallFilter.handled => 'טופלו',
  };
}

class _CallStatusPill extends StatelessWidget {
  const _CallStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CallDetailScreen extends StatelessWidget {
  const _CallDetailScreen({required this.controller, required this.call});

  final SessionController controller;
  final _CallItem call;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פרטי שיחה')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.fromNumber ?? 'מספר לא ידוע',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  _DetailLine(label: 'סטטוס', value: call.displayStatus),
                  _DetailLine(label: 'בחירה במענה', value: call.ivrSelection),
                  if (call.toNumber != null)
                    _DetailLine(label: 'מספר המזכירה', value: call.toNumber),
                  if (call.calledAt != null)
                    _DetailLine(
                      label: 'זמן שיחה',
                      value: formatDateTime(call.calledAt),
                    ),
                  if (call.urgent)
                    const _DetailLine(label: 'דחיפות', value: 'דחוף'),
                ],
              ),
            ),
          ),
          if (call.transcriptPreview != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'תמלול',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(call.transcriptPreview!),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (call.customer != null)
            FilledButton.icon(
              onPressed: () => openLinkedEntity(
                context: context,
                controller: controller,
                type: 'customer',
                id: call.customer!.id,
                customer: call.customer,
              ),
              icon: const Icon(Icons.person_outline),
              label: Text('פתח את ${call.customer!.name}'),
            ),
          if (call.customer == null && call.fromNumber != null)
            FilledButton.icon(
              onPressed: () => _createCustomerFromCall(context),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('צור לקוח מהשיחה'),
            ),
          if (call.relatedTaskId != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openLinkedEntity(
                context: context,
                controller: controller,
                type: 'task',
                id: call.relatedTaskId,
                customer: call.customer,
                title: 'חזרה ללקוח מהשיחה',
              ),
              icon: const Icon(Icons.alarm_outlined),
              label: const Text('פתח משימה קשורה'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createCustomerFromCall(BuildContext context) async {
    final changed = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2CustomerFormScreen(
          controller: controller,
          initialName: 'לקוח מהשיחה',
          initialPhone: call.fromNumber,
        ),
      ),
    );
    if (changed == true) controller.markDataChanged({DataScope.calls});
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }
}

class _CallItem {
  const _CallItem({
    required this.id,
    this.fromNumber,
    this.toNumber,
    this.calledAt,
    this.ivrSelection,
    this.displayStatus,
    this.urgent = false,
    this.transcriptPreview,
    this.relatedTaskId,
    this.customer,
  });

  final String id;
  final String? fromNumber;
  final String? toNumber;
  final DateTime? calledAt;
  final String? ivrSelection;
  final String? displayStatus;
  final bool urgent;
  final String? transcriptPreview;
  final String? relatedTaskId;
  final Customer? customer;

  factory _CallItem.fromJson(Map<String, Object?> json) {
    final relatedTask = mapValue(json['relatedTask']);
    final customerJson = json['customer'];
    return _CallItem(
      id: stringValue(json['id']),
      fromNumber: nullableString(json['fromNumber']),
      toNumber: nullableString(json['toNumber']),
      calledAt: dateValue(json['calledAt'] ?? json['createdAt']),
      ivrSelection: nullableString(json['ivrSelection']),
      displayStatus: nullableString(json['displayStatus']),
      urgent: json['urgent'] == true,
      transcriptPreview: nullableString(
        json['transcriptPreview'] ?? json['transcript'],
      ),
      relatedTaskId: nullableString(relatedTask['id']),
      customer: customerJson is Map<String, Object?>
          ? Customer.fromJson(customerJson)
          : null,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
