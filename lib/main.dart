// import 'dart:developer';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:westview_app/publications.dart';
import 'schedule_page.dart';
import 'newsletter_page.dart';
import 'calendars.dart';
import 'theme/theme.dart';


void main() {
  runApp(const WestviewApp());
}

class WestviewApp extends StatelessWidget {
  const WestviewApp({super.key});

  // This widget is the root of the application.
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
  int _selectedIndex = 0;

  // Keep all pages alive so video (WebView) continues playing when switching tabs
  final List<Widget> _pages = const [
    SchedulePage(),
    NewsletterPage(),
    PublicationsPage(),
    CalendarsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: true,
        items: [
          AdaptiveNavigationDestination(
            icon: PlatformInfo.isIOS26OrHigher()
                ? "house.fill"
                : PlatformInfo.isIOS
                ? CupertinoIcons.home
                : Icons.home_outlined, 
            label: 'Home'
          ),
          AdaptiveNavigationDestination(
            icon: PlatformInfo.isIOS26OrHigher()
                ? "newspaper"
                : PlatformInfo.isIOS
                ? CupertinoIcons.news
                : Icons.newspaper,
            label: 'Newsletter'
          ),
          AdaptiveNavigationDestination(
            icon: PlatformInfo.isIOS26OrHigher()
                ? "text.justify.leading"
                : PlatformInfo.isIOS
                ? CupertinoIcons.text_justifyleft
                : Icons.cell_tower,
            label: 'Publications'
          ),
          AdaptiveNavigationDestination(
            icon: PlatformInfo.isIOS26OrHigher()
                ? "text.justify.leading"
                : PlatformInfo.isIOS
                ? CupertinoIcons.text_justifyleft
                : Icons.calendar_today,
            label: 'Calendars'
          ),
        ],
        selectedIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
    );
  }
}

