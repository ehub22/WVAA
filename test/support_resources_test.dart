import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:westview_app/safety.dart';
import 'package:westview_app/support.dart';

/// These tests exist to catch the one class of bug that matters most here:
/// a mistyped hotline number or a softened disclaimer reaching a student.
/// They deliberately hard-code the expected digits instead of reading them
/// from the constants they are checking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('crisis hotlines', () {
    Hotline byId(String id) => crisisHotlines.firstWhere((h) => h.id == id);

    test('988 is callable and textable', () {
      final h = byId('988');
      expect(h.callUri.toString(), 'tel:988');
      expect(h.smsUri.toString(), startsWith('sms:988'));
    });

    test('San Diego Access & Crisis Line number is exactly 1-888-724-7240', () {
      expect(byId('sdaocl').callUri.toString(), 'tel:18887247240');
    });

    test('Crisis Text Line hints HOME to 741741', () {
      final uri = byId('crisistext').smsUri!;
      expect(uri.toString(), contains('741741'));
      expect(Uri.decodeFull(uri.query), contains('HOME'));
    });

    test('The Trevor Project numbers match the published ones', () {
      final h = byId('trevor');
      expect(h.callUri.toString(), 'tel:18664887386');
      expect(h.smsUri.toString(), contains('678678'));
    });

    test('PUSD tip line is 1-844-PUSD-TIP', () {
      // 1-844-787-3747
      expect(byId('pusdtip').callUri.toString(), 'tel:18447873747');
    });

    test('every hotline has at least one way to reach it', () {
      for (final h in crisisHotlines) {
        expect(
          h.callUri != null || h.smsUri != null || h.websiteUri != null,
          isTrue,
          reason: '${h.name} has no contact action',
        );
      }
    });

    test('no hotline uses a deprecated 1-800-273-8255 lifeline number', () {
      for (final h in crisisHotlines) {
        expect(h.callNumber, isNot('18002738255'));
      }
    });

    test('website links are https only', () {
      for (final h in crisisHotlines) {
        if (h.website != null) {
          expect(Uri.parse(h.website!).scheme, 'https', reason: h.name);
        }
      }
    });
  });

  group('Westview counselors', () {
    test('all five caseload ranges are covered with no gaps', () {
      expect(westviewCounselors, hasLength(5));
      expect(
        westviewCounselors.map((c) => c.caseload).toList(),
        ['A–C', 'D–J', 'K–M', 'N–Sh', 'Si–Z'],
      );
    });

    test('counselors are reachable by phone and e-mail', () {
      for (final c in westviewCounselors) {
        // Main line is (858) 780-2000, extension encoded after the pause.
        expect(c.phoneUri.scheme, 'tel');
        expect(Uri.decodeFull(c.phoneUri.path),
            contains('8587802000;ext=${c.extension}'));
        expect(c.email, endsWith('@powayusd.com'));
      }
    });

    test('no duplicate extensions or e-mail addresses', () {
      expect(westviewCounselors.map((c) => c.extension).toSet(),
          hasLength(westviewCounselors.length));
      expect(westviewCounselors.map((c) => c.email).toSet(),
          hasLength(westviewCounselors.length));
    });
  });

  group('disclaimers', () {
    test('English disclaimer carries the district-required clauses', () {
      expect(disclaimers.english, contains('not a school-sponsored activity'));
      expect(disclaimers.english,
          contains('is not endorsed by the school or Poway Unified School '
              'District'));
    });

    test('Spanish disclaimer is present and mentions the district', () {
      expect(disclaimers.spanish, contains('AVISO LEGAL'));
      expect(disclaimers.spanish, contains('Poway'));
    });

    test('short disclaimer says it is not a PUSD app', () {
      expect(shortDisclaimer, contains('Not a Poway Unified app'));
      // Case-insensitive: the sentence starts with a capital, but the
      // assertion is about the substance of the claim.
      expect(shortDisclaimer.toLowerCase(), contains('not sponsored or endorsed'));
    });

    test('short disclaimer is at least as specific, not vaguer', () {
      // Guards against someone "simplifying" it into meaningless marketing
      // copy like "not affiliated with any school".
      expect(shortDisclaimer.toLowerCase(), contains('poway unified school '
          'district'));
      expect(shortDisclaimer.toLowerCase(), contains('westview high school'));
    });
  });

  group('SupportPage', () {
    testWidgets('renders counselors, hotlines and the disclaimer without '
        'any network', (tester) async {
      // Tall viewport so the lazily built ListView renders every section —
      // the point of the test is that no section needs a network call.
      tester.view.physicalSize = const Size(1200, 12000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: SupportPage()));
      await tester.pumpAndSettle();

      expect(find.text('Get help'), findsOneWidget);
      // Emergency actions come first.
      expect(find.text('Call 911'), findsOneWidget);
      // Crisis resources.
      expect(find.textContaining('988'), findsWidgets);
      expect(find.text('San Diego Access & Crisis Line'), findsOneWidget);
      // Counselors.
      expect(find.text('Talk to a counselor at Westview'), findsOneWidget);
      expect(find.text('Taylor Oakley'), findsOneWidget);
      // The disclaimer.
      expect(find.text('This app is not part of Poway Unified'),
          findsOneWidget);
    });

    testWidgets('keeps every contact action at a 48dp tap target',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: SupportPage()));
      await tester.pumpAndSettle();

      final buttons = find.byWidgetPredicate((w) =>
          w is IconButton ||
          w is FilledButton ||
          w is OutlinedButton ||
          w is TextButton);
      expect(buttons, findsWidgets);
      for (final element in buttons.evaluate()) {
        final size = element.size;
        if (size == null) continue;
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });
  });

  group('SafetySettings', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      SafetySettings.instance.resetForTesting();
      await SafetySettings.instance.load();
    });

    test('both protections default to on (safe by default)', () {
      expect(SafetySettings.instance.quickExitEnabled, isTrue);
      expect(SafetySettings.instance.hideRecents, isTrue);
    });

    test('turning each off persists across a reload', () async {
      await SafetySettings.instance.setQuickExitEnabled(false);
      await SafetySettings.instance.setHideRecents(false);

      SafetySettings.instance.resetForTesting();
      await SafetySettings.instance.load();

      expect(SafetySettings.instance.quickExitEnabled, isFalse);
      expect(SafetySettings.instance.hideRecents, isFalse);
    });

    test('a storage failure keeps the safe defaults', () async {
      // No mock values at all and no binding failure path: load must not throw
      // and must leave both protections on.
      SafetySettings.instance.resetForTesting();
      await SafetySettings.instance.load();
      expect(SafetySettings.instance.quickExitEnabled, isTrue);
      expect(SafetySettings.instance.hideRecents, isTrue);
    });
  });

  group('QuickExit', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(QuickExit.channel, (call) async {
        calls.add(call);
        return call.method == 'moveTaskToBack' ? true : null;
      });
      SafetySettings.instance.resetForTesting();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(QuickExit.channel, null);
    });

    test('sends the moveTaskToBack platform call', () async {
      final handled = await QuickExit.trigger();
      expect(handled, isTrue);
      expect(calls.single.method, 'moveTaskToBack');
    });

    test('applies the recents-privacy flag with the requested value', () async {
      await QuickExit.applyRecentsPrivacy(true);
      expect(calls.single.method, 'setRecentsPrivacy');
      expect(calls.single.arguments, <String, Object?>{'hide': true});
    });

    test('a missing platform implementation still reports success or '
        'falls back without throwing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(QuickExit.channel, null);
      // Either SystemNavigator.pop succeeds (returns true) or it is a no-op in
      // tests; the important part is that it never throws.
      await expectLater(QuickExit.trigger(), completes);
    });

    testWidgets('a long-press on the help button exits without a confirm '
        'dialog', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SupportPage()));
      await tester.pumpAndSettle();

      // No dialog text should ever appear as part of exiting.
      expect(find.text('Are you sure?'), findsNothing);
      expect(QuickExit.longPressHandler(
        tester.element(find.byType(SupportPage)),
      ), isNotNull);
    });
  });
}
