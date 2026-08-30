import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/theme/theme.dart';
import 'package:westview_app/widgets/status_views.dart';

void main() {
  testWidgets('ErrorStatusView exposes a working retry button', (tester) async {
    var retries = 0;

    // Without a callback (e.g. a permanent failure) no dead button is shown.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ErrorStatusView(message: 'Check your connection.'),
      ),
    ));
    expect(find.text('Retry'), findsNothing);

    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: ErrorStatusView(
          message: 'Check your connection and try again.',
          onRetry: () => retries++,
        ),
      ),
    ));

    expect(find.text("Can't load this right now"), findsOneWidget);
    expect(
        find.text('Check your connection and try again.'), findsOneWidget);

    final retry = find.widgetWithText(FilledButton, 'Retry');
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48),
        reason: 'retry buttons must keep a 48dp tap target');

    await tester.tap(retry);
    expect(retries, 1);
  });

  testWidgets('EmptyStatusView shows title and message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyStatusView(
          icon: Icons.event_available,
          title: 'No upcoming events',
          message: 'Pull down to refresh.',
        ),
      ),
    ));

    expect(find.text('No upcoming events'), findsOneWidget);
    expect(find.text('Pull down to refresh.'), findsOneWidget);
  });

  testWidgets('SavedCopyNotice announces itself to screen readers',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SavedCopyNotice(label: 'Saved copy from Aug 29'),
      ),
    ));

    expect(
      find.bySemanticsLabel(
          RegExp('Saved copy from Aug 29. Pull down to refresh.')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('status views do not overflow at a 2x text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(2.0)),
        child: const MaterialApp(
          home: Scaffold(
            body: ErrorStatusView(
              title: 'A fairly long error title that needs to wrap',
              message:
                  'A much longer error message that will certainly need to '
                  'wrap onto several lines at double scale.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
