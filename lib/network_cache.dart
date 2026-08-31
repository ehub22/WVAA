import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One cached network response body plus when it was saved.
@immutable
class CachedResponse {
  const CachedResponse({required this.body, required this.cachedAt});

  final String body;
  final DateTime cachedAt;

  /// Whether this entry is young enough to be served without hitting the
  /// network at all.
  bool isFreshWithin(Duration maxAge, DateTime now) =>
      now.difference(cachedAt) < maxAge;

  Map<String, dynamic> toJson() => {
        'cachedAt': cachedAt.millisecondsSinceEpoch,
        'body': body,
      };

  static CachedResponse? fromJson(Object? json) {
    if (json is! Map) return null;
    final cachedAt = json['cachedAt'];
    final body = json['body'];
    if (cachedAt is! num || body is! String) return null;
    return CachedResponse(
      body: body,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(cachedAt.toInt()),
    );
  }
}

/// Last-known-good cache for the app's structured network content (calendar
/// events, lunch menus, nutrition recipes).
///
/// School Wi-Fi is unreliable, so every successful response body is stored on
/// disk and served again whenever a refresh fails — even past its normal
/// freshness window, a stale copy beats an error screen. Entries older than
/// [maxAge] are pruned to keep storage bounded.
class NetworkCache {
  NetworkCache._();

  static final NetworkCache instance = NetworkCache._();

  static const String _entryPrefix = 'network_cache_v1_';
  static const String _indexKey = 'network_cache_index_v1';

  /// How long a cached body is kept on disk before pruning. Note this is the
  /// *storage* limit — callers decide how fresh a response must be before the
  /// network is skipped; stale entries are still served offline.
  static const Duration maxAge = Duration(days: 30);

  /// Returns the cached body for [key], or null when nothing usable is
  /// stored. Never throws.
  Future<CachedResponse?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_entryPrefix$key');
      if (raw == null || raw.isEmpty) return null;
      return CachedResponse.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Stores [body] under [key] with the given timestamp (defaults to now).
  /// Never throws.
  Future<void> write(String key, String body, {DateTime? now}) async {
    final entry =
        CachedResponse(body: body, cachedAt: now ?? DateTime.now());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_entryPrefix$key', jsonEncode(entry.toJson()));
      await _updateIndex(prefs, key, entry.cachedAt);
      await _prune(prefs);
    } catch (_) {
      // Cache writes must never break the UI.
    }
  }

  /// Removes everything this cache has stored. Never throws.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = await _readIndex(prefs);
      for (final key in index.keys) {
        await prefs.remove('$_entryPrefix$key');
      }
      await prefs.remove(_indexKey);
    } catch (_) {
      // Best effort.
    }
  }

  Future<Map<String, int>> _readIndex(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_indexKey);
      if (raw == null || raw.isEmpty) return <String, int>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      final index = <String, int>{};
      decoded.forEach((key, value) {
        if (key is String && value is num) index[key] = value.toInt();
      });
      return index;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _updateIndex(
      SharedPreferences prefs, String key, DateTime cachedAt) async {
    final index = await _readIndex(prefs);
    index[key] = cachedAt.millisecondsSinceEpoch;
    await prefs.setString(_indexKey, jsonEncode(index));
  }

  Future<void> _prune(SharedPreferences prefs) async {
    final index = await _readIndex(prefs);
    final now = DateTime.now();
    final expired = index.entries
        .where((entry) =>
            now.difference(
                DateTime.fromMillisecondsSinceEpoch(entry.value)) >
            maxAge)
        .map((entry) => entry.key)
        .toList();
    if (expired.isEmpty) return;
    for (final key in expired) {
      await prefs.remove('$_entryPrefix$key');
      index.remove(key);
    }
    await prefs.setString(_indexKey, jsonEncode(index));
  }
}
