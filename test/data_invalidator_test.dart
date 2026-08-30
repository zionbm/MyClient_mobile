import 'package:dev_mobile/src/api/api_client.dart';
import 'package:dev_mobile/src/config/app_config.dart';
import 'package:dev_mobile/src/core/state/data_invalidator.dart';
import 'package:dev_mobile/src/features/auth/session_controller.dart';
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

  test('resolving an AI action refreshes CRM and the shared AI badge', () {
    final invalidator = DataInvalidator();
    final apiClient = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        coreBaseUrl: 'http://localhost:3000',
        authMode: 'mock',
      ),
    );
    addTearDown(apiClient.close);
    final controller = SessionController(
      apiClient: apiClient,
      dataInvalidator: invalidator,
    );

    controller.markAiActionResolved();

    expect(invalidator.revision(DataScope.crm), 1);
    expect(invalidator.revision(DataScope.ai), 1);
    expect(invalidator.revision(DataScope.calls), 0);
    expect(invalidator.revision(DataScope.settings), 0);

    controller.refreshPendingActions();

    expect(invalidator.revision(DataScope.crm), 1);
    expect(invalidator.revision(DataScope.ai), 2);
  });
}
