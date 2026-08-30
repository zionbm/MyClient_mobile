import 'package:dev_mobile/src/widgets/pending_actions_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the shared pending action count and opens the list', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.teal,
          body: PendingActionsIconButton(
            countFuture: Future.value(3),
            onPressed: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byTooltip('פעולות AI'));
    expect(opened, isTrue);
  });

  testWidgets('hides the badge when there are no pending actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PendingActionsIconButton(
          countFuture: Future.value(0),
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing);
    expect(find.byTooltip('פעולות AI'), findsOneWidget);
  });
}
