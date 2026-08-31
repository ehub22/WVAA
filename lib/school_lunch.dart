import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'network_cache.dart';
import 'telemetry.dart';
import 'widgets/status_views.dart';

class DailyLunch {
  const DailyLunch({
    required this.date,
    this.isDayOff = false,
    this.dayOffReason,
    this.entrees = const [],
    this.vegetables = const [],
    this.fruit = const [],
    this.milk = const [],
  });

  final DateTime date;
  final bool isDayOff;
  final String? dayOffReason;
  final List<String> entrees;
  final List<String> vegetables;
  final List<String> fruit;
  final List<String> milk;
}

/// The monthly school lunch menu.
///
/// Like the calendars, this view is cache-first: the last successful menu (and
/// its nutrition-recipe data) is saved on disk and shown whenever the
/// healthepro API cannot be reached, so the menu still opens on unreliable
/// school Wi-Fi. Pull down to force a refresh.
class SchoolLunchView extends StatefulWidget {
  const SchoolLunchView({super.key});

  @override
  State<SchoolLunchView> createState() => SchoolLunchViewState();
}

class SchoolLunchViewState extends State<SchoolLunchView> {
  final ItemScrollController _scrollController = ItemScrollController();
  final Map<String, dynamic> _recipes = {};

  static const String _apiOrg = '1556';
  static const String _apiMenu = '135312';
  static const String _apiRecipes = '111591';
  static const String _apiBase = 'https://menus.healthepro.com/api/organizations';
  static const String _menuCacheKey = 'lunch_menu_current_month';
  static const String _recipesCacheKey = 'lunch_recipes_current_month';
  static const Duration _cacheMaxAge = Duration(hours: 12);
  static const Duration _requestTimeout = Duration(seconds: 10);

  List<DailyLunch>? _lunches;
  DateTime? _cachedAt;
  bool _loading = false;
  bool _showingSavedCopy = false;
  String? _error;
  bool _needsScrollToToday = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // Serve the cached month immediately, if present and parseable.
    CachedResponse? menuCache;
    try {
      menuCache = await NetworkCache.instance.read(_menuCacheKey);
      if (_lunches == null && menuCache != null) {
        final cached = _parseLunchData(menuCache.body);
        if (cached.isNotEmpty) {
          _lunches = cached;
          _cachedAt = menuCache.cachedAt;
          final recipesCache =
              await NetworkCache.instance.read(_recipesCacheKey);
          if (recipesCache != null) {
            _parseRecipesInto(recipesCache.body, _recipes);
          }
        }
      }
    } catch (error) {
      // Corrupt cache entry: ignore it and go to the network.
      debugPrint('Lunch cache unusable: $error');
    }

    if (!force &&
        menuCache != null &&
        menuCache.isFreshWithin(_cacheMaxAge, DateTime.now()) &&
        (_lunches?.isNotEmpty ?? false)) {
      if (!mounted) return;
      setState(() => _loading = false);
      _scrollToTodayIfNeeded();
      return;
    }

    try {
      final now = DateTime.now();
      final recipesBody = await _fetchRecipes(now);
      final menuBody = await _fetchMenu(now);

      // Parse into fresh maps first so a parse error can't leave the view
      // half-updated.
      final recipes = <String, dynamic>{};
      _parseRecipesInto(recipesBody, recipes);
      final lunches = _parseLunchData(menuBody);

      await NetworkCache.instance.write(_recipesCacheKey, recipesBody);
      await NetworkCache.instance.write(_menuCacheKey, menuBody);
      Telemetry.instance.logEvent('lunch_refresh');

      if (!mounted) return;
      setState(() {
        _recipes
          ..clear()
          ..addAll(recipes);
        _lunches = lunches;
        _cachedAt = DateTime.now();
        _loading = false;
        _showingSavedCopy = false;
      });
      _scrollToTodayIfNeeded();
    } catch (error) {
      debugPrint('Lunch fetch failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_lunches != null && _lunches!.isNotEmpty) {
          _showingSavedCopy = true;
          Telemetry.instance.logEvent('lunch_cache_used');
        } else {
          _error = "Couldn't reach the menu server. "
              'Check your connection and try again.';
        }
      });
    }
  }

  void _scrollToTodayIfNeeded() {
    if (!_needsScrollToToday) return;
    final lunches = _lunches;
    if (lunches == null || lunches.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_needsScrollToToday) return;
      final now = DateTime.now();
      final target = lunches.indexWhere((l) =>
          (l.date.year == now.year &&
              l.date.month == now.month &&
              l.date.day == now.day) ||
          l.date.isAfter(now));
      if (target != -1 && _scrollController.isAttached) {
        _scrollController.jumpTo(index: target);
        _needsScrollToToday = false;
      }
    });
  }

  String _monthRecipesUrl(DateTime now) {
    final start =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final end =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    return '$_apiBase/$_apiOrg/menus/$_apiRecipes/start_date/$start/end_date/$end/recipes/';
  }

  Future<String> _fetchRecipes(DateTime now) async {
    // Recipes are best-effort nutrition info; don't fail the whole page if
    // that endpoint is flaky.
    try {
      final response = await http
          .get(Uri.parse(_monthRecipesUrl(now)))
          .timeout(_requestTimeout);
      if (response.statusCode == 200) return response.body;
    } catch (e) {
      debugPrint('Failed to fetch lunch recipes: $e');
    }
    return '';
  }

  Future<String> _fetchMenu(DateTime now) async {
    final url =
        '$_apiBase/$_apiOrg/menus/$_apiMenu/year/${now.year}/month/${now.month}/date_overwrites';
    final response =
        await http.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load lunch data (HTTP ${response.statusCode})');
    }
    return response.body;
  }

  /// Fills [recipes] with `name -> recipe` entries from an API response body.
  @visibleForTesting
  static void parseRecipes(String body, Map<String, dynamic> recipes) {
    _parseRecipesInto(body, recipes);
  }

  static void _parseRecipesInto(String body, Map<String, dynamic> recipes) {
    if (body.isEmpty) return;
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final recipeList = (data['data'] as List<dynamic>?) ?? const [];
      for (final r in recipeList) {
        if (r is Map<String, dynamic> && r['name'] != null) {
          recipes[r['name'] as String] = r;
        }
      }
    } catch (e) {
      debugPrint('Failed to parse lunch recipes: $e');
    }
  }

  /// Parses the healthepro `date_overwrites` body into a sorted day list.
  @visibleForTesting
  static List<DailyLunch> parseLunchData(String jsonString) {
    return _parseLunchData(jsonString);
  }

  static List<DailyLunch> _parseLunchData(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final days = (data['data'] as List<dynamic>?) ?? const [];
    final lunches = <DailyLunch>[];

    for (final dayData in days) {
      if (dayData is! Map<String, dynamic>) continue;
      final day = dayData['day'];
      final settingStr = dayData['setting'];
      if (day is! String || settingStr is! String) continue;

      final date = DateTime.tryParse(day);
      if (date == null) continue;

      final setting = json.decode(settingStr) as Map<String, dynamic>;
      final daysOff = setting['days_off'];

      var isDayOff = false;
      String? dayOffReason;
      final entrees = <String>[];
      final vegetables = <String>[];
      final fruit = <String>[];
      final milk = <String>[];

      if (daysOff is Map<String, dynamic> && daysOff['status'] == 1) {
        isDayOff = true;
        dayOffReason = daysOff['description'] as String?;
      } else {
        final currentDisplay =
            (setting['current_display'] as List<dynamic>?) ?? const [];
        var currentCategory = '';
        for (final item in currentDisplay) {
          if (item is! Map<String, dynamic>) continue;
          if (item['type'] == 'category') {
            currentCategory = (item['name'] as String?) ?? '';
          } else if (item['type'] == 'recipe') {
            final name = item['name'] as String?;
            if (name == null) continue;
            switch (currentCategory) {
              case 'Lunch Entree':
                entrees.add(name);
                break;
              case 'Vegetables':
                vegetables.add(name);
                break;
              case 'Fruit':
                fruit.add(name);
                break;
              case 'Milk':
                milk.add(name);
                break;
            }
          }
        }
      }

      if (isDayOff || entrees.isNotEmpty) {
        lunches.add(DailyLunch(
          date: date,
          isDayOff: isDayOff,
          dayOffReason: dayOffReason,
          entrees: entrees,
          vegetables: vegetables,
          fruit: fruit,
          milk: milk,
        ));
      }
    }
    lunches.sort((a, b) => a.date.compareTo(b.date));
    return lunches;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',    ];
    return '${weekdays[date.weekday - 1]}, ${shortDateLabel(date)}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatNutrient(dynamic value) {
    if (value == null) return '0';
    final parsed = num.tryParse(value.toString());
    return parsed?.round().toString() ?? value.toString();
  }

  void _showNutritionFacts(BuildContext context, String mealName) {
    Telemetry.instance.logEvent('nutrition_facts_opened');
    final recipe = _recipes[mealName];
    if (recipe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No nutrition facts available for $mealName')),
      );
      return;
    }

    var servingSizeText = '1 serving';
    var nutritionText = 'No detailed nutrition data available.';
    final nutrients = recipe['nutrients'];
    if (nutrients is Map<String, dynamic>) {
      servingSizeText =
          'Serving Size: ${nutrients['serving_size'] ?? '1 serving'}';
      nutritionText =
          'Calories: ${_formatNutrient(nutrients['calories_kcal'])}\n'
          'Total Fat: ${_formatNutrient(nutrients['total_fat_grams'])}g\n'
          '  Saturated Fat: ${_formatNutrient(nutrients['saturated_fat_grams'])}g\n'
          '  Trans Fat: ${_formatNutrient(nutrients['trans_fat_grams'])}g\n'
          'Cholesterol: ${_formatNutrient(nutrients['cholesterol_milligrams'])}mg\n'
          'Sodium: ${_formatNutrient(nutrients['sodium_milligrams'])}mg\n'
          'Carbohydrates: ${_formatNutrient(nutrients['carbohydrates_grams'])}g\n'
          '  Dietary Fiber: ${_formatNutrient(nutrients['fiber_grams'])}g\n'
          '  Sugars: ${_formatNutrient(nutrients['sugars_grams'])}g\n'
          'Protein: ${_formatNutrient(nutrients['protein_grams'])}g\n\n';
    }

    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                mealName,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                servingSizeText,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Divider(height: 32),
              Text(
                'Nutrition Facts',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                nutritionText,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(
      BuildContext context, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 2),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showNutritionFacts(context, item),
                // Full 48dp row height for an easy tap, with a label that
                // tells screen-reader users what tapping does.
                child: Semantics(
                  label: '$item — view nutrition facts',
                  excludeSemantics: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '• ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: scheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lunches = _lunches;
    final hasContent = lunches != null && lunches.isNotEmpty;

    Widget content;
    if (hasContent) {
      content = ScrollablePositionedList.builder(
        itemScrollController: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: lunches.length,
        itemBuilder: (context, index) =>
            _buildLunchCard(context, lunches[index], scheme),
      );
    } else if (_error != null) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          ErrorStatusView(
            title: "Couldn't load the lunch menu",
            message: _error!,
            onRetry: () => _load(force: true),
          ),
        ],
      );
    } else if (_loading) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          LoadingStatusView(label: 'Loading the menu…'),
        ],
      );
    } else {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyStatusView(
            icon: Icons.restaurant_menu,
            title: 'No lunch menu published',
            message:
                "This month's menu hasn't been published yet. Pull down to "
                'refresh.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: Column(
        children: [
          if (_showingSavedCopy && _cachedAt != null)
            SavedCopyNotice(
                label: 'Saved menu from ${shortDateLabel(_cachedAt!)}'),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildLunchCard(
      BuildContext context, DailyLunch lunch, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Text(
            _formatDate(lunch.date),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 1.2,
                ),
          ),
        ),
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: lunch.isDayOff
                ? Row(
                    children: [
                      Icon(Icons.beach_access_outlined,
                          size: 20, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lunch.dayOffReason ?? 'No School',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMenuSection(context, 'Lunch Entrees', lunch.entrees),
                      _buildMenuSection(
                          context, 'Vegetables', lunch.vegetables),
                      _buildMenuSection(context, 'Fruit & Juice', lunch.fruit),
                      _buildMenuSection(context, 'Milk Choice', lunch.milk),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
