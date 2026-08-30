import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'calendars.dart';
import 'newsletter_page.dart';
import 'publications.dart';
import 'schedule_page.dart';
import 'settings.dart';
import 'special_schedule.dart';
import 'theme/theme.dart';
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

  runApp(const WestviewApp());
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

  // Keep all pages alive (IndexedStack) so a playing Vimeo WebView is never
  // recreated when switching tabs or entering PiP.
  final List<Widget> _pages = const [
    SchedulePage(),
    NewsletterPage(),
    PublicationsPage(),
    CalendarsPage(),
  ];

  AdaptiveBottomNavigationBar _buildBottomNavigationBar() {
    return AdaptiveBottomNavigationBar(
      useNativeBottomBar: true,
      items: [
        AdaptiveNavigationDestination(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'house.fill'
              : PlatformInfo.isIOS
                  ? CupertinoIcons.home
                  : Icons.home_outlined,
          label: 'Home',
        ),
        AdaptiveNavigationDestination(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'newspaper'
              : PlatformInfo.isIOS
                  ? CupertinoIcons.news
                  : Icons.newspaper,
          label: 'Newsletter',
        ),
        AdaptiveNavigationDestination(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'text.justify.leading'
              : PlatformInfo.isIOS
                  ? CupertinoIcons.text_justifyleft
                  : Icons.cell_tower,
          label: 'Publications',
        ),
        AdaptiveNavigationDestination(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'text.justify.leading'
              : PlatformInfo.isIOS
                  ? CupertinoIcons.text_justifyleft
                  : Icons.calendar_today,
          label: 'Calendars',
        ),
      ],
      selectedIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: vimeoPipActive,
      builder: (context, isPipActive, _) {
        return AdaptiveScaffold(
          tabBarHidden: isPipActive,
          bottomNavigationBar: isPipActive ? null : _buildBottomNavigationBar(),
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
        );
      },
    );
  }
}
