import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _phoneController = TextEditingController();
  Future<List<_TeamMember>>? _future;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('צוות')),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'הוסף עובד',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'מספר טלפון',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _adding ? null : _addMember,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: _adding
                          ? const Text('מוסיף...')
                          : const Text('הוסף עובד'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<_TeamMember>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _InfoCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'לא הצלחנו לטעון צוות',
                    body: _messageFor(snapshot.error),
                  );
                }
                final members = snapshot.data ?? const <_TeamMember>[];
                if (members.isEmpty) {
                  return const _InfoCard(
                    icon: Icons.groups_outlined,
                    title: 'אין עובדים נוספים בעסק',
                    body: 'כאן יופיעו עובדים שהוספת לפי מספר טלפון.',
                  );
                }
                return Column(
                  children: members
                      .map(
                        (member) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(member.phoneNumber),
                              subtitle: Text(
                                [
                                  member.memberType,
                                  member.status,
                                  if (member.createdAt != null)
                                    formatDateTime(member.createdAt),
                                ].join(' · '),
                              ),
                              trailing: member.status == 'ACTIVE'
                                  ? IconButton(
                                      tooltip: 'השבת עובד',
                                      onPressed: () => _disable(member),
                                      icon: const Icon(Icons.block_outlined),
                                    )
                                  : null,
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
    );
  }

  void _load() {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient
          .listMembers(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          )
          .then(
            (json) => mapListValue(
              json['members'],
            ).map(_TeamMember.fromJson).toList(),
          );
    });
  }

  Future<void> _addMember() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'צריך להזין מספר טלפון');
      return;
    }
    final session = widget.controller.session!;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await widget.controller.apiClient.createMember(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        phoneNumber: phone,
      );
      _phoneController.clear();
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _disable(_TeamMember member) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('להשבית עובד?'),
        content: Text(member.phoneNumber),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('השבת'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.disableMember(
        businessId: session.businessId!,
        memberId: member.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _TeamMember {
  const _TeamMember({
    required this.id,
    required this.phoneNumber,
    required this.memberType,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String phoneNumber;
  final String memberType;
  final String status;
  final DateTime? createdAt;

  factory _TeamMember.fromJson(Map<String, Object?> json) {
    final user = mapValue(json['user']);
    return _TeamMember(
      id: stringValue(json['id']),
      phoneNumber: stringValue(
        json['phoneNumber'] ?? user['phoneNumber'],
        fallback: 'מספר לא ידוע',
      ),
      memberType: stringValue(json['memberType'], fallback: 'EMPLOYEE'),
      status: stringValue(json['status'], fallback: 'ACTIVE'),
      createdAt: dateValue(json['createdAt']),
    );
  }
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
          ],
        ),
      ),
    );
  }
}
