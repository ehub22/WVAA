import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:westview_app/publications.dart';

import 'calendars.dart';
import 'newsletter_page.dart';
import 'schedule_page.dart';
import 'theme/theme.dart';
import 'vimeo_pip.dart';

void main() {
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: vimeoPipActive,
      builder: (context, isPipActive, child) {
        return AdaptiveScaffold(
          // Keep the scaffold and IndexedStack mounted, but remove the app's
          // navigation chrome from the activity surface captured by Android.
          tabBarHidden: isPipActive,
          bottomNavigationBar: AdaptiveBottomNavigationBar(
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
          ),
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
