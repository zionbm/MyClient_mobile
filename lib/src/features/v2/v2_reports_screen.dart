import 'package:flutter/material.dart';

import '../../utils/json_read.dart';
import '../../navigation/linked_entity_navigation.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatting.dart';
import '../auth/session_controller.dart';

class V2ReportsScreen extends StatefulWidget {
  const V2ReportsScreen({super.key, required this.controller});
  final SessionController controller;

  @override
  State<V2ReportsScreen> createState() => _V2ReportsScreenState();
}

class _V2ReportsScreenState extends State<V2ReportsScreen> {
  Future<List<Map<String, Object?>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('תשלומים ויתרות')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('לא הצלחנו לטעון את הדוחות'));
        }
        final values = snapshot.data ?? const [];
        final payments = values.isEmpty ? const <String, Object?>{} : values[0];
        final balances = values.length < 2
            ? const <String, Object?>{}
            : values[1];
        final paymentEvents = mapListValue(payments['events']);
        final openAmounts = mapListValue(balances['amounts']);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReportCard(
                icon: Icons.payments_outlined,
                title: 'תשלומים שהתקבלו ב־30 הימים האחרונים',
                value: '${_amount(payments['totalPaid'])} ₪',
                subtitle: '${paymentEvents.length} אירועי תשלום',
              ),
              const SizedBox(height: 12),
              _ReportCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'יתרות פתוחות נוכחיות',
                value: '${_amount(balances['totalBalance'])} ₪',
                subtitle: '${openAmounts.length} פעילויות עם יתרה',
              ),
              const SizedBox(height: 24),
              const _ReportSectionTitle('יתרות שדורשות טיפול'),
              const SizedBox(height: 8),
              if (openAmounts.isEmpty)
                const _EmptyReportCard('אין כרגע יתרות פתוחות')
              else
                ...openAmounts.map(
                  (amount) => _BalanceTile(
                    amount: amount,
                    onTap: () => _openAmountActivity(amount),
                  ),
                ),
              const SizedBox(height: 24),
              const _ReportSectionTitle('תשלומים אחרונים'),
              const SizedBox(height: 8),
              if (paymentEvents.isEmpty)
                const _EmptyReportCard('לא התקבלו תשלומים בתקופה הזו')
              else
                ...paymentEvents.map(
                  (event) => _PaymentTile(
                    event: event,
                    onTap: () => _openPaymentActivity(event),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  Future<List<Map<String, Object?>>> _load() async {
    final session = widget.controller.session!;
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 30));
    return Future.wait([
      widget.controller.apiClient.v2Amounts.paymentsReport(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        from: from,
        to: to,
      ),
      widget.controller.apiClient.v2Amounts.openBalances(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
    ]);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openAmountActivity(Map<String, Object?> amount) async {
    await _openActivity(amount);
  }

  Future<void> _openPaymentActivity(Map<String, Object?> event) async {
    await _openActivity(mapValue(event['amount']));
  }

  Future<void> _openActivity(Map<String, Object?> amount) async {
    final reference = _activityReference(amount);
    if (reference == null) return;
    await openLinkedEntity(
      context: context,
      controller: widget.controller,
      type: reference.type,
      id: reference.id,
    );
    if (mounted) await _refresh();
  }
}

class _ReportSectionTitle extends StatelessWidget {
  const _ReportSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
  );
}

class _EmptyReportCard extends StatelessWidget {
  const _EmptyReportCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(text)),
  );
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.amount, required this.onTap});
  final Map<String, Object?> amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reference = _activityReference(amount);
    final total = _number(amount['totalAmount']);
    final paid = _number(amount['paidAmount']);
    return Card(
      child: ListTile(
        onTap: reference == null ? null : onTap,
        leading: const Icon(
          Icons.account_balance_wallet_outlined,
          color: AppColors.accent,
        ),
        title: Text(reference?.title ?? 'פעילות'),
        subtitle: Text(
          [
            if (reference?.customerName != null) reference!.customerName!,
            'שולם ${_amount(paid)} ₪ מתוך ${_amount(total)} ₪',
          ].join(' · '),
        ),
        trailing: Text(
          '${_amount(total - paid)} ₪',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.event, required this.onTap});
  final Map<String, Object?> event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reference = _activityReference(mapValue(event['amount']));
    final occurredAt = DateTime.tryParse(
      nullableString(event['occurredAt']) ?? '',
    );
    return Card(
      child: ListTile(
        onTap: reference == null ? null : onTap,
        leading: const Icon(Icons.payments_outlined, color: AppColors.success),
        title: Text(reference?.title ?? 'תשלום'),
        subtitle: Text(
          [
            if (reference?.customerName != null) reference!.customerName!,
            if (occurredAt != null) formatDateTime(occurredAt),
          ].join(' · '),
        ),
        trailing: Text(
          '${_amount(event['paidDelta'])} ₪',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ActivityReference {
  const _ActivityReference({
    required this.type,
    required this.id,
    required this.title,
    this.customerName,
  });
  final String type;
  final String id;
  final String title;
  final String? customerName;
}

_ActivityReference? _activityReference(Map<String, Object?> amount) {
  final job = mapValue(amount['job']);
  final visit = mapValue(amount['visit']);
  final activity = job.isNotEmpty ? job : visit;
  if (activity.isEmpty) return null;
  return _ActivityReference(
    type: job.isNotEmpty ? 'job' : 'visit',
    id: nullableString(activity['id']) ?? '',
    title: nullableString(activity['title']) ?? 'פעילות',
    customerName: nullableString(mapValue(activity['customer'])['name']),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 10),
          Text(title),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(subtitle),
        ],
      ),
    ),
  );
}

String _amount(Object? value) => switch (value) {
  num number => number.toStringAsFixed(2),
  String text => (double.tryParse(text) ?? 0).toStringAsFixed(2),
  _ => '0.00',
};

double _number(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text) ?? 0,
  _ => 0,
};
