class AppSession {
  const AppSession({
    required this.firebaseUid,
    this.mockPhoneNumber,
    this.userId,
    this.displayName,
    this.businessId,
    this.businessName,
    this.onboardingState,
  });

  final String firebaseUid;
  final String? mockPhoneNumber;
  final String? userId;
  final String? displayName;
  final String? businessId;
  final String? businessName;
  final String? onboardingState;

  bool get hasBusiness => businessId != null && businessId!.isNotEmpty;

  AppSession copyWith({
    String? userId,
    String? displayName,
    String? businessId,
    String? businessName,
    String? onboardingState,
  }) {
    return AppSession(
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      onboardingState: onboardingState ?? this.onboardingState,
    );
  }

  factory AppSession.fromAuthMe({
    required String firebaseUid,
    required String? mockPhoneNumber,
    required Map<String, Object?> json,
  }) {
    final user = _asMap(json['user']);
    final business = _asMap(json['business']) ?? _asMap(json['activeBusiness']);
    final membership =
        _asMap(json['membership']) ?? _asMap(json['activeMembership']);

    return AppSession(
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      userId: _string(user?['id']),
      displayName: _string(user?['displayName']),
      businessId:
          _string(business?['id']) ?? _string(membership?['businessId']),
      businessName:
          _string(business?['name']) ?? _string(business?['businessName']),
      onboardingState: _string(json['onboardingState']),
    );
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    return null;
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
