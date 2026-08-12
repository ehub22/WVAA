import 'package:flutter/material.dart';


Map<String, dynamic> createPeriod(String nameOfPeriod, int startHour, int startMinute, int endHour, int endMinute) {
  
  return Map.fromEntries([MapEntry('Period', nameOfPeriod), MapEntry('startTime', TimeOfDay(hour: startHour, minute: startMinute)), MapEntry('endTime', TimeOfDay(hour: endHour, minute: endMinute))]);
}


final List<Map<String, dynamic>> monFriSchedule = [
  createPeriod('Period 1', 8, 35, 10, 0),
  createPeriod('Passing', 10, 0, 10, 6),
  createPeriod('The DEN', 10, 6, 10, 27),
  createPeriod('Passing', 10, 27, 10, 33),
  createPeriod('Period 2', 10, 33, 11, 58),
  createPeriod('Lunch', 11, 58, 12, 33),
  createPeriod('Passing', 12, 33, 12, 39),
  createPeriod('Period 3', 12, 39, 14, 4),
  createPeriod('Passing', 14, 4, 14, 10),
  createPeriod('Period 4', 14, 10, 15, 35),
];

final List<Map<String, dynamic>> tueThursSchedule = [
  createPeriod('Period 1', 8, 35, 9, 56),
  createPeriod('Wolverine Time', 9, 56, 10, 26),
  createPeriod('Passing', 10, 26, 10, 32),
  createPeriod('Period 2', 10, 32, 11, 53),
  createPeriod('Lunch', 11, 53, 12, 28),
  createPeriod('Passing', 12, 28, 12, 34),
  createPeriod('SSH', 12, 34, 12, 47),
  createPeriod('Period 3', 12, 47, 14, 8),
  createPeriod('Passing', 14, 8, 14, 14),
  createPeriod('Period 4', 14, 14, 15, 35),
];

final List<Map<String, dynamic>> wedSchedule = [
  createPeriod('Period 1', 9, 35, 10, 44),
  createPeriod('Passing', 10, 44, 10, 50),
  createPeriod('Period 2', 10, 50, 11, 59),
  createPeriod('Lunch', 11, 59, 12, 34),
  createPeriod('Passing', 12, 34, 12, 40),
  createPeriod('Period 3', 12, 40, 13, 49),
  createPeriod('Wolverine Time', 13, 49, 14, 20),
  createPeriod('Passing', 14, 20, 14, 26),
  createPeriod('Period 4', 14, 26, 15, 35),
];
