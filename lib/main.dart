import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'calendars.dart';
import 'l10n/strings.dart';
import 'newsletter_page.dart';
import 'publications.dart';
import 'safety.dart';
import 'schedule_page.dart';
import 'settings.dart';
import 'special_schedule.dart';
import 'support.dart';
import 'theme/theme.dart';
import 'video_pip.dart';
import 'widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved settings before drawing the first frame so the UI doesn't flash
  // default values on startup.
  await AppSettings.instance.load();

  // Load safety switches (quick exit and app-switcher hiding) before the first
  // frame so the recent-apps preview is never briefly exposed.
  await SafetySettings.instance.load();
  unawaited(QuickExit.applyRecentsPrivacy(SafetySettings.instance.hideRecents));

  // Load any cached special schedules from local storage; the actual network
  // check runs when the Schedule tab opens.
  await SpecialScheduleService.instance.init();

  // Push every settings update straight to the Android home-screen widget.
  AppSettings.instance.onSaved = syncHomeWidget;

  // Sync today's schedule right away so the widget stays accurate even if the
  // user opens another tab first.
  await syncHomeWidget();

  await runZonedGuarded(() async {
    runApp(const WestviewApp());
  }, (error, stackTrace) {
    // Nothing is reported anywhere: a crash just ends the frame and Flutter
    // keeps running, which keeps the app free of any reporting pipeline.
    debugPrint('Uncaught error: $error');
  });
}

class WestviewApp extends StatelessWidget {
  const WestviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final language = AppSettings.instance.language;
        return MaterialApp(
          title: 'Westview HS',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,
          // Lock the locale if the user picked a specific language; otherwise
          // resolve against the phone's system locale.
          locale: language == AppLanguage.system ? null : Locale(language.code),
          // Include `fil` so Flutter's Material delegates accept phones set to
          // Filipino while `AppLanguage.resolve` maps it to our `tl` strings.
          // French resolves by language code alone, so `fr-CA` works too.
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
            Locale('zh'),
            Locale('tl'),
            Locale('fil'),
            Locale('fr'),
          ],
          localeResolutionCallback: (locale, supported) {
            if (language != AppLanguage.system) return Locale(language.code);
            final tag = AppLanguage.system.resolve(locale ?? const Locale('en'));
            return Locale(tag);
          },
          // Keep Flutter's built-in Material/Cupertino delegates wired up so
          // system labels like "Back", selection menus, and screen-reader hints
          // translate alongside our own strings.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            // Respect the phone's font-size setting up to 200%, clamping at 2.0
            // so huge scale multipliers can't push emergency call buttons off
            // the screen.
            final media = MediaQuery.of(context);
            final scaler = media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 2.0,
            );
            return MediaQuery(
              data: media.copyWith(textScaler: scaler),
              // Pass the system "Remove animations" / "Reduce Motion" setting
              // down the widget tree so animations can switch to zero duration.
              child: _ReducedMotionScope(
                enabled: media.disableAnimations,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const _HomePage(),
        );
      },
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

  // Keep all pages alive (IndexedStack) so a WebView with a playing video is
  // never recreated when switching tabs or entering PiP.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSafetyNotice();
    });
  }

  void _onTabSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  /// Shows the disclaimer once on first launch so nobody mistakes this for an
  /// official district app. The same text stays available under Settings >
  /// About this app afterward.
  Future<void> _maybeShowSafetyNotice() async {
    if (!mounted || AppSettings.instance.safetyNoticeSeen) return;

    await showDialog<void>(
      context: context,
      builder: (context) => const _SafetyNoticeDialog(),
    );

    await AppSettings.instance.setSafetyNoticeSeen();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: videoPipActive,
      builder: (context, isPipActive, _) {
        return Scaffold(
          body: ColoredBox(
            color: Colors.black,
            child: IndexedStack(
              // During PiP the app must always surface the Publications tab
              // (which owns the video WebView), no matter which tab the user
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
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          selectedIcon: const Icon(Icons.home),
                          label: AppStrings.of(context)['nav.schedule'],
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.newspaper_outlined),
                          selectedIcon: const Icon(Icons.newspaper),
                          label: AppStrings.of(context)['nav.newsletters'],
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.play_circle_outline),
                          selectedIcon: const Icon(Icons.play_circle),
                          label: AppStrings.of(context)['nav.publications'],
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.calendar_month_outlined),
                          selectedIcon: const Icon(Icons.calendar_month),
                          label: AppStrings.of(context)['nav.calendars'],
                        ),
                        // Keep Get help permanently in the tab bar so counseling
                        // and crisis contacts are always one tap away.
                        NavigationDestination(
                          icon: const Icon(Icons.support_agent),
                          selectedIcon: const Icon(Icons.support_agent),
                          label: AppStrings.of(context)['nav.getHelp'],
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

/// Short non-affiliation bar pinned under the bottom navigation bar on every
/// tab. Tapping it opens the full English and Spanish Poway Unified disclaimer
/// on the Get help screen.
class _DistrictDisclaimerBar extends StatelessWidget {
  const _DistrictDisclaimerBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = AppStrings.of(context)['disclaimer.short'];
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => openSupportPage(context),
        // Keep a comfortable tap height even when the text wraps across
        // multiple lines at 200% font scale.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    // Leave maxLines unset so the disclaimer never clips at
                    // large font sizes or in longer translations.
                    textAlign: TextAlign.center,
                    semanticsLabel: text,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First-launch disclaimer. The app has nothing to ask consent for, so this
/// only makes the unofficial status and the crisis-service limits clear.
class _SafetyNoticeDialog extends StatelessWidget {
  const _SafetyNoticeDialog();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings['disclaimer.title']),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings['disclaimer.plain']),
            const SizedBox(height: 12),
            Text(strings['disclaimer.crisis']),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings['common.close']),
        ),
      ],
    );
  }
}

/// Exposes the system reduced-motion setting down the widget tree so explicit
/// animation durations can drop to zero when animations are turned off.
class _ReducedMotionScope extends InheritedWidget {
  const _ReducedMotionScope({required this.enabled, required super.child});

  final bool enabled;

  @override
  bool updateShouldNotify(_ReducedMotionScope oldWidget) =>
      oldWidget.enabled != enabled;
}

/// Returns `Duration.zero` when reduced motion is enabled, or [normal] otherwise.
Duration reducedMotionFor(BuildContext context, Duration normal) {
  final scope = context.dependOnInheritedWidgetOfExactType<_ReducedMotionScope>();
  return (scope?.enabled ?? false) ? Duration.zero : normal;
}
