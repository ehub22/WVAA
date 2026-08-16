import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// Per-period customization: a student friendly name plus optional teacher and
/// room number, e.g. "Human Body Systems · Mr. Smith · Rm 402".
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

/// Every period name a student can rename (everything except passing periods).
///
/// The order follows the school day so the settings page reads naturally.
final List<String> customizablePeriodNames = () {
  final names = <String>[];
  for (final schedule in [monFriSchedule, tueThursSchedule, wedSchedule]) {
    for (final period in schedule) {
      final name = period['Period'] as String;
      if (name != 'Passing' && !names.contains(name)) {
        names.add(name);
      }
    }
  }
  return List<String>.unmodifiable(names);
}();

/// App wide, persisted user settings.
///
/// A [ChangeNotifier] singleton so any page can rebuild when a setting
/// changes: `ListenableBuilder(listenable: AppSettings.instance, ...)`.
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

  /// Called after settings are persisted (used to refresh the Android home
  /// screen widget). Set from `main()` to avoid a circular import.
  Future<void> Function()? onSaved;

  bool get isLoaded => _loaded;

  /// Master switch: when off the app posts no notifications at all.
  bool get notificationsEnabled => _notificationsEnabled;

  /// The ongoing "live activity" notification with the period countdown timer.
  bool get liveActivityEnabled => _liveActivityEnabled;

  /// The live activity only runs when notifications are allowed as well.
  bool get liveActivityActive => _notificationsEnabled && _liveActivityEnabled;

  /// Show the teacher name in the schedule / notification / widget.
  bool get showTeacher => _showTeacher;

  /// Show the room number in the schedule / notification / widget.
  bool get showRoom => _showRoom;

  PeriodSettings periodSettings(String canonicalName) =>
      _periods[canonicalName] ?? const PeriodSettings();

  /// The name to display for [canonicalName] ("Period 1" unless renamed).
  String displayName(String canonicalName) {
    final custom = periodSettings(canonicalName).customName;
    return custom.isEmpty ? canonicalName : custom;
  }

  /// Whether [canonicalName] has been renamed by the student.
  bool isRenamed(String canonicalName) =>
      periodSettings(canonicalName).customName.isNotEmpty;

  /// The secondary line for a period, e.g. "Mr. Smith · Rm 402".
  ///
  /// Returns an empty string when nothing should be shown (either nothing was
  /// entered or the matching toggles are off).
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
    // Don't turn "Room 402" or "Rm 402" into "Rm Room 402".
    if (lower.startsWith('rm') ||
        lower.startsWith('room') ||
        lower.startsWith('#')) {
      return trimmed;
    }
    return 'Rm $trimmed';
  }

  // --------------------------------------------------------------- mutations

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

  // ------------------------------------------------------------- persistence

  /// Loads the saved settings. Safe to call more than once and never throws.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Corrupt or unavailable storage: keep the defaults.
    }
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
          final settings =
              PeriodSettings.fromJson(Map<String, dynamic>.from(value));
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
    } catch (_) {
      // Never let a failed write break the UI.
    }
    try {
      await onSaved?.call();
    } catch (_) {
      // Widget syncing is best effort.
    }
  }
}
