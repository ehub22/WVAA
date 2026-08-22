import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/data.dart';
import 'package:westview_app/schedule_page.dart';

void main() {
  group('Schedule time calculations and period transitions', () {
    test('period is active at exact start time', () {
      final periodStart = const TimeOfDay(hour: 8, minute: 35);
      final periodEnd = const TimeOfDay(hour: 10, minute: 0);

      // 8:34:59 is before
      final before = DateTime(2026, 8, 17, 8, 34, 59);
      expect(isCurrentTimeInPeriod(periodStart, periodEnd, before), isFalse);

      // 8:35:00 exact start is active
      final start = DateTime(2026, 8, 17, 8, 35, 0);
      expect(isCurrentTimeInPeriod(periodStart, periodEnd, start), isTrue);

      // 9:59:59 is active
      final during = DateTime(2026, 8, 17, 9, 59, 59);
      expect(isCurrentTimeInPeriod(periodStart, periodEnd, during), isTrue);

      // 10:00:00 is end of Period 1
      final end = DateTime(2026, 8, 17, 10, 0, 0);
      expect(isCurrentTimeInPeriod(periodStart, periodEnd, end), isFalse);
    });

    test('next period starts immediately when previous period ends with no gap', () {
      // Period 1 ends at 10:00, Passing starts at 10:00
      final p1 = monFriSchedule[0]; // Period 1: 8:35 - 10:00
      final passing = monFriSchedule[1]; // Passing: 10:00 - 10:06
      final den = monFriSchedule[2]; // The DEN: 10:06 - 10:27

      final t1000 = DateTime(2026, 8, 17, 10, 0, 0);
      expect(isCurrentTimeInPeriod(p1['startTime'], p1['endTime'], t1000), isFalse);
      expect(isCurrentTimeInPeriod(passing['startTime'], passing['endTime'], t1000), isTrue);

      final t1006 = DateTime(2026, 8, 17, 10, 6, 0);
      expect(isCurrentTimeInPeriod(passing['startTime'], passing['endTime'], t1006), isFalse);
      expect(isCurrentTimeInPeriod(den['startTime'], den['endTime'], t1006), isTrue);
    });

    test('schedule lookup correctly identifies current schedule by weekday', () {
      // Monday (weekday 1)
      final monday = DateTime(2026, 8, 17);
      expect(getCurrentSchedule(monday), equals(monFriSchedule));

      // Tuesday (weekday 2)
      final tuesday = DateTime(2026, 8, 18);
      expect(getCurrentSchedule(tuesday), equals(tueThursSchedule));

      // Wednesday (weekday 3)
      final wednesday = DateTime(2026, 8, 19);
      expect(getCurrentSchedule(wednesday), equals(wedSchedule));

      // Friday (weekday 5)
      final friday = DateTime(2026, 8, 21);
      expect(getCurrentSchedule(friday), equals(monFriSchedule));

      // Saturday (weekday 6)
      final saturday = DateTime(2026, 8, 22);
      expect(getCurrentSchedule(saturday), isNull);
    });
  });
}
