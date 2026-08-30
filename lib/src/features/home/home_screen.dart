import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/repositories/work_item_repository.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/work_item.dart';
import '../../navigation/linked_entity_navigation.dart';
import '../../theme/app_theme.dart';
import '../../utils/home_week_dates.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../widgets/pending_actions_icon_button.dart';
import '../ai/pending_actions_screen.dart';
import '../auth/session_controller.dart';
import '../customers/customer_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../search/search_screen.dart';
import '../voice/voice_command_recorder.dart';
import '../voice/voice_command_result_sheet.dart';
import '../work_items/work_item_form_screen.dart';

part 'home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.pendingActionsCountFuture,
    this.voiceStartRequests,
    this.voicePhase,
  });

  final SessionController controller;
  final Future<int>? pendingActionsCountFuture;
  final ValueListenable<int>? voiceStartRequests;
  final ValueNotifier<VoiceRecordingPhase>? voicePhase;

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
    widget.voiceStartRequests?.addListener(_handleVoiceStartRequest);
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _loadHome();
  }

  @override
  void dispose() {
    _voiceRecorder.removeListener(_handleVoiceRecorderChanged);
    widget.voiceStartRequests?.removeListener(_handleVoiceStartRequest);
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
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              FutureBuilder<Map<String, Object?>>(
                future: _homeFuture,
                builder: (context, snapshot) {
                  final items = _extractItems(snapshot.data ?? const {});
                  return _HomeHero(
                    displayName: session.displayName,
                    businessName: session.businessName,
                    selectedDate: _selectedDate,
                    openCount: items.where((item) => !item.isFinished).length,
                    overdueCount: items.where(_isOverdue).length,
                    doneCount: items.where((item) => item.isFinished).length,
                    pendingActionsCountFuture: widget.pendingActionsCountFuture,
                    onSearch: _openSearch,
                    onNotifications: _openNotifications,
                    onPendingActions: _openPendingActions,
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _DateStrip(
                  selectedDate: _selectedDate,
                  onChanged: (date) {
                    setState(() => _selectedDate = date);
                    _loadHome();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: FutureBuilder<Map<String, Object?>>(
                  future: _homeFuture,
                  builder: (context, snapshot) {
                    final count = _extractItems(
                      snapshot.data ?? const {},
                    ).where((item) => !item.isFinished).length;
                    return _HomeActionsRow(
                      count: count,
                      filterLabel: _selectedFilter,
                      onCreate: _pickCreateAction,
                      onFilter: _pickFilter,
                    );
                  },
                ),
              ),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _WorkItemSection(
                          key: ValueKey(
                            'home-open-${_itemsStateKey(openItems)}',
                          ),
                          title: 'לביצוע',
                          count: openItems.length,
                          expanded: _openExpanded,
                          showHeader: false,
                          emptyText: 'אין משימות פתוחות ביום הזה',
                          onToggle: () =>
                              setState(() => _openExpanded = !_openExpanded),
                          children: openItems.map(_buildWorkItem).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _WorkItemSection(
                          key: ValueKey(
                            'home-done-${_itemsStateKey(doneItems)}',
                          ),
                          title: 'הושלמו',
                          count: doneItems.length,
                          expanded: _doneExpanded,
                          emptyText: 'אין משימות שבוצעו ביום הזה',
                          onToggle: () =>
                              setState(() => _doneExpanded = !_doneExpanded),
                          children: doneItems.map(_buildWorkItem).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 16,
          child: _VoiceRecordingStatus(
            recorder: _voiceRecorder,
            onStopAndSend: _stopHomeVoiceCommand,
            onCancel: _voiceRecorder.cancel,
          ),
        ),
      ],
    );
  }

  void _handleVoiceStartRequest() {
    if (!mounted || _voiceRecorder.preparing || _voiceRecorder.uploading) {
      return;
    }
    if (_voiceRecorder.recording) {
      _stopHomeVoiceCommand();
    } else {
      _voiceRecorder.start(widget.controller);
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(controller: widget.controller),
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
        builder: (_) => PendingActionsScreen(controller: widget.controller),
      ),
    );
    widget.controller.refreshPendingActions();
    _loadHome();
  }

  Future<void> _pickCreateAction() async {
    final kind = await showModalBottomSheet<WorkItemKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _CreateActionSheet(),
    );
    if (kind != null) await _create(kind);
  }

  Future<void> _pickFilter() async {
    const filters = [
      'הכל',
      'דחוף',
      'תזכורות',
      'ביקורי בית',
      'פגישות',
      'הצעות מחיר',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'סינון משימות',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            for (final filter in filters)
              ListTile(
                leading: Icon(
                  filter == _selectedFilter
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(filter),
                onTap: () => Navigator.of(context).pop(filter),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == _selectedFilter) return;
    setState(() => _selectedFilter = selected);
    _loadHome();
  }

  bool _isOverdue(WorkItem item) {
    if (item.isFinished || item.dueAt == null) return false;
    final due = item.dueAt!.toLocal();
    final now = DateTime.now();
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
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
    final phaseNotifier = widget.voicePhase;
    if (phaseNotifier != null && phaseNotifier.value != _voiceRecorder.phase) {
      phaseNotifier.value = _voiceRecorder.phase;
    }
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
    final approved = await showAppConfirmationDialog(
      context: context,
      title: 'למחוק פריט?',
      body: item.title,
      confirmLabel: 'מחיקה',
      icon: Icons.delete_outline_rounded,
      destructive: true,
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

  String _messageForError(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי רץ על הכתובת שהוגדרה.';
  }
}
