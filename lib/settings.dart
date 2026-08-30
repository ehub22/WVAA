import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// Per-period customization: custom name, teacher, and room number.
@immutable
class PeriodSettings {
  const PeriodSettings({
    this.customName = '',
    this.teacher = '',
    this.room = '',
  });

  final String customName;
  final String teacher;
  final String room;

  bool get isEmpty => customName.isEmpty && teacher.isEmpty && room.isEmpty;

  PeriodSettings copyWith({
    String? customName,
    String? teacher,
    String? room,
  }) {
    return PeriodSettings(
      customName: customName ?? this.customName,
      teacher: teacher ?? this.teacher,
      room: room ?? this.room,
    );
  }

  Map<String, dynamic> toJson() => {
        'customName': customName,
        'teacher': teacher,
        'room': room,
      };

  static PeriodSettings fromJson(Map<String, dynamic> json) {
    return PeriodSettings(
      customName: (json['customName'] as String? ?? '').trim(),
      teacher: (json['teacher'] as String? ?? '').trim(),
      room: (json['room'] as String? ?? '').trim(),
    );
  }
}

/// Periods that are not classes (nothing to rename).
const Set<String> _nonClassPeriods = {
  'Passing',
  'Lunch',
  'Wolverine Time',
  'SSH',
};

/// Every period a student can rename, in school-day order.
final List<String> customizablePeriodNames = () {
  final names = <String>[];
  for (final schedule in [monFriSchedule, tueThursSchedule, wedSchedule]) {
    for (final period in schedule) {
      final name = period['Period'] as String;
      if (!_nonClassPeriods.contains(name) && !names.contains(name)) {
        names.add(name);
      }
    }
  }
  return List<String>.unmodifiable(names);
}();

/// Persisted user settings, shared across the app via ChangeNotifier.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _prefsKey = 'westview_settings_v1';

  bool _loaded = false;
  bool _notificationsEnabled = true;
  bool _liveActivityEnabled = true;
  bool _showTeacher = true;
  bool _showRoom = true;
  Map<String, PeriodSettings> _periods = <String, PeriodSettings>{};

  /// Set from main() to refresh the Android home screen widget after changes.
  Future<void> Function()? onSaved;

  bool get isLoaded => _loaded;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get liveActivityEnabled => _liveActivityEnabled;
  bool get liveActivityActive => _notificationsEnabled && _liveActivityEnabled;
  bool get showTeacher => _showTeacher;
  bool get showRoom => _showRoom;

  PeriodSettings periodSettings(String canonicalName) =>
      _periods[canonicalName] ?? const PeriodSettings();

  String displayName(String canonicalName) {
    final custom = periodSettings(canonicalName).customName;
    return custom.isEmpty ? canonicalName : custom;
  }

  bool isRenamed(String canonicalName) =>
      periodSettings(canonicalName).customName.isNotEmpty;

  /// Returns "Mr. Smith · Rm 402" style detail, respecting showTeacher/showRoom.
  String detailsFor(String canonicalName) {
    final settings = periodSettings(canonicalName);
    final parts = <String>[];
    if (_showTeacher && settings.teacher.isNotEmpty) {
      parts.add(settings.teacher);
    }
    if (_showRoom && settings.room.isNotEmpty) {
      parts.add(_formatRoom(settings.room));
    }
    return parts.join(' · ');
  }

  static String _formatRoom(String room) {
    final trimmed = room.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    // Avoid double-prefixing "Rm Room 402"
    if (lower.startsWith('rm') || lower.startsWith('room') || lower.startsWith('#')) {
      return trimmed;
    }
    return 'Rm $trimmed';
  }

  // -- mutations --

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    await _persist();
  }

  Future<void> setLiveActivityEnabled(bool value) async {
    if (_liveActivityEnabled == value) return;
    _liveActivityEnabled = value;
    await _persist();
  }

  Future<void> setShowTeacher(bool value) async {
    if (_showTeacher == value) return;
    _showTeacher = value;
    await _persist();
  }

  Future<void> setShowRoom(bool value) async {
    if (_showRoom == value) return;
    _showRoom = value;
    await _persist();
  }

  Future<void> setPeriodSettings(String canonicalName, PeriodSettings value) async {
    if (value.isEmpty) {
      _periods.remove(canonicalName);
    } else {
      _periods[canonicalName] = value;
    }
    await _persist();
  }

  Future<void> resetPeriods() async {
    if (_periods.isEmpty) return;
    _periods = <String, PeriodSettings>{};
    await _persist();
  }

  // -- persistence --

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  void _applyJson(Map<String, dynamic> json) {
    _notificationsEnabled = json['notificationsEnabled'] as bool? ?? true;
    _liveActivityEnabled = json['liveActivityEnabled'] as bool? ?? true;
    _showTeacher = json['showTeacher'] as bool? ?? true;
    _showRoom = json['showRoom'] as bool? ?? true;

    final periods = json['periods'];
    final parsed = <String, PeriodSettings>{};
    if (periods is Map) {
      periods.forEach((key, value) {
        if (key is String && value is Map) {
          final settings = PeriodSettings.fromJson(Map<String, dynamic>.from(value));
          if (!settings.isEmpty) parsed[key] = settings;
        }
      });
    }
    _periods = parsed;
  }

  Map<String, dynamic> toJson() => {
        'notificationsEnabled': _notificationsEnabled,
        'liveActivityEnabled': _liveActivityEnabled,
        'showTeacher': _showTeacher,
        'showRoom': _showRoom,
        'periods': {
          for (final entry in _periods.entries) entry.key: entry.value.toJson(),
        },
      };

  Future<void> _persist() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(toJson()));
    } catch (_) {}
    try {
      await onSaved?.call();
    } catch (_) {}
  }
}
