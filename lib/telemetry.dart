import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

/// Where anonymous reports are delivered. Points at the same school server
/// that already hosts the special-schedule data; if the school has not stood
/// up a collector yet the endpoint answers 404 and queued reports are simply
/// dropped — telemetry never affects the app or the user.
const String telemetryEndpoint =
    'https://studycs.org/westview/app-metrics';

/// Privacy-first crash reporting and usage analytics.
///
/// What is collected (and all that is collected):
///  * the event name and a handful of scalar properties (screen name, result);
///  * for crashes: the error text and a truncated stack trace;
///  * coarse environment info: platform, OS family, app locale language;
///  * a random per-launch session id, regenerated every start.
///
/// What is never collected: names, student IDs, accounts, contacts, location,
/// advertising/device identifiers, or any content the student typed. There are
/// no third-party SDKs; reports go only to the endpoint above.
///
/// Both streams are opt-out from Settings ▸ Privacy, and are also surfaced in
/// a first-run disclosure dialog.
class Telemetry {
  Telemetry._({http.Client? client}) : _client = client ?? http.Client();

  /// Singleton used by the app.
  static final Telemetry instance = Telemetry();

  static const String _queueKey = 'telemetry_queue_v1';
  static const int _maxQueuedEvents = 50;
  static const int _maxErrorLength = 300;
  static const int _maxStackLength = 1500;
  static const int _maxParamLength = 100;
  static const Duration _timeout = Duration(seconds: 5);

  http.Client _client;
  final List<Map<String, Object?>> _queue = <Map<String, Object?>>[];
  Future<void>? _inFlightFlush;
  late final String _sessionId = _newSessionId();

  bool get _analyticsEnabled => AppSettings.instance.analyticsEnabled;
  bool get _crashReportingEnabled =>
      AppSettings.instance.crashReportingEnabled;

  static String _newSessionId() {
    final random = Random();
    return DateTime.now().microsecondsSinceEpoch.toRadixString(16) +
        random.nextInt(0x7fffffff).toRadixString(16);
  }

  /// Loads any unsent reports saved from previous (possibly offline) launches
  /// and tries to send them. Call once at startup, never blocks the UI.
  Future<void> init() async {
    await _loadQueue();
    logEvent('app_open');
    unawaited(flush());
  }

  /// Records an anonymous usage event, e.g. screen views and refreshes.
  void logEvent(String name, [Map<String, Object?>? properties]) {
    if (!_analyticsEnabled) return;
    _enqueue(<String, Object?>{
      'type': 'event',
      'name': _truncate(name, _maxParamLength),
      if (properties != null)
        'properties': _sanitizeProperties(properties),
    });
  }

  /// Records a crash report. Framework errors, platform errors and uncaught
  /// zone errors all funnel through here.
  void logError(Object error, StackTrace? stackTrace, {String? context}) {
    if (!_crashReportingEnabled) return;
    _enqueue(<String, Object?>{
      'type': 'crash',
      'error': _truncate(error.toString(), _maxErrorLength),
      'stack': _truncate(stackTrace?.toString() ?? '', _maxStackLength),
      if (context != null) 'context': _truncate(context, _maxParamLength),
    });
  }

  void _enqueue(Map<String, Object?> event) {
    event['ts'] = DateTime.now().millisecondsSinceEpoch;
    event['session'] = _sessionId;
    event['platform'] = defaultTargetPlatform.name;
    event['locale'] = PlatformDispatcher.instance.locale.languageCode;
    _queue.add(event);
    if (_queue.length > _maxQueuedEvents) {
      _queue.removeRange(0, _queue.length - _maxQueuedEvents);
    }
    unawaited(_saveQueue());
    unawaited(flush());
  }

  /// Sends everything queued. Safe to call repeatedly; concurrent calls share
  /// the in-flight attempt, and failures keep the queue for the next try.
  Future<void> flush() {
    return _inFlightFlush ??= _flush().whenComplete(() => _inFlightFlush = null);
  }

  Future<void> _flush() async {
    // Respect the current consent settings: events of a disabled category are
    // dropped rather than sent.
    _queue.removeWhere((event) =>
        event['type'] == 'crash' ? !_crashReportingEnabled : !_analyticsEnabled);
    if (_queue.isEmpty) {
      await _saveQueue();
      return;
    }

    final batch = List<Map<String, Object?>>.of(_queue);
    try {
      final response = await _client
          .post(
            Uri.parse(telemetryEndpoint),
            headers: <String, String>{'content-type': 'application/json'},
            body: jsonEncode(<String, Object?>{
              'app': 'westview-wvaa',
              'session': _sessionId,
              'events': batch,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _queue.removeRange(0, batch.length);
      } else if (response.statusCode >= 400 &&
          response.statusCode < 500 &&
          response.statusCode != 429) {
        // The endpoint permanently rejected the batch (e.g. not configured).
        // Drop it instead of retrying forever.
        _queue.removeRange(0, batch.length);
      }
      // Anything else (5xx, network failure, timeout): keep for later.
      await _saveQueue();
    } catch (_) {
      // Offline — the queue is persisted and retried on a later launch.
      await _saveQueue();
    }
  }

  Map<String, Object?> _sanitizeProperties(Map<String, Object?> properties) {
    final sanitized = <String, Object?>{};
    properties.forEach((key, value) {
      if (value is num || value is bool) {
        sanitized[key] = value;
      } else if (value is String) {
        sanitized[key] = _truncate(value, _maxParamLength);
      }
      // Anything else (lists, maps, objects) could be identifying: dropped.
    });
    return sanitized;
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _queue.clear();
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          _queue.add(Map<String, Object?>.from(entry));
        }
      }
    } catch (_) {
      // Corrupt queue: start fresh.
      _queue.clear();
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, jsonEncode(_queue));
    } catch (_) {
      // Storage unavailable — telemetry is best effort by design.
    }
  }

  /// Swaps the HTTP client and clears all state (used by tests).
  @visibleForTesting
  void resetForTesting({http.Client? client}) {
    if (client != null) _client = client;
    _queue.clear();
    _inFlightFlush = null;
  }
}
