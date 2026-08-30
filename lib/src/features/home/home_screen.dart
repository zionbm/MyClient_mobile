import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/repositories/work_item_repository.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/work_item.dart';
import '../../navigation/linked_entity_navigation.dart';
import '../../utils/date_formatting.dart';
import '../ai/pending_actions_screen.dart';
import '../auth/session_controller.dart';
import '../customers/customer_detail_screen.dart';
import '../voice/voice_command_recorder.dart';
import '../voice/voice_command_result_sheet.dart';
import '../work_items/work_item_form_screen.dart';

part 'home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.pendingActionsCountFuture,
  });

  final SessionController controller;
  final Future<int>? pendingActionsCountFuture;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VoiceCommandRecorder _voiceRecorder = VoiceCommandRecorder();
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'הכל';
  Future<Map<String, Object?>>? _homeFuture;
  bool _openExpanded = true;
  bool _doneExpanded = false;
  late int _seenDataVersion;
  bool _suppressNextDataChange = false;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
    _voiceRecorder.addListener(_handleVoiceRecorderChanged);
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _loadHome();
  }

  @override
  void dispose() {
    _voiceRecorder.removeListener(_handleVoiceRecorderChanged);
    _voiceRecorder.dispose();
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    super.dispose();
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
                future: widget.pendingActionsCountFuture,
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
      _seenDataVersion = widget.controller.dataInvalidator.revision(
        DataScope.crm,
      );
      _homeFuture = widget.controller.apiClient.home.get(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        date: _selectedDate,
        filter: _apiFilter,
      );
    });
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
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
      type: item.linkedEntityType ?? item.type.apiValue,
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
    return item.type == WorkItemType.reminder ||
        item.type == WorkItemType.homeVisit ||
        item.type == WorkItemType.appointment ||
        item.type == WorkItemType.quote;
  }

  bool _canEdit(WorkItem item) => _canDelete(item);

  bool _canReopen(WorkItem item) => item.isFinished && _canDelete(item);

  WorkItemKind _kindFor(WorkItem item) {
    return switch (item.type) {
      WorkItemType.homeVisit => WorkItemKind.homeVisit,
      WorkItemType.appointment => WorkItemKind.appointment,
      WorkItemType.quote => WorkItemKind.quote,
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
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
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
