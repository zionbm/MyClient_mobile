import 'package:dev_mobile/src/app.dart';
import 'package:dev_mobile/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows local login screen', (tester) async {
    await tester.pumpWidget(
      const MyClientApp(
        config: AppConfig(
          environment: AppEnvironment.local,
          coreBaseUrl: 'http://localhost:3000',
          authMode: 'mock',
        ),
      ),
    );

    expect(find.text('MyClient'), findsOneWidget);
    expect(find.text('התחברות מקומית'), findsOneWidget);
    expect(find.text('בדוק התחברות'), findsOneWidget);
  });
}
