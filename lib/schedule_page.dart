import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:live_activities/live_activities.dart';
import 'data.dart';
import 'package:permission_handler/permission_handler.dart';
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
  DateTime? _lastTrackedPeriodEndTime;
  bool _isActivityActive = false;

  /// End time of the period the home screen widget was last synced for.
  DateTime? _lastWidgetPeriodEnd;

  @override
  void initState() {
    super.initState();
    _initLiveActivities();
    
    // rebuild the widget every second to update
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
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
    await Permission.notification.request();
    await _liveActivitiesPlugin.init(appGroupId: 'group.com.your.app');
    await _liveActivitiesPlugin.endAllActivities(); 
  }

  void _updateLiveActivity() async {
    DateTime? currentEndTime = _getCurrentPeriodEndTime();
    String? currentPeriodName = _getCurrentPeriodName();

    // If there is an active period running
    if (currentEndTime != null && currentPeriodName != null) {
      // Create or update only if we moved to a NEW period
      if (_lastTrackedPeriodEndTime != currentEndTime) {
        _lastTrackedPeriodEndTime = currentEndTime;
        
        final data = {
          'periodName': currentPeriodName,
          'endTime': currentEndTime.millisecondsSinceEpoch.toString(), 
        };

        // 2. Use positional arguments! No "activityId:" or "data:"
        await _liveActivitiesPlugin.createOrUpdateActivity(_activityId, data);
        _isActivityActive = true;
      }
    } else {
      // No active period, end activity if exists
      if (_isActivityActive) {
        // 3. Use positional argument here as well
        await _liveActivitiesPlugin.endActivity(_activityId);
        _isActivityActive = false;
        _lastTrackedPeriodEndTime = null;
      }
    }
  }

  // Cancel the timer and Live Activity when the widget is disposed
  @override
  void dispose() {
    _timer?.cancel();
    if (_isActivityActive) {
      _liveActivitiesPlugin.endActivity(_activityId);
    }
    super.dispose();
  }

  DateTime? _getCurrentPeriodEndTime() {
    final now = DateTime.now();
    if (currentDaySchedule != null) {
      for (var period in currentDaySchedule ?? []) {
        final startTime = period['startTime'] as TimeOfDay;
        final endTime = period['endTime'] as TimeOfDay;

        if (isCurrentTimeInPeriod(startTime, endTime)) {
          return DateTime(
              now.year, now.month, now.day, endTime.hour, endTime.minute);
        }
      }
    }
    return null;
  }

  // Helper to extract the string name of the period
  String? _getCurrentPeriodName() {
    if (currentDaySchedule != null) {
      for (var period in currentDaySchedule ?? []) {
        final startTime = period['startTime'] as TimeOfDay;
        final endTime = period['endTime'] as TimeOfDay;

        if (isCurrentTimeInPeriod(startTime, endTime)) {
          return period['Period'] as String;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    DateTime? currentPeriodEndTime = _getCurrentPeriodEndTime();

    return SafeArea(
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
                      selectedDaySchedule=[monFriSchedule, tueThursSchedule, wedSchedule][index];
                      selectedDayScheduleIndex = index;
                      if (mounted) {
                        setState(() {});
                      }
                    }),

                // Countdown
                Card(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, left: 8, right: 8, bottom: 8),
                    child: Center(
                      // Check if a period is active
                      child: currentPeriodEndTime != null
                          ? TimerCountdown(
                              format: CountDownTimerFormat.hoursMinutesSeconds,
                              // Set the endTime to the end of the current period
                              endTime: currentPeriodEndTime,
                              timeTextStyle: TextStyle(fontSize: 20),
                              onEnd: () {
                                // When the timer ends, force update
                                if (mounted) {
                                  setState(() {});
                                }
                                currentPeriodEndTime = _getCurrentPeriodEndTime();
                              },
                            )
                          : Text(
                              "No active period",
                              style: TextStyle(
                                  fontSize: 20,
                                  color: Theme.of(context).colorScheme.outline),
                            ),
                    ),
                  ),
                ),

                // Schedule
                for (var period in selectedDaySchedule ?? [])
                  Card(
                      elevation: isCurrentTimeInPeriod(
                              period['startTime'], period['endTime']) && selectedDaySchedule==currentDaySchedule
                          ? 5
                          : 0,
                      color: isCurrentTimeInPeriod(
                              period['startTime'], period['endTime']) && selectedDaySchedule==currentDaySchedule
                          ? Theme.of(context).appBarTheme.backgroundColor
                          : Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5, 
                              child: Text(
                                period['Period'], 
                                style: isCurrentTimeInPeriod(period['startTime'], period['endTime']) && selectedDaySchedule==currentDaySchedule
                                  ? Theme.of(context).appBarTheme.titleTextStyle
                                  : null,
                              )
                            ),
                            Expanded(
                              flex: 2, 
                              child: Text(
                                period['startTime'].format(context), 
                                style: isCurrentTimeInPeriod(period['startTime'], period['endTime']) && selectedDaySchedule==currentDaySchedule
                                  ? Theme.of(context).appBarTheme.titleTextStyle
                                  : null,
                              )
                            ),
                            Expanded(
                              flex: 2, 
                              child: Text(
                                period['endTime'].format(context), 
                                style: isCurrentTimeInPeriod(period['startTime'], period['endTime']) && selectedDaySchedule==currentDaySchedule
                                  ? Theme.of(context).appBarTheme.titleTextStyle
                                  : null,
                              )
                            ),
                          ],
                        ),
                      ))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// check if current time is in the period
bool isCurrentTimeInPeriod(TimeOfDay startTime, TimeOfDay endTime) {
  final now = DateTime.now();
  final startDateTime =
      DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
  final endDateTime =
      DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
  
  return now.isAfter(startDateTime) && now.isBefore(endDateTime);
}

List? getCurrentSchedule(){
  final day = DateTime.now().weekday;
  if (day==1 || day==5) {
    return monFriSchedule;
  } else if (day==2 || day==4){
    return tueThursSchedule;
  } else if (day==3) {
    return wedSchedule;
  } else {
    return null;
  }
}

// function to get current day of week for the segmented control
int getCurrentDayOfWeek() {
  final day = DateTime.now().weekday;
  // returns day=0
  if (day==0 || day == 1 || day == 5 || day == 6) {
    return 0;
  } else if (day == 2 || day == 4) {
    return 1;
  } else {
    return 2;
  }
}