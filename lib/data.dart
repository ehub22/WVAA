import 'package:flutter/material.dart';

/// Typed shortcut for the schedule structures used throughout the app. Each
/// map contains the canonical period name and its start/end times.
typedef PeriodEntry = Map<String, dynamic>;

PeriodEntry _period(String name, int startHour, int startMinute, int endHour,
    int endMinute) {
  return <String, dynamic>{
    'Period': name,
    'startTime': TimeOfDay(hour: startHour, minute: startMinute),
    'endTime': TimeOfDay(hour: endHour, minute: endMinute),
  };
}

/// Monday and Friday schedule (block days).
final List<PeriodEntry> monFriSchedule = [
  _period('Period 1', 8, 35, 10, 0),
  _period('Passing', 10, 0, 10, 6),
  _period('The DEN', 10, 6, 10, 27),
  _period('Passing', 10, 27, 10, 33),
  _period('Period 2', 10, 33, 11, 58),
  _period('Lunch', 11, 58, 12, 33),
  _period('Passing', 12, 33, 12, 39),
  _period('Period 3', 12, 39, 14, 4),
  _period('Passing', 14, 4, 14, 10),
  _period('Period 4', 14, 10, 15, 35),
];

/// Tuesday and Thursday schedule.
final List<PeriodEntry> tueThursSchedule = [
  _period('Period 1', 8, 35, 9, 56),
  _period('Wolverine Time', 9, 56, 10, 26),
  _period('Passing', 10, 26, 10, 32),
  _period('Period 2', 10, 32, 11, 53),
  _period('Lunch', 11, 53, 12, 28),
  _period('Passing', 12, 28, 12, 34),
  _period('SSH', 12, 34, 12, 47),
  _period('Period 3', 12, 47, 14, 8),
  _period('Passing', 14, 8, 14, 14),
  _period('Period 4', 14, 14, 15, 35),
];

/// Wednesday (late-start) schedule.
final List<PeriodEntry> wedSchedule = [
  _period('Period 1', 9, 35, 10, 44),
  _period('Passing', 10, 44, 10, 50),
  _period('Period 2', 10, 50, 11, 59),
  _period('Lunch', 11, 59, 12, 34),
  _period('Passing', 12, 34, 12, 40),
  _period('Period 3', 12, 40, 13, 49),
  _period('Wolverine Time', 13, 49, 14, 20),
  _period('Passing', 14, 20, 14, 26),
  _period('Period 4', 14, 26, 15, 35),
];
