import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westview_app/settings.dart';
import 'package:westview_app/telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final settings = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings.resetForTesting();
    await settings.load();
  });

  tearDown(() {
    Telemetry.instance.resetForTesting();
  });

  test('events are sent and the queue empties on success', () async {
    http.Request? captured;
    Telemetry.instance.resetForTesting(
      client: MockClient((request) async {
        captured = request;
        return http.Response('ok', 200);
      }),
    );

    Telemetry.instance.logEvent('screen_view', {'screen': 'calendars'});
    await Telemetry.instance.flush();

    expect(captured, isNotNull);
    expect(captured!.url.toString(), telemetryEndpoint);
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['app'], 'westview-wvaa');
    final events = (body['events'] as List).cast<Map<String, dynamic>>();
    expect(events, isNotEmpty);
    expect(events.first['name'], 'screen_view');
    expect(events.first['properties'], {'screen': 'calendars'});

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('telemetry_queue_v1')!) as List;
    expect(stored, isEmpty);
  });

  test('failed sends keep their queue for the next launch', () async {
    Telemetry.instance
        .resetForTesting(client: MockClient((request) async => http.Response('oops', 503)));

    Telemetry.instance.logEvent('lunch_refresh');
    await Telemetry.instance.flush();

    var sent = 0;
    Telemetry.instance.resetForTesting(
      client: MockClient((request) async {
        sent++;
        return http.Response('ok', 200);
      }),
    );
    // Simulates a relaunch: init() re-loads the persisted queue and flushes.
    await Telemetry.instance.init();
    await Telemetry.instance.flush();

    expect(sent, 1);
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('telemetry_queue_v1')!) as List;
    expect(stored, isEmpty);
  });

  test('4xx responses drop the batch instead of retrying forever', () async {
    Telemetry.instance
        .resetForTesting(client: MockClient((request) async => http.Response('not found', 404)));

    Telemetry.instance.logEvent('app_open');
    await Telemetry.instance.flush();

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('telemetry_queue_v1')!) as List;
    expect(stored, isEmpty);
  });

  test('opting out stops analytics events and crash reports', () async {
    var sent = 0;
    Telemetry.instance.resetForTesting(
      client: MockClient((request) async {
        sent++;
        return http.Response('ok', 200);
      }),
    );

    await settings.setAnalyticsEnabled(false);
    await settings.setCrashReportingEnabled(false);

    Telemetry.instance.logEvent('screen_view');
    Telemetry.instance
        .logError(StateError('boom'), StackTrace.current, context: 'test');
    await Telemetry.instance.flush();

    expect(sent, 0);
  });

  test('queued events of a disabled category are dropped at flush time',
      () async {
    var sentBodies = <Map<String, dynamic>>[];
    Telemetry.instance.resetForTesting(
      client: MockClient((request) async {
        sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('ok', 200);
      }),
    );

    Telemetry.instance.logEvent('screen_view');
    // Crash reporting turned off after a crash was already queued.
    Telemetry.instance
        .logError(StateError('boom'), null, context: 'test');
    await settings.setCrashReportingEnabled(false);

    await Telemetry.instance.flush();

    expect(sentBodies, hasLength(1));
    final sent =
        (sentBodies.single['events'] as List).cast<Map<String, dynamic>>();
    expect(sent, hasLength(1));
    expect(sent.single['type'], 'event');
  });

  test('crash reports truncate long errors and stacks', () async {
    http.Request? captured;
    Telemetry.instance.resetForTesting(
      client: MockClient((request) async {
        captured = request;
        return http.Response('ok', 200);
      }),
    );

    final longError = 'x' * 5000;
    final longStack = StackTrace.current.toString() * 20;
    Telemetry.instance.logError(StateError(longError), StackTrace.fromString(longStack));
    await Telemetry.instance.flush();

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final crash =
        (body['events'] as List).cast<Map<String, dynamic>>().single;
    expect((crash['error'] as String).length, lessThanOrEqualTo(300));
    expect((crash['stack'] as String).length, lessThanOrEqualTo(1500));
  });

  test('only scalar properties are kept', () async {
    http.Request? captured;
    Telemetry.instance.resetForTesting(
      client: MockClient((request) async {
        captured = request;
        return http.Response('ok', 200);
      }),
    );

    Telemetry.instance.logEvent('weird', {
      'count': 3,
      'ok': true,
      'name': 'school calendar',
      'secret_object': {'nested': 'map'},
    });
    await Telemetry.instance.flush();

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final event =
        (body['events'] as List).cast<Map<String, dynamic>>().single;
    expect(event['properties'], {
      'count': 3,
      'ok': true,
      'name': 'school calendar',
    });
  });
}
