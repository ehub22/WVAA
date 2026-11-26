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
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final language = AppSettings.instance.language;
        return MaterialApp(
          title: 'Westview HS',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,
          // Pin the language when the student picked one, otherwise follow the
          // device. `localeResolutionCallback` keeps the app's own translations
          // authoritative instead of Flutter's default fallback.
          locale: language == AppLanguage.system ? null : Locale(language.code),
          // `fil` is included so Flutter's own delegates accept a device set
          // to Filipino; the app resolves it to the `tl` catalogue.
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
            Locale('zh'),
            Locale('tl'),
            Locale('fil'),
          ],
          localeResolutionCallback: (locale, supported) {
            if (language != AppLanguage.system) return Locale(language.code);
            final tag = AppLanguage.system.resolve(locale ?? const Locale('en'));
            return Locale(tag);
          },
          // Without these delegates Flutter's own widgets (the date picker in
          // Settings, "Back", the text-selection menu, semantic announcements)
          // would stay in English even when the app copy is translated.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            // Accessible text scaling: honour the OS setting all the way up to
            // the largest supported size, and never let a runaway scale factor
            // push a crisis phone number off screen. 2.0 keeps every safety
            // action reachable while still doubling the type size.
            final media = MediaQuery.of(context);
            final scaler = media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 2.0,
            );
            return MediaQuery(
              data: media.copyWith(textScaler: scaler),
              // Respect the OS "remove animations" switch (Android: Settings ▸
              // Accessibility ▸ Remove animations; iOS: Reduce Motion). Reduced
              // motion is a vestibular-disorder accommodation and is also what
              // some autistic and migraine-prone students turn on.
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
                        // Always-available help: a student in a bad moment
                        // should never have to guess which tab hides the
                        // counselling and crisis resources.
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

/// Permanent, compact district disclaimer pinned under the navigation bar on
/// every tab. The full wording (English + Spanish) lives on the Get-help
/// screen; this is the always-visible one-liner so the app never looks like an
/// official Poway Unified product at a glance.
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
        // The bar is tappable; keep a comfortable target even when the
        // translated text wraps to three lines at 200% text scale.
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
                    // No maxLines: the disclaimer must never be clipped, even
                    // at 200% text scale or in a longer translation.
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

/// First-run privacy disclosure. Deliberately written in plain language and
/// asked *before* anything is collected (opt-in, not opt-out).
class _PrivacyNoticeDialog extends StatelessWidget {
  const _PrivacyNoticeDialog();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings['privacy.title']),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings['privacy.intro']),
            const SizedBox(height: 12),
            Text(strings['privacy.bullet1']),
            Text(strings['privacy.bullet2']),
            const SizedBox(height: 12),
            Text(strings['privacy.never']),
            const SizedBox(height: 12),
            Text(strings['privacy.offUntil']),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings['privacy.dontShare']),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings['privacy.share']),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${strings['disclaimer.short']}\n\n${strings['disclaimer.crisis']}',
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Applies Flutter's [AnimatedX] widgets at a shorter duration when the OS asks
/// for reduced motion.
///
/// Flutter does not implement "remove animations" for its own [AnimatedX]
/// widgets, so every place that animates can read [reducedMotionFor] and get a
/// near-zero duration instead. The app itself only animates page/tab
/// transitions and the pull-to-refresh spinner, but third-party widgets
/// (WebViews, the countdown) should be wrapped too if they ever animate.
class _ReducedMotionScope extends InheritedWidget {
  const _ReducedMotionScope({required this.enabled, required super.child});

  final bool enabled;

  @override
  bool updateShouldNotify(_ReducedMotionScope oldWidget) =>
      oldWidget.enabled != enabled;
}

/// Duration to use for a decorative animation, honouring the OS setting.
Duration reducedMotionFor(BuildContext context, Duration normal) {
  final scope = context.dependOnInheritedWidgetOfExactType<_ReducedMotionScope>();
  return (scope?.enabled ?? false) ? Duration.zero : normal;
}
