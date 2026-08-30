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

  test('telemetry consent defaults to on and can be turned off', () async {
    expect(settings.analyticsEnabled, isTrue);
    expect(settings.crashReportingEnabled, isTrue);

    await settings.setAnalyticsEnabled(false);
    await settings.setCrashReportingEnabled(false);

    expect(settings.analyticsEnabled, isFalse);
    expect(settings.crashReportingEnabled, isFalse);
  });

  test('consent survives a reload from storage', () async {
    await settings.setAnalyticsEnabled(false);

    await settings.load();
    expect(settings.analyticsEnabled, isFalse);
    expect(settings.crashReportingEnabled, isTrue);
  });

  test('consent is persisted in the settings payload', () async {
    await settings.setCrashReportingEnabled(false);

    final prefs = await SharedPreferences.getInstance();
    final decoded =
        jsonDecode(prefs.getString('westview_settings_v1')!) as Map<String, dynamic>;
    expect(decoded['crashReportingEnabled'], isFalse);
    expect(decoded['analyticsEnabled'], isTrue);
  });

  test('the privacy notice is shown only until acknowledged', () async {
    expect(settings.privacyNoticeSeen, isFalse);

    await settings.setPrivacyNoticeSeen();
    expect(settings.privacyNoticeSeen, isTrue);

    await settings.load();
    expect(settings.privacyNoticeSeen, isTrue);
  });
}
