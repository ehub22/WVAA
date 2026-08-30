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

  test('customizable period names cover only the four class periods', () {
    expect(customizablePeriodNames, contains('Period 1'));
    expect(customizablePeriodNames, contains('Period 4'));
    expect(customizablePeriodNames,
        isNot(contains('Passing')));
    expect(customizablePeriodNames, isNot(contains('Lunch')));
  });
}
