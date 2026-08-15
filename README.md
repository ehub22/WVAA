Westview Android App


Functions implemented so far:
  Calendars (Athletics, school calendar, and school lunch)
  Schedules by day (Modified schedules still don't work)
  Newsletters (Weekly newsletter, counseling newsletters, and den announcements)
  School publications (Nexus and Newscast)



Used flutter in case we want to make this multiplatform later, but right now, I believe only android works.

## Building the APK with GitHub Actions

This repo includes a GitHub Actions workflow (`.github/workflows/build-apk.yml`) that
builds a release Android APK automatically:

- On every push to `main`, the workflow builds the APK and publishes it to a rolling
  **"Latest build" release** on the Releases page (direct `.apk` download), and also
  uploads it as a downloadable **build artifact** (kept for 30 days).
- When you push a tag named `vX.Y.Z` (e.g. `v1.0.0`), the workflow creates a stable
  GitHub **Release** and attaches the APK.
- You can also trigger a build manually from **Actions → Build Android APK → Run workflow**.

### Downloading and installing the APK

**Easiest way — use the Releases page:**

1. On your phone's browser, go to:
   https://github.com/ehub22/WVAA/releases
2. Tap the **"Latest build"** release and download `app-release.apk` (a raw `.apk`,
   ready to install — no unzipping needed).
   Direct link (after the first build has run):
   https://github.com/ehub22/WVAA/releases/download/latest/app-release.apk
3. Open the downloaded file and install it. You may need to allow
   "Install from unknown sources" for your browser/files app.

**Alternative — download the build artifact:**

1. Open the **Actions** tab and pick a successful run.
2. Scroll to **Artifacts** and download `app-release-<run-number>`.
3. **Unzip it first** — GitHub packages artifacts as a `.zip`. Installing the `.zip`
   directly (or renaming it to `.apk`) is the most common cause of the
   *"App not installed / package appears to be invalid"* error.
4. Install the `app-release.apk` that was inside the zip.

### "Package appears to be invalid" — troubleshooting

- **Make sure you're installing an actual `.apk` file**, not the zipped artifact.
  See the two download methods above.
- **Uninstall any older copy of the app first.** If the app is already on the phone
  (for example, installed from Android Studio / `flutter run`), Android will refuse
  to install a new APK that was signed with a different key. Go to Settings → Apps →
  Westview HS → Uninstall, then install the new APK.
- **Download the file again.** A partial/corrupted download also triggers this error.
- **Sign the release with a stable key** (below). If different CI builds use different
  auto-generated debug keys, you must uninstall between builds. A stable release
  keystore fixes this for good.

### Versioning
Each CI build sets `versionCode` to the GitHub run number so every APK is
monotonically increasing, which is required to install an update over an existing
install (and required before publishing anywhere).

### Signing the release APK (recommended)

By default the CI build signs the APK with Flutter's auto-generated debug key. That is
fine for a one-off sideload, but the key is regenerated on every CI machine, so two
different builds are signed with two different keys and one will not install over the
other. To make releases install cleanly on top of each other, sign them with your own
stable keystore:

1. Generate a keystore on your computer (requires the Java `keytool`):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   (Keep `upload-keystore.jks` somewhere safe and never commit it to the repo.)

2. Add two repository secrets (Settings → Secrets and variables → Actions → New
   repository secret):
   - `ANDROID_KEYSTORE_BASE64` — the keystore, base64-encoded:
     ```bash
     base64 -i upload-keystore.jks | pbcopy   # macOS
     base64 -w0 upload-keystore.jks           # Linux, copy the output
     ```
   - `ANDROID_KEY_PROPERTIES` — the signing properties (replace the passwords):
     ```
     keyAlias=upload
     keyPassword=YOUR_KEY_PASSWORD
     storePassword=YOUR_STORE_PASSWORD
     storeFile=upload-keystore.jks
     ```

3. Re-run the workflow. The release APK will now be signed with your key. For full
   details on signing for Google Play, see
   https://docs.flutter.dev/deployment/android#signing-the-app.
