import 'package:flutter/material.dart';

import '../../utils/json_read.dart';
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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReportCard(
              icon: Icons.payments_outlined,
              title: 'תשלומים שהתקבלו ב־30 הימים האחרונים',
              value: '${_amount(payments['totalPaid'])} ₪',
              subtitle:
                  '${mapListValue(payments['events']).length} אירועי תשלום',
            ),
            const SizedBox(height: 12),
            _ReportCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'יתרות פתוחות נוכחיות',
              value: '${_amount(balances['totalBalance'])} ₪',
              subtitle:
                  '${mapListValue(balances['amounts']).length} פעילויות עם יתרה',
            ),
          ],
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
