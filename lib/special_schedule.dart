import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The StudyCS special-schedule endpoint.
///
/// `GET <endpoint>/<month>/<day>` (e.g. `/westview/special_schedule2/8/18`)
/// answers either with an empty body ("no special schedule") or with a
/// plain-text path containing ".json", which must then be downloaded from
/// `https://studycs.org/<path>`. Any response without ".json" is treated as
/// "no special schedule".
const String _specialScheduleBaseUrl = 'https://studycs.org';
const String _specialScheduleEndpoint =
    '$_specialScheduleBaseUrl/westview/special_schedule2';

/// How long a fetched answer (a special schedule, or a confirmed "none") is
/// reused before the app is allowed to ask the server again.
///
/// The requirement is at least 2 days so the server is not flooded with
/// requests; 3 days leaves some headroom. A stale answer is still used while
/// the server is unreachable.
const Duration specialScheduleCacheTtl = Duration(days: 3);

/// One cached answer for a single calendar day.
///
/// [periods] is null when the server explicitly answered that the day has no
/// special schedule; otherwise it holds the schedule in the same period-map
/// format as `data.dart` (`Period`, `startTime`, `endTime`).
@immutable
class SpecialScheduleResult {
  const SpecialScheduleResult({required this.fetchedAt, this.periods});

  /// When this answer was fetched from the network.
  final DateTime fetchedAt;

  /// The special schedule for the day, or null for a confirmed "none".
  final List<Map<String, dynamic>>? periods;

  bool get hasSpecialSchedule => periods != null && periods!.isNotEmpty;

  /// Whether this answer is young enough to reuse without asking the server
  /// again (at least [specialScheduleCacheTtl]).
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
                    'startMinute':
                        _minutesOfDay(period['startTime'] as TimeOfDay),
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
          'startTime':
              TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60),
          'endTime': TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60),
        });
      }
      if (parsed.isEmpty) {
        periods = null; // Nothing usable: treat like "no special schedule".
      } else {
        periods = parsed;
      }
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

/// Fetches and caches the StudyCS special (modified) schedules.
///
/// Usage: call [init] once at startup (loads the cache, no network), then
/// [refreshToday] whenever the schedule page opens or the app resumes. The
/// network is only touched when there is no cached answer for today or the
/// cached answer is older than [specialScheduleCacheTtl] (at least 2 days).
class SpecialScheduleService extends ChangeNotifier {
  SpecialScheduleService({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  /// Singleton used by the app.
  static final SpecialScheduleService instance = SpecialScheduleService();

  static const String _prefsKey = 'special_schedule_cache_v1';
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Backup sources for the special-schedule data, tried in order when the
  /// primary StudyCS server cannot be reached.
  ///
  /// A URL may contain the `{month}` and `{day}` placeholders (e.g.
  /// `https://example.com/westview/{month}/{day}.json`), or point at a single
  /// file that is served for every date — such as a public Google Drive
  /// direct-download link
  /// (`https://drive.google.com/uc?export=download&id=YOUR_PUBLIC_FILE_ID`).
  ///
  /// Fallback sources are expected to serve the schedule JSON directly (see
  /// [parseSpecialScheduleJson]); the ".json" path contract is also accepted.
  final List<String> fallbackUrls = [];

  http.Client _client;
  final DateTime Function() _clock;

  bool _initialized = false;
  Future<void>? _inFlight;
  final Map<String, SpecialScheduleResult> _cache = {};

  /// Whether the last refresh attempt could not reach any schedule source.
  /// The UI uses this to show the "schedule may not be accurate" banner.
  bool _lastFetchFailed = false;
  bool get lastFetchFailed => _lastFetchFailed;

  /// Today's special schedule when the cache has one — including a stale one,
  /// which is still better than the regular schedule while the server is
  /// down. Returns null when the server confirmed there is none, or when
  /// nothing has been fetched yet.
  List<Map<String, dynamic>>? get todaySchedule {
    final entry = _cache[_dayKey(_clock())];
    return entry?.periods;
  }

  /// Loads previously cached answers from disk. Fast, makes no network
  /// requests, and never throws.
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
    } catch (_) {
      // Corrupt or unavailable storage: start with an empty cache.
    }
    notifyListeners();
  }

  /// Makes sure today's answer is available, asking the network only when the
  /// cached answer is missing or older than [specialScheduleCacheTtl].
  ///
  /// Never throws: on failure the previous (even stale) cached answer is kept
  /// and [lastFetchFailed] is set so the UI can warn the user.
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

    // A fresh answer is reused verbatim, so the server is never asked more
    // than once per date within the cache TTL (>= 2 days).
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
      // Unreachable: keep whatever we had (even stale) and warn the UI.
      debugPrint('Special schedule fetch failed: $error');
      _lastFetchFailed = true;
    }
    notifyListeners();
  }

  /// Clears all state (used by tests).
  @visibleForTesting
  void resetForTesting({http.Client? client}) {
    if (client != null) _client = client;
    _initialized = false;
    _inFlight = null;
    _cache.clear();
    _lastFetchFailed = false;
  }

  // ----------------------------------------------------------------- network

  Future<SpecialScheduleResult> _fetchForDay(DateTime day) async {
    final month = day.month;
    final dayOfMonth = day.day;
    final urls = <String>[
      '$_specialScheduleEndpoint/$month/$dayOfMonth',
      for (final url in fallbackUrls)
        url
            .replaceAll('{month}', '$month')
            .replaceAll('{day}', '$dayOfMonth'),
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
    throw Exception(
        'No special-schedule source reachable (${urls.join(', ')}): $lastError');
  }

  /// The StudyCS contract: an empty body, or any body without ".json", means
  /// "no special schedule"; otherwise the body is a path whose content is the
  /// schedule JSON, downloaded from the same server.
  Future<SpecialScheduleResult?> _fetchFromStudyCs(
      String url, DateTime day) async {
    final response = await _client.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('StudyCS endpoint returned HTTP ${response.statusCode}');
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
      throw Exception(
          'Special schedule file returned HTTP ${jsonResponse.statusCode}');
    }
    return SpecialScheduleResult(
      fetchedAt: day,
      periods: parseSpecialScheduleJson(jsonResponse.body),
    );
  }

  /// Backup sources serve the schedule JSON directly; the ".json" path
  /// contract is also tolerated for compatibility.
  Future<SpecialScheduleResult?> _fetchFromFallback(
      String url, DateTime day) async {
    final response = await _client.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Fallback source returned HTTP ${response.statusCode}');
    }
    final body = response.body.trim();
    if (body.isEmpty) return null; // Not configured: try the next source.

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
        throw Exception(
            'Fallback schedule file returned HTTP ${jsonResponse.statusCode}');
      }
      return SpecialScheduleResult(
        fetchedAt: day,
        periods: parseSpecialScheduleJson(jsonResponse.body),
      );
    }
    return null;
  }

  // ------------------------------------------------------------------ cache

  String _dayKey(DateTime day) => '${day.month}/${day.day}';

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final entry in _cache.entries) entry.key: entry.value.toJson(),
        }),
      );
    } catch (_) {
      // Never let a failed cache write break the UI.
    }
  }

  void _prune(DateTime now) {
    _cache.removeWhere(
        (key, entry) => now.difference(entry.fetchedAt) > const Duration(days: 60));
  }
}

/// Parses special-schedule JSON as served by StudyCS: a list of entries with
/// `hour`, `minute`, `duration` (in minutes) and `title`.
///
/// Hours are 1-12; `isPM` marks afternoon times. When `isPM` is absent,
/// hours 1-7 are assumed to be PM (school events) and hours 8-12 AM, which
/// matches the server's output. Returns the schedule in the app's usual
/// period-map format (`Period`, `startTime`, `endTime`).
List<Map<String, dynamic>> parseSpecialScheduleJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const FormatException(
        'Special schedule JSON must be a list of periods');
  }
  final periods = <Map<String, dynamic>>[];
  for (final entry in decoded) {
    final period = _parsePeriodEntry(entry);
    if (period != null) periods.add(period);
  }
  if (periods.isEmpty) {
    throw const FormatException(
        'Special schedule JSON contained no usable periods');
  }
  return periods;
}

Map<String, dynamic>? _parsePeriodEntry(Object? entry) {
  if (entry is! Map) return null;
  final hour = entry['hour'];
  final minute = entry['minute'];
  final duration = entry['duration'];
  final title = entry['title'];
  if (hour is! num ||
      minute is! num ||
      duration is! num ||
      title is! String ||
      title.trim().isEmpty) {
    return null;
  }

  var hour24 = hour.toInt();
  if (hour24 < 1 || hour24 > 12) return null;
  final isPm = entry['isPM'] == true || (entry['isPM'] == null && hour24 < 8);
  if (isPm && hour24 != 12) hour24 += 12;
  if (!isPm && hour24 == 12) hour24 = 0;

  final startMinute = hour24 * 60 + minute.toInt();
  final endMinute =
      (startMinute + duration.toInt()).clamp(0, 24 * 60 - 1).toInt();
  if (endMinute <= startMinute) return null;

  return {
    'Period': title,
    'startTime': TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60),
    'endTime': TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60),
  };
}
