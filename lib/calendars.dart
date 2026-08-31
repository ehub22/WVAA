import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'school_lunch.dart';

enum CalendarType { google, schoolLunch }

/// Description of a top-level calendar tab. When [type] is
/// [CalendarType.schoolLunch], [url] is ignored and the native lunch view is
/// rendered.
class CalendarTab {
  const CalendarTab(this.title, this.url,
      {this.isApi = false, this.type = CalendarType.google});

  final String title;
  final String url;
  final bool isApi;
  final CalendarType type;
}

class CalendarEventsView extends StatefulWidget {
  const CalendarEventsView({super.key, required this.apiUrl});

  final String apiUrl;

  @override
  State<CalendarEventsView> createState() => _CalendarEventsViewState();
}

class _CalendarEventsViewState extends State<CalendarEventsView> {
  late Future<List<dynamic>> _eventsFuture;
  final ItemScrollController _scrollController = ItemScrollController();

  @override
  void initState() {
    super.initState();
    _eventsFuture = _fetchEvents();
    _eventsFuture.then((events) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToToday(events);
      });
    });
  }

  void _scrollToToday(List<dynamic> events) {
    final now = DateTime.now();
    final targetIndex = events.indexWhere((e) {
      final displayDate = e['displayDate'] as DateTime;
      return _isSameDay(displayDate, now) || displayDate.isAfter(now);
    });
    if (targetIndex != -1 && _scrollController.isAttached) {
      _scrollController.jumpTo(index: targetIndex);
    }
  }

  Future<List<dynamic>> _fetchEvents() async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 1));
    final timeMin =
        Uri.encodeComponent(twoDaysAgo.toUtc().toIso8601String());
    final url =
        '${widget.apiUrl}&timeMin=$timeMin&singleEvents=True&orderBy=startTime&maxResults=100';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load events (HTTP ${response.statusCode})');
    }

    final data = json.decode(response.body);
    final items = (data['items'] as List<dynamic>?) ?? const [];
    final expanded = <Map<String, dynamic>>[];

    for (final event in items) {
      if (event is! Map<String, dynamic>) continue;
      final start = _parseEventDate(event['start']);
      final end = _parseEventDate(event['end']);
      final inclusiveEnd =
          end.isAtSameMomentAs(start) ? end : end.subtract(const Duration(milliseconds: 1));

      var current = DateTime(start.year, start.month, start.day);
      final last =
          DateTime(inclusiveEnd.year, inclusiveEnd.month, inclusiveEnd.day);

      while (!current.isAfter(last)) {
        final clone = Map<String, dynamic>.from(event);
        clone['displayDate'] = current;
        expanded.add(clone);
        current = current.add(const Duration(days: 1));
      }
    }

    expanded.sort((a, b) =>
        (a['displayDate'] as DateTime).compareTo(b['displayDate'] as DateTime));
    return expanded;
  }

  DateTime _parseEventDate(Map<String, dynamic>? dateMap) {
    if (dateMap == null) return DateTime.now();
    if (dateMap['dateTime'] != null) {
      return DateTime.parse(dateMap['dateTime'] as String).toLocal();
    }
    if (dateMap['date'] != null) return DateTime.parse(dateMap['date'] as String);
    return DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
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

  String _formatTime(Map<String, dynamic> event) {
    final raw = event['start']?['dateTime'];
    if (raw == null) return 'All Day';
    final dt = DateTime.parse(raw as String).toLocal();
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _showEventDetails(
      BuildContext context, Map<String, dynamic> event, String timeStr) {
    final description =
        (event['description'] as String?) ?? 'No description provided.';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
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
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    (event['summary'] as String?) ?? 'Untitled Event',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (event['location'] != null) ...[
                    const SizedBox(height: 4),
                    Text('${event['location']}',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                  const Divider(height: 32),
                  const Text(
                    'Description',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _eventsFuture,
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
                    'Couldn\'t load calendar events.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _eventsFuture = _fetchEvents()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final events = snapshot.data ?? const [];
        if (events.isEmpty) {
          return const Center(child: Text('No events found.'));
        }

        return ScrollablePositionedList.builder(
          itemScrollController: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index] as Map<String, dynamic>;
            final displayDate = event['displayDate'] as DateTime;
            final prevDate = index > 0
                ? (events[index - 1] as Map<String, dynamic>)['displayDate']
                    as DateTime?
                : null;
            final showHeader =
                prevDate == null || !_isSameDay(displayDate, prevDate);

            final title = (event['summary'] as String?) ?? 'Untitled Event';
            final location = event['location']?.toString();
            final timeStr = _formatTime(event);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 10),
                    child: Text(
                      _dayLabel(displayDate),
                      style: const TextStyle(
                          fontSize: 15, letterSpacing: 1.2),
                    ),
                  ),
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: () => _showEventDetails(context, event, timeStr),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    title: Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(timeStr,
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        if (location != null && location.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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

class CalendarsPage extends StatefulWidget {
  const CalendarsPage({super.key});

  @override
  State<CalendarsPage> createState() => _CalendarsPageState();
}

class _CalendarsPageState extends State<CalendarsPage> {
  int selectedIndex = 0;
  late final PageController _carouselController;

  final List<CalendarTab> _calendars = const [
    CalendarTab(
      'School Calendar',
      'https://www.googleapis.com/calendar/v3/calendars/westviewwolverines@gmail.com/events'
      '?key=AIzaSyDeFW5b_wnH-uDLG-RjPsTX6P2iOZHwGBo',
      isApi: true,
    ),
    CalendarTab(
      'Athletics',
      'https://www.googleapis.com/calendar/v3/calendars/c_bdlim8dben51vvr6p2omiguh1k@group.calendar.google.com/events'
      '?key=AIzaSyDeFW5b_wnH-uDLG-RjPsTX6P2iOZHwGBo',
      isApi: true,
    ),
    CalendarTab(
      'School Lunches',
      '',
      isApi: true,
      type: CalendarType.schoolLunch,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.7);
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _carouselController.animateToPage(
      index,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 90,
            child: PageView.builder(
              controller: _carouselController,
              itemCount: _calendars.length,
              onPageChanged: (index) => setState(() => selectedIndex = index),
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                return GestureDetector(
                  onTap: () => _onItemTapped(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).appBarTheme.backgroundColor
                          : Theme.of(context).appBarTheme.foregroundColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : const [],
                    ),
                    child: Center(
                      child: Text(
                        _calendars[index].title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: isSelected ? 16 : 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _calendars[selectedIndex].type == CalendarType.schoolLunch
                ? const SchoolLunchView()
                : CalendarEventsView(
                    key: ValueKey(_calendars[selectedIndex].url),
                    apiUrl: _calendars[selectedIndex].url,
                  ),
          ),
        ],
      ),
    );
  }
}
