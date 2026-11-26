import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/l10n/strings.dart';
import 'package:westview_app/settings.dart';
import 'package:westview_app/theme/theme.dart';
import 'package:westview_app/widgets/status_views.dart';

/// The status views fall back to translated copy, so they need the app's
/// locale plumbing. English is pinned so the assertions below are stable.
Widget _app(Widget child, {TextScaler? textScaler}) {
  return MaterialApp(
    theme: lightTheme,
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('es'), Locale('zh'),
      Locale('tl')],
    home: Scaffold(
      body: textScaler == null
          ? child
          : MediaQuery(
              data: MediaQueryData(textScaler: textScaler),
              child: child,
            ),
    ),
  );
}

void main() {
  setUp(() {
    AppSettings.instance.resetForTesting();
  });

  testWidgets('ErrorStatusView exposes a working retry button', (tester) async {
    var retries = 0;

    // Without a callback (e.g. a permanent failure) no dead button is shown.
    // ErrorStatusView falls back to the *translated* title and retry label,
    // which needs a Localizations scope that knows the app's catalogue.
    await tester.pumpWidget(_app(
      const ErrorStatusView(message: 'Check your connection.'),
    ));
    expect(find.text('Try again'), findsNothing);

    await tester.pumpWidget(_app(
      ErrorStatusView(
        message: 'Check your connection and try again.',
        onRetry: () => retries++,
      ),
    ));

    expect(find.text("Can't load this right now"), findsOneWidget);
    expect(
        find.text('Check your connection and try again.'), findsOneWidget);

    // The label comes from the catalogue (common.retry = "Try again") so a
    // translated build never shows English here.
    final retry = find.widgetWithText(FilledButton, 'Try again');
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48),
        reason: 'retry buttons must keep a 48dp tap target');

    await tester.tap(retry);
    expect(retries, 1);
  });

  testWidgets('EmptyStatusView shows title and message', (tester) async {
    await tester.pumpWidget(_app(
      const EmptyStatusView(
        icon: Icons.event_available,
        title: 'No upcoming events',
        message: 'Pull down to refresh.',
      ),
    ));

    expect(find.text('No upcoming events'), findsOneWidget);
    expect(find.text('Pull down to refresh.'), findsOneWidget);
  });

  testWidgets('SavedCopyNotice announces itself to screen readers',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
        _app(const SavedCopyNotice(label: 'Saved copy from Aug 29')));

    expect(
      find.bySemanticsLabel(
          RegExp('Saved copy from Aug 29. Pull down to refresh.')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('status views do not overflow at a 2x text scale', (tester) async {
    await tester.pumpWidget(_app(
      const ErrorStatusView(
        title: 'A fairly long error title that needs to wrap',
        message: 'A much longer error message that will certainly need to '
            'wrap onto several lines at double scale.',
      ),
      textScaler: const TextScaler.linear(2.0),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
