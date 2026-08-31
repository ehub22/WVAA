import 'dart:async';

import 'package:flutter/material.dart';

import 'calendars.dart';
import 'newsletter_page.dart';
import 'publications.dart';
import 'schedule_page.dart';
import 'settings.dart';
import 'special_schedule.dart';
import 'telemetry.dart';
import 'theme/theme.dart';
import 'vimeo_pip.dart';
import 'widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted settings before the first frame so nothing flashes with
  // the defaults.
  await AppSettings.instance.load();

  // Rehydrate the special-schedule cache from disk. The network refresh
  // happens lazily from the schedule page.
  await SpecialScheduleService.instance.init();

  // Every settings change must also reach the Android home-screen widget.
  AppSettings.instance.onSaved = syncHomeWidget;

  // Prime the widget with today's schedule so it's correct even before the
  // user opens the schedule page.
  await syncHomeWidget();

  // Crash reporting: framework widget errors, platform-dispatcher errors and
  // anything escaping the zone all funnel into the anonymous reporter below.
  // Rendering continues as normal afterwards.
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    Telemetry.instance
        .logError(details.exception, details.stack, context: 'flutter_error');
    previousFlutterOnError?.call(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stackTrace) {
    Telemetry.instance.logError(error, stackTrace, context: 'platform');
    return true;
  };

  // Sends anything queued from previous offline launches, then records the
  // anonymous app-open event.
  unawaited(Telemetry.instance.init());

  await runZonedGuarded(() async {
    runApp(const WestviewApp());
  }, (error, stackTrace) {
    Telemetry.instance.logError(error, stackTrace, context: 'zone');
  });
}

class WestviewApp extends StatelessWidget {
  const WestviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Westview HS',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  static const int _publicationsIndex = 2;
  int _selectedIndex = 0;

  static const List<String> _screenNames = [
    'schedule',
    'newsletters',
    'publications',
    'calendars',
  ];

  // Keep all pages alive (IndexedStack) so a playing Vimeo WebView is never
  // recreated when switching tabs or entering PiP.
  final List<Widget> _pages = const [
    SchedulePage(),
    NewsletterPage(),
    PublicationsPage(),
    CalendarsPage(),
  ];

  @override
  void initState() {
    super.initState();
    Telemetry.instance
        .logEvent('screen_view', {'screen': _screenNames[_selectedIndex]});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPrivacyNotice();
    });
  }

  void _onTabSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    Telemetry.instance
        .logEvent('screen_view', {'screen': _screenNames[index]});
  }

  /// One-time, plain-language disclosure of what the app reports (and what it
  /// never reports), with a one-tap opt-out. See Settings ▸ Privacy afterwards.
  Future<void> _maybeShowPrivacyNotice() async {
    if (!mounted || AppSettings.instance.privacyNoticeSeen) return;

    final optedOut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PrivacyNoticeDialog(),
    );

    if (optedOut == true) {
      await AppSettings.instance.setAnalyticsEnabled(false);
      await AppSettings.instance.setCrashReportingEnabled(false);
    }
    await AppSettings.instance.setPrivacyNoticeSeen();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: vimeoPipActive,
      builder: (context, isPipActive, _) {
        return Scaffold(
          body: ColoredBox(
            color: Colors.black,
            child: IndexedStack(
              // During PiP the app must always surface the Publications tab
              // (which owns the Vimeo WebView), no matter which tab the user
              // last selected.
              index: isPipActive ? _publicationsIndex : _selectedIndex,
              children: _pages,
            ),
          ),
          // NavigationBar destinations expose their labels to TalkBack, and
          // each destination keeps a 48dp+ touch target at any text scale.
          bottomNavigationBar: isPipActive
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onTabSelected,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Schedule',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.newspaper),
                      selectedIcon: Icon(Icons.newspaper),
                      label: 'Newsletters',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.play_circle_outline),
                      selectedIcon: Icon(Icons.play_circle),
                      label: 'Publications',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Calendars',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// First-run privacy disclosure.
class _PrivacyNoticeDialog extends StatelessWidget {
  const _PrivacyNoticeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy at a glance'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'To keep this app working, Westview HS collects two things — '
              'and nothing else:',
            ),
            SizedBox(height: 12),
            Text('• Anonymous usage counts (which screens are opened, '
                'whether a refresh succeeded).'),
            Text('• Crash reports (the error text and stack trace) when '
                'something breaks.'),
            SizedBox(height: 12),
            Text('It never collects your name, student ID, contacts, '
                'location, or any advertising identifier, and it shares '
                'nothing with third parties. Reports go only to the '
                'school\u2019s server.'),
            SizedBox(height: 12),
            Text('You can turn either off at any time in Settings ▸ '
                'Privacy.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Turn off both'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
