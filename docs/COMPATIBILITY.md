# Compatibility and Maintenance Review

This review evaluates Westview HS (WVAA) across three perspectives: **students using the app**, **developers maintaining the repository**, and **school administrators reviewing an unofficial project**. Entries are ordered from highest-impact risks to routine maintenance items. Each entry explains what can go wrong, how the current codebase handles it, and what follow-up remains.

Status labels: **[done]** implemented in the repository · **[todo]** recommended follow-up · **[decide]** requires a policy or maintenance decision.

---

## A. Safety-Critical Maintenance Risks

### A1. Counselor or Hotline Details Becoming Outdated [todo] [decide]

Counselor names, last-name caseload ranges, phone extensions, and crisis-line numbers are compiled directly into `lib/support.dart`. Compiling those contacts guarantees that Get help works without internet access, though it also means that a summer staffing change at Westview makes the bundled list outdated until a new APK is released.

- **Effect on students:** A student might dial an extension that was reassigned or email the wrong counselor for their last name.
- **Current and recommended mitigation:** Keep the on-screen verification date ("checked November 2025") and the link to `westview.powayusd.com/apps/pages/counseling-staff`, and set a start-of-semester reminder each August and January to re-check counselor caseloads as well as 988, `741741`, and `678678`.
- **Optional design choice:** Host a small, optional JSON file on `studycs.org` that updates phone numbers and extensions while keeping the compiled list in `lib/support.dart` as the offline fallback whenever a fetch fails.

### A2. Annual Bell-Schedule Updates [done] (requires yearly check)

Regular weekday bell schedules (`monFriSchedule`, `tueThursSchedule`, and `wedSchedule`) live in `lib/data.dart` and `ScheduleWidgetRenderer.kt`, while single-day modified schedules are fetched from `studycs.org`. Because high schools occasionally adjust passing periods or start times between school years, hardcoded base times can drift over the summer.

- **Recommended mitigation:** Re-verify `lib/data.dart` and the default fallback lists in `ScheduleWidgetRenderer.kt` against Westview's published bell schedule every August before school starts. Assemblies and minimum days are already handled dynamically by the special-schedule endpoint.

### A3. No API Keys in Client Code [done]

`lib/calendars.dart` reads the school calendar from its public Google Calendar `.ics` address and the Athletics calendar from the district's own athletics feed (`westview.powayusd.com/apps/events/ical?id=1`). Neither needs an API key, so none ships in the APK. Without a key there is no quota for anyone to exhaust and nothing to rotate, which removes the failure mode where a leaked key could lock every student out of the calendar at once. The lunch menu was always keyless: `lib/school_lunch.dart` calls a public menus API.

- **Trade-off:** The Google feed returns every year of history, so the parser filters to yesterday onward and caps the list at 100 rows before rendering. The two feeds also disagree on format: Google publishes UTC timestamps and plain dates, while the district publishes local wall-clock times with a zone name, `DURATION` instead of `DTEND`, and repeated days as `RDATE`. The parser handles both. A feed that stops being public also stops working, since there is no authenticated fallback.
- **Why Athletics moved:** The old Athletics Google calendar stopped being updated after the 2026 spring season, which left the tab empty while the school's own athletics page was showing November and December games. The district feed is the one the athletics office keeps current.
- **Follow-up:** If a calendar is ever made private again, host a nightly export somewhere the app can reach rather than reintroducing a key into the APK.

---

## B. Student Device Compatibility

### B1. Older Android Versions [done]

`android/app/build.gradle.kts` sets `minSdk = maxOf(flutter.minSdkVersion, 24)` (Android 7.0), which supports virtually every Android phone currently carried on campus. Newer platform features degrade cleanly on older releases: notification channels are gated on API 26+, Android 13 notification permissions only prompt on API 33+, and `AlarmManager` falls back to inexact idle alarms if `SCHEDULE_EXACT_ALARM` is unavailable on Android 12+.

### B2. Devices Without Google Play Services [done]

The app does not depend on Firebase, Google Play Services libraries, or third-party analytics SDKs. As a result, sideloaded APKs install and run normally on stock Android as well as de-Googled distributions such as GrapheneOS and LineageOS.

### B3. Screen Sizes and Enlarged System Fonts [done] (needs tablet test)

`MediaQuery.textScaler` scales up to `200%` (`2.0`), important text wraps without `maxLines` truncation, and `test/l10n_test.dart` verifies `SupportPage` at `2.0` text scale in Spanish. However, wide tablet/foldable landscape layouts and text dialogs with the software keyboard open at `200%` scale have not been tested automatically yet; adding an `800x1280` widget test would cover that gap.

### B4. Local Storage Growth [done]

`NetworkCache` stores only the latest response per cache key, evicts entries older than 30 days (`NetworkCache.maxAge`), and lets students wipe all saved copies from `Settings > Saved content`. Special-schedule cache entries prune old dates after 60 days (`lib/special_schedule.dart`). There is currently no per-entry size cap; feeds are small text (`.ics`/JSON), so this is a known limitation if a feed ever grows large.

### B5. Mobile Data Usage [done]

Schedules, calendars, and lunch menus transfer only small JSON responses and reuse local caches when offline. Almost all bandwidth usage comes from the embedded WebViews on the Newsletters and Publications tabs (especially video playback on the Westview Newscast channel), since those tabs load full school webpages and video streams.

### B6. Accessibility Coverage

See [`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md).

---

## C. Developer and Build Compatibility

### C1. Pre-Build Automated Checks in CI [done]

Before running Gradle, `.github/workflows/build-apk.yml` runs three fast checks:

```sh
python3 tools/audit_contrast.py --strict
python3 tools/check_strings.py
flutter test --reporter expanded
```

Running these steps ahead of `flutter build apk` catches contrast regressions, malformed or missing translations in `lib/l10n/strings.dart`, and broken contact or schedule logic within a couple of minutes rather than after a full Android build.

### C2. Native Plugin Pinning [done]

`pubspec.yaml` pins `live_activities` to exact version `2.4.7` because version `2.5.0` requires a newer Flutter SDK and renames its Kotlin package (`com.example.live_activities` to `com.istornz.live_activities`), which would break `CustomLiveActivityManager.kt` and `MainActivity.kt`. Other dependencies use standard caret ranges and should be checked periodically with `flutter pub outdated` when upgrading Flutter's stable channel.

### C3. Static Analysis Step (`flutter analyze`) in CI [done]

`flutter analyze` runs in `.github/workflows/build-apk.yml` before `flutter test`, with output formatted via `tools/annotate_ci.py` (`analyze` mode), so lint warnings, unused imports, and `const` mistakes fail the build early.

### C4. Android System WebView Differences [known]

Newsletter and newspaper rendering, the locked-down Newscast embed (`lib/newscast_embed.dart`), and the video picture-in-picture bridge (`lib/video_pip.dart`) depend on the device's installed Android System WebView, the Newscast upload feed at `youtube.com/feeds/videos.xml`, and YouTube's iframe API. If an older WebView build misses a media event, or either site changes its page wrapper, PiP handoff fails safely back to regular in-app video playback rather than crashing. Any `webview_flutter` upgrade should be checked on a physical Android phone.

The Newscast embed sends a `Referer` header naming the app (`https://com.westviewhs.app`) on every load. That is not cosmetic: YouTube refuses to configure its player for a request it cannot identify and shows "Error 153: Video player configuration error" instead. An Android WebView sends no referrer on a top-level navigation, so the header has to be set in code, and losing it breaks playback with a message that points at the video rather than at the app. `test/newscast_feed_test.dart` asserts the header, the referrer policy, and that the URL's `origin` parameter matches, so the failure is caught before it ships.

### C5. iOS Target Status [decide]

The iOS project directory compiles in code, and `lib/publications.dart` preserves WebKit inline playback parameters, yet there is no Apple Developer signing setup or macOS CI workflow. Keeping the current note in `README.md` that Android is the supported target while iOS is unmaintained sets accurate expectations unless a macOS runner and signing certificates are added later.

### C6. Release Signing and Versioning [todo]

- **Signing key:** Release APKs in `android/app/build.gradle.kts` currently sign with the debug keystore so students can sideload CI artifacts easily. Before publishing to Google Play, or distributing long-lived sideloaded releases from multiple machines, configure a dedicated upload keystore via GitHub Secrets so updates can install over previous builds without requiring an uninstall.
- **Version policy:** `pubspec.yaml` stays at `1.0.0+1` while CI passes `--build-number=${{ github.run_number }}` for `versionCode`. On a `vX.Y.Z` tag, CI now also passes `--build-name=X.Y.Z` so `versionName` matches the tag and bug reports can be mapped to a release. Signing (above) remains TODO.

---

## D. School and District Compatibility

### D1. Unofficial-App Disclaimer [done]

Poway Unified's required English and Spanish outside-organization disclaimers appear verbatim on Get help and in Settings, while a short notice stays pinned above the bottom navigation bar on every tab. Translating the surrounding explanation into Chinese, Filipino, and French supplements those notices without replacing the district's exact English and Spanish text.

### D2. Zero District Account or SIS Integration [done]

WVAA never asks for a Poway Unified login, Synergy/Canvas credentials, or a student ID number. Operating solely on public schedules, public calendars, and student-typed class labels avoids handling protected student education records and removes the need for a district data-sharing agreement.

### D3. No Diagnostics Pipeline at All [done]

The app collects nothing: there is no analytics SDK, no crash reporter, and no reporting endpoint anywhere in the dependency list or in `lib/`. Outbound traffic is limited to the school's public calendar feeds, the lunch menu API, and the special-schedule files on `studycs.org`, none of which carries anything typed by a student.

### D4. Google Play Store Distribution [todo] [decide]

Sideloading APKs from GitHub Releases works today without store review, whereas listing an app named "Westview HS" with school imagery on Google Play can trigger trademark or impersonation review unless authorized. Before submitting to Google Play:

- Request written permission from Westview's administration to use the school name and icon in a student-built listing.
- Complete Google Play's Data Safety declaration to match Section D3, where every answer is "no data collected" and "no data shared".
- Include the non-affiliation disclaimer directly in the Play Store description.

### D5. Upstream Data Accuracy Expectations [todo] [decide]

Because calendars, lunch menus, nutrition facts, and newsletters come from school-managed feeds and webpages, upstream mistakes can look like app bugs to students. The "Saved copy from ..." offline banner and the counselor verification date already distinguish stale caches from live pages, and keeping a clear note in `About this app` that feed data comes from Westview's public pages helps set accurate expectations.

---

## E. Summary of Developer Liability Protections [done]

- The app states clearly that it is not a monitored crisis service and directs emergencies to 911 and 988.
- Listed crisis lines are presented as independent public services with no sponsorship, partnership, or financial tie.
- Counselor entries reproduce public staff directory information without offering medical or counseling advice.
- No diagnostics leave the device, so there is no payload that could identify a student or expose a schedule.
- Quick exit and hidden app-switcher previews operate locally on the device without logging when they are triggered.

---

## Recommended Priority Order

1. **A1 & A2:** Set a recurring August/January check for Westview's counselor caseloads, hotline numbers, and base bell schedules.
2. **C3 & B3:** Add `flutter analyze` to `.github/workflows/build-apk.yml` and add a landscape tablet/keyboard widget test at `200%` text scale.
3. **C6:** Set up a dedicated release signing keystore in GitHub Secrets before broad distribution.
4. **D4:** Obtain administrative sign-off before any Google Play Store submission.
