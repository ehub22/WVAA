import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'l10n/strings.dart';
import 'network_cache.dart';
import 'school_lunch.dart';
import 'support.dart';
import 'widgets/section_selector.dart';
import 'widgets/status_views.dart';

enum CalendarType { google, schoolLunch }

/// Description of a top-level calendar tab. When [type] is
/// [CalendarType.schoolLunch], [url] is ignored and the native lunch view is
/// rendered.
class CalendarTab {
  const CalendarTab(this.titleKey, this.url,
      {this.isApi = false, this.type = CalendarType.google});

  /// Key in `strings.dart` so tab labels translate with the app language.
  final String titleKey;
  final String url;
  final bool isApi;
  final CalendarType type;
}

/// Displays upcoming events from one Google Calendar feed.
///
/// This loads from local storage first so the calendar still opens right away
/// when campus Wi-Fi is down, and pulling down (or tapping Retry) forces a
/// fresh network fetch.
class CalendarEventsView extends StatefulWidget {
  const CalendarEventsView({
    super.key,
    required this.apiUrl,
  });

  final String apiUrl;

  @override
  State<CalendarEventsView> createState() => CalendarEventsViewState();
}

class CalendarEventsViewState extends State<CalendarEventsView> {
  final ItemScrollController _scrollController = ItemScrollController();
  static const Duration _cacheMaxAge = Duration(hours: 6);
  static const Duration _requestTimeout = Duration(seconds: 15);

  List<Map<String, dynamic>>? _events;
  DateTime? _cachedAt;
  bool _loading = false;
  bool _showingSavedCopy = false;
  /// Tracks whether the initial load failed with nothing cached, stored as a
  /// bool so switching languages updates the error text automatically.
  bool _error = false;

  /// Whether the initial scroll-to-today still needs to happen.
  bool _needsScrollToToday = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads events: disk cache first, then network unless the cache is fresh.
  /// With [force], always goes to the network (pull-to-refresh / Retry).
  Future<void> _load({bool force = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    // Serve the cached response immediately, if present and parseable.
    CachedResponse? cache;
    try {
      cache = await NetworkCache.instance.read(widget.apiUrl);
      if (_events == null && cache != null) {
        final cached = parseEvents(cache.body);
        if (cached.isNotEmpty) {
          _events = cached;
          _cachedAt = cache.cachedAt;
        }
      }
    } catch (error) {
      // Corrupt cache entry: ignore it and go to the network.
      debugPrint('Calendar cache unusable: $error');
    }

    // A fresh cache satisfies the load without touching the network, keeping
    // the school's calendar quota (and the student's battery) happy.
    if (!force &&
        cache != null &&
        cache.isFreshWithin(_cacheMaxAge, DateTime.now()) &&
        (_events?.isNotEmpty ?? false)) {
      if (!mounted) return;
      setState(() => _loading = false);
      _scrollToTodayIfNeeded();
      return;
    }

    try {
      final body = await _fetchEventsBody();
      final events = parseEvents(body);
      await NetworkCache.instance.write(widget.apiUrl, body);
      if (!mounted) return;
      setState(() {
        _events = events;
        _cachedAt = DateTime.now();
        _loading = false;
        _showingSavedCopy = false;
      });
      _scrollToTodayIfNeeded();
    } catch (error) {
      debugPrint('Calendar fetch failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_events != null && _events!.isNotEmpty) {
          // Offline: keep showing the last known events.
          _showingSavedCopy = true;
        } else {
          _error = true;
        }
      });
    }
  }

  void _scrollToTodayIfNeeded() {
    if (!_needsScrollToToday) return;
    final events = _events;
    if (events == null || events.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_needsScrollToToday) return;
      final now = DateTime.now();
      final targetIndex = events.indexWhere((e) {
        final displayDate = e['displayDate'] as DateTime;
        return _isSameDay(displayDate, now) || displayDate.isAfter(now);
      });
      if (targetIndex != -1 && _scrollController.isAttached) {
        _scrollController.jumpTo(index: targetIndex);
        _needsScrollToToday = false;
      }
    });
  }

  Future<String> _fetchEventsBody() async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 1));
    final timeMin = Uri.encodeComponent(twoDaysAgo.toUtc().toIso8601String());
    final url =
        '${widget.apiUrl}&timeMin=$timeMin&singleEvents=True&orderBy=startTime&maxResults=100';

    final response =
        await http.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to load events (HTTP ${response.statusCode})');
    }
    return response.body;
  }

  /// Parses a Google Calendar API `events` response into a flat, sorted list
  /// where multi-day events are expanded to one entry per day.
  ///
  /// Public and static so it can be unit-tested against saved payloads.
  @visibleForTesting
  static List<Map<String, dynamic>> parseEvents(String body) {
    final data = json.decode(body);
    final items = (data['items'] as List<dynamic>?) ?? const [];
    final expanded = <Map<String, dynamic>>[];

    for (final event in items) {
      if (event is! Map<String, dynamic>) continue;
      final start = _parseEventDate(event['start']);
      final end = _parseEventDate(event['end']);
      final inclusiveEnd = end.isAtSameMomentAs(start)
          ? end
          : end.subtract(const Duration(milliseconds: 1));

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

  static DateTime _parseEventDate(Map<String, dynamic>? dateMap) {
    if (dateMap == null) return DateTime.now();
    if (dateMap['dateTime'] != null) {
      return DateTime.parse(dateMap['dateTime'] as String).toLocal();
    }
    if (dateMap['date'] != null) return DateTime.parse(dateMap['date'] as String);
    return DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date, AppStrings strings) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return strings['calendar.today'];
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return strings['calendar.yesterday'];
    }
    if (_isSameDay(date, now.add(const Duration(days: 1)))) {
      return strings['calendar.tomorrow'];
    }

    // Weekday names come from `strings.dart` so we don't need extra locale
    // date-format tables just for headers.
    final weekdays = strings['calendar.weekdays'].split(',');
    final name = weekdays[(date.weekday - 1).clamp(0, 6)];
    return '$name, ${shortDateLabel(date)}';
  }

  String _formatTime(Map<String, dynamic> event, AppStrings strings) {
    final raw = event['start']?['dateTime'];
    if (raw == null) return strings['calendar.allDay'];
    final dt = DateTime.parse(raw as String).toLocal();
    final ampm =
        dt.hour >= 12 ? strings['calendar.pm'] : strings['calendar.am'];
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _showEventDetails(
      BuildContext context, Map<String, dynamic> event, String timeStr) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    final description =
        (event['description'] as String?) ?? strings['calendar.noDescription'];
    showModalBottomSheet<void>(
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
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    (event['summary'] as String?) ??
                        strings['calendar.untitled'],
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (event['location'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${event['location']}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const Divider(height: 32),
                  Text(
                    strings['calendar.description'],
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5),
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
    final events = _events;
    final hasContent = events != null && events.isNotEmpty;

    // Every non-content state is rendered inside a scrollable so that
    // pull-to-refresh keeps working from the loading/empty/error screens.
    Widget content;
    if (hasContent) {
      content = ScrollablePositionedList.builder(
        itemScrollController: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: events.length,
        itemBuilder: (context, index) =>
            _buildEventTile(context, events, index),
      );
    } else if (_error) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          ErrorStatusView(
            title: AppStrings.of(context)['calendar.errorTitle'],
            message: AppStrings.of(context)['calendar.errorBody'],
            onRetry: () => _load(force: true),
          ),
        ],
      );
    } else if (_loading) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          LoadingStatusView(
            label: AppStrings.of(context)['calendar.loading'],
          ),
        ],
      );
    } else {
      final emptyStrings = AppStrings.of(context);
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyStatusView(
            icon: Icons.event_available,
            title: emptyStrings['calendar.emptyTitle'],
            message: emptyStrings['calendar.emptyBody'],
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
              label:
                  '${AppStrings.of(context)['calendar.savedCopy']} ${shortDateLabel(_cachedAt!)}',
            ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildEventTile(
      BuildContext context, List<Map<String, dynamic>> events, int index) {
    final scheme = Theme.of(context).colorScheme;
    final event = events[index];
    final displayDate = event['displayDate'] as DateTime;
    final prevDate = index > 0
        ? (events[index - 1])['displayDate'] as DateTime?
        : null;
    final showHeader = prevDate == null || !_isSameDay(displayDate, prevDate);

    final strings = AppStrings.of(context);
    final title = (event['summary'] as String?) ?? strings['calendar.untitled'];
    final location = event['location']?.toString();
    final timeStr = _formatTime(event, strings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Text(
              _dayLabel(displayDate, AppStrings.of(context)),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 1.2,
                    color: scheme.onSurfaceVariant,
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
          child: ListTile(
            onTap: () => _showEventDetails(context, event, timeStr),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                if (location != null && location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
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
  }
}

class CalendarsPage extends StatefulWidget {
  const CalendarsPage({super.key});

  @override
  State<CalendarsPage> createState() => _CalendarsPageState();
}

class _CalendarsPageState extends State<CalendarsPage> {
  int selectedIndex = 0;

  static const List<CalendarTab> _calendars = [
    CalendarTab(
      'calendar.tabSchool',
      'https://www.googleapis.com/calendar/v3/calendars/westviewwolverines@gmail.com/events'
      '?key=AIzaSyDeFW5b_wnH-uDLG-RjPsTX6P2iOZHwGBo',
      isApi: true,
    ),
    CalendarTab(
      'calendar.tabAthletics',
      'https://www.googleapis.com/calendar/v3/calendars/c_bdlim8dben51vvr6p2omiguh1k@group.calendar.google.com/events'
      '?key=AIzaSyDeFW5b_wnH-uDLG-RjPsTX6P2iOZHwGBo',
      isApi: true,
    ),
    CalendarTab(
      'calendar.tabLunch',
      '',
      isApi: true,
      type: CalendarType.schoolLunch,
    ),
  ];

  void _onItemTapped(int index) {
    setState(() => selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SectionSelector(
                  labels: [
                    for (final tab in _calendars)
                      AppStrings.of(context)[tab.titleKey],
                  ],
                  selectedIndex: selectedIndex,
                  onSelected: _onItemTapped,
                ),
              ),
              // Help is reachable from every tab, not just the home screen.
              const HelpIconButton(),
              const SizedBox(width: 4),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: LazyIndexedStack(
              index: selectedIndex,
              itemCount: _calendars.length,
              itemBuilder: (context, index) {
                final tab = _calendars[index];
                return tab.type == CalendarType.schoolLunch
                    ? const SchoolLunchView()
                    : CalendarEventsView(
                        key: ValueKey(tab.url),
                        apiUrl: tab.url,
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}
