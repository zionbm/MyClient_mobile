import '../../core/network/api_transport.dart';
import '../../models/work_item.dart';

enum CrmWorkItemType { reminder, homeVisit, appointment, quote }

extension CrmWorkItemTypeParsing on CrmWorkItemType {
  static CrmWorkItemType? fromApiType(Object value) => switch (value) {
    'reminder' || WorkItemType.reminder => CrmWorkItemType.reminder,
    'home_visit' || WorkItemType.homeVisit => CrmWorkItemType.homeVisit,
    'appointment' || WorkItemType.appointment => CrmWorkItemType.appointment,
    'quote' || WorkItemType.quote => CrmWorkItemType.quote,
    _ => null,
  };
}

extension on CrmWorkItemType {
  String get apiValue => switch (this) {
    CrmWorkItemType.reminder => 'reminder',
    CrmWorkItemType.homeVisit => 'home_visit',
    CrmWorkItemType.appointment => 'appointment',
    CrmWorkItemType.quote => 'quote',
  };

  String get collection => switch (this) {
    CrmWorkItemType.reminder => 'reminders',
    CrmWorkItemType.homeVisit => 'home-visits',
    CrmWorkItemType.appointment => 'appointments',
    CrmWorkItemType.quote => 'quotes',
  };
}

class WorkItemRepository {
  const WorkItemRepository(this._transport);

  final ApiTransport _transport;

  Future<WorkItem> get({
    required CrmWorkItemType type,
    required String businessId,
    required String itemId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    final json = await _transport.getJson(
      '/businesses/$businessId/work-items/${type.apiValue}/$itemId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
    );
    final item = json['item'];
    if (item is! Map<String, Object?>) {
      throw const FormatException('Work item response is missing item');
    }
    return WorkItem.fromJson(item);
  }

  Future<void> create({
    required CrmWorkItemType type,
    required String businessId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) async {
    await _transport.sendJson(
      'POST',
      '/businesses/$businessId/${type.collection}',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<void> update({
    required CrmWorkItemType type,
    required String businessId,
    required String itemId,
    required String firebaseUid,
    String? mockPhoneNumber,
    required Map<String, Object?> body,
  }) async {
    await _transport.sendJson(
      'PATCH',
      '/businesses/$businessId/${type.collection}/$itemId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: body,
    );
  }

  Future<void> complete({
    required CrmWorkItemType type,
    required String businessId,
    required String itemId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => _action(
    type: type,
    businessId: businessId,
    itemId: itemId,
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    action: type == CrmWorkItemType.quote ? 'mark-paid' : 'complete',
  );

  Future<void> reopen({
    required CrmWorkItemType type,
    required String businessId,
    required String itemId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) => update(
    type: type,
    businessId: businessId,
    itemId: itemId,
    firebaseUid: firebaseUid,
    mockPhoneNumber: mockPhoneNumber,
    body: const {'status': 'OPEN'},
  );

  Future<void> delete({
    required CrmWorkItemType type,
    required String businessId,
    required String itemId,
    required String firebaseUid,
    String? mockPhoneNumber,
  }) async {
    await _transport.sendJson(
      'DELETE',
      '/businesses/$businessId/${type.collection}/$itemId',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }

  Future<void> _action({
    required CrmWorkItemType type,
    required String businessId,
    required String itemId,
    required String firebaseUid,
    required String action,
    String? mockPhoneNumber,
  }) async {
    await _transport.sendJson(
      'POST',
      '/businesses/$businessId/${type.collection}/$itemId/$action',
      firebaseUid: firebaseUid,
      mockPhoneNumber: mockPhoneNumber,
      body: const {},
    );
  }
}
