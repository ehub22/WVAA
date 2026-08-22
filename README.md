Westview Android App


Functions implemented so far:
  Calendars (Athletics, school calendar, and school lunch)
  Schedules by day, including special (modified) schedules fetched from the school's server
  Newsletters (Weekly newsletter, counseling newsletters, and den announcements)
  School publications (Nexus and Newscast)
  Home screen widget (current period + time left, Android only)


## Special (modified) schedules

On days with a special schedule (early release, Link Crew, assemblies, …) the
app replaces the regular weekday schedule with the special one, in the app and
on the home screen widget, and shows a dismissable banner saying a special
schedule is in effect.

The schedule comes from the school's server:

```
GET https://studycs.org/westview/special_schedule2/{month}/{day}
```

- `HTTP 200` with a plain-text path containing `.json` → the app downloads
  `https://studycs.org/{path}` and parses it (a JSON list of
  `{hour, minute, duration, title, isPM}` entries).
- `HTTP 200` with an empty body (or any response without `.json`) → no special
  schedule that day, and the regular schedule is shown.

### Caching

Every answer (schedule or "none") is cached on the device for **at least 2
days** (3 days, to be safe), so the server is never asked more than once per
date within that window. If the server cannot be reached, the last known
answer — even a stale one — is still used, and a dismissable banner warns
that "today's schedule may not be accurate". The cache also survives app
restarts.

### Backup sources

If the primary server is down, the app tries each URL in the
`fallbackUrls` list in `lib/special_schedule.dart` (empty by default). To add
a backup, put the same JSON in a public Google Drive file (or any static
host) and add its direct-download URL there, e.g.:

```dart
fallbackUrls.add('https://drive.google.com/uc?export=download&id=YOUR_PUBLIC_FILE_ID');
```

URLs may use `{month}` and `{day}` placeholders for per-date hosts.


## Home Screen Widget (Android)

The app ships a "Current Period" home screen widget (Android only):

- Shows the current period (e.g. "Period 2") and a live countdown of how much
  time is left, ticking every second via a native `Chronometer`.
- Before school it counts down to the first period; after school and on
  weekends it shows "School's out" / "No school today".
- The Flutter app syncs the schedules (see `lib/widget_sync.dart`) into
  SharedPreferences via the [`home_widget`](https://pub.dev/packages/home_widget)
  plugin, and re-syncs whenever the current period changes while the app runs.
- Native code (`ScheduleWidgetProvider.kt`, `ScheduleWidgetRenderer.kt`,
  `ScheduleWidgetAlarmReceiver.kt`) renders the widget and schedules precise
  `AlarmManager` wakeups for each period transition, plus re-renders on boot
  and on time/date/time-zone changes — so the widget stays correct even when
  the app hasn't been opened in a while.

To add the widget: long-press the home screen → Widgets → Westview HS →
drag "Current Period" onto the home screen.



Used flutter in case we want to make this multiplatform later, but right now, I believe only android works.

## Settings (Android)

A settings button sits in the bottom right corner of the home page. It opens a
settings page with:

- **Notifications** – master switch for every notification the app posts.
- **Live activity** – the ongoing notification with the countdown timer to the
  end of the current period. It only runs while notifications are on.
- **Show teacher / Show room number** – whether the teacher and room number
  are displayed.
- **My classes** – rename any period (e.g. "Human Body Systems" instead of
  "Period 1") and enter the teacher and room number for it.

Custom names, teachers and room numbers appear in the schedule list, in the
live activity notification with the countdown timer, and on the home screen
widget. Settings are saved on the device and applied immediately.

## Building the APK with GitHub Actions

This repo includes a GitHub Actions workflow (`.github/workflows/build-apk.yml`) that
builds a release Android APK automatically:

- On every push to `main` and on every pull request to `main`, the workflow builds
  the APK and uploads it as a downloadable **build artifact** (kept for 30 days).
- When you push a tag named `vX.Y.Z` (e.g. `v1.0.0`), the workflow creates a GitHub
  **Release** and attaches the APK.
- You can also trigger a build manually from **Actions → Build Android APK → Run workflow**.

### Downloading the APK
1. Open the **Actions** tab and pick a successful run.
2. Scroll to **Artifacts** and download `app-release-<run-number>`.
3. Install it on an Android device (you may need to allow "Install from unknown sources").

### Versioning
Each CI build sets `versionCode` to the GitHub run number so every APK is
monotonically increasing, which is required before publishing anywhere.

### Signing for Google Play (optional)
The CI build signs the APK with Flutter's auto-generated debug key. That is fine for
direct distribution/sideloading, but not for the Play Store. To sign releases with your
own keystore, follow the official Flutter guide
(https://docs.flutter.dev/deployment/android#signing-the-app), then in CI store the
keystore as a base64 secret and generate `android/key.properties` from it.
