# Westview HS — Android Companion App

A Flutter app built for students at Westview High School (Poway Unified School District). It brings together everything a student needs during the school day: live period countdowns, daily newsletters, school athletics calendars, lunch menus, and school publications — all in one place.

## Features

| Feature | Description |
|---------|-------------|
| **Live Schedule** | Real-time countdown to the end of the current period, with the full day's schedule at a glance. Switch between Mon/Fri, Tue/Thu, and Wed views. |
| **Special Schedules** | Automatically detects early release days, assemblies, and other modified schedules fetched from the school's server. A banner notifies you when one is in effect. |
| **Personalization** | Rename your periods (e.g. "Human Body Systems"), add teacher names and room numbers. These appear in the schedule, the notification, and the home screen widget. |
| **Countdown Notification** | An ongoing Android notification with a live countdown timer, visible on the lock screen. Updates automatically at each period boundary. |
| **Home Screen Widget** | Android widget showing the current period and a ticking countdown. Works even when the app hasn't been opened recently. |
| **Newsletters** | Weekly newsletter, counseling newsletters, and DEN announcements — all embedded as WebViews. |
| **Publications** | Westview Nexus (student news) and the Westview Newscast with Vimeo PiP support. |
| **Calendars** | School calendar, athletics schedule, and daily lunch menu with nutritional info, all pulled from live data sources. |

## Architecture

```
lib/
├── main.dart              # App entry point, navigation shell
├── schedule_page.dart     # Live schedule with countdown timer
├── newsletter_page.dart   # Weekly/counseling/DEN newsletters
├── publications.dart      # Nexus + Newscast with Vimeo PiP
├── calendars.dart         # School calendar, athletics, lunch
├── school_lunch.dart      # Healthepro lunch menu integration
├── settings_page.dart     # Notification/period customization UI
├── settings.dart          # Persisted user preferences (ChangeNotifier)
├── special_schedule.dart  # StudyCS special schedule fetch + cache
├── widget_sync.dart       # Flutter → Android home screen widget bridge
├── vimeo_pip.dart         # Vimeo PiP JavaScript bridge
├── data.dart              # Schedule definitions (periods, times)
└── theme/                 # Material 3 color scheme + themes

android/app/src/main/kotlin/com/westviewhs/app/
├── MainActivity.kt                    # FlutterActivity + PiP callback
├── ScheduleWidgetProvider.kt          # Home screen widget provider
├── ScheduleWidgetRenderer.kt          # Widget rendering + alarm scheduling
├── ScheduleWidgetAlarmReceiver.kt     # Period-transition alarm handler
├── ScheduleNotificationManager.kt     # Ongoing countdown notification
└── CustomLiveActivityManager.kt       # Live activity notification builder
```

## Special (Modified) Schedules

On days with early release, Link Crew, assemblies, etc., the app fetches the modified schedule from the school's StudyCS server:

```
GET https://studycs.org/westview/special_schedule2/{month}/{day}
```

- Response contains a `.json` path → fetches and parses the JSON schedule
- Empty response or no `.json` → no special schedule that day

### Caching

Answers are cached on-device for 3 days. The server is never asked more than once per date within that window. If the server is unreachable, the last known answer (even stale) is used and a banner warns the user.

### Backup Sources

If the primary server is down, the app tries each URL in `fallbackUrls` in `lib/special_schedule.dart`. URLs support `{month}` and `{day}` placeholders.

## Home Screen Widget (Android)

The "Current Period" widget shows:
- The active period name (with custom names from settings)
- Teacher and room number when configured
- A live `Chronometer` countdown ticking every second
- Before school: counts down to first period
- After school / weekends: "School's out" / "No school today"

The Flutter app syncs schedule data into SharedPreferences via `home_widget`. Native code (`ScheduleWidgetRenderer`, `ScheduleWidgetAlarmReceiver`) handles rendering and `AlarmManager` transitions independently, so the widget stays correct even when the app is closed.

## Settings

Accessible from a button in the bottom-right corner of the home page:

- **Notifications** — master switch for all notifications
- **Live activity** — ongoing countdown notification (requires notifications enabled)
- **Show teacher / Show room number** — toggle visibility in schedule, notification, and widget
- **My classes** — rename periods, add teacher and room number

All settings persist locally via SharedPreferences and apply immediately.

## Building

### Prerequisites
- Flutter SDK (stable channel)
- Java 17 (Temurin recommended)
- Android SDK with platforms 35+ and build-tools 35+

### Local Build

```bash
flutter pub get
flutter build apk --release
```

The APK is output to `build/app/outputs/flutter-apk/app-release.apk`.

### CI/CD (GitHub Actions)

The `.github/workflows/build-apk.yml` workflow:

- **Push to `main`** → builds APK, uploads as artifact (30-day retention)
- **PR to `main`** → validates the build
- **Tag `vX.Y.Z`** → creates a GitHub Release with the APK attached
- **Manual trigger** → via workflow_dispatch in the Actions tab

Each CI build sets `versionCode` to the GitHub run number for monotonically increasing version codes.

### Signing for Google Play

The CI build signs with Flutter's debug keystore (fine for sideloading). For Play Store distribution, configure a release keystore — see the [Flutter Android signing guide](https://docs.flutter.dev/deployment/android#signing-the-app).

## Package Structure

| Identifier | Value |
|-----------|-------|
| Flutter package name | `westview_app` |
| Android application ID | `com.westviewhs.app` |
| Kotlin package | `com.westviewhs.app` |
| Widget provider | `com.westviewhs.app.ScheduleWidgetProvider` |

## License

Private project for Westview High School. Not published to pub.dev.
