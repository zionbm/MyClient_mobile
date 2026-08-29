import 'package:dev_mobile/src/core/state/data_invalidator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalidates only the requested data scopes', () {
    final invalidator = DataInvalidator();

    invalidator.invalidate({DataScope.crm, DataScope.ai});

    expect(invalidator.revision(DataScope.crm), 1);
    expect(invalidator.revision(DataScope.ai), 1);
    expect(invalidator.revision(DataScope.calls), 0);
    expect(invalidator.revision(DataScope.settings), 0);
  });
}
