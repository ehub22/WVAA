import 'dart:async';

import 'package:flutter/material.dart';

import 'calendars.dart';
import 'newsletter_page.dart';
import 'publications.dart';
import 'safety.dart';
import 'schedule_page.dart';
import 'settings.dart';
import 'special_schedule.dart';
import 'support.dart';
import 'telemetry.dart';
import 'theme/theme.dart';
import 'vimeo_pip.dart';
import 'widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted settings before the first frame so nothing flashes with
  // the defaults.
  await AppSettings.instance.load();

  // Safety toggles (quick exit, recents privacy). Loaded before the first
  // frame so the recents thumbnail is never briefly un-hidden.
  await SafetySettings.instance.load();
  unawaited(QuickExit.applyRecentsPrivacy(SafetySettings.instance.hideRecents));

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
  // anonymous app-open event. Both are no-ops until the student opts in (see
  // settings.dart / telemetry.dart).
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
  static const int _helpIndex = 4;
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
    SupportPage(),
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
    // The Get-help tab is deliberately excluded from analytics: the app never
    // records that a student looked at crisis or counseling resources.
    if (index != _helpIndex) {
      Telemetry.instance
          .logEvent('screen_view', {'screen': _screenNames[index]});
    }
  }

  /// One-time, plain-language disclosure of what the app *may* report (and
  /// what it never reports), with an explicit choice. Nothing is sent before
  /// this dialog is answered, and either stream can be turned off later in
  /// Settings ▸ Privacy.
  Future<void> _maybeShowPrivacyNotice() async {
    if (!mounted || AppSettings.instance.privacyNoticeSeen) return;

    final share = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PrivacyNoticeDialog(),
    );

    // Either way, both streams are set explicitly so the stored state always
    // reflects a real decision rather than a default.
    final agreed = share ?? false;
    await AppSettings.instance.setAnalyticsEnabled(agreed);
    await AppSettings.instance.setCrashReportingEnabled(agreed);
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
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NavigationBar(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _onTabSelected,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
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
                          label: 'Calendar',
                        ),
                        // Always-available help: a student in a bad moment
                        // should never have to guess which tab hides the
                        // counselling and crisis resources.
                        NavigationDestination(
                          icon: Icon(Icons.support_agent),
                          selectedIcon: Icon(Icons.support_agent),
                          label: 'Get help',
                        ),
                      ],
                    ),
                    const _DistrictDisclaimerBar(),
                  ],
                ),
        );
      },
    );
  }
}

/// Permanent, compact district disclaimer pinned under the navigation bar on
/// every tab. The full wording (English + Spanish) lives on the Get-help
/// screen; this is the always-visible one-liner so the app never looks like an
/// official Poway Unified product at a glance.
class _DistrictDisclaimerBar extends StatelessWidget {
  const _DistrictDisclaimerBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => openSupportPage(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  shortDisclaimer,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-run privacy disclosure. Deliberately written in plain language and
/// asked *before* anything is collected (opt-in, not opt-out).
class _PrivacyNoticeDialog extends StatelessWidget {
  const _PrivacyNoticeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your privacy'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This app can send two things to the school’s own server, and '
              'nothing else:',
            ),
            SizedBox(height: 12),
            Text('• Anonymous usage counts — which screens are opened and '
                'whether a refresh worked. No names, no accounts.'),
            Text('• Crash reports — the error text, with anything you typed '
                'into Settings removed, so bugs can be fixed.'),
            SizedBox(height: 12),
            Text(
              'It never collects your name, student ID, contacts, location, '
              'or advertising identifiers, and it shares nothing with third '
              'parties. There is no third-party analytics.',
            ),
            SizedBox(height: 12),
            Text('Both are off unless you turn them on, and you can change '
                'this any time in Settings ▸ Privacy.'),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Don’t share'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Share anonymously'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Westview HS (WVAA) is a student-built app. It is not a Poway '
            'Unified app and is not endorsed by the District. The Get help '
            'tab has counselors and 24/7 crisis lines — opening it is never '
            'recorded.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
