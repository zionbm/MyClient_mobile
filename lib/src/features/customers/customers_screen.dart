import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../navigation/app_route_observer.dart';
import '../auth/session_controller.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> with RouteAware {
  final _searchController = TextEditingController();
  Future<List<Customer>>? _future;
  String _filter = 'all';
  late int _seenDataVersion;
  bool _subscribedToRoute = false;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataVersion;
    widget.controller.addListener(_handleDataChanged);
    _future = _loadCustomers();
  }

  @override
  void dispose() {
    if (_subscribedToRoute) {
      appRouteObserver.unsubscribe(this);
    }
    widget.controller.removeListener(_handleDataChanged);
    _searchController.dispose();
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
    _refresh();
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
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _pickFilter,
                icon: const Icon(Icons.filter_list),
                label: Text(_filterLabel),
              ),
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
                              trailing: Wrap(
                                spacing: 2,
                                children: [
                                  if (customer.phone != null)
                                    IconButton(
                                      tooltip: 'התקשר',
                                      onPressed: () =>
                                          _launchPhone(customer.phone!),
                                      icon: const Icon(Icons.call_outlined),
                                    ),
                                  if (customer.phone != null)
                                    IconButton(
                                      tooltip: 'WhatsApp',
                                      onPressed: () =>
                                          _launchWhatsApp(customer.phone!),
                                      icon: const Icon(Icons.chat_outlined),
                                    ),
                                  const Icon(Icons.chevron_left),
                                ],
                              ),
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
    _seenDataVersion = widget.controller.dataVersion;
    setState(() => _future = _loadCustomers());
    await _future;
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataVersion;
    if (currentVersion == _seenDataVersion) return;
    _refresh();
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
    final filtered = customers.where((customer) {
      final matchesFilter = switch (_filter) {
        'with_phone' => customer.phone != null,
        'without_phone' => customer.phone == null,
        _ => true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return customer.name.contains(query) ||
          (customer.phone?.contains(query) ?? false) ||
          (customer.address?.contains(query) ?? false);
    }).toList();
    return filtered;
  }

  String get _filterLabel {
    return switch (_filter) {
      'with_phone' => 'עם מספר טלפון',
      'without_phone' => 'בלי מספר טלפון',
      _ => 'כל הלקוחות',
    };
  }

  Future<void> _pickFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _filter == 'all'
                    ? Icons.radio_button_checked
                    : Icons.circle_outlined,
              ),
              title: const Text('כל הלקוחות'),
              onTap: () => Navigator.of(context).pop('all'),
            ),
            ListTile(
              leading: Icon(
                _filter == 'with_phone'
                    ? Icons.radio_button_checked
                    : Icons.circle_outlined,
              ),
              title: const Text('עם מספר טלפון'),
              onTap: () => Navigator.of(context).pop('with_phone'),
            ),
            ListTile(
              leading: Icon(
                _filter == 'without_phone'
                    ? Icons.radio_button_checked
                    : Icons.circle_outlined,
              ),
              title: const Text('בלי מספר טלפון'),
              onTap: () => Navigator.of(context).pop('without_phone'),
            ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _filter = selected);
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) _showError('לא ניתן לפתוח שיחה');
  }

  Future<void> _launchWhatsApp(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$normalized');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('לא ניתן לפתוח WhatsApp');
    }
  }

  Future<void> _createCustomer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(controller: widget.controller),
      ),
    );
    if (created == true) {
      widget.controller.markDataChanged();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _refresh();
    }
  }

  String _messageForError(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
