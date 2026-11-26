import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'data.dart';
import 'settings.dart';
import 'special_schedule.dart';

/// Fully-qualified class name of the Android home-screen widget provider
/// (see `ScheduleWidgetProvider.kt` under `com.westviewhs.app`).
const String _scheduleWidgetProvider =
    'com.westviewhs.app.ScheduleWidgetProvider';

/// SharedPreferences keys read by the native widget; keep in sync with
/// `ScheduleWidgetRenderer.kt`.
const String _keyMonFri = 'schedule_monfri';
const String _keyTueThu = 'schedule_tuethu';
const String _keyWed = 'schedule_wed';
const String _keySpecial = 'schedule_special';
const String _keySpecialTomorrow = 'schedule_special_tomorrow';

int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

List<Map<String, dynamic>> _periodsToJson(List<PeriodEntry> schedule) {
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

/// Pushes the current schedules + settings to the Android home-screen widget
/// and asks it to re-render immediately.
///
/// Android-only and best-effort: silently no-ops on other platforms and when
/// the plugin channel is unavailable (e.g. in tests). Between app launches the
/// widget keeps itself up-to-date via AlarmManager and a self-ticking
/// Chronometer.
Future<void> syncHomeWidget() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final settings = AppSettings.instance;
    await HomeWidget.saveWidgetData(
        _keyMonFri, jsonEncode(_periodsToJson(monFriSchedule)));
    await HomeWidget.saveWidgetData(
        _keyTueThu, jsonEncode(_periodsToJson(tueThursSchedule)));
    await HomeWidget.saveWidgetData(
        _keyWed, jsonEncode(_periodsToJson(wedSchedule)));

    // Today's + tomorrow's special schedule overrides — always overwrite
    // so a stale yesterday entry can't leak through. Tomorrow is pre-fetched
    // so the widget is correct tomorrow morning before the app is opened.
    await SpecialScheduleService.instance.init();
    final now = DateTime.now();
    String dateOf(DateTime d) => '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final special = SpecialScheduleService.instance.todaySchedule;
    if (special != null && special.isNotEmpty) {
      await HomeWidget.saveWidgetData(
        _keySpecial,
        jsonEncode({'date': dateOf(now), 'periods': _periodsToJson(special)}),
      );
    } else {
      await HomeWidget.saveWidgetData(_keySpecial, '');
    }

    final tomorrow = now.add(const Duration(days: 1));
    // Pre-fetch tomorrow in the background (never block startup/widget
    // sync on the network): if it isn't cached yet, kick off a fetch and
    // re-sync when it lands. The re-sync sees the cached answer and does
    // not fetch again.
    if (!SpecialScheduleService.instance.hasCachedAnswerFor(tomorrow)) {
      unawaited(() async {
        try {
          await SpecialScheduleService.instance.refreshForDate(tomorrow);
          await syncHomeWidget();
        } catch (_) {
          // Best effort: widget falls back to the regular schedule tomorrow.
        }
      }());
    }
    final tomorrowSpecial =
        SpecialScheduleService.instance.scheduleForDate(tomorrow);
    if (tomorrowSpecial != null && tomorrowSpecial.isNotEmpty) {
      await HomeWidget.saveWidgetData(
        _keySpecialTomorrow,
        jsonEncode({
          'date': dateOf(tomorrow),
          'periods': _periodsToJson(tomorrowSpecial),
        }),
      );
    } else {
      await HomeWidget.saveWidgetData(_keySpecialTomorrow, '');
    }

    await HomeWidget.saveWidgetData(
        'notifications_enabled', settings.notificationsEnabled);
    await HomeWidget.saveWidgetData(
        'live_activity_enabled', settings.liveActivityEnabled);
    await HomeWidget.updateWidget(
        qualifiedAndroidName: _scheduleWidgetProvider);
  } on MissingPluginException {
    // No plugin on this platform — nothing to sync.
  } catch (_) {
    // Widget syncing is best-effort; the native side self-heals with its
    // own alarms and periodic updates.
  }
}
