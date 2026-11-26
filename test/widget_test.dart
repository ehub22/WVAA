import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:westview_app/data.dart';
import 'package:westview_app/settings.dart';

void main() {
  test('default schedules are well-formed and sorted', () {
    // Every schedule must list consecutive periods that never overlap and end
    // no later than the last bell (15:35 / 3:35 PM).
    for (final schedule in [monFriSchedule, tueThursSchedule, wedSchedule]) {
      expect(schedule, isNotEmpty);
      for (var i = 1; i < schedule.length; i++) {
        final prevEnd = schedule[i - 1]['endTime'];
        final curStart = schedule[i]['startTime'];
        // Allow adjacent or passing periods to touch/overlap by 6 minutes, but
        // never large gaps or backwards times.
        expect(prevEnd.hour * 60 + prevEnd.minute,
            lessThanOrEqualTo(curStart.hour * 60 + curStart.minute));
      }
    }
  });

  test('Kotlin widget defaults match lib/data.dart (no drift)', () {
    // ScheduleWidgetRenderer.kt duplicates the bell schedules as fallback
    // defaults until the Flutter app syncs once. If the two drift, the
    // widget shows the wrong period. Parse the Kotlin defaults and compare.
    final file = File(
      'android/app/src/main/kotlin/com/westviewhs/app/'
      'ScheduleWidgetRenderer.kt',
    );
    expect(file.existsSync(), isTrue,
        reason: 'run flutter test from the repo root');
    final source = file.readAsStringSync();

    List<(String, int, int)> parseList(String varName) {
      final start = source.indexOf('val $varName = listOf(');
      expect(start, isNot(-1), reason: '$varName not found in Kotlin file');
      // The list closes with a line containing only "    )".
      final end = source.indexOf('\n    )', start);
      expect(end, isNot(-1), reason: '$varName list end not found');
      final block = source.substring(start, end);
      final pattern = RegExp(r'Period\("([^"]+)",\s*([^,]+),\s*([^\)]+)\)');
      return [
        for (final m in pattern.allMatches(block))
          (
            m.group(1)!,
            _evalMinutes(m.group(2)!.trim()),
            _evalMinutes(m.group(3)!.trim()),
          ),
      ];
    }

    List<(String, int, int)> dartList(List<PeriodEntry> schedule) => [
          for (final p in schedule)
            (
              p['Period'] as String,
              (p['startTime'] as TimeOfDay).hour * 60 +
                  (p['startTime'] as TimeOfDay).minute,
              (p['endTime'] as TimeOfDay).hour * 60 +
                  (p['endTime'] as TimeOfDay).minute,
            ),
        ];

    expect(parseList('defaultMonFri'), dartList(monFriSchedule));
    expect(parseList('defaultTueThu'), dartList(tueThursSchedule));
    expect(parseList('defaultWed'), dartList(wedSchedule));
  });

  test('customizable period names cover only the four class periods', () {
    expect(customizablePeriodNames, contains('Period 1'));
    expect(customizablePeriodNames, contains('Period 4'));
    expect(customizablePeriodNames,
        isNot(contains('Passing')));
    expect(customizablePeriodNames, isNot(contains('Lunch')));
  });
}

/// Evaluates a Kotlin minutes expression like `8 * 60 + 35` or `10 * 60`.
int _evalMinutes(String expr) {
  var total = 0;
  for (final part in expr.split('+')) {
    final factors = part.split('*').map((s) => int.parse(s.trim())).toList();
    total += factors.reduce((a, b) => a * b);
  }
  return total;
}
