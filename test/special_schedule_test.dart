import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westview_app/special_schedule.dart';

/// The example schedule shared by the school's StudyCS server.
const String sampleSpecialScheduleJson = '''[
  { "hour": 8,  "minute": 35, "duration": 120, "title": "Link Crew Event - 9th Graders" },
  { "hour": 10,  "minute": 35, "duration": 16,  "title": "Den - All Students" },
  { "hour": 10, "minute": 51, "duration": 6, "title": "Passing" },
  { "hour": 10, "minute": 57, "duration": 58, "title": "Period 1" },
  { "hour": 11, "minute": 55,  "duration": 30, "title": "Lunch",   "isPM": false },
  { "hour": 12, "minute": 25, "duration": 6,  "title": "Passing", "isPM": true },
  { "hour": 12, "minute": 31, "duration": 58, "title": "Period 2","isPM": true },
  { "hour": 1,  "minute": 29,  "duration": 6,  "title": "Passing", "isPM": true },
  { "hour": 1,  "minute": 35, "duration": 58, "title": "Period 3","isPM": true },
  { "hour": 2,  "minute": 32,  "duration": 6,  "title": "Passing", "isPM": true },
  { "hour": 2,  "minute": 38, "duration": 58, "title": "Period 4","isPM": true }
]''';

TimeOfDay time(int hour, int minute) => TimeOfDay(hour: hour, minute: minute);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('parseSpecialScheduleJson', () {
    test('converts hour/minute/duration/isPM into period maps', () {
      final periods = parseSpecialScheduleJson(sampleSpecialScheduleJson);

      expect(periods, hasLength(11));

      expect(periods[0]['Period'], 'Link Crew Event - 9th Graders');
      expect(periods[0]['startTime'], time(8, 35));
      expect(periods[0]['endTime'], time(10, 35));

      expect(periods[3]['Period'], 'Period 1');
      expect(periods[3]['startTime'], time(10, 57));
      expect(periods[3]['endTime'], time(11, 55));

      // Lunch is explicitly marked AM.
      expect(periods[4]['Period'], 'Lunch');
      expect(periods[4]['startTime'], time(11, 55));
      expect(periods[4]['endTime'], time(12, 25));

      expect(periods[6]['Period'], 'Period 2');
      expect(periods[6]['startTime'], time(12, 31));
      expect(periods[6]['endTime'], time(13, 29));

      expect(periods[10]['Period'], 'Period 4');
      expect(periods[10]['startTime'], time(14, 38));
      expect(periods[10]['endTime'], time(15, 36));
    });

    test('assumes PM for low hours without isPM (school events)', () {
      final periods = parseSpecialScheduleJson(
        '[{"hour": 1, "minute": 0, "duration": 60, "title": "Event"}]',
      );
      expect(periods.single['startTime'], time(13, 0));
      expect(periods.single['endTime'], time(14, 0));
    });

    test('treats high hours without isPM as morning times', () {
      final periods = parseSpecialScheduleJson(
        '[{"hour": 9, "minute": 30, "duration": 45, "title": "Assembly"}]',
      );
      expect(periods.single['startTime'], time(9, 30));
      expect(periods.single['endTime'], time(10, 15));
    });

    test('skips malformed entries but keeps valid ones', () {
      final periods = parseSpecialScheduleJson(
        '[{"hour": 8, "minute": 0, "duration": 30, "title": "A"},'
        ' {"hour": 99, "minute": 0, "duration": 30, "title": "Bad"},'
        ' {"no": "fields"}]',
      );
      expect(periods, hasLength(1));
      expect(periods.single['Period'], 'A');
    });

    test('rejects non-list bodies and empty lists', () {
      expect(
        () => parseSpecialScheduleJson('{"nope": true}'),
        throwsFormatException,
      );
      expect(() => parseSpecialScheduleJson('[]'), throwsFormatException);
      expect(() => parseSpecialScheduleJson('not json'), throwsFormatException);
    });
  });

  group('SpecialScheduleService', () {
    test('follows the .json path contract and parses the schedule', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/westview/special_schedule2/8/18')) {
          return http.Response('/westview/special/0818.json', 200);
        }
        if (request.url.path.endsWith('.json')) {
          return http.Response(sampleSpecialScheduleJson, 200);
        }
        return http.Response('not found', 404);
      });
      final service = SpecialScheduleService(
        client: client,
        clock: () => DateTime(2026, 8, 18, 9),
      );

      await service.refreshToday();

      expect(service.lastFetchFailed, isFalse);
      expect(service.todaySchedule, isNotNull);
      expect(
        service.todaySchedule!.first['Period'],
        'Link Crew Event - 9th Graders',
      );
    });

    test('treats an empty body as "no special schedule"', () async {
      final client = MockClient((request) async => http.Response('', 200));
      final service = SpecialScheduleService(
        client: client,
        clock: () => DateTime(2026, 8, 18, 9),
      );

      await service.refreshToday();

      expect(service.lastFetchFailed, isFalse);
      expect(service.todaySchedule, isNull);
    });

    test('treats a body without .json as "no special schedule"', () async {
      final client = MockClient(
        (request) async => http.Response('nothing today', 200),
      );
      final service = SpecialScheduleService(
        client: client,
        clock: () => DateTime(2026, 8, 18, 9),
      );

      await service.refreshToday();

      expect(service.lastFetchFailed, isFalse);
      expect(service.todaySchedule, isNull);
    });

    test('caches for at least 2 days without asking the server again', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        if (request.url.path.endsWith('/westview/special_schedule2/8/18')) {
          return http.Response('', 200); // no special schedule
        }
        return http.Response('not found', 404);
      });
      var now = DateTime(2026, 8, 18, 9);
      final service = SpecialScheduleService(client: client, clock: () => now);

      await service.refreshToday();
      expect(requests, 1);

      // Same day, cache is fresh: no additional request.
      await service.refreshToday();
      await service.refreshToday();
      expect(requests, 1);

      // Two days later the cache is still fresh (TTL is 3 days).
      now = now.add(const Duration(days: 2));
      await service.refreshToday();
      expect(requests, 1);

      // Once the TTL has passed, the server is asked again.
      now = now.add(const Duration(days: 1, minutes: 1));
      await service.refreshToday();
      expect(requests, 2);
    });

    test('survives restarts through the persisted cache', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/westview/special_schedule2/8/18')) {
          return http.Response('/westview/special/0818.json', 200);
        }
        return http.Response(sampleSpecialScheduleJson, 200);
      });
      final now = DateTime(2026, 8, 18, 9);
      final first = SpecialScheduleService(client: client, clock: () => now);
      await first.refreshToday();

      // A new instance (simulated app restart) must load the cache without
      // touching the network: give it a client that would fail if called.
      var requests = 0;
      final offline = MockClient((request) async {
        requests++;
        return http.Response('down', 503);
      });
      final second =
          SpecialScheduleService(client: offline, clock: () => now);
      await second.init();
      await second.refreshToday();

      expect(requests, 0);
      expect(second.todaySchedule, isNotNull);
      expect(
        second.todaySchedule!.first['Period'],
        'Link Crew Event - 9th Graders',
      );
    });

    test('keeps the stale schedule and reports failure when unreachable',
        () async {
      final now = DateTime(2026, 8, 18, 9);
      final good = MockClient((request) async {
        if (request.url.path.endsWith('/westview/special_schedule2/8/18')) {
          return http.Response('/westview/special/0818.json', 200);
        }
        return http.Response(sampleSpecialScheduleJson, 200);
      });
      final first = SpecialScheduleService(client: good, clock: () => now);
      await first.refreshToday();
      expect(first.todaySchedule, isNotNull);

      // The server goes down while the cached answer is (past) stale: the
      // previous schedule must be kept and the failure must be reported.
      final down = MockClient(
        (request) async => http.Response('oops', 503),
      );
      final service = SpecialScheduleService(client: down, clock: () => now);

      await service.refreshToday(force: true);

      expect(service.lastFetchFailed, isTrue);
      expect(service.todaySchedule, isNotNull);
      expect(
        service.todaySchedule!.first['Period'],
        'Link Crew Event - 9th Graders',
      );
    });

    test('reports failure when nothing is cached and no source is reachable',
        () async {
      final down = MockClient(
        (request) async => http.Response('oops', 503),
      );
      final service = SpecialScheduleService(
        client: down,
        clock: () => DateTime(2026, 8, 18, 9),
      );

      await service.refreshToday();

      expect(service.lastFetchFailed, isTrue);
      expect(service.todaySchedule, isNull);
    });

    test('falls back to backup sources when the primary is unreachable',
        () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/westview/special_schedule2/8/18')) {
          return http.Response('oops', 500); // primary server is down
        }
        if (path.endsWith('/mirror/westview/8/18.json')) {
          return http.Response(sampleSpecialScheduleJson, 200);
        }
        return http.Response('not found', 404);
      });
      final service = SpecialScheduleService(
        client: client,
        clock: () => DateTime(2026, 8, 18, 9),
      );
      service.fallbackUrls.add(
        'https://mirror.example.com/mirror/westview/{month}/{day}.json',
      );

      await service.refreshToday();

      expect(service.lastFetchFailed, isFalse);
      expect(service.todaySchedule, isNotNull);
      expect(service.todaySchedule, hasLength(11));
    });
  });
}
