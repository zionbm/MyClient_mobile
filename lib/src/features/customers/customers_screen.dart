import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../auth/session_controller.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  Future<List<Customer>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'חיפוש לקוחות',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'נקה',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Customer>>(
              future: _future,
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
                    title: 'לא הצלחנו לטעון לקוחות',
                    body: _messageForError(snapshot.error),
                    actionLabel: 'נסה שוב',
                    onAction: _refresh,
                  );
                }

                final customers = _filtered(snapshot.data ?? const []);
                if (customers.isEmpty) {
                  return const _StateCard(
                    icon: Icons.people_alt_outlined,
                    title: 'עדיין אין לקוחות',
                    body: 'אפשר להוסיף לקוח ראשון מהכפתור למטה.',
                  );
                }

                return Column(
                  children: customers
                      .map(
                        (customer) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: ListTile(
                              title: Text(customer.name),
                              subtitle: Text(
                                [
                                  if (customer.phone != null) customer.phone!,
                                  if (customer.address != null)
                                    customer.address!,
                                ].join(' · '),
                              ),
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CustomerDetailScreen(
                                      controller: widget.controller,
                                      customerId: customer.id,
                                    ),
                                  ),
                                );
                                _refresh();
                              },
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCustomer,
        icon: const Icon(Icons.add),
        label: const Text('לקוח חדש'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadCustomers());
    await _future;
  }

  Future<List<Customer>> _loadCustomers() async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.listCustomers(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    return (json['customers'] as List?)
            ?.whereType<Map<String, Object?>>()
            .map(Customer.fromJson)
            .toList() ??
        const [];
  }

  List<Customer> _filtered(List<Customer> customers) {
    final query = _searchController.text.trim();
    if (query.isEmpty) return customers;
    return customers.where((customer) {
      return customer.name.contains(query) ||
          (customer.phone?.contains(query) ?? false) ||
          (customer.address?.contains(query) ?? false);
    }).toList();
  }

  Future<void> _createCustomer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(controller: widget.controller),
      ),
    );
    if (created == true) _refresh();
  }

  String _messageForError(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
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
