import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:westview_app/publications.dart';

import 'calendars.dart';
import 'newsletter_page.dart';
import 'schedule_page.dart';
import 'settings.dart';
import 'special_schedule.dart';
import 'theme/theme.dart';
import 'vimeo_pip.dart';
import 'widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the user settings (custom class names, teacher/room, notification
  // preferences) before the first frame so nothing flashes the defaults.
  await AppSettings.instance.load();

  // Load any cached special (modified) schedules before the first frame.
  // This only reads local storage; the network refresh happens later on the
  // schedule page.
  await SpecialScheduleService.instance.init();

  // Any settings change must also reach the Android home screen widget.
  AppSettings.instance.onSaved = syncHomeWidget;

  // Push the schedule data (including today's special schedule, when cached)
  // to the Android home screen widget so it can show the current period even
  // before the schedule page is opened.
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
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const int _publicationsIndex = 2;
  int _selectedIndex = 0;

  // Keep all pages alive so the WebView and its video are never recreated when
  // switching tabs or when Android changes the activity to PiP dimensions.
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
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: vimeoPipActive,
      builder: (context, isPipActive, child) {
        return AdaptiveScaffold(
          // `tabBarHidden` hides the native iOS tab bar, while Android's
          // adaptive bottom bar must be removed from the scaffold explicitly.
          // The persistent IndexedStack below remains mounted either way.
          tabBarHidden: isPipActive,
          bottomNavigationBar: isPipActive
              ? null
              : _buildBottomNavigationBar(),
          body: ColoredBox(
            color: Colors.black,
            child: IndexedStack(
              // A Vimeo video may still be playing after the user switches to
              // another app tab. PiP must nevertheless show its persistent
              // Publications WebView, never the currently selected app page.
              index: isPipActive ? _publicationsIndex : _selectedIndex,
              children: _pages,
            ),
          ),
        );
      },
    );
  }
}
