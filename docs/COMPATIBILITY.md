# Compatibility review

Written from three seats at once — **student**, **developer**, **administrator** —
for Westview HS (WVAA). Sections are ordered by risk, not by effort. Each item
says what breaks today, what to do, and roughly what it costs.

Status key: **[done]** already in the app · **[todo]** recommended, not started ·
**[decide]** needs a human decision (school, district, or maintainer).

---

## A. Things that break safety if they fail (fix first)

### A1. Contact data goes stale — [todo] [decide]

The counselor roster, caseloads, extensions and crisis-line numbers are compiled
into `lib/support.dart`. That is deliberate (it works offline, on bad Wi-Fi, on a
dead phone), but it means **a June staffing change silently makes the app wrong**
until someone ships a release.

- **Student impact:** a student is told to call an extension that no longer
  exists, or is routed to the wrong counselor and gives up.
- **Do:** keep the "list checked November 2025" note on screen (already there),
  and add a **quarterly reminder** to the repo — the `.github/ISSUE_TEMPLATE`
  or a calendar entry owned by the maintainer. Re-verify:
  `westview.powayusd.com/apps/pages/counseling-staff`, the district crisis page,
  and 988/741741/678678.
- **Consider:** an optional, offline-first remote override (a tiny JSON on the
  same `studycs.org` host as the special schedule) that updates *phone numbers
  only*, with the compiled values as the fallback when the fetch fails. This
  keeps the offline guarantee and removes the "stale until next release" gap.
  Don't do this for caseload letters — those are cheap to leave manual.

### A2. The school year changes the schedule — [done] partly

Regular schedules are hard-coded (`monFriSchedule`, `tueThursSchedule`,
`wedSchedule`), and special schedules are fetched from the server. Block
scheduling changes most years.

- **Do:** before each August, re-check the bell schedule against the school's
  page. The special-schedule override already covers assemblies and early
  releases, so the risk is bounded to the base schedule.

### A3. Google API keys are in the client — [decide]

`lib/calendars.dart` and `lib/school_lunch.dart` contain Google API keys for
public calendars. They are restricted-by-referrer API keys for *public* data, so
leaking them exposes nothing private — but they can be abused to burn the
project's quota.

- **Do:** restrict each key to the Android app's package name + SHA-1 in Google
  Cloud, and keep the quota low. Document the key rotation owner.
- **Why it matters for students:** a quota-exhausted key means the Calendar tab
  goes empty on a day when it is actually needed.

---

## B. Student-side compatibility

### B1. Old Android versions — [done]

`minSdk = maxOf(flutter.minSdkVersion, 24)` (Android 7.0). That covers essentially
every phone a student actually carries. Notification APIs degrade gracefully
(channel importance, exact alarms fall back to inexact).

### B2. Phones without Google Play Services — [done]

No Firebase, no Play Services dependency, no analytics SDK. The app installs and
works on de-Googled Android (GrapheneOS, Lineage) and on sideloaded APKs.

### B3. Screen sizes and text scaling — [done, needs a tablet test]

`textScaler` is clamped to 0.85–2.0 and nothing important is `maxLines`-clipped.
The test suite renders the Help screen at 200 % in Spanish. **Still unverified:**
tablets/foldables in landscape, and 200 % with the on-screen keyboard up (the
"rename my class" dialog). Add a widget test with a 800×1280 surface.

### B4. Storage pressure — [done]

Caches are bounded (`network_cache.dart`) and clearable in Settings ▸ Saved
content. Nothing accumulates silently.

### B5. Data cost — [done, worth stating]

The heavy tabs (newsletters, publications) are the school's own WebViews and are
by far the biggest data users. Everything else is a few KB of JSON, cached. If
the school ever wants a "data saver" note in the onboarding, this is where it
goes.

### B6. Accessibility — see [`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md)

---

## C. Developer-side compatibility

### C1. CI only builds an APK — [done]

`.github/workflows/build-apk.yml` now runs, before the Gradle build:

```sh
python3 tools/audit_contrast.py --strict   # WCAG pairs + CVD ΔE
flutter test                              # incl. test/l10n_test.dart
```

so a broken translation or a contrast regression fails the PR in ~2 minutes
instead of shipping.

### C2. Dependency pinning — [done] for the risky one

`live_activities` is pinned at 2.4.7 with the reason in `pubspec.yaml`; upgrading
it renames the Android plugin package and breaks `CustomLiveActivityManager`.
Everything else is caret-ranged.

- **Do:** when Flutter's stable channel moves, run the whole suite. `flutter
  pub outdated` quarterly.

### C3. No `flutter analyze` gate — [todo]

Add `flutter analyze` to CI. It is fast and would have caught several
`const`-list/localization errors during the i18n work.

### C4. WebView behaviour differs across Android WebView versions — [known]

The Vimeo PiP bridge and the newsletter WebViews rely on postMessage and on
`webview_flutter`'s platform channels. On very old WebView builds the PiP
hand-off can fail; the app degrades to normal playback, which is acceptable. Test
the PiP path after any `webview_flutter` bump, on a real device.

### C5. iOS — [decide]

iOS compiles but is not maintained (no signing, no TestFlight). Either commit to
it (needs an Apple Developer account and a Mac in CI) or state plainly in the
README that it is unsupported. Right now the README says "compiles but is not
actively maintained", which is honest.

### C6. Release hygiene — [todo]

- Set a real `versionName`/`versionCode` policy (currently `1.0.0+1` plus the CI
  run number).
- Sign with a **release keystore**, not the auto-generated debug key, before any
  Play upload. Losing the debug key means every installed copy must be
  uninstalled to update.
- Keep the keystore and its password out of the repo; use GitHub Secrets.

---

## D. Administrator-side compatibility

### D1. The district disclaimer — [done]

The PUSD-required English and Spanish wording is shown **verbatim** on the Get
help screen ("This app is not part of Poway Unified…" / "AVISO LEGAL…"), and a
compact one-liner is pinned under the navigation bar on every tab. Translation of
the *explanation* never replaces the required wording.

### D2. Nothing here needs a district account — [done]

No student login, no SIS integration, no student IDs, no district SSO. That means
no data-processing agreement is required to run the app, which is the single
biggest administrative blocker for a student-built project.

### D3. Analytics and consent — [done]

Opt-in, off by default, first-run plain-language dialog, per-stream switch,
scrubbed payloads, school-hosted endpoint (`studycs.org`), and the Get help tab
is never logged. Consent version is bumped (`privacyConsentVersion = 2`) so a
changed disclosure re-asks instead of silently inheriting old consent.

- **Do:** if the endpoint ever moves to a vendor, that is a new consent version
  and a new disclosure.

### D4. Publishing on Play — [todo] [decide]

A student-built app using the school's name and logo invites a trademark
question. Before publishing:

- get written permission (or a clear blessing) from Westview's administration for
  the name/icon, and
- fill in Play's Data safety form to match §D3 (nothing collected unless opted
  in), and
- keep the disclaimer visible in the store listing, not just in-app.

Sideloading an APK from the repo needs none of this and is how it works today.

### D5. Content accuracy — [todo] [decide]

Lunch menus, calendars and newsletters are the school's data. If a menu is wrong,
students blame the app. The "saved copy" banner and the verification dates are
the mitigation; a short "data comes from the school's public pages" line in the
About footer would close the loop.

---

## E. Legal / personal-risk items for the developer — [done]

- The app **never** claims to be a crisis service; the disclaimer says it is not
  monitored and routes to 911/988.
- Crisis lines are linked, not "partnered with" — no affiliation is implied and
  no money changes hands (stated on screen).
- No medical or diagnostic advice is given; the counselor roster is factual data
  from a public page.
- Telemetry cannot reconstruct an individual: no names, IDs, contacts, location,
  or device identifiers, and typed text is scrubbed.
- Quick-exit and hidden-recents protect a student who is being monitored, and
  neither creates a record that they used them.

---

## Suggested order of work

1. **A1** quarterly contact re-verification (or the numbers-only remote override).
2. **C3** `flutter analyze` in CI, and **B3** the tablet/keyboard widget test.
3. **A3** restrict the Google API keys.
4. **C6** release keystore + version policy.
5. **D4** Play-store permissions and Data safety form.
6. Everything else as it becomes relevant.
