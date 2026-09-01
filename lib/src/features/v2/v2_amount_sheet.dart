import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../models/v2_activity.dart';
import '../../models/v2_amount.dart';
import '../auth/session_controller.dart';

class V2AmountSheet extends StatefulWidget {
  const V2AmountSheet({
    super.key,
    required this.controller,
    required this.activity,
  });
  final SessionController controller;
  final V2Activity activity;

  @override
  State<V2AmountSheet> createState() => _V2AmountSheetState();
}

class _V2AmountSheetState extends State<V2AmountSheet> {
  final _total = TextEditingController();
  final _payment = TextEditingController();
  Future<V2Amount?>? _future;
  V2Amount? _amount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _total.dispose();
    _payment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: FutureBuilder<V2Amount?>(
      future: _future,
      builder: (context, snapshot) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'סכום ותשלום',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (_amount == null) ...[
              const Text('עדיין לא הוגדר סכום לפעילות'),
              const SizedBox(height: 12),
              TextField(
                controller: _total,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'סכום כולל בש״ח'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _create,
                child: const Text('שמירת סכום'),
              ),
            ] else ...[
              Text(
                'סה״כ: ${_money(_amount!.totalAmount)} ₪',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text('שולם: ${_money(_amount!.paidAmount)} ₪'),
              Text('יתרה: ${_money(_amount!.balance)} ₪'),
              const SizedBox(height: 12),
              TextField(
                controller: _total,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'עדכון הסכום הכולל',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving ? null : _updateTotal,
                child: const Text('שמירת סכום כולל'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _payment,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'סכום תשלום'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _saving ? null : () => _pay('ADD'),
                    child: const Text('הוספת תשלום'),
                  ),
                  FilledButton.tonal(
                    onPressed: _saving ? null : () => _pay('SET_PAID_TOTAL'),
                    child: const Text('עדכון שולם במצטבר'),
                  ),
                  FilledButton(
                    onPressed: _saving || _amount!.balance <= 0
                        ? null
                        : () => _pay('SETTLE_BALANCE'),
                    child: const Text('סגירת יתרה'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Future<V2Amount?> _load() async {
    final session = widget.controller.session!;
    try {
      _amount = await widget.controller.apiClient.v2Amounts.get(
        kind: widget.activity.kind,
        businessId: session.businessId!,
        entityId: widget.activity.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      _total.text = _money(_amount!.totalAmount);
      return _amount;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _create() async {
    final total = double.tryParse(_total.text.trim());
    if (total == null || total < 0) return _error('צריך להזין סכום תקין');
    await _run(() async {
      final session = widget.controller.session!;
      return widget.controller.apiClient.v2Amounts.put(
        kind: widget.activity.kind,
        businessId: session.businessId!,
        entityId: widget.activity.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('amount_put'),
        body: {'totalAmount': total},
      );
    });
  }

  Future<void> _pay(String mode) async {
    final value = mode == 'SETTLE_BALANCE'
        ? null
        : double.tryParse(_payment.text.trim());
    if (mode != 'SETTLE_BALANCE' && (value == null || value < 0)) {
      return _error('צריך להזין סכום תשלום תקין');
    }
    await _run(() async {
      final session = widget.controller.session!;
      return widget.controller.apiClient.v2Amounts.payment(
        kind: widget.activity.kind,
        businessId: session.businessId!,
        entityId: widget.activity.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('amount_payment'),
        mode: mode,
        amount: value,
      );
    });
  }

  Future<void> _updateTotal() async {
    final amount = _amount!;
    final total = double.tryParse(_total.text.trim());
    if (total == null || total < 0) return _error('צריך להזין סכום תקין');
    if (total < amount.paidAmount) {
      return _error('הסכום הכולל לא יכול להיות נמוך מהסכום שכבר שולם');
    }
    await _run(() async {
      final session = widget.controller.session!;
      return widget.controller.apiClient.v2Amounts.update(
        kind: widget.activity.kind,
        businessId: session.businessId!,
        entityId: widget.activity.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('amount_update'),
        body: {'totalAmount': total, 'version': amount.version},
      );
    });
  }

  Future<void> _run(Future<V2Amount> Function() action) async {
    setState(() => _saving = true);
    try {
      _amount = await action();
      _total.text = _money(_amount!.totalAmount);
      _payment.clear();
      if (mounted) setState(() => _future = Future.value(_amount));
    } on ApiException catch (error) {
      _error(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

String _money(double value) =>
    value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
