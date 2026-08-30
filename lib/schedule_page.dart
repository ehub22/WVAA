import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:live_activities/live_activities.dart';
import 'data.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'special_schedule.dart';
import 'widget_sync.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> with WidgetsBindingObserver {
  Timer? _tickTimer;
  List? selectedDaySchedule = getCurrentSchedule();
  int selectedDayScheduleIndex = getCurrentDayOfWeek();

  List<Map<String, dynamic>>? _todaySpecialSchedule;
  bool _specialScheduleFetchFailed = false;
  bool _specialScheduleBannerDismissed = false;
  bool _fetchFailedBannerDismissed = false;

  DateTime _loadedDate = DateTime.now();

  final _liveActivitiesPlugin = LiveActivities();
  final String _activityId = 'schedule_countdown_activity';
  String? _lastActivitySignature;
  bool _isActivityActive = false;
  bool _liveActivitiesReady = false;
  bool _notificationPermissionRequested = false;

  final AppSettings _settings = AppSettings.instance;
  DateTime? _lastWidgetPeriodEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLiveActivities();
    _initSpecialSchedules();
    _settings.addListener(_onSettingsChanged);

    // Lightweight tick: only syncs the widget and checks for midnight rollover.
    // The countdown timer widget rebuilds itself via TimerCountdown.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkForNewDay();
      final currentPeriodEnd = _getCurrentPeriodEndTime();
      if (currentPeriodEnd != _lastWidgetPeriodEnd) {
        _lastWidgetPeriodEnd = currentPeriodEnd;
        unawaited(syncHomeWidget());
      }
      _updateLiveActivity();
    });
  }

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
      _fetchFailedBannerDismissed = false;
    }
    _specialScheduleFetchFailed = service.lastFetchFailed;

    final scheduleChanged = special != _todaySpecialSchedule;
    _todaySpecialSchedule = special;

    if (selectedDayScheduleIndex == getCurrentDayOfWeek()) {
      selectedDaySchedule = _todaySchedule;
    }

    setState(() {});
    if (scheduleChanged) {
      unawaited(syncHomeWidget());
    }
  }

  void _checkForNewDay() {
    final now = DateTime.now();
    if (now.year == _loadedDate.year &&
        now.month == _loadedDate.month &&
        now.day == _loadedDate.day) {
      return;
    }
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
    }
  }

  Future<void> _initLiveActivities() async {
    await _liveActivitiesPlugin.init(appGroupId: 'group.com.your.app');
    await _liveActivitiesPlugin.endAllActivities();
    _liveActivitiesReady = true;
    await _ensureNotificationPermission();
    _updateLiveActivity();
  }

  Future<void> _ensureNotificationPermission() async {
    if (!_settings.liveActivityActive) return;
    if (_notificationPermissionRequested) return;
    _notificationPermissionRequested = true;
    try {
      await Permission.notification.request();
    } catch (_) {}
  }

  void _onSettingsChanged() {
    unawaited(_ensureNotificationPermission());
    _lastActivitySignature = null;
    _updateLiveActivity();
    if (mounted) setState(() {});
  }

  void _updateLiveActivity() async {
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

        final data = {
          'periodName': displayName,
          'periodDetail': details,
          'endTime': currentEndTime.millisecondsSinceEpoch.toString(),
        };

        await _liveActivitiesPlugin.createOrUpdateActivity(_activityId, data);
        _isActivityActive = true;
      }
    } else {
      if (_isActivityActive) {
        await _liveActivitiesPlugin.endActivity(_activityId);
        _isActivityActive = false;
        _lastActivitySignature = null;
      }
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _settings.removeListener(_onSettingsChanged);
    SpecialScheduleService.instance.removeListener(_onSpecialSchedulesChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (_isActivityActive) {
      _liveActivitiesPlugin.endActivity(_activityId);
    }
    super.dispose();
  }

  List? _scheduleFor(DateTime now) {
    final today = DateTime.now();
    final isToday = now.year == today.year &&
        now.month == today.month &&
        now.day == today.day;
    return isToday ? _todaySchedule : getCurrentSchedule(now);
  }

  DateTime? _getCurrentPeriodEndTime([DateTime? customNow]) {
    final now = customNow ?? DateTime.now();
    final schedule = _scheduleFor(now);
    if (schedule != null) {
      for (var period in schedule) {
        final startTime = period['startTime'] as TimeOfDay;
        final endTime = period['endTime'] as TimeOfDay;
        if (isCurrentTimeInPeriod(startTime, endTime, now)) {
          return DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
        }
      }
    }
    return null;
  }

  String? _getCurrentPeriodName([DateTime? customNow]) {
    final now = customNow ?? DateTime.now();
    final schedule = _scheduleFor(now);
    if (schedule != null) {
      for (var period in schedule) {
        final startTime = period['startTime'] as TimeOfDay;
        final endTime = period['endTime'] as TimeOfDay;
        if (isCurrentTimeInPeriod(startTime, endTime, now)) {
          return period['Period'] as String;
        }
      }
    }
    return null;
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? currentPeriodEndTime = _getCurrentPeriodEndTime();

    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsetsGeometry.directional(start: 10, end: 10),
                  child: ListView(
                    children: [
                      // Banners
                      if (!_fetchFailedBannerDismissed &&
                          _specialScheduleFetchFailed)
                        _ScheduleNotice(
                          icon: Icons.cloud_off,
                          message:
                              "Couldn't reach the special-schedule server, "
                              "so today's schedule may not be accurate.",
                          background: Theme.of(context).colorScheme.error,
                          foreground: Theme.of(context).colorScheme.onError,
                          onDismiss: () =>
                              setState(() => _fetchFailedBannerDismissed = true),
                        ),
                      if (!_specialScheduleBannerDismissed &&
                          _todaySpecialSchedule != null)
                        _ScheduleNotice(
                          icon: Icons.event_note,
                          message: 'A special schedule is in effect today.',
                          background:
                              Theme.of(context).colorScheme.primaryContainer,
                          foreground:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          onDismiss: () => setState(
                              () => _specialScheduleBannerDismissed = true),
                        ),

                      AdaptiveSegmentedControl(
                          labels: const ['Mon/Fri', 'Tue/Thu', 'Wed'],
                          selectedIndex: selectedDayScheduleIndex,
                          onValueChanged: (index) {
                            selectedDayScheduleIndex = index;
                            selectedDaySchedule =
                                index == getCurrentDayOfWeek()
                                    ? _todaySchedule
                                    : [
                                        monFriSchedule,
                                        tueThursSchedule,
                                        wedSchedule
                                      ][index];
                            if (mounted) setState(() {});
                          }),

                      Card(
                        color: Theme.of(context).cardColor,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 16, left: 8, right: 8, bottom: 8),
                          child: Center(
                            child: currentPeriodEndTime != null
                                ? TimerCountdown(
                                    format: CountDownTimerFormat
                                        .hoursMinutesSeconds,
                                    endTime: currentPeriodEndTime,
                                    timeTextStyle:
                                        const TextStyle(fontSize: 20),
                                    onEnd: () {
                                      if (mounted) {
                                        _updateLiveActivity();
                                      }
                                    },
                                  )
                                : Text(
                                    "No active period",
                                    style: TextStyle(
                                        fontSize: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline),
                                  ),
                          ),
                        ),
                      ),

                      for (var period in selectedDaySchedule ?? [])
                        _buildPeriodCard(context, period),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
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
    final canonicalName = period['Period'] as String;
    final displayName = _settings.displayName(canonicalName);
    final details = _settings.detailsFor(canonicalName);
    final isNow = isCurrentTimeInPeriod(
            period['startTime'], period['endTime']) &&
        identical(selectedDaySchedule, _todaySchedule);

    final highlightStyle =
        isNow ? Theme.of(context).appBarTheme.titleTextStyle : null;
    final detailStyle = (highlightStyle ??
            Theme.of(context).textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(
      fontSize: 12,
      color: isNow
          ? Theme.of(context).appBarTheme.titleTextStyle?.color
          : Theme.of(context).colorScheme.outline,
    );

    return Card(
      elevation: isNow ? 5 : 0,
      color: isNow
          ? Theme.of(context).appBarTheme.backgroundColor
          : Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName, style: highlightStyle),
                  if (details.isNotEmpty) Text(details, style: detailStyle),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(period['startTime'].format(context),
                  style: highlightStyle),
            ),
            Expanded(
              flex: 2,
              child: Text(period['endTime'].format(context),
                  style: highlightStyle),
            ),
          ],
        ),
      ),
    );
  }
}

bool isCurrentTimeInPeriod(TimeOfDay startTime, TimeOfDay endTime,
    [DateTime? nowTime]) {
  final now = nowTime ?? DateTime.now();
  final start =
      DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
  final end =
      DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
  return (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
      now.isBefore(end);
}

List? getCurrentSchedule([DateTime? customNow]) {
  final day = (customNow ?? DateTime.now()).weekday;
  if (day == 1 || day == 5) return monFriSchedule;
  if (day == 2 || day == 4) return tueThursSchedule;
  if (day == 3) return wedSchedule;
  return null;
}

int getCurrentDayOfWeek([DateTime? customNow]) {
  final day = (customNow ?? DateTime.now()).weekday;
  if (day == 0 || day == 1 || day == 5 || day == 6) return 0;
  if (day == 2 || day == 4) return 1;
  return 2;
}

class _ScheduleNotice extends StatelessWidget {
  const _ScheduleNotice({
    super.key,
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
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: foreground),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
