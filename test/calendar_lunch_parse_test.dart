import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/calendars.dart';
import 'package:westview_app/school_lunch.dart';

void main() {
  group('CalendarEventsViewState.parseEvents', () {
    // Fixed "today" so the yesterday-onward filter never makes a test flaky.
    final now = DateTime(2026, 11, 26, 12);

    String feed(String events) =>
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$events\r\nEND:VCALENDAR\r\n';

    test('expands multi-day all-day events into one entry per day', () {
      final body = feed(
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20261127\r\n'
        // iCalendar all-day end dates are exclusive.
        'DTEND;VALUE=DATE:20261129\r\n'
        'SUMMARY:Homecoming Week\r\n'
        'END:VEVENT',
      );

      final events = CalendarEventsViewState.parseEvents(body, now: now);

      expect(events, hasLength(2));
      expect((events[0]['displayDate'] as DateTime).day, 27);
      expect((events[1]['displayDate'] as DateTime).day, 28);
      expect(events[0]['start']['date'], '2026-11-27');
    });

    test('sorts by display date and keeps timed event details', () {
      final body = feed(
        'BEGIN:VEVENT\n'
        'DTSTART:20261128T170000Z\n'
        'DTEND:20261128T180000Z\n'
        'SUMMARY:Later event\n'
        'END:VEVENT\n'
        'BEGIN:VEVENT\n'
        'DTSTART:20261127T150000Z\n'
        'DTEND:20261127T160000Z\n'
        'LOCATION:Westview High School\\, San Diego\\, CA\n'
        'DESCRIPTION:First line\\nSecond line\\, with a comma\n'
        'SUMMARY:Earlier event\n'
        'END:VEVENT',
      );

      final events = CalendarEventsViewState.parseEvents(body, now: now);

      expect(events, hasLength(2));
      expect(events[0]['summary'], 'Earlier event');
      expect(events[1]['summary'], 'Later event');
      expect(events[0]['location'], 'Westview High School, San Diego, CA');
      expect(events[0]['description'],
          'First line\nSecond line, with a comma');
      // UTC values are converted to the phone's zone, so the exact hour
      // depends on where the test runs.
      expect(DateTime.parse(events[0]['start']['dateTime'] as String).isUtc,
          isFalse);
    });

    test('joins folded lines before reading a value', () {
      final body = feed(
        'BEGIN:VEVENT\n'
        'DTSTART;VALUE=DATE:20261127\n'
        'DTEND;VALUE=DATE:20261128\n'
        'SUMMARY:A summary Google wrapped across\n'
        '  two lines\n'
        'END:VEVENT',
      );

      final events = CalendarEventsViewState.parseEvents(body, now: now);

      expect(events.single['summary'],
          'A summary Google wrapped across two lines');
    });

    test('reads the district feed style: TZID, DURATION, and RDATE', () {
      // Copied from the Westview athletics feed on westview.powayusd.com:
      // local wall-clock times with a zone name, DURATION instead of DTEND,
      // and one event repeated with RDATE.
      final body = feed(
        'BEGIN:VEVENT\n'
        'UID:51738449@westview.powayusd.com#20260825\n'
        'DTSTART;VALUE=DATE:20261127\n'
        'DURATION:P1D\n'
        'SUMMARY:Back to School Night\n'
        'END:VEVENT\n'
        'BEGIN:VEVENT\n'
        'UID:60768832@westview.powayusd.com#20261130\n'
        'DTSTART;TZID=US/Pacific:20261130T193000\n'
        'DTEND;TZID=US/Pacific:20261130T203000\n'
        'RDATE;TZID=US/Pacific:20261202T193000,20261203T190000\n'
        'SUMMARY:Boys Basketball (JV) Winter Classic\n'
        'END:VEVENT',
      );

      final events = CalendarEventsViewState.parseEvents(body, now: now);

      expect(events, hasLength(4));
      expect(events[0]['summary'], 'Back to School Night');
      expect(events[0]['start']['date'], '2026-11-27');
      // The RDATE days show up even though the event only has one DTSTART.
      expect(
        events.map((e) => (e['displayDate'] as DateTime).day).toList(),
        <int>[27, 30, 2, 3],
      );
      expect(events[3]['summary'], 'Boys Basketball (JV) Winter Classic');
    });

    test('drops EXDATE occurrences (cancelled/moved days)', () {
      final body = feed(
        'BEGIN:VEVENT\n'
        'DTSTART;VALUE=DATE:20261127\n'
        'DTEND;VALUE=DATE:20261128\n'
        'RDATE;VALUE=DATE:20261128,20261129\n'
        'EXDATE;VALUE=DATE:20261128\n'
        'SUMMARY:Cancelled middle day\n'
        'END:VEVENT',
      );
      final events = CalendarEventsViewState.parseEvents(body, now: now);
      expect(
        events.map((e) => (e['displayDate'] as DateTime).day).toList(),
        <int>[27, 29],
      );
    });

    test('expands RRULE WEEKLY with COUNT', () {
      final body = feed(
        'BEGIN:VEVENT\n'
        'DTSTART;VALUE=DATE:20261127\n'
        'DTEND;VALUE=DATE:20261128\n'
        'RRULE:FREQ=WEEKLY;COUNT=3\n'
        'SUMMARY:Weekly assembly\n'
        'END:VEVENT',
      );
      final events = CalendarEventsViewState.parseEvents(body, now: now);
      expect(
        events.map((e) => (e['displayDate'] as DateTime).day).toList(),
        <int>[27, 4, 11],
      );
    });

    test('expands RRULE DAILY with UNTIL and drops EXDATE inside it', () {
      final body = feed(
        'BEGIN:VEVENT\n'
        'DTSTART:20261127T170000Z\n'
        'DTEND:20261127T180000Z\n'
        'RRULE:FREQ=DAILY;UNTIL=20261129T235959Z\n'
        'EXDATE:20261128T170000Z\n'
        'SUMMARY:Daily practice\n'
        'END:VEVENT',
      );
      final events = CalendarEventsViewState.parseEvents(body, now: now);
      // 27th kept, 28th excluded, 29th kept (times shift by zone, days don't).
      expect(events.map((e) => e['summary']).toSet(), {'Daily practice'});
      expect(
        events.map((e) => (e['displayDate'] as DateTime).day).toList(),
        <int>[27, 29],
      );
    });

    test('an empty feed parses to an empty list', () {
      expect(CalendarEventsViewState.parseEvents(feed(''), now: now), isEmpty);
      expect(CalendarEventsViewState.parseEvents('', now: now), isEmpty);
    });

    test('drops events older than yesterday', () {
      final body = feed(
        'BEGIN:VEVENT\n'
        'DTSTART;VALUE=DATE:20250101\n'
        'DTEND;VALUE=DATE:20250102\n'
        'SUMMARY:Old news\n'
        'END:VEVENT\n'
        'BEGIN:VEVENT\n'
        'DTSTART;VALUE=DATE:20261127\n'
        'DTEND;VALUE=DATE:20261128\n'
        'SUMMARY:Coming up\n'
        'END:VEVENT',
      );

      final events = CalendarEventsViewState.parseEvents(body, now: now);

      expect(events.single['summary'], 'Coming up');
    });
  });

  group('SchoolLunchViewState.parseLunchData', () {
    test('parses day-off and menu days, sorted by date', () {
      final menuDay = {
        'day': '2026-09-02',
        'setting': jsonEncode({
          'current_display': [
            {'type': 'category', 'name': 'Lunch Entree'},
            {'type': 'recipe', 'name': 'Pizza'},
            {'type': 'category', 'name': 'Fruit'},
            {'type': 'recipe', 'name': 'Apple Slices'},
          ],
        }),
      };
      final dayOff = {
        'day': '2026-09-01',
        'setting': jsonEncode({
          'days_off': {'status': 1, 'description': 'Labor Day'},
        }),
      };

      final lunches = SchoolLunchViewState
          .parseLunchData(jsonEncode({'data': [menuDay, dayOff]}));

      expect(lunches, hasLength(2));
      expect(lunches[0].date, DateTime(2026, 9, 1));
      expect(lunches[0].isDayOff, isTrue);
      expect(lunches[0].dayOffReason, 'Labor Day');
      expect(lunches[1].date, DateTime(2026, 9, 2));
      expect(lunches[1].entrees, ['Pizza']);
      expect(lunches[1].fruit, ['Apple Slices']);
    });

    test('one malformed day does not kill the whole month', () {
      final goodDay = {
        'day': '2026-09-02',
        'setting': jsonEncode({
          'current_display': [
            {'type': 'category', 'name': 'Lunch Entree'},
            {'type': 'recipe', 'name': 'Pizza'},
          ],
        }),
      };
      final badDay = {'day': '2026-09-03', 'setting': 'not json{{{'};
      final notObjectDay = {'day': '2026-09-04', 'setting': '[1,2,3]'};

      final lunches = SchoolLunchViewState.parseLunchData(
        jsonEncode({
          'data': [badDay, goodDay, notObjectDay],
        }),
      );

      expect(lunches, hasLength(1));
      expect(lunches.single.entrees, ['Pizza']);
    });

    test('days without entrees are dropped', () {
      final emptyDay = {
        'day': '2026-09-03',
        'setting': jsonEncode({
          'current_display': [
            {'type': 'category', 'name': 'Breakfast'},
            {'type': 'recipe', 'name': 'Cereal'},
          ],
        }),
      };

      final lunches = SchoolLunchViewState
          .parseLunchData(jsonEncode({'data': [emptyDay]}));

      expect(lunches, isEmpty);
    });
  });

  group('SchoolLunchViewState.parseRecipes', () {
    test('indexes recipes by name', () {
      final body = jsonEncode({
        'data': [
          {
            'name': 'Pizza',
            'nutrients': {'calories_kcal': 280, 'serving_size': '1 slice'},
          },
          {'name': 'Milk'},
          {'nonsense': true},
        ],
      });

      final recipes = <String, dynamic>{};
      SchoolLunchViewState.parseRecipes(body, recipes);

      expect(recipes.keys, containsAll(['Pizza', 'Milk']));
      expect((recipes['Pizza'] as Map)['nutrients']['calories_kcal'], 280);
    });

    test('an empty body (recipes endpoint failed) is a no-op', () {
      final recipes = <String, dynamic>{};
      SchoolLunchViewState.parseRecipes('', recipes);
      expect(recipes, isEmpty);
    });

    test('invalid JSON is a no-op, not a crash', () {
      final recipes = <String, dynamic>{};
      SchoolLunchViewState.parseRecipes('<html>error</html>', recipes);
      expect(recipes, isEmpty);
    });
  });
}
