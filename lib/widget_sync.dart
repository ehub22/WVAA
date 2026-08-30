import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'data.dart';
import 'settings.dart';
import 'special_schedule.dart';

/// Fully qualified class name of the Android home screen widget provider.
const String _scheduleWidgetProvider =
    'com.westviewhs.app.ScheduleWidgetProvider';

/// SharedPreferences keys read by the native widget renderer.
const String _keyMonFri = 'schedule_monfri';
const String _keyTueThu = 'schedule_tuethu';
const String _keyWed = 'schedule_wed';
const String _keySpecial = 'schedule_special';

int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

/// Converts schedule period maps into the compact JSON the native widget parses,
/// applying the student's custom names and teacher/room details.
List<Map<String, dynamic>> _periodsToJson(List<Map<String, dynamic>> schedule) {
  final settings = AppSettings.instance;
  return [
    for (final period in schedule)
      {
        'name': settings.displayName(period['Period'] as String),
        'detail': settings.detailsFor(period['Period'] as String),
        'start': _minutesOfDay(period['startTime'] as TimeOfDay),
        'end': _minutesOfDay(period['endTime'] as TimeOfDay),
      },
  ];
}

/// Pushes the school schedules to the Android home screen widget and
/// triggers an immediate re-render. Android-only, best effort.
Future<void> syncHomeWidget() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final settings = AppSettings.instance;
    await HomeWidget.saveWidgetData(_keyMonFri, jsonEncode(_periodsToJson(monFriSchedule)));
    await HomeWidget.saveWidgetData(_keyTueThu, jsonEncode(_periodsToJson(tueThursSchedule)));
    await HomeWidget.saveWidgetData(_keyWed, jsonEncode(_periodsToJson(wedSchedule)));

    await SpecialScheduleService.instance.init();
    final special = SpecialScheduleService.instance.todaySchedule;
    if (special != null && special.isNotEmpty) {
      final now = DateTime.now();
      final date = '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await HomeWidget.saveWidgetData(
        _keySpecial,
        jsonEncode({'date': date, 'periods': _periodsToJson(special)}),
      );
    } else {
      await HomeWidget.saveWidgetData(_keySpecial, '');
    }

    await HomeWidget.saveWidgetData('notifications_enabled', settings.notificationsEnabled);
    await HomeWidget.saveWidgetData('live_activity_enabled', settings.liveActivityEnabled);
    await HomeWidget.updateWidget(qualifiedAndroidName: _scheduleWidgetProvider);
  } on MissingPluginException {
    // No plugin on this platform.
  } catch (_) {
    // Never let widget sync crash the app.
  }
}
