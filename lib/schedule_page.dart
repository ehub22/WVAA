import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:live_activities/live_activities.dart';
import 'data.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'widget_sync.dart';


// Schedule page
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  Timer? _timer;
  List? currentDaySchedule = getCurrentSchedule();
  List? selectedDaySchedule = getCurrentSchedule();
  int selectedDayScheduleIndex = getCurrentDayOfWeek();

  final _liveActivitiesPlugin = LiveActivities();

  final String _activityId = 'schedule_countdown_activity';

  /// Identifies the content currently shown by the live activity, so it is
  /// only rewritten when the period *or* its user settings actually change.
  String? _lastActivitySignature;
  bool _isActivityActive = false;
  bool _liveActivitiesReady = false;
  bool _notificationPermissionRequested = false;

  final AppSettings _settings = AppSettings.instance;

  /// End time of the period the home screen widget was last synced for.
  DateTime? _lastWidgetPeriodEnd;

  @override
  void initState() {
    super.initState();
    _initLiveActivities();
    _settings.addListener(_onSettingsChanged);

    // rebuild the widget every second to update
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        currentDaySchedule = getCurrentSchedule();
        // Keep the Android home screen widget in sync whenever the current
        // period changes (including "no active period").
        final currentPeriodEnd = _getCurrentPeriodEndTime();
        if (currentPeriodEnd != _lastWidgetPeriodEnd) {
          _lastWidgetPeriodEnd = currentPeriodEnd;
          unawaited(syncHomeWidget());
        }
        setState(() {
          _updateLiveActivity();
        });
      }
    });
  }

  Future<void> _initLiveActivities() async {
    await _liveActivitiesPlugin.init(appGroupId: 'group.com.your.app');
    await _liveActivitiesPlugin.endAllActivities();
    _liveActivitiesReady = true;
    // Only ask for the notification permission when the student actually
    // wants notifications (see the settings page).
    await _ensureNotificationPermission();
    _updateLiveActivity();
  }

  Future<void> _ensureNotificationPermission() async {
    if (!_settings.liveActivityActive) return;
    if (_notificationPermissionRequested) return;
    _notificationPermissionRequested = true;
    try {
      await Permission.notification.request();
    } catch (_) {
      // Permission plugin unavailable (e.g. desktop): ignore.
    }
  }

  /// Settings changed: refresh the notification immediately (turn it off,
  /// turn it back on, or rewrite it with the new name/teacher/room).
  void _onSettingsChanged() {
    unawaited(_ensureNotificationPermission());
    _lastActivitySignature = null;
    _updateLiveActivity();
    if (mounted) setState(() {});
  }

  void _updateLiveActivity() async {
    if (!_liveActivitiesReady) return;

    DateTime? currentEndTime = _getCurrentPeriodEndTime();
    String? currentPeriodName = _getCurrentPeriodName();

    // Notifications (or just the live activity) can be turned off in settings.
    final enabled = _settings.liveActivityActive;

    // If there is an active period running and notifications are allowed
    if (enabled && currentEndTime != null && currentPeriodName != null) {
      final displayName = _settings.displayName(currentPeriodName);
      final details = _settings.detailsFor(currentPeriodName);
      final signature =
          '$displayName|$details|${currentEndTime.millisecondsSinceEpoch}';

      // Create or update only if the displayed content changed
      if (_lastActivitySignature != signature) {
        _lastActivitySignature = signature;

        final data = {
          'periodName': displayName,
          'periodDetail': details,
          'endTime': currentEndTime.millisecondsSinceEpoch.toString(),
        };

        // Use positional arguments
        await _liveActivitiesPlugin.createOrUpdateActivity(_activityId, data);
        _isActivityActive = true;
      }
    } else {
      // No active period (or notifications disabled): end activity if it exists
      if (_isActivityActive) {
        await _liveActivitiesPlugin.endActivity(_activityId);
        _isActivityActive = false;
        _lastActivitySignature = null;
      }
    }
  }

  // Cancel the timer and Live Activity when the widget is disposed
  @override
  void dispose() {
    _timer?.cancel();
    _settings.removeListener(_onSettingsChanged);
    if (_isActivityActive) {
      _liveActivitiesPlugin.endActivity(_activityId);
    }
    super.dispose();
  }

  DateTime? _getCurrentPeriodEndTime([DateTime? customNow]) {
    final now = customNow ?? DateTime.now();
    final schedule = getCurrentSchedule(now);
    if (schedule != null) {
      for (var period in schedule) {
        final startTime = period['startTime'] as TimeOfDay;
        final endTime = period['endTime'] as TimeOfDay;

        if (isCurrentTimeInPeriod(startTime, endTime, now)) {
          return DateTime(
              now.year, now.month, now.day, endTime.hour, endTime.minute);
        }
      }
    }
    return null;
  }

  // Helper to extract the string name of the period
  String? _getCurrentPeriodName([DateTime? customNow]) {
    final now = customNow ?? DateTime.now();
    final schedule = getCurrentSchedule(now);
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
              // Scrolling schedule.
              Expanded(
                child: Padding(
                  padding: EdgeInsetsGeometry.directional(start: 10, end: 10),
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Selector bar for the day at the top
                        AdaptiveSegmentedControl(
                            labels: const ['Mon/Fri', 'Tue/Thu', 'Wed'],
                            selectedIndex: selectedDayScheduleIndex,
                            onValueChanged: (index) {
                              selectedDaySchedule = [
                                monFriSchedule,
                                tueThursSchedule,
                                wedSchedule
                              ][index];
                              selectedDayScheduleIndex = index;
                              if (mounted) {
                                setState(() {});
                              }
                            }),

                        // Countdown
                        Card(
                          color: Theme.of(context).cardColor,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                top: 16, left: 8, right: 8, bottom: 8),
                            child: Center(
                              // Check if a period is active
                              child: currentPeriodEndTime != null
                                  ? TimerCountdown(
                                      format: CountDownTimerFormat
                                          .hoursMinutesSeconds,
                                      // Set the endTime to the end of the current period
                                      endTime: currentPeriodEndTime,
                                      timeTextStyle: const TextStyle(fontSize: 20),
                                      onEnd: () {
                                        // When the timer ends, immediately refresh
                                        // so the next period countdown starts seamlessly.
                                        if (mounted) {
                                          setState(() {
                                            _updateLiveActivity();
                                          });
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

                        // Schedule
                        for (var period in selectedDaySchedule ?? [])
                          _buildPeriodCard(context, period),

                        const SizedBox(height: 8),
                      ],
                      ),
                    ),
                  ),
                ),
              ),

              // Settings button, locked to the bottom right of the home page.
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
        selectedDaySchedule == currentDaySchedule;

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
                  // Teacher and/or room number, when entered and enabled.
                  if (details.isNotEmpty)
                    Text(details, style: detailStyle),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                period['startTime'].format(context),
                style: highlightStyle,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                period['endTime'].format(context),
                style: highlightStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// check if current time is in the period
bool isCurrentTimeInPeriod(TimeOfDay startTime, TimeOfDay endTime, [DateTime? nowTime]) {
  final now = nowTime ?? DateTime.now();
  final startDateTime =
      DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
  final endDateTime =
      DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
  
  return (now.isAfter(startDateTime) || now.isAtSameMomentAs(startDateTime)) && now.isBefore(endDateTime);
}

List? getCurrentSchedule([DateTime? customNow]) {
  final day = (customNow ?? DateTime.now()).weekday;
  if (day == 1 || day == 5) {
    return monFriSchedule;
  } else if (day == 2 || day == 4) {
    return tueThursSchedule;
  } else if (day == 3) {
    return wedSchedule;
  } else {
    return null;
  }
}

// function to get current day of week for the segmented control
int getCurrentDayOfWeek([DateTime? customNow]) {
  final day = (customNow ?? DateTime.now()).weekday;
  // returns day=0
  if (day == 0 || day == 1 || day == 5 || day == 6) {
    return 0;
  } else if (day == 2 || day == 4) {
    return 1;
  } else {
    return 2;
  }
}
