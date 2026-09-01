import 'package:flutter_test/flutter_test.dart';
import 'package:dev_mobile/src/models/session.dart';

void main() {
  test('auth session defaults to V1 when capabilities are absent', () {
    final session = AppSession.fromAuthMe(
      firebaseUid: 'user-1',
      mockPhoneNumber: null,
      json: {
        'user': {'id': 'user-1'},
        'business': {'id': 'business-1', 'name': 'העסק שלי'},
        'onboardingState': 'HAS_BUSINESS',
      },
    );

    expect(session.productModelVersion, 1);
    expect(session.v2ApiEnabled, isFalse);
    expect(session.v2AssistantEnabled, isFalse);
  });

  test('auth session reads V2 capabilities additively', () {
    final session = AppSession.fromAuthMe(
      firebaseUid: 'user-1',
      mockPhoneNumber: null,
      json: {
        'user': {'id': 'user-1'},
        'business': {'id': 'business-1', 'name': 'העסק שלי'},
        'onboardingState': 'HAS_BUSINESS',
        'capabilities': {
          'productModelVersion': 2,
          'v2Api': true,
          'v2Assistant': true,
        },
      },
    );

    expect(session.productModelVersion, 2);
    expect(session.v2ApiEnabled, isTrue);
    expect(session.v2AssistantEnabled, isTrue);
  });
}
