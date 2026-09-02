import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/v2_activity.dart';
import '../../models/v2_amount.dart';
import '../../theme/app_theme.dart';
import '../auth/session_controller.dart';
import 'v2_amount_sheet.dart';
import 'v2_customers_screen.dart';
import 'v2_home_screen.dart';

class V2ActivityDetailScreen extends StatefulWidget {
  const V2ActivityDetailScreen({
    super.key,
    required this.controller,
    required this.kind,
    required this.activityId,
    this.initialActivity,
  });

  final SessionController controller;
  final V2ActivityKind kind;
  final String activityId;
  final V2Activity? initialActivity;

  @override
  State<V2ActivityDetailScreen> createState() => _V2ActivityDetailScreenState();
}

class _V2ActivityDetailScreenState extends State<V2ActivityDetailScreen> {
  Future<_ActivityDetailData>? _future;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('פרטי ${widget.kind.hebrewLabel}'),
        actions: [
          PopupMenuButton<String>(
            enabled: !_working,
            onSelected: (value) {
              if (value == 'edit') _edit();
              if (value == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('עריכה')),
              PopupMenuItem(value: 'delete', child: Text('מחיקה')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<_ActivityDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const _DetailMessage(
              icon: Icons.cloud_off_outlined,
              text: 'לא הצלחנו לטעון את הפעילות',
            );
          }
          return _body(snapshot.data!);
        },
      ),
    );
  }

  Widget _body(_ActivityDetailData data) {
    final activity = data.activity;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ActivityOverview(activity: activity),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openCustomer(activity.customerId),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('לקוח'),
                ),
              ),
              if (activity.locationSnapshot != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _navigate(activity.locationSnapshot!),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('ניווט'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const _DetailSectionTitle('פרטי הפעילות'),
          const SizedBox(height: 8),
          _DetailCard(
            children: [
              if (activity.startsAt != null)
                _DetailRow(
                  icon: Icons.schedule,
                  title: 'מועד',
                  value: _formatWindow(context, activity),
                ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                title: 'כתובת',
                value: activity.locationSnapshot ?? 'עדיין לא הוגדרה כתובת',
              ),
              if (activity.description != null)
                _DetailRow(
                  icon: Icons.notes_outlined,
                  title: 'פרטים',
                  value: activity.description!,
                ),
            ],
          ),
          const SizedBox(height: 20),
          const _DetailSectionTitle('סכום ותשלום'),
          const SizedBox(height: 8),
          _AmountOverview(
            amount: data.amount,
            onOpen: () => _openAmount(activity),
          ),
          const SizedBox(height: 24),
          if (activity.status == V2ActivityStatus.open)
            FilledButton.icon(
              onPressed: _working ? null : () => _complete(activity),
              icon: const Icon(Icons.task_alt),
              label: const Text('דווח סיום'),
            )
          else if (activity.status != V2ActivityStatus.cancelled)
            OutlinedButton.icon(
              onPressed: _working ? null : () => _lifecycle(activity, 'reopen'),
              icon: const Icon(Icons.refresh),
              label: const Text('פתיחה מחדש'),
            ),
          if (activity.status == V2ActivityStatus.open) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _working ? null : () => _lifecycle(activity, 'cancel'),
              child: const Text('ביטול הפעילות'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    final session = widget.controller.session!;
    final future = () async {
      final activity = await widget.controller.apiClient.v2Activities.get(
        kind: widget.kind,
        businessId: session.businessId!,
        entityId: widget.activityId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      V2Amount? amount;
      try {
        amount = await widget.controller.apiClient.v2Amounts.get(
          kind: widget.kind,
          businessId: session.businessId!,
          entityId: widget.activityId,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      return _ActivityDetailData(activity: activity, amount: amount);
    }();
    setState(() => _future = future);
    await future;
  }

  Future<void> _edit() async {
    final data = await _future;
    if (!mounted || data == null) return;
    final updated = await showModalBottomSheet<V2Activity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2ActivityForm(
        controller: widget.controller,
        kind: data.activity.kind,
        initialDate: data.activity.startsAt?.toLocal() ?? DateTime.now(),
        activity: data.activity,
      ),
    );
    if (updated == null) return;
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
  }

  Future<void> _delete() async {
    final data = await _future;
    if (!mounted || data == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('למחוק את ה${data.activity.kind.hebrewLabel}?'),
        content: Text(data.activity.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('חזרה'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('מחיקה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final session = widget.controller.session!;
    await _run(() async {
      await widget.controller.apiClient.v2Activities.delete(
        kind: data.activity.kind,
        businessId: session.businessId!,
        entityId: data.activity.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('activity_detail_delete'),
      );
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _complete(V2Activity activity) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('סיום הפעילות'),
        content: const Text('האם היה חיוב עבור הפעילות?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'charge'),
            child: const Text('כן, יש חיוב'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'no_charge'),
            child: const Text('לא היה חיוב'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == 'charge') {
      await _openAmount(activity);
      return;
    }
    await _lifecycle(
      activity,
      'report-completed',
      body: const {'noCharge': true},
    );
  }

  Future<void> _lifecycle(
    V2Activity activity,
    String action, {
    Map<String, Object?> body = const {},
  }) async {
    final session = widget.controller.session!;
    await _run(() async {
      await widget.controller.apiClient.v2Activities.lifecycle(
        kind: activity.kind,
        businessId: session.businessId!,
        entityId: activity.id,
        action: action,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('activity_detail_$action'),
        body: body,
      );
      widget.controller.markDataChanged({DataScope.crm});
      await _load();
    });
  }

  Future<void> _openAmount(V2Activity activity) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          V2AmountSheet(controller: widget.controller, activity: activity),
    );
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
  }

  Future<void> _openCustomer(String customerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2CustomerDetailScreen(
          controller: widget.controller,
          customerId: customerId,
        ),
      ),
    );
    await _load();
  }

  Future<void> _navigate(String address) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('לא הצלחנו לפתוח ניווט');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActivityDetailData {
  const _ActivityDetailData({required this.activity, required this.amount});

  final V2Activity activity;
  final V2Amount? amount;
}

class _ActivityOverview extends StatelessWidget {
  const _ActivityOverview({required this.activity});

  final V2Activity activity;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (activity.status) {
      V2ActivityStatus.open => ('פתוח', AppColors.primary),
      V2ActivityStatus.closed => ('הושלם', const Color(0xFF277A57)),
      V2ActivityStatus.cancelled => ('בוטל', const Color(0xFFB53A32)),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD8ECEB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                activity.kind == V2ActivityKind.job
                    ? Icons.work_outline
                    : Icons.home_work_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                activity.kind.hebrewLabel,
                style: const TextStyle(color: AppColors.primary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            activity.title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          if (activity.customerName != null) ...[
            const SizedBox(height: 5),
            Text(
              activity.customerName!,
              style: const TextStyle(color: AppColors.muted, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(title, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _AmountOverview extends StatelessWidget {
  const _AmountOverview({required this.amount, required this.onOpen});

  final V2Amount? amount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (amount == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('עדיין לא הוגדר סכום'),
          trailing: const Icon(Icons.chevron_left),
          onTap: onOpen,
        ),
      );
    }
    final progress = amount!.totalAmount <= 0
        ? 0.0
        : (amount!.paidAmount / amount!.totalAmount).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'שולם ${_money(amount!.paidAmount)} מתוך ${_money(amount!.totalAmount)} ₪',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                'יתרה: ${_money(amount!.balance)} ₪',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _money(double value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(text),
      ],
    ),
  );
}

String _formatWindow(BuildContext context, V2Activity activity) {
  final start = activity.startsAt!.toLocal();
  final end = activity.effectiveEndsAt?.toLocal();
  final date = MaterialLocalizations.of(context).formatFullDate(start);
  final startTime = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(start));
  final endTime = end == null
      ? null
      : MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(TimeOfDay.fromDateTime(end));
  return endTime == null ? '$date · $startTime' : '$date · $startTime–$endTime';
}
