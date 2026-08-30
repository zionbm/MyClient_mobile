import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
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
  final _nameController = TextEditingController();
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
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => _load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _TeamHero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
              sliver: SliverList.list(
                children: [
                  const _TeamSectionTitle('הוספת עובד'),
                  const SizedBox(height: 9),
                  _AddMemberCard(
                    nameController: _nameController,
                    phoneController: _phoneController,
                    adding: _adding,
                    error: _error,
                    onAdd: _addMember,
                  ),
                  const SizedBox(height: 26),
                  const _TeamSectionTitle('חברי הצוות'),
                  const SizedBox(height: 9),
                  FutureBuilder<List<_TeamMember>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _TeamLoadingCard();
                      }
                      if (snapshot.hasError) {
                        return _InfoCard(
                          icon: Icons.cloud_off_outlined,
                          title: 'לא הצלחנו לטעון את הצוות',
                          body: _messageFor(snapshot.error),
                          actionLabel: 'נסה שוב',
                          onAction: _load,
                        );
                      }
                      final members = snapshot.data ?? const <_TeamMember>[];
                      if (members.isEmpty) {
                        return const _InfoCard(
                          icon: Icons.groups_outlined,
                          title: 'אין עובדים נוספים',
                          body:
                              'כשתוסיפו עובדים הם יופיעו כאן, עם סטטוס הגישה שלהם.',
                        );
                      }
                      return Column(
                        children: [
                          for (var index = 0; index < members.length; index++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == members.length - 1 ? 0 : 10,
                              ),
                              child: _MemberCard(
                                member: members[index],
                                onDisable: () => _disable(members[index]),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _load() {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient.business
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
    final name = _nameController.text.trim();
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
      await widget.controller.apiClient.business.createMember(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        phoneNumber: phone,
        displayName: name,
      );
      _nameController.clear();
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
        title: const Text('להסיר עובד?'),
        content: Text(
          'הגישה לעסק תבוטל עבור ${member.displayName ?? member.phoneNumber}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('הסר'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.business.disableMember(
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

class _TeamHero extends StatelessWidget {
  const _TeamHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 270,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        28,
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
                radius: 35,
                backgroundColor: AppColors.primarySoft,
                foregroundColor: Colors.white,
                child: Icon(Icons.groups_outlined, size: 38),
              ),
              SizedBox(height: 16),
              Text(
                'ניהול צוות',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'מוסיפים עובדים ומנהלים את הגישה לעסק',
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

class _TeamSectionTitle extends StatelessWidget {
  const _TeamSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AddMemberCard extends StatelessWidget {
  const _AddMemberCard({
    required this.nameController,
    required this.phoneController,
    required this.adding,
    required this.error,
    required this.onAdd,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool adding;
  final String? error;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _TeamIcon(icon: Icons.person_add_alt_1_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'פרטי העובד החדש',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'שם העובד',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            onSubmitted: (_) {
              if (!adding) onAdd();
            },
            decoration: const InputDecoration(
              labelText: 'מספר טלפון',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _TeamInlineError(message: error!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: adding ? null : onAdd,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            icon: adding
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.person_add_alt_1_outlined),
            label: Text(
              adding ? 'מוסיף...' : 'הוספת עובד',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onDisable});

  final _TeamMember member;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final name = member.displayName ?? member.phoneNumber;
    final active = member.status.toUpperCase() == 'ACTIVE';
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFDDEEE9),
            foregroundColor: AppColors.primary,
            child: Text(
              name.trim().isEmpty ? '?' : name.trim().characters.first,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MemberStatus(active: active),
                  ],
                ),
                const SizedBox(height: 4),
                if (member.displayName != null)
                  Text(
                    member.phoneNumber,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                Text(
                  [
                    _memberTypeLabel(member.memberType),
                    if (member.createdAt != null)
                      'נוסף ${formatDateTime(member.createdAt)}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'הסרת עובד',
            onPressed: onDisable,
            color: AppColors.accent,
            icon: const Icon(Icons.person_remove_outlined),
          ),
        ],
      ),
    );
  }

  String _memberTypeLabel(String type) {
    return switch (type.toUpperCase()) {
      'OWNER' => 'בעלים',
      'ADMIN' => 'מנהל',
      _ => 'עובד',
    };
  }
}

class _MemberStatus extends StatelessWidget {
  const _MemberStatus({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE4F2ED) : const Color(0xFFFFF0D5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'פעיל' : 'לא פעיל',
        style: TextStyle(
          color: active ? const Color(0xFF137A52) : const Color(0xFF9A6410),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TeamIcon extends StatelessWidget {
  const _TeamIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFFDDEEE9),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}

class _TeamInlineError extends StatelessWidget {
  const _TeamInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _TeamLoadingCard extends StatelessWidget {
  const _TeamLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _TeamMember {
  const _TeamMember({
    required this.id,
    required this.phoneNumber,
    required this.memberType,
    required this.status,
    this.displayName,
    this.createdAt,
  });

  final String id;
  final String phoneNumber;
  final String memberType;
  final String status;
  final String? displayName;
  final DateTime? createdAt;

  factory _TeamMember.fromJson(Map<String, Object?> json) {
    final user = mapValue(json['user']);
    return _TeamMember(
      id: stringValue(json['id']),
      phoneNumber: stringValue(
        json['phoneNumber'] ?? user['phoneNumber'],
        fallback: 'מספר לא ידוע',
      ),
      displayName: nullableString(json['displayName'] ?? user['displayName']),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _TeamIcon(icon: icon),
            const SizedBox(height: 12),
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
              style: const TextStyle(color: AppColors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
