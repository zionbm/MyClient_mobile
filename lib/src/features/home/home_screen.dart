import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/repositories/work_item_repository.dart';
import '../../models/work_item.dart';
import '../../navigation/app_route_observer.dart';
import '../../navigation/linked_entity_navigation.dart';
import '../../utils/date_formatting.dart';
import '../ai/pending_actions_screen.dart';
import '../auth/session_controller.dart';
import '../customers/customer_detail_screen.dart';
import '../voice/voice_command_recorder.dart';
import '../voice/voice_command_result_sheet.dart';
import '../work_items/work_item_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final VoiceCommandRecorder _voiceRecorder = VoiceCommandRecorder();
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'הכל';
  Future<Map<String, Object?>>? _homeFuture;
  Future<int>? _pendingActionsFuture;
  bool _openExpanded = true;
  bool _doneExpanded = false;
  late int _seenDataVersion;
  bool _subscribedToRoute = false;
  bool _suppressNextDataChange = false;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataVersion;
    _voiceRecorder.addListener(_handleVoiceRecorderChanged);
    widget.controller.addListener(_handleDataChanged);
    _loadHome();
  }

  @override
  void dispose() {
    if (_subscribedToRoute) {
      appRouteObserver.unsubscribe(this);
    }
    _voiceRecorder.removeListener(_handleVoiceRecorderChanged);
    _voiceRecorder.dispose();
    widget.controller.removeListener(_handleDataChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribedToRoute) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
      _subscribedToRoute = true;
    }
  }

  @override
  void didPopNext() {
    _loadHome();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session!;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => _loadHome(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
            children: [
              Text(
                'שלום${session.displayName == null ? '' : ', ${session.displayName}'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(_selectedDate),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedDate = _today());
                      _loadHome();
                    },
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('היום'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CreateActions(
                onReminder: () => _create(WorkItemKind.reminder),
                onHomeVisit: () => _create(WorkItemKind.homeVisit),
                onAppointment: () => _create(WorkItemKind.appointment),
                onQuote: () => _create(WorkItemKind.quote),
              ),
              const SizedBox(height: 12),
              FutureBuilder<int>(
                future: _pendingActionsFuture,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PendingActionsBanner(
                      count: count,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PendingActionsScreen(
                              controller: widget.controller,
                            ),
                          ),
                        );
                        _loadHome();
                      },
                    ),
                  );
                },
              ),
              _DateStrip(
                selectedDate: _selectedDate,
                onChanged: (date) {
                  setState(() => _selectedDate = date);
                  _loadHome();
                },
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      [
                            'הכל',
                            'דחוף',
                            'תזכורות',
                            'ביקורי בית',
                            'פגישות',
                            'הצעות מחיר',
                          ]
                          .map(
                            (filter) => Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: FilterChip(
                                selected: _selectedFilter == filter,
                                label: Text(filter),
                                onSelected: (_) {
                                  setState(() => _selectedFilter = filter);
                                  _loadHome();
                                },
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, Object?>>(
                future: _homeFuture,
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
                      title: 'לא הצלחנו לטעון את הבית',
                      body: _messageForError(snapshot.error),
                      actionLabel: 'נסה שוב',
                      onAction: _loadHome,
                    );
                  }

                  final items = _extractItems(snapshot.data ?? const {});
                  if (items.isEmpty) {
                    return const _StateCard(
                      icon: Icons.check_circle_outline,
                      title: 'אין דברים לטפל בהם ביום הזה',
                    );
                  }

                  final openItems = items
                      .where((item) => !item.isFinished)
                      .toList();
                  final doneItems = items
                      .where((item) => item.isFinished)
                      .toList();
                  return Column(
                    children: [
                      _WorkItemSection(
                        key: ValueKey('home-open-${_itemsStateKey(openItems)}'),
                        title: 'לביצוע',
                        count: openItems.length,
                        expanded: _openExpanded,
                        emptyText: 'אין משימות פתוחות ביום הזה',
                        onToggle: () =>
                            setState(() => _openExpanded = !_openExpanded),
                        children: openItems.map(_buildWorkItem).toList(),
                      ),
                      const SizedBox(height: 12),
                      _WorkItemSection(
                        key: ValueKey('home-done-${_itemsStateKey(doneItems)}'),
                        title: 'בוצעו',
                        count: doneItems.length,
                        expanded: _doneExpanded,
                        emptyText: 'אין משימות שבוצעו ביום הזה',
                        onToggle: () =>
                            setState(() => _doneExpanded = !_doneExpanded),
                        children: doneItems.map(_buildWorkItem).toList(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 104,
          child: _VoiceRecordingStatus(
            recorder: _voiceRecorder,
            onCancel: _voiceRecorder.cancel,
          ),
        ),
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 16,
          child: SafeArea(
            child: Center(
              child: SizedBox(
                width: 76,
                height: 76,
                child: FloatingActionButton.large(
                  heroTag: 'home-voice-command',
                  tooltip: _voiceRecorder.recording
                      ? 'עצור ושלח'
                      : _voiceRecorder.preparing
                      ? 'מכין הקלטה'
                      : 'פקודה קולית',
                  onPressed:
                      _voiceRecorder.uploading || _voiceRecorder.preparing
                      ? null
                      : _voiceRecorder.recording
                      ? _stopHomeVoiceCommand
                      : () => _voiceRecorder.start(widget.controller),
                  child: Icon(
                    _voiceRecorder.uploading
                        ? Icons.cloud_upload_outlined
                        : _voiceRecorder.preparing
                        ? Icons.hourglass_top
                        : _voiceRecorder.recording
                        ? Icons.stop
                        : Icons.mic,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _loadHome() {
    final session = widget.controller.session!;
    setState(() {
      _seenDataVersion = widget.controller.dataVersion;
      _homeFuture = widget.controller.apiClient.getHome(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        date: _selectedDate,
        filter: _apiFilter,
      );
      _pendingActionsFuture = widget.controller.apiClient
          .listAiPendingActions(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            status: 'PENDING',
          )
          .then((json) => (json['aiPendingActions'] as List?)?.length ?? 0);
    });
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataVersion;
    if (_suppressNextDataChange) {
      _suppressNextDataChange = false;
      _seenDataVersion = currentVersion;
      return;
    }
    if (currentVersion == _seenDataVersion) return;
    _loadHome();
  }

  void _handleVoiceRecorderChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _stopHomeVoiceCommand() async {
    final result = await _voiceRecorder.stopAndUpload(widget.controller);
    if (result == null) return;
    _loadHome();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: VoiceCommandResultSheet(
          result: result.result,
          controller: widget.controller,
          onOpenPendingActions: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PendingActionsScreen(controller: widget.controller),
              ),
            );
          },
          onRecordAgain: () => _voiceRecorder.start(widget.controller),
          onResolved: _loadHome,
        ),
      ),
    );
  }

  Future<void> _create(WorkItemKind kind) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            WorkItemFormScreen(controller: widget.controller, kind: kind),
      ),
    );
    if (created == true) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _loadHome();
      _notifyExternalTaskDataChanged();
    }
  }

  Widget _buildWorkItem(WorkItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _WorkItemCard(
        item: item,
        onOpen: _canEdit(item) ? () => _edit(item) : () => _openItem(item),
        onOpenCustomer: item.customer == null
            ? null
            : () => _openCustomer(item.customer!.id),
        onComplete: item.canComplete ? () => _complete(item) : null,
        onMarkPaid: item.canMarkPaid ? () => _markPaid(item) : null,
        onReopen: _canReopen(item) ? () => _reopen(item) : null,
        onDelete: _canDelete(item) ? () => _delete(item) : null,
      ),
    );
  }

  Future<void> _edit(WorkItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkItemFormScreen(
          controller: widget.controller,
          kind: _kindFor(item),
          initialCustomer: item.customer,
          existingItem: item,
        ),
      ),
    );
    if (changed == true) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _loadHome();
      _notifyExternalTaskDataChanged();
    }
  }

  Future<void> _openItem(WorkItem item) async {
    final opened = await openLinkedEntity(
      context: context,
      controller: widget.controller,
      type: item.linkedEntityType ?? item.type,
      id: item.linkedEntityId ?? item.id,
      customer: item.customer,
      title: item.title,
    );
    if (opened) _loadHome();
  }

  Future<void> _openCustomer(String customerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          controller: widget.controller,
          customerId: customerId,
        ),
      ),
    );
    if (mounted) _loadHome();
  }

  Future<void> _complete(WorkItem item) async {
    final session = widget.controller.session!;
    final type = CrmWorkItemTypeParsing.fromApiType(item.type);
    if (type == null) return;
    try {
      await widget.controller.apiClient.workItems.complete(
        type: type,
        businessId: session.businessId!,
        itemId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      _loadHome();
      _notifyExternalTaskDataChanged();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _markPaid(WorkItem item) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.workItems.complete(
        type: CrmWorkItemType.quote,
        businessId: session.businessId!,
        itemId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      _loadHome();
      _notifyExternalTaskDataChanged();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _reopen(WorkItem item) async {
    final session = widget.controller.session!;
    final type = CrmWorkItemTypeParsing.fromApiType(item.type);
    if (type == null) return;
    try {
      await widget.controller.apiClient.workItems.reopen(
        type: type,
        businessId: session.businessId!,
        itemId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      _loadHome();
      _notifyExternalTaskDataChanged();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _delete(WorkItem item) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('למחוק פריט?'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    final session = widget.controller.session!;
    final type = CrmWorkItemTypeParsing.fromApiType(item.type);
    if (type == null) return;
    try {
      await widget.controller.apiClient.workItems.delete(
        type: type,
        businessId: session.businessId!,
        itemId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      _loadHome();
      _notifyExternalTaskDataChanged();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  bool _canDelete(WorkItem item) {
    return item.type == 'reminder' ||
        item.type == 'home_visit' ||
        item.type == 'appointment' ||
        item.type == 'quote';
  }

  bool _canEdit(WorkItem item) => _canDelete(item);

  bool _canReopen(WorkItem item) => item.isFinished && _canDelete(item);

  WorkItemKind _kindFor(WorkItem item) {
    return switch (item.type) {
      'home_visit' => WorkItemKind.homeVisit,
      'appointment' => WorkItemKind.appointment,
      'quote' => WorkItemKind.quote,
      _ => WorkItemKind.reminder,
    };
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _notifyExternalTaskDataChanged() {
    _suppressNextDataChange = true;
    widget.controller.markDataChanged();
    _seenDataVersion = widget.controller.dataVersion;
  }

  String _itemsStateKey(List<WorkItem> items) {
    return items.map((item) => '${item.id}:${item.status ?? ''}').join('|');
  }

  String get _apiFilter {
    return switch (_selectedFilter) {
      'דחוף' => 'urgent',
      'תזכורות' => 'reminders',
      'ביקורי בית' => 'home_visits',
      'פגישות' => 'appointments',
      'הצעות מחיר' => 'quotes',
      _ => 'all',
    };
  }

  List<WorkItem> _extractItems(Map<String, Object?> payload) {
    final candidates = [
      payload['items'],
      payload['workItems'],
      payload['homeItems'],
      payload['reminders'],
      payload['homeVisits'],
      payload['appointments'],
      payload['quotes'],
    ];

    final items = <WorkItem>[];
    for (final candidate in candidates) {
      if (candidate is List) {
        items.addAll(
          candidate.whereType<Map<String, Object?>>().map(WorkItem.fromJson),
        );
      }
    }
    return items;
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final diff = normalizedDate.difference(normalizedToday).inDays;

    return switch (diff) {
      -1 => 'אתמול',
      0 => 'היום, ${date.day}.${date.month}.${date.year}',
      1 => 'מחר, ${date.day}.${date.month}.${date.year}',
      _ => '${date.day}.${date.month}.${date.year}',
    };
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _messageForError(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי רץ על הכתובת שהוגדרה.';
  }
}

class _CreateActions extends StatelessWidget {
  const _CreateActions({
    required this.onReminder,
    required this.onHomeVisit,
    required this.onAppointment,
    required this.onQuote,
  });

  final VoidCallback onReminder;
  final VoidCallback onHomeVisit;
  final VoidCallback onAppointment;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onReminder,
          icon: const Icon(Icons.alarm_add_outlined),
          label: const Text('תזכורת'),
        ),
        FilledButton.icon(
          onPressed: onHomeVisit,
          icon: const Icon(Icons.home_repair_service_outlined),
          label: const Text('ביקור'),
        ),
        FilledButton.icon(
          onPressed: onAppointment,
          icon: const Icon(Icons.event_outlined),
          label: const Text('פגישה'),
        ),
        OutlinedButton.icon(
          onPressed: onQuote,
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('הצעה'),
        ),
      ],
    );
  }
}

class _VoiceRecordingStatus extends StatelessWidget {
  const _VoiceRecordingStatus({required this.recorder, required this.onCancel});

  final VoiceCommandRecorder recorder;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final error = recorder.error;
    if (!recorder.recording &&
        !recorder.preparing &&
        !recorder.uploading &&
        error == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final message =
        error ??
        (recorder.uploading ? 'מסיים ומפענח...' : recorder.inputLevelMessage());
    final transcript = recorder.liveTranscript;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        recorder.uploading
                            ? Icons.cloud_upload_outlined
                            : recorder.preparing
                            ? Icons.hourglass_top
                            : error == null
                            ? Icons.mic
                            : Icons.error_outline,
                        color: error == null
                            ? colorScheme.primary
                            : colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  if (recorder.recording) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: recorder.inputLevel,
                        minHeight: 6,
                      ),
                    ),
                    if (transcript.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          transcript,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('ביטול הקלטה'),
                    ),
                  ] else if (recorder.preparing) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('ביטול'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selectedDate, required this.onChanged});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(7, (index) {
      final offset = index - 2;
      return DateTime(
        today.year,
        today.month,
        today.day,
      ).add(Duration(days: offset));
    });

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final selected = _sameDay(date, selectedDate);
          return ChoiceChip(
            selected: selected,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            label: SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_weekday(date)),
                  const SizedBox(height: 1),
                  Text(
                    '${date.day}.${date.month}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            onSelected: (_) => onChanged(date),
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekday(DateTime date) {
    return switch (date.weekday) {
      DateTime.sunday => 'א׳',
      DateTime.monday => 'ב׳',
      DateTime.tuesday => 'ג׳',
      DateTime.wednesday => 'ד׳',
      DateTime.thursday => 'ה׳',
      DateTime.friday => 'ו׳',
      _ => 'ש׳',
    };
  }
}

class _WorkItemSection extends StatelessWidget {
  const _WorkItemSection({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.emptyText,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final int count;
  final bool expanded;
  final String emptyText;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
                const SizedBox(width: 4),
                Text(
                  '$title ($count)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(emptyText),
            )
          else
            ...children,
      ],
    );
  }
}

class _PendingActionsBanner extends StatelessWidget {
  const _PendingActionsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.auto_awesome,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        title: Text('$count פעולות AI ממתינות לאישור'),
        subtitle: const Text('בדוק, ערוך או אשר לפני ביצוע'),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}

class _WorkItemCard extends StatelessWidget {
  const _WorkItemCard({
    required this.item,
    this.onOpen,
    this.onOpenCustomer,
    this.onComplete,
    this.onMarkPaid,
    this.onReopen,
    this.onDelete,
  });

  final WorkItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onOpenCustomer;
  final VoidCallback? onComplete;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onReopen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 6),
        child: Column(
          children: [
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              contentPadding: const EdgeInsetsDirectional.only(
                start: 4,
                end: 4,
              ),
              onTap: onOpen,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: item.isUrgent
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  _iconForType(item.type),
                  color: item.isUrgent
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _WorkItemSubtitle(
                typeLabel: _labelForType(item.type),
                customerName: item.customer?.name,
                onOpenCustomer: onOpenCustomer,
                dueAt: item.dueAt,
                isFinished: item.isFinished,
                description: item.description,
              ),
            ),
            if (onComplete != null ||
                onMarkPaid != null ||
                onReopen != null ||
                onDelete != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 4,
                  children: [
                    if (onComplete != null)
                      TextButton.icon(
                        onPressed: onComplete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('בוצע'),
                      ),
                    if (onMarkPaid != null)
                      TextButton.icon(
                        onPressed: onMarkPaid,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('שולם'),
                      ),
                    if (onReopen != null)
                      TextButton.icon(
                        onPressed: onReopen,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('פתח מחדש'),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('מחק'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type.toLowerCase()) {
      'reminder' => Icons.alarm_outlined,
      'home_visit' => Icons.home_repair_service_outlined,
      'appointment' => Icons.event_outlined,
      'quote' => Icons.request_quote_outlined,
      'call' => Icons.call_outlined,
      'notification' => Icons.notifications_none,
      _ => Icons.task_alt,
    };
  }

  String _labelForType(String type) {
    return switch (type.toLowerCase()) {
      'reminder' => 'תזכורת',
      'home_visit' => 'ביקור בית',
      'appointment' => 'פגישה',
      'quote' => 'הצעת מחיר',
      'call' => 'שיחה',
      'notification' => 'התראה',
      _ => type,
    };
  }
}

class _WorkItemSubtitle extends StatelessWidget {
  const _WorkItemSubtitle({
    required this.typeLabel,
    required this.customerName,
    required this.onOpenCustomer,
    required this.dueAt,
    required this.isFinished,
    required this.description,
  });

  final String typeLabel;
  final String? customerName;
  final VoidCallback? onOpenCustomer;
  final DateTime? dueAt;
  final bool isFinished;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final mutedStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final linkStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );
    final overdueText = _overdueText(dueAt, isFinished);

    return Wrap(
      spacing: 4,
      runSpacing: 1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(typeLabel, style: mutedStyle),
        if (customerName != null) ...[
          Text('·', style: mutedStyle),
          InkWell(
            onTap: onOpenCustomer,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                customerName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: linkStyle,
              ),
            ),
          ),
        ],
        if (dueAt != null) ...[
          Text('·', style: mutedStyle),
          Text(formatDateTime(dueAt), style: mutedStyle),
        ],
        if (overdueText != null) ...[
          Text('·', style: mutedStyle),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              overdueText,
              style: style?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (description != null) ...[
          Text('·', style: mutedStyle),
          Text(
            description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedStyle,
          ),
        ],
      ],
    );
  }

  String? _overdueText(DateTime? dueAt, bool isFinished) {
    if (dueAt == null || isFinished) return null;
    final localDueAt = dueAt.toLocal();
    final dueDate = DateTime(localDueAt.year, localDueAt.month, localDueAt.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(dueDate).inDays;
    if (days <= 0) return null;
    if (days == 1) return 'באיחור יום';
    return 'באיחור $days ימים';
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
