import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/theme/theme.dart';
import 'package:westview_app/widgets/section_selector.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: lightTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('every pill meets the 48dp minimum tap target', (tester) async {
    await tester.pumpWidget(_wrap(SectionSelector(
      labels: const ['School Calendar', 'Athletics', 'School Lunches'],
      selectedIndex: 0,
      onSelected: (_) {},
    )));

    for (final label in ['School Calendar', 'Athletics', 'School Lunches']) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      final inkWell = find
          .ancestor(of: text, matching: find.byType(InkWell))
          .first;
      final size = tester.getSize(inkWell);
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '$label tap target must be at least 48dp tall');
      expect(size.width, greaterThanOrEqualTo(48),
          reason: '$label tap target must be at least 48dp wide');
    }
  });

  testWidgets('pills announce their label and selected state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(SectionSelector(
      labels: const ['Weekly Newsletter', 'Counseling'],
      selectedIndex: 1,
      onSelected: (_) {},
    )));

    final selected =
        find.bySemanticsLabel('Counseling').first;
    final unselected =
        find.bySemanticsLabel('Weekly Newsletter').first;
    expect(selected, findsOneWidget);
    expect(unselected, findsOneWidget);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Counseling').first)
          .flags
          .contains(SemanticsFlag.isSelected),
      isTrue,
      reason: 'the active section must be announced as selected',
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Weekly Newsletter').first)
          .flags
          .contains(SemanticsFlag.isSelected),
      isFalse,
    );

    handle.dispose();
  });

  testWidgets('tapping a pill selects it', (tester) async {
    var selected = -1;
    await tester.pumpWidget(_wrap(SectionSelector(
      labels: const ['One', 'Two'],
      selectedIndex: 0,
      onSelected: (index) => selected = index,
    )));

    await tester.tap(find.text('Two'));
    expect(selected, 1);
  });

  testWidgets('labels stay visible at a 2x text scale without overflow',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(2.0)),
        child: _wrap(SectionSelector(
          labels: const [
            'Weekly Newsletter',
            'Counseling Newsletters',
            'Den Announcements',
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        )),
      ),
    );
    await tester.pumpAndSettle();

    // Overflow exceptions (RenderFlex / layout) surface here.
    expect(tester.takeException(), isNull);
    for (final label in [
      'Weekly Newsletter',
      'Counseling Newsletters',
      'Den Announcements',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('LazyIndexedStack builds only visited children and keeps state',
      (tester) async {
    await tester.pumpWidget(_wrap(const _LazyTestHost()));

    // Only the first section is alive initially.
    expect(find.text('count 0: 0'), findsOneWidget);
    expect(find.text('count 1: 0'), findsNothing);
    expect(find.text('count 2: 0'), findsNothing);

    // Change state in section 1, then leave and come back.
    await tester.tap(find.text('show 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('inc 1'));
    await tester.tap(find.text('inc 1'));
    await tester.pumpAndSettle();
    expect(find.text('count 1: 2'), findsOneWidget);

    await tester.tap(find.text('show 0'));
    await tester.pumpAndSettle();
    expect(find.text('count 0: 0'), findsOneWidget);

    await tester.tap(find.text('show 1'));
    await tester.pumpAndSettle();
    // State survived the round trip.
    expect(find.text('count 1: 2'), findsOneWidget);
    // Section 2 was never opened, so it was never built.
    expect(find.text('count 2: 0'), findsNothing);
  });
}

class _LazyTestHost extends StatefulWidget {
  const _LazyTestHost();

  @override
  State<_LazyTestHost> createState() => _LazyTestHostState();
}

class _LazyTestHostState extends State<_LazyTestHost> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          TextButton(
            onPressed: () => setState(() => index = i),
            child: Text('show $i'),
          ),
        Expanded(
          child: LazyIndexedStack(
            index: index,
            itemCount: 3,
            itemBuilder: (context, i) => _CounterChild(index: i),
          ),
        ),
      ],
    );
  }
}

class _CounterChild extends StatefulWidget {
  const _CounterChild({required this.index});

  final int index;

  @override
  State<_CounterChild> createState() => _CounterChildState();
}

class _CounterChildState extends State<_CounterChild> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('count ${widget.index}: $count'),
        TextButton(
          onPressed: () => setState(() => count++),
          child: Text('inc ${widget.index}'),
        ),
      ],
    );
  }
}
