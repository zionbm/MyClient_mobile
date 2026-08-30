import 'package:dev_mobile/src/app.dart';
import 'package:dev_mobile/src/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows the unified login screen in local mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MyClientApp(
          config: AppConfig(
            environment: AppEnvironment.local,
            coreBaseUrl: 'http://localhost:3000',
            authMode: 'mock',
          ),
        ),
      ),
    );

    expect(find.text('MyClient'), findsOneWidget);
    expect(find.text('נעים להכיר'), findsOneWidget);
    expect(find.text('שלחו לי קוד'), findsOneWidget);
    expect(find.text('התחברות מקומית'), findsNothing);
    expect(find.textContaining('Firebase UID'), findsNothing);

    await tester.enterText(find.byType(TextFormField), '0501111111');
    final sendCodeButton = find.text('שלחו לי קוד');
    await tester.ensureVisible(sendCodeButton);
    await tester.tap(sendCodeButton);
    await tester.pumpAndSettle();

    expect(find.text('הקוד בדרך אליך'), findsOneWidget);
    expect(find.text('אימות וכניסה'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
  });
}
