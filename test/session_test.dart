import 'package:flutter_test/flutter_test.dart';
import 'package:dev_mobile/src/models/session.dart';

void main() {
  test('auth session reads the active business without version flags', () {
    final session = AppSession.fromAuthMe(
      firebaseUid: 'user-1',
      mockPhoneNumber: null,
      json: {
        'user': {'id': 'user-1', 'displayName': 'בעל העסק'},
        'business': {'id': 'business-1', 'name': 'העסק שלי'},
        'onboardingState': 'HAS_BUSINESS',
      },
    );

    expect(session.userId, 'user-1');
    expect(session.businessId, 'business-1');
    expect(session.businessName, 'העסק שלי');
    expect(session.hasBusiness, isTrue);
  });
}
