import '../config/app_config.dart';
import '../core/network/api_transport.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/work_item_repository.dart';

export '../core/network/api_exception.dart';

/// Temporary compatibility façade while feature code migrates to repositories.
/// New endpoints belong in a feature repository, not in this class.
class ApiClient {
  ApiClient({required AppConfig config})
    : _transport = ApiTransport(config: config) {
    auth = AuthRepository(_transport);
    customers = CustomerRepository(_transport);
    workItems = WorkItemRepository(_transport);
  }

  final ApiTransport _transport;
  late final AuthRepository auth;
  late final CustomerRepository customers;
  late final WorkItemRepository workItems;

  bool get isMockAuth => _transport.isMockAuth;

  void close() => _transport.close();

  Future<Map<String, Object?>> getAuthMe({
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return auth.getMe(
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> registerBusiness({
    required String firebaseUid,
    String? mockPhoneNumber,
    required String businessName,
    String? displayName,
  }) {
    return auth.registerBusiness(
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      businessName: businessName,
      displayName: displayName,
    );
  }

  Future<Map<String, Object?>> getHome({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    DateTime? date,
    String? query,
    String filter = 'all',
  }) {
    final params = <String, String>{};
    if (date != null) {
      params['date'] = date.toIso8601String().split('T').first;
    }
    if (query != null && query.trim().isNotEmpty) {
      params['search'] = query.trim();
    }
    params['filter'] = filter;
    return getJson(
      '/businesses/$businessId/home',
      queryParameters: params,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> searchBusiness({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String query,
    required String target,
    String status = 'all',
    int limit = 50,
    String? cursor,
  }) => getJson(
    '/businesses/$businessId/search',
    queryParameters: {
      'query': query,
      'target': target,
      'status': status,
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    },
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );

  Future<Map<String, Object?>> listCustomers({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) {
    return getJson(
      '/businesses/$businessId/customers',
      queryParameters: _paginationQuery(limit: limit, cursor: cursor),
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> getCustomer({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return getJson(
      '/businesses/$businessId/customers/$customerId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> createCustomer({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return postJson(
      '/businesses/$businessId/customers',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> updateCustomer({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return patchJson(
      '/businesses/$businessId/customers/$customerId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> deleteCustomer({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return deleteJson(
      '/businesses/$businessId/customers/$customerId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> createCustomerNote({
    required String businessId,
    required String customerId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String text,
  }) {
    return postJson(
      '/businesses/$businessId/customers/$customerId/notes',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: {'text': text.trim()},
    );
  }

  Future<Map<String, Object?>> updateCustomerNote({
    required String businessId,
    required String customerId,
    required String noteId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return patchJson(
      '/businesses/$businessId/customers/$customerId/notes/$noteId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> deleteCustomerNote({
    required String businessId,
    required String customerId,
    required String noteId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return deleteJson(
      '/businesses/$businessId/customers/$customerId/notes/$noteId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> mergeCustomer({
    required String businessId,
    required String sourceCustomerId,
    required String targetCustomerId,
    required String firebaseUid,
    String? mockPhoneNumber,
    Map<String, String>? fieldChoices,
  }) {
    return postJson(
      '/businesses/$businessId/customers/$sourceCustomerId/merge',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: {
        'targetCustomerId': targetCustomerId,
        if (fieldChoices != null && fieldChoices.isNotEmpty)
          'fieldChoices': fieldChoices,
      },
    );
  }

  Future<Map<String, Object?>> listCalls({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) {
    return getJson(
      '/businesses/$businessId/calls',
      queryParameters: _paginationQuery(limit: limit, cursor: cursor),
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> listNotifications({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? status,
    int? limit,
    String? cursor,
  }) {
    final params = _paginationQuery(limit: limit, cursor: cursor);
    if (status != null) params['status'] = status;
    return getJson(
      '/businesses/$businessId/notifications',
      queryParameters: params,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> markNotificationRead({
    required String businessId,
    required String notificationId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/notifications/$notificationId/read',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<Map<String, Object?>> markAllNotificationsRead({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/notifications/read-all',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<Map<String, Object?>> snoozeNotification({
    required String businessId,
    required String notificationId,
    required String preset,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/notifications/$notificationId/snooze',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: {'preset': preset},
    );
  }

  Future<Map<String, Object?>> registerDeviceToken({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String token,
    String? platform,
    String? appVersion,
  }) {
    final body = <String, Object?>{'token': token};
    if (platform != null) body['platform'] = platform;
    if (appVersion != null) body['appVersion'] = appVersion;
    return postJson(
      '/businesses/$businessId/device-tokens',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> getSettings({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return getJson(
      '/businesses/$businessId/settings',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> updateSettings({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return patchJson(
      '/businesses/$businessId/settings',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> listPhoneNumbers({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return getJson(
      '/businesses/$businessId/phone-numbers',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> listMembers({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return getJson(
      '/businesses/$businessId/members',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> createMember({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String phoneNumber,
    String? displayName,
    String memberType = 'EMPLOYEE',
  }) {
    return postJson(
      '/businesses/$businessId/members',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: {
        'phoneNumber': phoneNumber.trim(),
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
        'memberType': memberType,
      },
    );
  }

  Future<Map<String, Object?>> disableMember({
    required String businessId,
    required String memberId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/members/$memberId/disable',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<Map<String, Object?>> listAiPendingActions({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    String? status,
    int? limit,
    String? cursor,
  }) {
    final params = _paginationQuery(limit: limit, cursor: cursor);
    if (status != null) params['status'] = status;
    return getJson(
      '/businesses/$businessId/ai-pending-actions',
      queryParameters: params,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> updateAiPendingAction({
    required String businessId,
    required String aiPendingActionId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return patchJson(
      '/businesses/$businessId/ai-pending-actions/$aiPendingActionId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> approveAiPendingAction({
    required String businessId,
    required String aiPendingActionId,
    required String firebaseUid,
    String? mockPhoneNumber,
    Map<String, Object?> payload = const {},
  }) {
    return postJson(
      '/businesses/$businessId/ai-pending-actions/$aiPendingActionId/approve',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: payload.isEmpty ? const {} : {'payload': payload},
    );
  }

  Future<Map<String, Object?>> rejectAiPendingAction({
    required String businessId,
    required String aiPendingActionId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/ai-pending-actions/$aiPendingActionId/reject',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<Map<String, Object?>> listVoiceCommands({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) {
    return getJson(
      '/businesses/$businessId/voice-commands',
      queryParameters: _paginationQuery(limit: limit, cursor: cursor),
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> createVoiceRealtimeSession({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/voice-commands/realtime-session',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<Map<String, Object?>> submitVoiceCommandTranscript({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required String transcript,
    required String idempotencyKey,
    String languageCode = 'he-IL',
  }) {
    return _transport.sendTranscript(
      '/businesses/$businessId/voice-commands/transcript',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      headers: {
        'x-idempotency-key': idempotencyKey,
        'x-language-code': languageCode,
      },
      body: {
        'transcript': transcript,
        'languageCode': languageCode,
        'sttProvider': 'openai-realtime',
      },
    );
  }

  Future<Map<String, Object?>> uploadVoiceCommandAudio({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required List<int> bytes,
    required String idempotencyKey,
    String filename = 'owner-command.m4a',
    String languageCode = 'he-IL',
  }) {
    return _transport.sendBytes(
      '/businesses/$businessId/voice-commands/audio',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      bytes: bytes,
      contentType: 'audio/mp4',
      headers: {
        'x-idempotency-key': idempotencyKey,
        'x-language-code': languageCode,
        'x-audio-filename': filename,
      },
    );
  }

  Future<Map<String, Object?>> createReminder({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return postJson(
      '/businesses/$businessId/reminders',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> updateReminder({
    required String businessId,
    required String reminderId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return patchJson(
      '/businesses/$businessId/reminders/$reminderId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> completeReminder({
    required String businessId,
    required String reminderId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/reminders/$reminderId/complete',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<Map<String, Object?>> reopenReminder({
    required String businessId,
    required String reminderId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return updateReminder(
      businessId: businessId,
      reminderId: reminderId,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {'status': 'OPEN'},
    );
  }

  Future<Map<String, Object?>> deleteReminder({
    required String businessId,
    required String reminderId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return deleteJson(
      '/businesses/$businessId/reminders/$reminderId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> listReminders({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) {
    return getJson(
      '/businesses/$businessId/reminders',
      queryParameters: _paginationQuery(limit: limit, cursor: cursor),
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> listAppointments({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) {
    return getJson(
      '/businesses/$businessId/appointments',
      queryParameters: _paginationQuery(limit: limit, cursor: cursor),
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> createAppointment({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) => postJson(
    '/businesses/$businessId/appointments',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: body,
  );

  Future<Map<String, Object?>> updateAppointment({
    required String businessId,
    required String appointmentId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) => patchJson(
    '/businesses/$businessId/appointments/$appointmentId',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: body,
  );

  Future<Map<String, Object?>> completeAppointment({
    required String businessId,
    required String appointmentId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => postJson(
    '/businesses/$businessId/appointments/$appointmentId/complete',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {},
  );

  Future<Map<String, Object?>> reopenAppointment({
    required String businessId,
    required String appointmentId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => updateAppointment(
    businessId: businessId,
    appointmentId: appointmentId,
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {'status': 'OPEN'},
  );

  Future<Map<String, Object?>> deleteAppointment({
    required String businessId,
    required String appointmentId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => deleteJson(
    '/businesses/$businessId/appointments/$appointmentId',
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
  );

  Future<Map<String, Object?>> createHomeVisit({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return postJson(
      '/businesses/$businessId/home-visits',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> updateHomeVisit({
    required String businessId,
    required String homeVisitId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return patchJson(
      '/businesses/$businessId/home-visits/$homeVisitId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> completeHomeVisit({
    required String businessId,
    required String homeVisitId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/home-visits/$homeVisitId/complete',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<Map<String, Object?>> reopenHomeVisit({
    required String businessId,
    required String homeVisitId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return updateHomeVisit(
      businessId: businessId,
      homeVisitId: homeVisitId,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {'status': 'OPEN'},
    );
  }

  Future<Map<String, Object?>> deleteHomeVisit({
    required String businessId,
    required String homeVisitId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return deleteJson(
      '/businesses/$businessId/home-visits/$homeVisitId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> listHomeVisits({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) {
    return getJson(
      '/businesses/$businessId/home-visits',
      queryParameters: _paginationQuery(limit: limit, cursor: cursor),
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> createQuote({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return postJson(
      '/businesses/$businessId/quotes',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> updateQuote({
    required String businessId,
    required String quoteId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) {
    return patchJson(
      '/businesses/$businessId/quotes/$quoteId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<Map<String, Object?>> markQuotePaid({
    required String businessId,
    required String quoteId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return postJson(
      '/businesses/$businessId/quotes/$quoteId/mark-paid',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<Map<String, Object?>> reopenQuote({
    required String businessId,
    required String quoteId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return updateQuote(
      businessId: businessId,
      quoteId: quoteId,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {'status': 'OPEN'},
    );
  }

  Future<Map<String, Object?>> deleteQuote({
    required String businessId,
    required String quoteId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) {
    return deleteJson(
      '/businesses/$businessId/quotes/$quoteId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> listQuotes({
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    int? limit,
    String? cursor,
  }) {
    return getJson(
      '/businesses/$businessId/quotes',
      queryParameters: _paginationQuery(limit: limit, cursor: cursor),
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Map<String, String> _paginationQuery({int? limit, String? cursor}) {
    final params = <String, String>{};
    if (limit != null) params['limit'] = '$limit';
    if (cursor != null && cursor.trim().isNotEmpty) params['cursor'] = cursor;
    return params;
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    return _transport.getJson(
      path,
      queryParameters: queryParameters,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    return _transport.sendJson(
      'POST',
      path,
      body: body,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> patchJson(
    String path, {
    required Map<String, Object?> body,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    return _transport.sendJson(
      'PATCH',
      path,
      body: body,
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }

  Future<Map<String, Object?>> deleteJson(
    String path, {
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    return _transport.sendJson(
      'DELETE',
      path,
      body: const {},
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
  }
}
