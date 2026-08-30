import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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

class SchoolLunchView extends StatefulWidget {
  const SchoolLunchView({super.key});

  @override
  State<SchoolLunchView> createState() => _SchoolLunchViewState();
}

class _SchoolLunchViewState extends State<SchoolLunchView> {
  late Future<List<DailyLunch>> _lunchFuture;
  final ItemScrollController _scrollController = ItemScrollController();
  final Map<String, dynamic> _recipes = {};

  static const String _apiOrg = '1556';
  static const String _apiMenu = '135312';
  static const String _apiRecipes = '111591';
  static const String _apiBase = 'https://menus.healthepro.com/api/organizations';

  @override
  void initState() {
    super.initState();
    _lunchFuture = _fetchLunches();
    _lunchFuture.then((lunches) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToToday(lunches);
      });
    });
  }

  void _scrollToToday(List<DailyLunch> lunches) {
    final now = DateTime.now();
    final target = lunches.indexWhere((l) =>
        (l.date.year == now.year &&
            l.date.month == now.month &&
            l.date.day == now.day) ||
        l.date.isAfter(now));
    if (target != -1 && _scrollController.isAttached) {
      _scrollController.jumpTo(index: target);
    }
  }

  void _retry() {
    setState(() {
      _recipes.clear();
      _lunchFuture = _fetchLunches();
    });
    _lunchFuture.then((lunches) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToToday(lunches);
      });
    });
  }

  Future<List<DailyLunch>> _fetchLunches() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final end =
        '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final recipesUrl =
        '$_apiBase/$_apiOrg/menus/$_apiRecipes/start_date/$start/end_date/$end/recipes/';

    // Recipes are best-effort nutrition info; don't fail the whole page if
    // that endpoint is flaky.
    try {
      final recipeResponse = await http
          .get(Uri.parse(recipesUrl))
          .timeout(const Duration(seconds: 10));
      if (recipeResponse.statusCode == 200) {
        final recipeData =
            json.decode(recipeResponse.body) as Map<String, dynamic>;
        final recipeList = (recipeData['data'] as List<dynamic>?) ?? const [];
        for (final r in recipeList) {
          if (r is Map<String, dynamic> && r['name'] != null) {
            _recipes[r['name'] as String] = r;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch lunch recipes: $e');
    }

    final url =
        '$_apiBase/$_apiOrg/menus/$_apiMenu/year/$year/month/$month/date_overwrites';

    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load lunch data (HTTP ${response.statusCode})');
    }
    return _parseLunchData(response.body);
  }

  List<DailyLunch> _parseLunchData(String jsonString) {
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
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatNutrient(dynamic value) {
    if (value == null) return '0';
    final parsed = num.tryParse(value.toString());
    return parsed?.round().toString() ?? value.toString();
  }

  void _showNutritionFacts(BuildContext context, String mealName) {
    final recipe = _recipes[mealName];
    if (recipe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No nutrition facts available for $mealName')),
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(mealName,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                servingSizeText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Divider(height: 32),
              const Text('Nutrition Facts',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(nutritionText,
                  style: const TextStyle(fontSize: 15, height: 1.5)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 2),
            child: InkWell(
              onTap: () => _showNutritionFacts(context, item),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DailyLunch>>(
      future: _lunchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Couldn\'t load school lunches.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final lunches = snapshot.data ?? const [];
        if (lunches.isEmpty) {
          return const Center(child: Text('No lunch data available.'));
        }

        return ScrollablePositionedList.builder(
          itemScrollController: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: lunches.length,
          itemBuilder: (context, index) {
            final lunch = lunches[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Text(
                    _formatDate(lunch.date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: lunch.isDayOff
                        ? Row(
                            children: [
                              Text(
                                lunch.dayOffReason ?? 'No School',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color.fromARGB(255, 158, 146, 105),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMenuSection(
                                  context, 'Lunch Entrees', lunch.entrees),
                              _buildMenuSection(
                                  context, 'Vegetables', lunch.vegetables),
                              _buildMenuSection(
                                  context, 'Fruit & Juice', lunch.fruit),
                              _buildMenuSection(
                                  context, 'Milk Choice', lunch.milk),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
