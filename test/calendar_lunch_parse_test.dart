import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/calendars.dart';
import 'package:westview_app/school_lunch.dart';

void main() {
  group('CalendarEventsViewState.parseEvents', () {
    String feed(String events) =>
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$events\r\nEND:VCALENDAR\r\n';

    test('expands multi-day all-day events into one entry per day', () {
      final body = feed(
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20260928\r\n'
        // iCalendar all-day end dates are exclusive.
        'DTEND;VALUE=DATE:20260930\r\n'
        'SUMMARY:Homecoming Week\r\n'
        'END:VEVENT',
      );

      final events = CalendarEventsViewState.parseEvents(body);

      expect(events, hasLength(2));
      expect((events[0]['displayDate'] as DateTime).day, 28);
      expect((events[1]['displayDate'] as DateTime).day, 29);
      expect(events[0]['start']['date'], '2026-09-28');
    });

    test('sorts by display date and keeps timed event details', () {
      final body = feed(
        'BEGIN:VEVENT\n'
        'DTSTART:20260902T170000Z\n'
        'DTEND:20260902T180000Z\n'
        'SUMMARY:Later event\n'
        'END:VEVENT\n'
        'BEGIN:VEVENT\n'
        'DTSTART:20260901T150000Z\n'
        'DTEND:20260901T160000Z\n'
        'LOCATION:Westview High School\\, San Diego\\, CA\n'
        'DESCRIPTION:First line\\nSecond line\\, with a comma\n'
        'SUMMARY:Earlier event\n'
        'END:VEVENT',
      );

      final events = CalendarEventsViewState.parseEvents(body);

      expect(events, hasLength(2));
      expect(events[0]['summary'], 'Earlier event');
      expect(events[1]['summary'], 'Later event');
      expect(events[0]['location'], 'Westview High School, San Diego, CA');
      expect(events[0]['description'],
          'First line\nSecond line, with a comma');
      // Timed values are stored as UTC and read back as local wall-clock time,
      // so the exact hour depends on the test machine's zone.
      expect(events[0]['start']['dateTime'], isA<String>());
    });

    test('joins folded lines before reading a value', () {
      final body = feed(
        'BEGIN:VEVENT\n'
        'DTSTART;VALUE=DATE:20261111\n'
        'DTEND;VALUE=DATE:20261112\n'
        'SUMMARY:A summary Google wrapped across\n'
        '  two lines\n'
        'END:VEVENT',
      );

      final events = CalendarEventsViewState.parseEvents(body);

      expect(events.single['summary'],
          'A summary Google wrapped across two lines');
    });

    test('an empty feed parses to an empty list', () {
      expect(CalendarEventsViewState.parseEvents(feed('')), isEmpty);
      expect(CalendarEventsViewState.parseEvents(''), isEmpty);
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
