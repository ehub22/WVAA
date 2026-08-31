import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/calendars.dart';
import 'package:westview_app/school_lunch.dart';

void main() {
  group('CalendarEventsViewState.parseEvents', () {
    test('expands multi-day events into one entry per day', () {
      final body = jsonEncode({
        'items': [
          {
            'summary': 'Homecoming Week',
            'start': {'date': '2026-09-28'},
            // Google Calendar all-day end dates are exclusive.
            'end': {'date': '2026-09-30'},
          },
        ],
      });

      final events = CalendarEventsViewState.parseEvents(body);

      expect(events, hasLength(2));
      expect((events[0]['displayDate'] as DateTime).day, 28);
      expect((events[1]['displayDate'] as DateTime).day, 29);
    });

    test('sorts by display date and keeps timed event details', () {
      final body = jsonEncode({
        'items': [
          {
            'summary': 'Later event',
            'start': {'dateTime': '2026-09-02T10:00:00-07:00'},
            'end': {'dateTime': '2026-09-02T11:00:00-07:00'},
          },
          {
            'summary': 'Earlier event',
            'start': {'dateTime': '2026-09-01T08:00:00-07:00'},
            'end': {'dateTime': '2026-09-01T09:00:00-07:00'},
          },
        ],
      });

      final events = CalendarEventsViewState.parseEvents(body);

      expect(events, hasLength(2));
      expect(events[0]['summary'], 'Earlier event');
      expect(events[1]['summary'], 'Later event');
    });

    test('an empty calendar parses to an empty list', () {
      expect(CalendarEventsViewState.parseEvents(jsonEncode({})), isEmpty);
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
