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

  test('only actual classes can be renamed', () {
    expect(customizablePeriodNames, contains('Period 1'));
    expect(customizablePeriodNames, contains('Period 4'));
    expect(customizablePeriodNames, isNot(contains('Passing')));
    expect(customizablePeriodNames, isNot(contains('Lunch')));
    expect(customizablePeriodNames, isNot(contains('Wolverine Time')));
    expect(customizablePeriodNames, isNot(contains('SSH')));
  });

  test('periods keep their default name until renamed', () async {
    expect(settings.displayName('Period 1'), 'Period 1');
    expect(settings.isRenamed('Period 1'), isFalse);

    await settings.setPeriodSettings(
      'Period 1',
      const PeriodSettings(customName: 'Human Body Systems'),
    );

    expect(settings.displayName('Period 1'), 'Human Body Systems');
    expect(settings.isRenamed('Period 1'), isTrue);
  });

  test('teacher and room are combined and can be toggled off', () async {
    await settings.setPeriodSettings(
      'Period 2',
      const PeriodSettings(teacher: 'Mr. Smith', room: '402'),
    );
    expect(settings.detailsFor('Period 2'), 'Mr. Smith · Rm 402');

    await settings.setShowTeacher(false);
    expect(settings.detailsFor('Period 2'), 'Rm 402');

    await settings.setShowRoom(false);
    expect(settings.detailsFor('Period 2'), isEmpty);
  });

  test('room labels the student already typed are left alone', () async {
    await settings.setPeriodSettings(
      'Period 3',
      const PeriodSettings(room: 'Room 12'),
    );
    expect(settings.detailsFor('Period 3'), 'Room 12');
  });

  test('the live activity follows the notification master switch', () async {
    expect(settings.liveActivityActive, isTrue);

    await settings.setLiveActivityEnabled(false);
    expect(settings.liveActivityActive, isFalse);

    await settings.setLiveActivityEnabled(true);
    await settings.setNotificationsEnabled(false);
    expect(settings.liveActivityActive, isFalse);
  });

  test('settings are written to storage and read back', () async {
    await settings.setNotificationsEnabled(false);
    await settings.setPeriodSettings(
      'Period 4',
      const PeriodSettings(customName: 'Ceramics', teacher: 'Ms. Lee'),
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('westview_settings_v1');
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['notificationsEnabled'], isFalse);
    expect(
      (decoded['periods'] as Map)['Period 4']['customName'],
      'Ceramics',
    );

    await settings.load();
    expect(settings.notificationsEnabled, isFalse);
    expect(settings.displayName('Period 4'), 'Ceramics');
    expect(settings.detailsFor('Period 4'), 'Ms. Lee');
  });
}
