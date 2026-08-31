import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/state/data_invalidator.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/paging/paged_list_view.dart';
import '../../models/page.dart' as pagination;
import '../../navigation/linked_entity_navigation.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import '../voice/voice_command_result.dart';
import '../voice/voice_command_result_widgets.dart';
import '../work_items/work_item_form_screen.dart';

class PendingActionsScreen extends StatefulWidget {
  const PendingActionsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<PendingActionsScreen> createState() => _PendingActionsScreenState();
}

class _PendingActionsScreenState extends State<PendingActionsScreen> {
  Future<List<VoiceCommandResultItem>>? _future;
  late PagingController<VoiceCommandResultItem> _paging;
  final Set<String> _submittingItems = {};
  String _status = 'PENDING';

  @override
  void initState() {
    super.initState();
    _createPaging();
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
          const _PendingActionsHero(),
          Expanded(
            child: PagedListView<VoiceCommandResultItem>(
              future: _future,
              onRefresh: _refresh,
              canLoadMore: _paging.canLoadMore,
              onLoadMore: _loadMore,
              loadMoreLabel: 'טען עוד פעולות',
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              header: _ActionStatusFilter(
                status: _status,
                onChanged: (status) {
                  setState(() => _status = status);
                  _paging.dispose();
                  _createPaging();
                },
              ),
              empty: _InfoCard(
                icon: Icons.auto_awesome_outlined,
                title: _emptyTitle,
                body: _emptyBody,
              ),
              errorBuilder: (context, error) => _InfoCard(
                icon: Icons.cloud_off_outlined,
                title: 'לא הצלחנו לטעון פעולות',
                body: _messageFor(error),
              ),
              itemBuilder: (context, item) => VoiceResultItemCard(
                item: item,
                submitting: _submittingItems.contains(item.id),
                onTap: item.status == 'pending'
                    ? () => _editAndApprove(item)
                    : null,
                onApprove: item.status == 'pending'
                    ? () => _approve(item)
                    : null,
                onReject: item.status == 'pending' ? () => _reject(item) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _emptyTitle => switch (_status) {
    'EXECUTED' => 'אין פעולות שבוצעו',
    'REJECTED' => 'אין פעולות שנדחו',
    _ => 'אין פעולות שמחכות לך',
  };

  String get _emptyBody => switch (_status) {
    'EXECUTED' => 'פעולות AI שאישרת והושלמו יופיעו כאן.',
    'REJECTED' => 'פעולות שבחרת לדחות יופיעו כאן.',
    _ => 'כשפקודה קולית תדרוש אישור, היא תופיע כאן.',
  };

  void _load() {
    final paging = _paging;
    setState(() {
      _future = paging.refresh().then((_) => paging.items);
    });
  }

  Future<void> _refresh() async {
    _load();
    await _future;
  }

  void _createPaging() {
    _paging = PagingController<VoiceCommandResultItem>(
      _loadPage,
      itemKey: (item) => item.id,
    );
    _load();
  }

  Future<pagination.Page<VoiceCommandResultItem>> _loadPage(
    String? cursor,
  ) async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.aiActions.list(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      status: _status,
      limit: 50,
      cursor: cursor,
    );
    return pagination.Page(
      items: mapListValue(
        json['aiPendingActions'],
      ).map(VoiceCommandResultItem.fromPendingActionJson).toList(),
      pageInfo: pagination.PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
  }

  Future<void> _editAndApprove(VoiceCommandResultItem item) async {
    final target = voiceWorkItemTarget(item);
    if (target != null && item.aiPendingActionId != null) {
      final completed = await openVoiceWorkItemAction(
        context: context,
        controller: widget.controller,
        action: item,
        target: target,
      );
      if (completed == true) {
        widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
        _load();
      }
      return;
    }
    if (isExistingVoiceWorkItemAction(item.actionType)) {
      _showError('לא נמצא פריט מתאים שאפשר לפתוח. אפשר לדחות ולנסות שוב.');
      return;
    }
    final kind = _workItemKindForActionType(item.actionType);
    if (kind != null && item.aiPendingActionId != null) {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => WorkItemFormScreen(
            controller: widget.controller,
            kind: kind,
            initialPayload: item.payload,
            aiPendingActionId: item.aiPendingActionId,
          ),
        ),
      );
      if (completed == true) {
        widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
        _load();
      }
      return;
    }

    final edited = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: VoicePayloadEditorSheet(item: item),
      ),
    );
    if (edited == null) return;
    await _approve(item, edited);
  }

  Future<void> _approve(
    VoiceCommandResultItem item, [
    Map<String, Object?>? editedPayload,
  ]) async {
    final aiPendingActionId = item.aiPendingActionId;
    if (aiPendingActionId == null) return;
    if (editedPayload == null && item.missingFields.isNotEmpty) {
      _showError('לא ניתן לבצע בלי להשלים את הפרטים החסרים.');
      return;
    }

    final session = widget.controller.session!;
    setState(() => _submittingItems.add(item.id));
    try {
      await widget.controller.apiClient.aiActions.approve(
        businessId: session.businessId!,
        aiPendingActionId: aiPendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        payload: editedPayload ?? item.payload,
      );
      widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
      _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _submittingItems.remove(item.id));
      _showError(error.message);
    } catch (_) {
      if (mounted) setState(() => _submittingItems.remove(item.id));
      _showError('לא הצלחנו להשלים את הפעולה');
    }
  }

  Future<void> _reject(VoiceCommandResultItem item) async {
    final aiPendingActionId = item.aiPendingActionId;
    if (aiPendingActionId == null) return;

    final session = widget.controller.session!;
    setState(() => _submittingItems.add(item.id));
    try {
      await widget.controller.apiClient.aiActions.reject(
        businessId: session.businessId!,
        aiPendingActionId: aiPendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
      _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _submittingItems.remove(item.id));
      _showError(error.message);
    } catch (_) {
      if (mounted) setState(() => _submittingItems.remove(item.id));
      _showError('לא הצלחנו למחוק את הפעולה');
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

class _PendingActionsHero extends StatelessWidget {
  const _PendingActionsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 245,
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
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 33,
                backgroundColor: AppColors.primarySoft,
                foregroundColor: Colors.white,
                child: Icon(Icons.auto_awesome_outlined, size: 36),
              ),
              SizedBox(height: 14),
              Text(
                'פעולות AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'בודקים, מעדכנים ומאשרים לפני הביצוע',
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

class _ActionStatusFilter extends StatelessWidget {
  const _ActionStatusFilter({required this.status, required this.onChanged});

  final String status;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFEE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _FilterOption(
            label: 'ממתינות',
            selected: status == 'PENDING',
            onTap: () => onChanged('PENDING'),
          ),
          _FilterOption(
            label: 'בוצעו',
            selected: status == 'EXECUTED',
            onTap: () => onChanged('EXECUTED'),
          ),
          _FilterOption(
            label: 'נדחו',
            selected: status == 'REJECTED',
            onTap: () => onChanged('REJECTED'),
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.muted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

WorkItemKind? _workItemKindForActionType(String actionType) {
  return switch (voiceWorkItemKindName(actionType)) {
    'reminder' => WorkItemKind.reminder,
    'homeVisit' => WorkItemKind.homeVisit,
    'appointment' => WorkItemKind.appointment,
    'quote' => WorkItemKind.quote,
    'note' => WorkItemKind.note,
    _ => null,
  };
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
