import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westview_app/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final settings = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings.resetForTesting();
    await settings.load();
  });

  test('telemetry consent defaults to OFF (opt-in) and can be turned on',
      () async {
    // Nothing may be collected before the student explicitly agrees in the
    // first-run dialog, so both streams start disabled.
    expect(settings.analyticsEnabled, isFalse);
    expect(settings.crashReportingEnabled, isFalse);

    await settings.setAnalyticsEnabled(true);
    await settings.setCrashReportingEnabled(true);

    expect(settings.analyticsEnabled, isTrue);
    expect(settings.crashReportingEnabled, isTrue);
  });

  test('consent survives a reload from storage', () async {
    await settings.setAnalyticsEnabled(true);

    await settings.load();
    expect(settings.analyticsEnabled, isTrue);
    expect(settings.crashReportingEnabled, isFalse);
  });

  test('consent is persisted in the settings payload', () async {
    await settings.setCrashReportingEnabled(true);

    final prefs = await SharedPreferences.getInstance();
    final decoded =
        jsonDecode(prefs.getString('westview_settings_v1')!) as Map<String, dynamic>;
    expect(decoded['crashReportingEnabled'], isTrue);
    expect(decoded['analyticsEnabled'], isFalse);
  });

  test('settings stored by an older (opt-out) build never opt a student in',
      () async {
    // An upgrade from a build that recorded "analytics on" as a *default*, not
    // as consent. Nothing in that payload proves the student agreed, so it is
    // discarded, the streams stay off, and the first-run dialog is shown again.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'westview_settings_v1': jsonEncode(<String, dynamic>{
        'analyticsEnabled': true,
        'crashReportingEnabled': true,
        'privacyNoticeSeen': true,
      }),
    });
    settings.resetForTesting();
    await settings.load();

    expect(settings.analyticsEnabled, isFalse);
    expect(settings.crashReportingEnabled, isFalse);
    expect(settings.privacyNoticeSeen, isFalse);
  });

  test('consent recorded by the current model is honoured on reload', () async {
    await settings.setAnalyticsEnabled(true);
    await settings.setPrivacyNoticeSeen();

    settings.resetForTesting();
    await settings.load();

    expect(settings.analyticsEnabled, isTrue);
    expect(settings.crashReportingEnabled, isFalse);
    expect(settings.privacyNoticeSeen, isTrue);
  });

  test('the stored payload records the consent model version', () async {
    await settings.setCrashReportingEnabled(true);
    final prefs = await SharedPreferences.getInstance();
    final decoded = jsonDecode(prefs.getString('westview_settings_v1')!)
        as Map<String, dynamic>;
    expect(decoded['privacyConsentVersion'], 2);
  });

  test('the privacy notice is shown only until acknowledged', () async {
    expect(settings.privacyNoticeSeen, isFalse);

    await settings.setPrivacyNoticeSeen();
    expect(settings.privacyNoticeSeen, isTrue);

    // load() reads from an empty store here (setUp doesn't persist the mock
    // values between calls), so simulate a real relaunch via the payload.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('westview_settings_v1');
    expect(raw, isNotNull);
    SharedPreferences.setMockInitialValues(
      <String, Object>{'westview_settings_v1': raw!},
    );
    settings.resetForTesting();
    await settings.load();
    expect(settings.privacyNoticeSeen, isTrue);
  });
}
