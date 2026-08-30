import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Primary endpoint: GET /westview/special_schedule2/{month}/{day}
/// Returns either a path to a .json file or an empty body ("no special schedule").
const String _specialScheduleBaseUrl = 'https://studycs.org';
const String _specialScheduleEndpoint =
    '$_specialScheduleBaseUrl/westview/special_schedule2';

/// Cached answers are reused for 3 days so the server isn't hammered.
const Duration specialScheduleCacheTtl = Duration(days: 3);

/// One cached answer for a single calendar day.
/// [periods] is null when the server confirmed "no special schedule" that day.
@immutable
class SpecialScheduleResult {
  const SpecialScheduleResult({required this.fetchedAt, this.periods});

  final DateTime fetchedAt;
  final List<Map<String, dynamic>>? periods;

  bool get hasSpecialSchedule => periods != null && periods!.isNotEmpty;

  bool isFresh(DateTime now) =>
      now.difference(fetchedAt) < specialScheduleCacheTtl;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
        'periods': periods == null
            ? null
            : [
                for (final period in periods!)
                  {
                    'Period': period['Period'],
                    'startMinute': _minutesOfDay(period['startTime'] as TimeOfDay),
                    'endMinute': _minutesOfDay(period['endTime'] as TimeOfDay),
                  },
              ],
      };

  static SpecialScheduleResult? fromJson(Object? json) {
    if (json is! Map) return null;
    final fetchedAt = json['fetchedAt'];
    if (fetchedAt is! num) return null;

    final rawPeriods = json['periods'];
    List<Map<String, dynamic>>? periods;
    if (rawPeriods is List) {
      final parsed = <Map<String, dynamic>>[];
      for (final raw in rawPeriods) {
        if (raw is! Map) continue;
        final name = raw['Period'];
        final start = raw['startMinute'];
        final end = raw['endMinute'];
        if (name is! String || start is! num || end is! num) continue;
        final startMinute = _clampMinutes(start.toInt());
        final endMinute = _clampMinutes(end.toInt());
        if (endMinute <= startMinute) continue;
        parsed.add({
          'Period': name,
          'startTime': TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60),
          'endTime': TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60),
        });
      }
      if (parsed.isNotEmpty) periods = parsed;
    }
    return SpecialScheduleResult(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAt.toInt()),
      periods: periods,
    );
  }

  static int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;
  static int _clampMinutes(int minutes) =>
      minutes < 0 ? 0 : (minutes > 1439 ? 1439 : minutes);
}

/// Fetches and caches special (modified) schedules from StudyCS.
///
/// Call [init] once at startup (loads disk cache, no network), then
/// [refreshToday] when the schedule page opens or the app resumes.
/// The network is only hit when the cache is missing or stale.
class SpecialScheduleService extends ChangeNotifier {
  SpecialScheduleService({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  static final SpecialScheduleService instance = SpecialScheduleService();

  static const String _prefsKey = 'special_schedule_cache_v1';
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Backup sources tried when the primary server is unreachable.
  /// URLs may use {month}/{day} placeholders.
  final List<String> fallbackUrls = [];

  http.Client _client;
  final DateTime Function() _clock;

  bool _initialized = false;
  Future<void>? _inFlight;
  final Map<String, SpecialScheduleResult> _cache = {};
  bool _lastFetchFailed = false;
  bool get lastFetchFailed => _lastFetchFailed;

  List<Map<String, dynamic>>? get todaySchedule {
    return _cache[_dayKey(_clock())]?.periods;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        if (key is String) {
          final entry = SpecialScheduleResult.fromJson(value);
          if (entry != null) _cache[key] = entry;
        }
      });
    } catch (_) {}
    notifyListeners();
  }

  Future<void> refreshToday({bool force = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _refreshToday(force: force);
    _inFlight = future.whenComplete(() => _inFlight = null);
    return future;
  }

  Future<void> _refreshToday({required bool force}) async {
    await init();
    final now = _clock();
    final key = _dayKey(now);
    final cached = _cache[key];

    if (!force && cached != null && cached.isFresh(now)) {
      _lastFetchFailed = false;
      notifyListeners();
      return;
    }

    try {
      final fetched = await _fetchForDay(now);
      _cache[key] = fetched;
      _lastFetchFailed = false;
      _prune(now);
      await _persist();
    } catch (error) {
      debugPrint('Special schedule fetch failed: $error');
      _lastFetchFailed = true;
    }
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting({http.Client? client}) {
    if (client != null) _client = client;
    _initialized = false;
    _inFlight = null;
    _cache.clear();
    _lastFetchFailed = false;
  }

  Future<SpecialScheduleResult> _fetchForDay(DateTime day) async {
    final month = day.month;
    final dayOfMonth = day.day;
    final urls = <String>[
      '$_specialScheduleEndpoint/$month/$dayOfMonth',
      for (final url in fallbackUrls)
        url.replaceAll('{month}', '$month').replaceAll('{day}', '$dayOfMonth'),
    ];

    Object? lastError;
    for (var i = 0; i < urls.length; i++) {
      try {
        final fetched = i == 0
            ? await _fetchFromStudyCs(urls[i], day)
            : await _fetchFromFallback(urls[i], day);
        if (fetched != null) return fetched;
      } catch (error) {
        lastError = error;
      }
    }
    throw Exception('No special-schedule source reachable: $lastError');
  }

  /// StudyCS contract: empty body or no ".json" means "no special schedule".
  Future<SpecialScheduleResult?> _fetchFromStudyCs(String url, DateTime day) async {
    final response = await _client.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('StudyCS returned HTTP ${response.statusCode}');
    }
    final body = response.body.trim();
    if (body.isEmpty || !body.contains('.json')) {
      return SpecialScheduleResult(fetchedAt: day, periods: null);
    }

    var path = body;
    if (!path.startsWith('/')) path = '/$path';
    final jsonResponse = await _client
        .get(Uri.parse('$_specialScheduleBaseUrl$path'))
        .timeout(_requestTimeout);
    if (jsonResponse.statusCode != 200) {
      throw Exception('Schedule file returned HTTP ${jsonResponse.statusCode}');
    }
    return SpecialScheduleResult(
      fetchedAt: day,
      periods: parseSpecialScheduleJson(jsonResponse.body),
    );
  }

  /// Fallback sources serve schedule JSON directly; ".json" path is also accepted.
  Future<SpecialScheduleResult?> _fetchFromFallback(String url, DateTime day) async {
    final response = await _client.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Fallback source returned HTTP ${response.statusCode}');
    }
    final body = response.body.trim();
    if (body.isEmpty) return null;

    if (body.startsWith('[') || body.startsWith('{')) {
      return SpecialScheduleResult(
        fetchedAt: day,
        periods: parseSpecialScheduleJson(body),
      );
    }

    if (body.contains('.json')) {
      var path = body;
      if (!path.startsWith('/')) path = '/$path';
      final jsonResponse = await _client
          .get(Uri.parse('$_specialScheduleBaseUrl$path'))
          .timeout(_requestTimeout);
      if (jsonResponse.statusCode != 200) {
        throw Exception('Fallback schedule file returned HTTP ${jsonResponse.statusCode}');
      }
      return SpecialScheduleResult(
        fetchedAt: day,
        periods: parseSpecialScheduleJson(jsonResponse.body),
      );
    }
    return null;
  }

  String _dayKey(DateTime day) => '${day.month}/${day.day}';

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({for (final e in _cache.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }

  void _prune(DateTime now) {
    _cache.removeWhere(
        (_, entry) => now.difference(entry.fetchedAt) > const Duration(days: 60));
  }
}

/// Parses StudyCS special-schedule JSON: list of {hour, minute, duration, title, isPM}.
/// Hours are 1-12; hours < 8 are assumed PM (school events) when isPM is absent.
List<Map<String, dynamic>> parseSpecialScheduleJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const FormatException('Special schedule JSON must be a list of periods');
  }
  final periods = <Map<String, dynamic>>[];
  for (final entry in decoded) {
    final period = _parsePeriodEntry(entry);
    if (period != null) periods.add(period);
  }
  if (periods.isEmpty) {
    throw const FormatException('Special schedule JSON contained no usable periods');
  }
  return periods;
}

Map<String, dynamic>? _parsePeriodEntry(Object? entry) {
  if (entry is! Map) return null;
  final hour = entry['hour'];
  final minute = entry['minute'];
  final duration = entry['duration'];
  final title = entry['title'];
  if (hour is! num || minute is! num || duration is! num || title is! String || title.trim().isEmpty) {
    return null;
  }

  var hour24 = hour.toInt();
  if (hour24 < 1 || hour24 > 12) return null;
  // Hours 1-7 default to PM; 8-12 default to AM when isPM is not specified.
  final isPm = entry['isPM'] == true || (entry['isPM'] == null && hour24 < 8);
  if (isPm && hour24 != 12) hour24 += 12;
  if (!isPm && hour24 == 12) hour24 = 0;

  final startMinute = hour24 * 60 + minute.toInt();
  final endMinute = (startMinute + duration.toInt()).clamp(0, 24 * 60 - 1).toInt();
  if (endMinute <= startMinute) return null;

  return {
    'Period': title,
    'startTime': TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60),
    'endTime': TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60),
  };
}
