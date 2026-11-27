# Google Play Release Guide

This guide covers publishing WVAA to Google Play. The code side (upload-keystore
signing + AAB builds in CI) is implemented; the remaining steps are one-time
account/listing tasks only the maintainer can do.

> **Status:** Signing and AAB pipeline — done in code. Play Console account,
> listing, and school permission — still manual (see checklist at the end).

## How signing works

WVAA uses **Play App Signing**:

- Google holds the **app signing key** and re-signs the app before delivery.
- You hold the **upload key** (a keystore you generate once) and sign the
  AAB/APK you upload with it.
- `android/app/build.gradle.kts` loads the upload key from
  `android/key.properties` (local) or `KEYSTORE_*` environment variables (CI).
  When neither is present, release builds fall back to the debug keystore so
  sideload builds keep working — the AAB step in CI is skipped in that case.

⚠️ **Back up the upload keystore and both passwords** (password manager +
offline copy). Losing them means requesting an upload-key reset in Play
Console before you can publish updates. Never commit `android/key.properties`,
`*.jks`, or `*.keystore` — all are gitignored.

⚠️ **One-way switch:** once students install a debug-signed build, switching
to upload-key signing requires an uninstall/reinstall (signatures differ).
Switch before announcing a release to students.

## 1. Generate the upload keystore (once)

```sh
./tools/generate_upload_keystore.sh
# or manually with keytool (see https://docs.flutter.dev/deployment/android#signing-the-app)
```

This creates `android/app/upload-keystore.jks` (alias `upload`, RSA 2048,
~25-year validity). The script prints the base64 value for the next step.

## 2. Add GitHub Secrets

Repo **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | Single-line base64 of the `.jks` file (`base64 -w0 android/app/upload-keystore.jks`) |
| `KEYSTORE_PASSWORD` | Store password |
| `KEYSTORE_ALIAS` | Key alias (e.g. `upload`) |
| `KEYSTORE_KEY_PASSWORD` | Key password |

CI (`.github/workflows/build-apk.yml`) decodes the keystore, writes
`android/key.properties`, builds the APK as before, and additionally runs
`flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
(uploaded as a 90-day artifact, and attached to GitHub Releases on `vX.Y.Z` tags).

## 3. Local builds with the upload key

```sh
cp android/key.properties.example android/key.properties
# fill in storePassword / keyPassword / keyAlias / storeFile=upload-keystore.jks
flutter build appbundle --release   # Play upload
flutter build apk --release         # sideload (now upload-signed)
```

Verify the signature:

```sh
# AAB: unzip and check, or use bundletool / apksigner on the APK:
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

## 4. Play Console setup (manual)

1. Create a developer account ($25 one-time), complete identity verification.
2. Create app `com.westviewhs.app`, enroll in **Play App Signing**, register
   the upload key from step 1.
3. Upload the AAB from CI (Actions → latest run → `app-release-aab-*` artifact)
   or a local `flutter build appbundle`.
4. New personal accounts must run **closed testing** (12+ testers, 14 days)
   before production. Add testers, upload to the closed track, and collect
   feedback before promoting.

## 5. Store listing checklist

- **Name/icon:** "Westview HS" — see trademark note below.
- **Screenshots:** capture real device screenshots (phone + 7-inch tablet if
  claiming tablet support). `docs/screenshots/` are rendered mockups, not
  Play-ready captures.
- **Feature graphic + icon:** 1024×500 feature graphic, 512×512 icon.
- **Description:** include the non-affiliation disclaimer verbatim (see
  `docs/SAFETY.md` §2) — the app is student-built and not endorsed by
  Poway Unified / Westview HS.
- **Privacy policy URL:** required in the listing even though the app collects
  no data. Host a short policy (e.g. a GitHub Pages / repo-hosted page)
  stating: no data collected, no data shared, no analytics/crash SDKs.
- **Data Safety form:** every answer "no data collected / no data shared"
  (matches `docs/COMPATIBILITY.md` D3 — no telemetry in the code).
- **Content rating + target audience:** complete the questionnaire. WVAA is a
  general-audience school-information app with no accounts, ads, or
  user-generated content; answer accordingly and do not claim "Designed for
  Families" unless you intend to meet those requirements.
- **App content / permissions declarations:**
  - `SCHEDULE_EXACT_ALARM` — declare the exact-alarm use (period-transition
    widget/notification updates) in Play Console, or remove the permission
    and accept inexact alarms (the app already falls back gracefully).
  - No foreground service, no `QUERY_ALL_PACKAGES`, no sensitive permissions.
- **Category:** Education.

## 6. Trademark / permission (required before submission)

Per `docs/COMPATIBILITY.md` D4, listing an app named "Westview HS" with school
imagery can trigger Play's trademark/impersonation review. **Get written
permission from Westview administration** to use the school name/icon in a
Play listing before submitting. Keep the in-app and listing disclaimers
regardless.

## 7. Pre-launch verification (safety data)

- Re-verify counselor caseloads/extensions and crisis lines against
  `westview.powayusd.com/apps/pages/counseling-staff` (last checked
  November 2025) and update `lib/support.dart` + `test/support_resources_test.dart`
  together if anything changed (see `docs/COMPATIBILITY.md` A1).
- Re-verify base bell schedules in `lib/data.dart` (A2).
- Test the AAB on a physical device: widget, countdown notification,
  PiP, WebViews, and the Get help tab offline.

## Versioning

`pubspec.yaml` `versionName` is the user-visible version (currently `1.0.0`);
CI sets `versionCode` from `GITHUB_RUN_NUMBER` so every build is higher than
the last. Bump `versionName` (and push a `vX.Y.Z` tag) for each Play release
so bug reports map to builds.
