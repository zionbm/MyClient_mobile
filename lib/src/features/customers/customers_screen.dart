import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../core/state/data_invalidator.dart';
import '../../core/paging/paging_controller.dart';
import '../../models/customer.dart';
import '../../models/page.dart' as pagination;
import '../../theme/app_theme.dart';
import '../ai/pending_actions_screen.dart';
import '../auth/session_controller.dart';
import '../notifications/notifications_screen.dart';
import '../search/search_screen.dart';
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
  late final PagingController<Customer> _paging;
  String _filter = 'all';
  late int _seenDataVersion;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _paging = PagingController<Customer>(
      _loadCustomerPage,
      itemKey: (item) => item.id,
    );
    _future = _paging.refresh().then((_) => _paging.items);
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    _paging.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _CustomersHero(
            businessName: widget.controller.session?.businessName,
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
            onClearSearch: () {
              _searchController.clear();
              setState(() {});
            },
            onOpenSearch: _openGlobalSearch,
            onNotifications: _openNotifications,
            onPendingActions: _openPendingActions,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Text(
                  'הלקוחות שלי',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _pickFilter,
                  icon: const Icon(Icons.filter_list, size: 20),
                  label: Text(_filter == 'all' ? 'סינון' : _filterLabel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _createCustomer,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('לקוח חדש'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Customer>>(
                future: _future,
                builder: _buildCustomerList,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(
    BuildContext context,
    AsyncSnapshot<List<Customer>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        children: const [
          SizedBox(height: 48),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (snapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _StateCard(
            icon: Icons.cloud_off_outlined,
            title: 'לא הצלחנו לטעון לקוחות',
            body: _messageForError(snapshot.error),
            actionLabel: 'נסה שוב',
            onAction: _refresh,
          ),
        ],
      );
    }
    final customers = _filtered(snapshot.data ?? const []);
    if (customers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: const [
          _StateCard(
            icon: Icons.people_alt_outlined,
            title: 'עדיין אין לקוחות',
            body: 'אפשר להוסיף לקוח ראשון מהכפתור למטה.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: customers.length + (_paging.canLoadMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == customers.length) {
          return OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('טען עוד לקוחות'),
          );
        }
        return _customerCard(customers[index]);
      },
    );
  }

  Widget _customerCard(Customer customer) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: _avatarColor(customer.name),
                child: Text(
                  _initials(customer.name),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (customer.phone != null)
                      Text(
                        customer.phone!,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    if (customer.address != null || customer.email != null)
                      Text(
                        customer.address ?? customer.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              if (customer.phone != null) ...[
                _CustomerQuickAction(
                  tooltip: 'התקשר',
                  icon: Icons.call_outlined,
                  onPressed: () => _launchPhone(customer.phone!),
                ),
                const SizedBox(width: 4),
                _CustomerQuickAction(
                  tooltip: 'WhatsApp',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () => _launchWhatsApp(customer.phone!),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }

  Color _avatarColor(String value) {
    const colors = [
      Color(0xFFDDEFF5),
      Color(0xFFDDEEE9),
      Color(0xFFFFEDD0),
      Color(0xFFE9E5F1),
      Color(0xFFFFE4DA),
    ];
    return colors[value.hashCode.abs() % colors.length];
  }

  Future<void> _openGlobalSearch() async {
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
  }

  Future<void> _refresh() async {
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
    setState(() => _future = _paging.refresh().then((_) => _paging.items));
    await _future;
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
    if (currentVersion == _seenDataVersion) return;
    _refresh();
  }

  Future<pagination.Page<Customer>> _loadCustomerPage(String? cursor) async {
    final session = widget.controller.session!;
    final page = await widget.controller.apiClient.customers.list(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      limit: 50,
      cursor: cursor,
    );
    return page;
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
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

class _CustomersHero extends StatelessWidget {
  const _CustomersHero({
    required this.businessName,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onOpenSearch,
    required this.onNotifications,
    required this.onPendingActions,
  });

  final String? businessName;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenSearch;
  final VoidCallback onNotifications;
  final VoidCallback onPendingActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xFFE2F0F1),
                    child: Icon(Icons.person_outline, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      businessName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xDDFFFFFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'חיפוש כללי',
                    onPressed: onOpenSearch,
                    icon: const Icon(Icons.search, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'פעולות AI',
                    onPressed: onPendingActions,
                    icon: const Icon(
                      Icons.auto_awesome_outlined,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'התראות',
                    onPressed: onNotifications,
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'לקוחות',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'כל אנשי הקשר במקום אחד',
                style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 17),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'חיפוש לפי שם, טלפון או כתובת',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'נקה',
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerQuickAction extends StatelessWidget {
  const _CustomerQuickAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        side: const BorderSide(color: AppColors.border),
      ),
      icon: Icon(icon, size: 21),
    );
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
