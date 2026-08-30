import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:live_activities/live_activities.dart';
import 'package:permission_handler/permission_handler.dart';

import 'data.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'special_schedule.dart';
import 'telemetry.dart';
import 'widget_sync.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with WidgetsBindingObserver {
  Timer? _ticker;
  List? selectedDaySchedule = getCurrentSchedule();
  int selectedDayScheduleIndex = getCurrentDayOfWeek();

  /// Today's special (modified) schedule when the server/cache provides one.
  List<Map<String, dynamic>>? _todaySpecialSchedule;

  /// Whether the last special-schedule refresh could not reach any source.
  bool _specialScheduleFetchFailed = false;

  /// Per-banner dismissal flags; banners reappear on a new day or fresh failure.
  bool _specialScheduleBannerDismissed = false;
  bool _fetchFailedBannerDismissed = false;

  /// Used to detect midnight rollover without rebuilding on every tick.
  DateTime _loadedDate = DateTime.now();

  final _liveActivitiesPlugin = LiveActivities();
  static const String _activityId = 'schedule_countdown_activity';

  /// Content signature of the live activity, so we only push updates when the
  /// displayed period (or its user settings) actually change.
  String? _lastActivitySignature;
  bool _isActivityActive = false;
  bool _liveActivitiesReady = false;
  bool _notificationPermissionRequested = false;

  final AppSettings _settings = AppSettings.instance;

  /// End-time of the period the widget was last synced for.
  DateTime? _lastWidgetPeriodEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
    _initSpecialSchedules();
    unawaited(_initLiveActivities());

    // Ticker drives the per-second countdown and widget/notification updates.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkForNewDay();
      final currentPeriodEnd = _getCurrentPeriodEndTime();
      if (currentPeriodEnd != _lastWidgetPeriodEnd) {
        _lastWidgetPeriodEnd = currentPeriodEnd;
        unawaited(syncHomeWidget());
      }
      _updateLiveActivity();
      setState(() {});
    });
  }

  /// Today's effective schedule — special when one applies, otherwise regular.
  List? get _todaySchedule => _todaySpecialSchedule ?? getCurrentSchedule();

  void _initSpecialSchedules() {
    SpecialScheduleService.instance.addListener(_onSpecialSchedulesChanged);
    _onSpecialSchedulesChanged();
    unawaited(SpecialScheduleService.instance.refreshToday());
  }

  void _onSpecialSchedulesChanged() {
    if (!mounted) return;
    final service = SpecialScheduleService.instance;
    final special = service.todaySchedule;

    if (service.lastFetchFailed && !_specialScheduleFetchFailed) {
      // A fresh failure: re-show the "may not be accurate" banner.
      _fetchFailedBannerDismissed = false;
      Telemetry.instance
          .logEvent('special_schedule_fetch_failed', {'stale': special != null});
    }
    _specialScheduleFetchFailed = service.lastFetchFailed;

    final scheduleChanged = special != _todaySpecialSchedule;
    _todaySpecialSchedule = special;

    if (selectedDayScheduleIndex == getCurrentDayOfWeek()) {
      selectedDaySchedule = _todaySchedule;
    }

    setState(() {});
    if (scheduleChanged) unawaited(syncHomeWidget());
  }

  /// Handles day rollover at midnight so the schedule picks up the new day.
  void _checkForNewDay() {
    final now = DateTime.now();
    if (_isSameDay(now, _loadedDate)) return;
    _loadedDate = now;
    _specialScheduleBannerDismissed = false;
    _fetchFailedBannerDismissed = false;
    _onSpecialSchedulesChanged();
    unawaited(SpecialScheduleService.instance.refreshToday());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForNewDay();
      unawaited(SpecialScheduleService.instance.refreshToday());
      unawaited(_ensureNotificationPermission());
    }
  }

  Future<void> _initLiveActivities() async {
    // appGroupId is an iOS-only concern; passing null/empty is fine on Android
    // but we use a real reverse-DNS identifier to avoid the placeholder string
    // from leaking into plugin logs.
    try {
      await _liveActivitiesPlugin.init(appGroupId: 'group.com.westviewhs.app');
    } catch (_) {
      // Plugin init is best-effort (e.g. on desktop).
    }
    try {
      await _liveActivitiesPlugin.endAllActivities();
    } catch (_) {}
    _liveActivitiesReady = true;
    await _ensureNotificationPermission();
    _updateLiveActivity();
  }

  /// Asks Android 13+ for POST_NOTIFICATIONS once per process lifetime, but
  /// only when the live activity is actually enabled (default: on).
  Future<void> _ensureNotificationPermission() async {
    if (!_settings.liveActivityActive) return;
    if (_notificationPermissionRequested) return;
    _notificationPermissionRequested = true;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isRestricted) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Permission plugin unavailable (desktop/web) — ignore.
    }
  }

  void _onSettingsChanged() {
    unawaited(_ensureNotificationPermission());
    _lastActivitySignature = null;
    _updateLiveActivity();
    if (mounted) setState(() {});
  }

  void _updateLiveActivity() {
    if (!_liveActivitiesReady) return;

    final currentEndTime = _getCurrentPeriodEndTime();
    final currentPeriodName = _getCurrentPeriodName();
    final enabled = _settings.liveActivityActive;

    if (enabled && currentEndTime != null && currentPeriodName != null) {
      final displayName = _settings.displayName(currentPeriodName);
      final details = _settings.detailsFor(currentPeriodName);
      final signature =
          '$displayName|$details|${currentEndTime.millisecondsSinceEpoch}';

      if (_lastActivitySignature != signature) {
        _lastActivitySignature = signature;
        unawaited(_liveActivitiesPlugin.createOrUpdateActivity(_activityId, {
          'periodName': displayName,
          'periodDetail': details,
          'endTime': currentEndTime.millisecondsSinceEpoch.toString(),
        }));
        _isActivityActive = true;
      }
    } else if (_isActivityActive) {
      unawaited(_liveActivitiesPlugin.endActivity(_activityId));
      _isActivityActive = false;
      _lastActivitySignature = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _settings.removeListener(_onSettingsChanged);
    SpecialScheduleService.instance.removeListener(_onSpecialSchedulesChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (_isActivityActive) {
      unawaited(_liveActivitiesPlugin.endActivity(_activityId));
    }
    super.dispose();
  }

  List? _scheduleFor(DateTime now) {
    final today = DateTime.now();
    final isToday = _isSameDay(now, today);
    return isToday ? _todaySchedule : getCurrentSchedule(now);
  }

  DateTime? _getCurrentPeriodEndTime([DateTime? customNow]) {
    final now = customNow ?? DateTime.now();
    final schedule = _scheduleFor(now);
    if (schedule == null) return null;
    for (final period in schedule) {
      final start = period['startTime'] as TimeOfDay;
      final end = period['endTime'] as TimeOfDay;
      if (isCurrentTimeInPeriod(start, end, now)) {
        return DateTime(now.year, now.month, now.day, end.hour, end.minute);
      }
    }
    return null;
  }

  String? _getCurrentPeriodName([DateTime? customNow]) {
    final now = customNow ?? DateTime.now();
    final schedule = _scheduleFor(now);
    if (schedule == null) return null;
    for (final period in schedule) {
      final start = period['startTime'] as TimeOfDay;
      final end = period['endTime'] as TimeOfDay;
      if (isCurrentTimeInPeriod(start, end, now)) {
        return period['Period'] as String;
      }
    }
    return null;
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPeriodEndTime = _getCurrentPeriodEndTime();
    final currentPeriodName = _getCurrentPeriodName();
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return SafeArea(
          child: Column(
            children: [
              // Thin progress line while today's special schedule is being
              // checked against the server.
              if (SpecialScheduleService.instance.isRefreshing)
                const LinearProgressIndicator(
                  minHeight: 2,
                  semanticsLabel: 'Checking for schedule updates',
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 10, 0),
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (!_fetchFailedBannerDismissed &&
                              _specialScheduleFetchFailed)
                            _ScheduleNotice(
                              icon: Icons.cloud_off,
                              message:
                                  "Couldn't reach the special-schedule server, "
                                  "so today's schedule may not be accurate.",
                              background: scheme.errorContainer,
                              foreground: scheme.onErrorContainer,
                              onDismiss: () => setState(
                                  () => _fetchFailedBannerDismissed = true),
                            ),
                          if (!_specialScheduleBannerDismissed &&
                              _todaySpecialSchedule != null)
                            _ScheduleNotice(
                              icon: Icons.event_note,
                              message:
                                  'A special schedule is in effect today.',
                              background: scheme.primaryContainer,
                              foreground: scheme.onPrimaryContainer,
                              onDismiss: () => setState(
                                  () => _specialScheduleBannerDismissed = true),
                            ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: SegmentedButton<int>(
                              // The segments show whole-day schedules, not a
                              // transient choice, so the checkmark is noise.
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                    value: 0, label: Text('Mon/Fri')),
                                ButtonSegment(
                                    value: 1, label: Text('Tue/Thu')),
                                ButtonSegment(value: 2, label: Text('Wed')),
                              ],
                              selected: {selectedDayScheduleIndex},
                              onSelectionChanged: (selection) {
                                final index = selection.first;
                                setState(() {
                                  selectedDayScheduleIndex = index;
                                  selectedDaySchedule =
                                      index == getCurrentDayOfWeek()
                                          ? _todaySchedule
                                          : [
                                              monFriSchedule,
                                              tueThursSchedule,
                                              wedSchedule,
                                            ][index];
                                });
                              },
                            ),
                          ),
                          Card(
                            color: scheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  top: 16, left: 8, right: 8, bottom: 8),
                              child: Center(
                                child: currentPeriodEndTime != null
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _settings.displayName(
                                                currentPeriodName ?? ''),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: scheme
                                                      .onPrimaryContainer,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          // The ticking digits are excluded
                                          // from the semantic tree (they would
                                          // re-announce every second); the
                                          // period name above carries the
                                          // meaning for screen readers.
                                          ExcludeSemantics(
                                            child: TimerCountdown(
                                              format: CountDownTimerFormat
                                                  .hoursMinutesSeconds,
                                              endTime: currentPeriodEndTime,
                                              timeTextStyle: TextStyle(
                                                fontSize: 20,
                                                color: scheme
                                                    .onPrimaryContainer,
                                              ),
                                              onEnd: () {
                                                // Roll straight into the next
                                                // period's countdown without a
                                                // visible pause.
                                                if (mounted) {
                                                  _updateLiveActivity();
                                                  setState(() {});
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'No active period',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color:
                                                  scheme.onSurfaceVariant,
                                            ),
                                      ),
                              ),
                            ),
                          ),
                          for (final period in selectedDaySchedule ?? const [])
                            _buildPeriodCard(context, period),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Standard-size FAB (56dp) for a comfortable touch target;
                    // the tooltip doubles as the screen-reader label.
                    FloatingActionButton(
                      heroTag: 'home_settings_button',
                      tooltip: 'Settings',
                      onPressed: _openSettings,
                      child: const Icon(Icons.settings),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodCard(BuildContext context, dynamic period) {
    final scheme = Theme.of(context).colorScheme;
    final canonicalName = period['Period'] as String;
    final displayName = _settings.displayName(canonicalName);
    final details = _settings.detailsFor(canonicalName);
    final isNow = isCurrentTimeInPeriod(
            period['startTime'], period['endTime']) &&
        identical(selectedDaySchedule, _todaySchedule);

    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: isNow ? scheme.onPrimaryContainer : scheme.onSurface,
          fontWeight: FontWeight.w600,
        );
    final detailStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isNow ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            );
    final timeStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isNow ? scheme.onPrimaryContainer : scheme.onSurface,
        );

    return Card(
      elevation: isNow ? 5 : 0,
      color: isNow ? scheme.primaryContainer : scheme.surfaceContainerLow,
      child: Semantics(
        container: true,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName, style: titleStyle),
                    if (details.isNotEmpty)
                      Text(details, style: detailStyle),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  (period['startTime'] as TimeOfDay).format(context),
                  style: timeStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  (period['endTime'] as TimeOfDay).format(context),
                  style: timeStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool isCurrentTimeInPeriod(TimeOfDay startTime, TimeOfDay endTime,
    [DateTime? nowTime]) {
  final now = nowTime ?? DateTime.now();
  final start = DateTime(
      now.year, now.month, now.day, startTime.hour, startTime.minute);
  final end = DateTime(
      now.year, now.month, now.day, endTime.hour, endTime.minute);
  return (now.isAtSameMomentAs(start) || now.isAfter(start)) &&
      now.isBefore(end);
}

/// Returns the base schedule for [customNow] (defaults to now). Weekend days
/// return null.
List<Map<String, dynamic>>? getCurrentSchedule([DateTime? customNow]) {
  final day = (customNow ?? DateTime.now()).weekday;
  switch (day) {
    case DateTime.monday:
    case DateTime.friday:
      return monFriSchedule;
    case DateTime.tuesday:
    case DateTime.thursday:
      return tueThursSchedule;
    case DateTime.wednesday:
      return wedSchedule;
    default:
      return null;
  }
}

/// Returns the segment index (0=Mon/Fri, 1=Tue/Thu, 2=Wed) for [customNow].
/// Weekends fall back to Mon/Fri since those bracket the school week.
int getCurrentDayOfWeek([DateTime? customNow]) {
  final day = (customNow ?? DateTime.now()).weekday;
  switch (day) {
    case DateTime.monday:
    case DateTime.friday:
    case DateTime.saturday:
    case DateTime.sunday:
      return 0;
    case DateTime.tuesday:
    case DateTime.thursday:
      return 1;
    case DateTime.wednesday:
      return 2;
  }
  return 0;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Small dismissable notice banner shown above the schedule.
class _ScheduleNotice extends StatelessWidget {
  const _ScheduleNotice({
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
    required this.onDismiss,
  });

  final IconData icon;
  final String message;
  final Color background;
  final Color foreground;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Full 48dp tap target; only the glyph is small.
          IconButton(
            tooltip: 'Dismiss',
            iconSize: 18,
            icon: Icon(Icons.close, color: foreground),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
