# Westview HS (WVAA)

A companion app for Westview High School (Poway Unified School District), built with Flutter. The app brings together the schedules, calendars, newsletters, student publications, and lunch menu that students use every day, plus a live countdown notification and a home-screen widget that shows the current class period.

> The app is optimized for Android (the primary target). iOS support compiles but is not actively maintained.

## Features

- **Schedules** — Mon/Fri, Tue/Thu, and Wednesday late-start schedules with a live per-second countdown to the end of the current period. Any period can be renamed (e.g. "Human Body Systems" instead of "Period 1") with teacher and room number.
- **Special (modified) schedules** — Early-release, assembly, and Link-Crew days are fetched from the school server and override the regular schedule in-app, on the widget, and in the ongoing notification. Results are cached for at least two days so the app still works when the server is unreachable.
- **Live countdown notification** — An ongoing Android notification shows the current period, teacher/room, and a ticking Chronometer. It renders on the lock screen and survives reboots via AlarmManager.
- **Home-screen widget** — "Current Period" widget shows the active class, a live countdown, and a one-liner about what's next. It self-updates at period boundaries with precise alarms and uses a Chronometer so it ticks without waking the device.
- **Calendars** — School and Athletics Google Calendars, plus the daily school lunch menu with nutrition-fact details.
- **Newsletters** — Weekly newsletter, counseling newsletters, and DEN announcements, each in an embedded WebView.
- **Publications** — Westview Nexus (student newspaper) and Westview Newscast (Vimeo). Vimeo videos automatically enter Android picture-in-picture when you leave the app mid-playback.
- **Theming** — Material 3 light and dark themes that follow the system setting, built from the school's gold/brass palette with WCAG-AA-checked contrast pairs.
- **Works on bad Wi-Fi** — Calendars, lunch menus and special schedules cache their last-known content on disk and keep showing it (with a "saved copy" notice) whenever the school network is down. Newsletter/publication WebViews keep their loaded pages and never blank out mid-session.
- **Refresh everywhere** — Pull-to-refresh on calendars and lunch menus; a refresh button on newsletters and publications; retry buttons on every error screen.
- **Accessibility** — Screen-reader labels on tabs, icons and interactive rows; 48dp minimum tap targets; full support for system font scaling (no clipped text).
- **Privacy-first telemetry** — Anonymous crash reports and usage counts, disclosed up front, with per-stream opt-out. See [Privacy](#privacy) below.

## Material 3, Android-first

Android is the only actively supported target, so the UI is plain Material 3 throughout — `NavigationBar`, `SegmentedButton`, Material switches, bottom sheets — instead of cross-platform adaptive widgets. The one deliberate exception is the Publications WebView, which keeps a small platform branch for iOS inline-video playback so the project keeps compiling there.

## Privacy

The app collects two things, both anonymous, and nothing else:

- **Anonymous usage statistics** — counts of which screens are opened and whether refreshes succeeded.
- **Crash reports** — the error text and a truncated stack trace, when something breaks.

It never collects names, student IDs, accounts, contacts, location, or advertising/device identifiers, and it uses no third-party analytics or crash SDKs. Reports go only to the school's own server (`studycs.org`, the same host as the special-schedule data). A first-run dialog discloses all of this, both streams can be turned off at any time in **Settings ▸ Privacy & data**, and disabling a stream drops its queued reports instead of sending them. Cached content (calendars, menus, nutrition data) stays on the device and can be wiped from **Settings ▸ Saved content**.

## Project layout

```
lib/
  main.dart              App entry point, Material 3 navigation shell, crash
                         reporting bootstrap, first-run privacy dialog
  data.dart              Bell schedules (Mon/Fri, Tue/Thu, Wed)
  schedule_page.dart     Home/Schedule tab, live countdown, settings FAB
  special_schedule.dart  Special-schedule fetch + multi-day cache
  settings.dart          Persisted user settings incl. telemetry consent
  settings_page.dart     Settings UI (notifications, privacy, classes)
  telemetry.dart         Anonymous crash reporting + analytics (opt-out)
  network_cache.dart     Last-known-good disk cache for network content
  widget_sync.dart       Pushes schedules/settings to the Android widget
  calendars.dart         Calendar tabs (School, Athletics, Lunches)
  school_lunch.dart      Lunch menu + nutrition facts (cache-first)
  newsletter_page.dart   Newsletter tabs
  publications.dart      Publications tabs + Vimeo PiP handling
  vimeo_pip.dart         Vimeo player <-> PiP bridge (injected JS)
  web_page.dart          Shared WebView wrapper (loading/error/retry states)
  theme/                 App color tokens + light/dark Material 3 ThemeData
  widgets/
    section_selector.dart  Material 3 pill tabs + lazy keep-alive stack
    status_views.dart      Shared loading / empty / error / saved-copy states

android/app/src/main/kotlin/com/westviewhs/app/
  MainActivity.kt                    Flutter activity, PiP callbacks, channel init
  CustomLiveActivityManager.kt       Custom notification UI for the live activity
  ScheduleNotificationManager.kt     Ongoing countdown notification + channel
  ScheduleWidgetProvider.kt          Home-screen widget provider
  ScheduleWidgetRenderer.kt          Widget rendering + AlarmManager scheduling
  ScheduleWidgetAlarmReceiver.kt     Broadcast receiver for period ticks
```

## Special (modified) schedules

On days with a special schedule (early release, Link Crew, assemblies, …) the app replaces the regular weekday schedule with the one returned by the school's server and shows a dismissable "A special schedule is in effect today" banner.

```
GET https://studycs.org/westview/special_schedule2/{month}/{day}
```

- `HTTP 200` with a plain-text body containing `.json` → the app downloads `https://studycs.org/<path>` and parses it as a JSON list of `{hour, minute, duration, title, isPM}` entries.
- `HTTP 200` with an empty body (or any body without `.json`) → no special schedule that day; the regular schedule is shown.

### Caching

Every answer (schedule or "none") is cached on device for **at least 2 days** (3 to leave headroom). The server is never asked more than once per date inside that window, so the app doesn't contribute to load spikes. If the server cannot be reached the last known answer — even a stale one — is still used, and a banner warns that "today's schedule may not be accurate". The cache survives app restarts via SharedPreferences.

### Backup sources

If the primary server is down, the app tries each URL in `fallbackUrls` (empty by default). A backup URL can point at a static host (e.g. a public Google Drive direct-download link) and may use `{month}`/`{day}` placeholders.

```dart
fallbackUrls.add(
  'https://drive.google.com/uc?export=download&id=YOUR_PUBLIC_FILE_ID',
);
```

## Home-screen widget (Android)

Add the widget by long-pressing the home screen → Widgets → Westview HS → drag "Current Period" onto the home screen.

- The widget shows the current period and a Chronometer that counts down every second in the launcher process, so no wakeups are needed just to tick the timer.
- Precise `AlarmManager` wakeups are scheduled for each period transition, plus boot/time/timezone/date change broadcasts, so the widget stays correct even when the app hasn't been opened in a while.
- The Flutter app pushes schedules (including any special schedule and custom class/teacher/room names) via the `home_widget` plugin. Until the app runs once, built-in defaults (matching `lib/data.dart`) are used.

## Settings

A settings button in the bottom-right of the home screen opens:

- **Notifications** — master switch; when off the app posts no notifications at all.
- **Live activity** — ongoing countdown notification (only runs while notifications are enabled).
- **Show teacher / Show room number** — whether teacher/room show up in the schedule list, notification, and widget.
- **My classes** — rename any period and enter teacher / room number.

All settings are persisted immediately and applied across the schedule, notification, and widget.

## Lock-screen notifications

The live countdown notification is posted as an ongoing status notification on a channel with `VISIBILITY_PUBLIC` and `IMPORTANCE_DEFAULT` (silent, but visible on secure lock screens). Tapping it opens the app. On Android 13+ the app will ask for `POST_NOTIFICATIONS` on first launch (only when live activities are enabled, which is the default).

## Building

### Local (release APK, sideload)

```sh
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (signed with the debug keystore — fine for sideloading).

### Google Play

Configure a real signing keystore per the [Flutter signing guide](https://docs.flutter.dev/deployment/android#signing-the-app), then generate `android/key.properties` and point `release.signingConfig` at it.

### GitHub Actions

`.github/workflows/build-apk.yml` builds a release APK on every push to `main` and every pull request targeting `main`, and uploads it as a downloadable workflow artifact (kept for 30 days). Pushing a tag `vX.Y.Z` additionally creates a GitHub Release with the APK attached. The workflow also accepts `workflow_dispatch` for manual runs. `versionCode` is set to the GitHub Actions run number so builds are monotonically increasing.

## Architecture notes

- **State** — `AppSettings` and `SpecialScheduleService` are singletons extending `ChangeNotifier`; pages consume them via `ListenableBuilder` and add/remove listeners in `initState`/`dispose`.
- **Timer** — a single 1-second `Timer.periodic` in `SchedulePage` drives the countdown, widget sync, and midnight-rollover detection; all other state updates are event-driven.
- **Network** — HTTP calls go through a `http.Client` injected into `SpecialScheduleService` (for testability) with a 10-second timeout; failures never crash the UI.
- **PiP** — Vimeo playback is detected via a JS bridge injected into the WebView (`vimeo_pip.dart`) that talks to Vimeo's postMessage player API. When the app backgrounds mid-playback the Flutter shell hides its chrome so the player can fill the activity surface before Android captures it for picture-in-picture.
- **Package name** — Android application ID / namespace is `com.westviewhs.app`.

## Tests

```sh
flutter test
```

Tests cover schedule time math, settings persistence, the special-schedule parser and caching behavior (using `MockClient`), and Vimeo URL detection.

