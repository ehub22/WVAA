import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:westview_app/network_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('written bodies are read back with their timestamp', () async {
    final savedAt = DateTime(2026, 8, 29, 8, 30);
    await NetworkCache.instance.write('calendar', '{"items":[]}', now: savedAt);

    final cached = await NetworkCache.instance.read('calendar');
    expect(cached, isNotNull);
    expect(cached!.body, '{"items":[]}');
    expect(cached.cachedAt, savedAt);
  });

  test('missing entries read as null', () async {
    expect(await NetworkCache.instance.read('nope'), isNull);
  });

  test('corrupt entries read as null instead of throwing', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('network_cache_v1_bad', '{not json');
    expect(await NetworkCache.instance.read('bad'), isNull);
  });

  test('freshness window decides whether the network can be skipped', () async {
    final now = DateTime(2026, 8, 29, 12);
    await NetworkCache.instance
        .write('k', 'v', now: now.subtract(const Duration(hours: 5)));
    await NetworkCache.instance
        .write('old', 'v', now: now.subtract(const Duration(hours: 7)));

    expect(
      (await NetworkCache.instance.read('k'))!
          .isFreshWithin(const Duration(hours: 6), now),
      isTrue,
    );
    expect(
      (await NetworkCache.instance.read('old'))!
          .isFreshWithin(const Duration(hours: 6), now),
      isFalse,
    );
  });

  test('clearAll removes everything', () async {
    await NetworkCache.instance.write('a', '1');
    await NetworkCache.instance.write('b', '2');
    await NetworkCache.instance.clearAll();

    expect(await NetworkCache.instance.read('a'), isNull);
    expect(await NetworkCache.instance.read('b'), isNull);
  });

  test('entries older than the storage limit are pruned on write', () async {
    final prefs = await SharedPreferences.getInstance();

    // Hand-craft an index entry that expired long ago.
    final index = <String, dynamic>{
      'ancient': DateTime(2000, 1, 1).millisecondsSinceEpoch,
    };
    await prefs.setString(
        'network_cache_index_v1', jsonEncode(index));
    await prefs.setString(
        'network_cache_v1_ancient', jsonEncode({'cachedAt': 0, 'body': 'x'}));

    await NetworkCache.instance.write('fresh', 'v');

    expect(await NetworkCache.instance.read('ancient'), isNull);
    expect(await NetworkCache.instance.read('fresh'), isNotNull);
    expect(prefs.getString('network_cache_v1_ancient'), isNull);
  });
}
