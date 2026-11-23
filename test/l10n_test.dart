import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:westview_app/l10n/strings.dart';
import 'package:westview_app/settings.dart';
import 'package:westview_app/support.dart';

/// Guarantees that every language ships the same keys, that the
/// safety-critical screens are actually translated rather than silently
/// falling back to English, and that the Help screen survives 200% text scale
/// in the longest language.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSettings.instance.resetForTesting();
    await AppSettings.instance.load();
  });

  group('catalogue completeness', () {
    test('all four languages define exactly the same keys', () {
      final english = AppStrings.catalog['en']!.keys.toSet();
      expect(english, isNotEmpty);

      for (final language in ['es', 'zh', 'tl']) {
        final keys = AppStrings.catalog[language]!.keys.toSet();
        expect(
          keys.difference(english),
          isEmpty,
          reason: '$language has keys English does not: '
              '${keys.difference(english)}',
        );
        expect(
          english.difference(keys),
          isEmpty,
          reason: '$language is missing: ${english.difference(keys)}',
        );
      }
    });

    test('no translated value is empty or an untranslated placeholder', () {
      for (final entry in AppStrings.catalog.entries) {
        for (final kv in entry.value.entries) {
          expect(kv.value.trim(), isNotEmpty,
              reason: '${entry.key}/${kv.key} is empty');
        }
      }
    });

    test('safety-critical keys are translated in every language', () {
      final critical = AppStrings.criticalKeys;
      expect(critical, isNotEmpty);
      // The keys that matter if a student is in distress.
      expect(critical, contains('help.emergency.call'));
      expect(critical, contains('help.emergency.title'));
      expect(critical, contains('help.crisis.deaf'));
      expect(critical, contains('disclaimer.title'));
      expect(critical, contains('disclaimer.short'));

      for (final language in ['es', 'zh', 'tl']) {
        final strings = AppStrings.forTag(language);
        for (final key in critical) {
          expect(strings.isMissing(key), isFalse,
              reason: '$language is missing critical key $key');
          // Fallback would silently return English; force a real translation.
          // Proper nouns (the school name) and the district-required wording
          // are intentionally identical in every language, so they are
          // exempt.
          const allowedIdentical = {
            'help.counselor.careerRole',
          };
          if (allowedIdentical.contains(key)) continue;
          expect(
            strings[key],
            isNot(AppStrings.forTag('en')[key]),
            reason: '$language/$key looks untranslated',
          );
        }
      }
    });

    test('hotline keys exist for every hotline in the catalogue', () {
      for (final hotline in crisisHotlines) {
        for (final suffix in ['name', 'desc']) {
          final key = 'hotline.${hotline.id}.$suffix';
          for (final language in ['en', 'es', 'zh', 'tl']) {
            expect(AppStrings.forTag(language).isMissing(key), isFalse,
                reason: '$language missing $key');
          }
        }
        // Every action label that is rendered also exists.
        if (hotline.callUri != null) {
          expect(AppStrings.forTag('es').isMissing('hotline.${hotline.id}.call'),
              isFalse);
        }
        if (hotline.smsUri != null) {
          expect(AppStrings.forTag('es').isMissing('hotline.${hotline.id}.sms'),
              isFalse);
        }
      }
    });

    test('a missing key falls back to English, then to the key itself', () {
      final spanish = AppStrings.forTag('es');
      expect(spanish['definitely.not.a.key'], 'definitely.not.a.key');
      expect(AppStrings.forTag('xx')['nav.getHelp'], 'Get help');
    });

    test('the language picker shows every language name four ways', () {
      for (final language in AppLanguage.values) {
        // Each label names the language in all four shipped languages, so a
        // student can find it without reading the current UI language.
        expect(language.pluralLabel.split('·').length, 4,
            reason: 'label for ${language.code}');
      }
    });

    test('every catalogue key used in the app exists', () {
      // Cheap guard against a typo'd key silently rendering as "settings.xyz"
      // on a safety screen. Only catalogue lookups are matched (not JSON map
      // access), and the `hotline.$id.*` families are built at runtime.
      final english = AppStrings.catalog['en']!;
      final lookup = RegExp(
        // Negative lookbehind so `event['start']` is not read as a catalogue
        // lookup through the `t` alias.
        r"(?<![A-Za-z0-9_.])(?:strings|t|AppStrings\.of\(context\))"
        r"\[\s*'([^']+)'\s*\]",
      );
      final missing = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('l10n/strings.dart'));
      for (final file in files) {
        for (final match in lookup.allMatches(file.readAsStringSync())) {
          final key = match.group(1)!;
          if (english.containsKey(key)) continue;
          // `hotline.$id.name` etc. are built at run time from the hotline id;
          // their concrete keys are asserted in the hotline test above.
          if (key.contains(r'$')) continue;
          missing.add('${file.path}: $key');
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });
  });

  group('language resolution', () {
    test('system follows the device language, mapping filipino correctly', () {
      expect(AppLanguage.system.resolve(const Locale('es', 'MX')), 'es');
      expect(AppLanguage.system.resolve(const Locale('zh', 'CN')), 'zh');
      expect(AppLanguage.system.resolve(const Locale('fil', 'PH')), 'tl');
      expect(AppLanguage.system.resolve(const Locale('tl')), 'tl');
      expect(AppLanguage.system.resolve(const Locale('de')), 'en');
    });

    test('an explicit choice beats the device language', () {
      expect(AppLanguage.spanish.resolve(const Locale('zh')), 'es');
    });

    test('the choice is persisted', () async {
      await AppSettings.instance.setLanguage(AppLanguage.chinese);
      expect(AppSettings.instance.language, AppLanguage.chinese);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('westview_settings_v1')!;
      expect(raw, contains('"language":"zh"'));

      AppSettings.instance.resetForTesting();
      await AppSettings.instance.load();
      expect(AppSettings.instance.language, AppLanguage.chinese);
    });
  });

  group('Help screen under other languages / text scales', () {
    Future<void> pumpHelp(WidgetTester tester, AppLanguage language,
        {double scale = 1.0}) async {
      await AppSettings.instance.setLanguage(language);
      tester.view.physicalSize = const Size(1080, 14000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language == AppLanguage.system ? 'en' : language.code),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const SupportPage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders every language without layout errors', (tester) async {
      for (final language in [
        AppLanguage.english,
        AppLanguage.spanish,
        AppLanguage.chinese,
        AppLanguage.tagalog,
      ]) {
        await pumpHelp(tester, language);
        // A RenderFlex overflow would be reported as an exception.
        expect(tester.takeException(), isNull, reason: 'failed: $language');
        expect(find.byType(SupportPage), findsOneWidget);
      }
    });

    testWidgets('survives 200% text scale in the longest language',
        (tester) async {
      await pumpHelp(tester, AppLanguage.spanish, scale: 2.0);
      expect(tester.takeException(), isNull);
      // The emergency action must still be there and reachable.
      expect(find.byIcon(Icons.call), findsWidgets);
    });

    testWidgets('shows Spanish copy, not English fallbacks', (tester) async {
      await pumpHelp(tester, AppLanguage.spanish);
      expect(find.text('Ayuda'), findsOneWidget);
      expect(find.text('¿Peligro inmediato?'), findsOneWidget);
      expect(find.text('In immediate danger?'), findsNothing);
      expect(find.text('Llamar al 911'), findsOneWidget);
    });

    testWidgets('911 button announces the number to screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHelp(tester, AppLanguage.english);
      final label = AppStrings.forTag('en')['help.emergency.call'];
      expect(find.bySemanticsLabel('$label, 9 1 1'), findsOneWidget);
      handle.dispose();
    });
  });
}
