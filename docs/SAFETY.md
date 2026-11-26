# Student Safety and Developer Safeguards

This document records how Westview HS (WVAA) protects student privacy and safety, what data and permissions the app avoids collecting, and what boundaries protect the student maintainer from administrative or legal misunderstandings. Every claim below points to the source files that enforce it so a reviewer can verify each rule directly in the codebase.

> Scope note: WVAA is an independent school-information app. It is **not** a crisis service, it is **not** affiliated with Poway Unified School District (PUSD), and it does **not** replace a school counselor, a parent or guardian, or 911.

---

## 1. Crisis and Counseling Resources (Get Help Tab)

`lib/support.dart`

The app keeps a permanent **Get help** tab in the bottom navigation bar across the entire app, while also providing a **Help** button on the Schedule screen and an entry under `Settings > Safety > Get help now`. Keeping those entry points in fixed locations ensures that a student looking for support does not have to search through menus first.

Within the Get help screen, sections appear in order of urgency so that immediate emergencies sit at the top without requiring scrolling:

1. **In immediate danger?:** A full-width **Call 911** button (`tel:911`).
2. **Talk to a counselor at Westview:** The main school phone number, a link to the school's counseling page, and every Westview counselor listed by last-name caseload alongside 48dp call and email buttons.
3. **24/7 free, confidential crisis lines:** Direct call, text, and website buttons for six public resources:
   - 988 Suicide & Crisis Lifeline (call or text 988)
   - San Diego Access & Crisis Line (1-888-724-7240)
   - Crisis Text Line (text `HOME` to 741741)
   - The Trevor Project (1-866-488-7386 or text `START` to 678678)
   - Say Something Anonymous Reporting / Sandy Hook Promise (1-844-5-SAYNOW)
   - PUSD "See Something, Say Something" tip line (1-844-PUSD-TIP)
4. **Report a safety concern:** Guidance on reaching a trusted adult when worried about a classmate, paired with the two anonymous reporting lines above.
5. **About this app:** The official Poway Unified disclaimer in English and Spanish, followed by a plain-language summary of what the app does and does not monitor.

### Verified Contact Data (Checked November 2025)

Counselor assignments are organized by the first letters of a student's last name, sourced from `westview.powayusd.com/apps/pages/counseling-staff`:

| Caseload | Counselor | Extension | Email |
| --- | --- | --- | --- |
| A–C | Taylor Oakley | 3080 | toakley@powayusd.com |
| D–J | Isabella Rusy | 3062 | irusy@powayusd.com |
| K–M | Christine Cudmore | 3030 | ccudmore@powayusd.com |
| N–Sh | Adriana Chittuluru | 3026 | achittuluru@powayusd.com |
| Si–Z | Vicki deJesus | 3023 | vdejesus@powayusd.com |

College & Career Guidance Technician: Danielle Beccarelli, ext. 3019.
Main office line: (858) 780-2000. Address: 13500 Camino del Sur, San Diego, CA 92129.

Because counselor caseloads can shift between school years, the screen displays a verification date ("checked November 2025") and links to Westview's live counseling webpage so students can confirm current assignments. **Whenever counselor assignments change, `lib/support.dart`, this table, and `test/support_resources_test.dart` must be updated together.**

### Why Contact Numbers Are Compiled Into the App

The Get help screen makes zero network requests when it opens. Bundling these phone numbers and extensions into the binary allows the screen to load immediately when campus Wi-Fi drops, when mobile data is unavailable, or when an external website is down. Additionally, `test/support_resources_test.dart` asserts the exact digits of each phone number and extension directly so an accidental edit cannot ship an invalid number.

---

## 2. District Disclaimer

`lib/support.dart` (`disclaimers`), `lib/main.dart`, `lib/settings_page.dart`

The app includes the exact disclaimer text required by Poway Unified School District on its "Flyers – Outside Organizations" page for materials distributed by non-district groups:

> **DISCLAIMER:** This activity is not a school-sponsored activity and is not
> endorsed by the school or Poway Unified School District. The products or
> services advertised in this flyer are not endorsed by the school or the
> District.

> **AVISO LEGAL:** Esta actividad no es una actividad patrocinada por la escuela
> y no está avalada por la escuela ni por el Distrito Escolar Unificado de
> Poway. Los productos o servicios anunciados en este folleto no están
> respaldados por la escuela ni el Distrito.

To make sure students, parents, and administrators can always tell that WVAA is independent of the school district, the disclaimer appears in three places:

- **Pinned bar above the bottom navigation bar on every tab:** Displays a short notice stating that WVAA is an independent student-built app and is not sponsored or endorsed by Westview High School or Poway Unified School District; tapping the bar opens the full text.
- **Get help ("About this app" card):** Displays the full English and Spanish district text alongside a translated plain-language summary.
- **Settings > About this app:** Displays the full English and Spanish district text alongside a reminder that the app is not monitored and is not a crisis service.

The first-launch notice also states this disclaimer, so the app opens by making its unofficial status clear.

---

## 3. Data and Permission Boundaries

| Boundary | Enforcement Location |
| --- | --- |
| **No usage tracking anywhere.** The repository contains no analytics SDK, no crash reporter, and no reporting endpoint, so there is no code path that uploads how a student uses the app. Opening Get help therefore records nothing, and neither does any other screen. | `pubspec.yaml`, `lib/` |
| **No advertising or device identifiers.** The app never reads `AdvertisingIdClient`, the Android ID, or an install identifier, and it does not declare the `AD_ID` permission. | `AndroidManifest.xml`, `pubspec.yaml` |
| **No collection of names, accounts, or class details.** Custom class names, teacher names, and room numbers stay in local `SharedPreferences` on the phone and are never serialized into a network request. The only outbound requests go to the school's calendar feeds and to `studycs.org` for special schedules. | `lib/settings.dart`, `lib/calendars.dart`, `lib/special_schedule.dart` |
| **No class details on a locked screen.** The countdown notification channel uses `VISIBILITY_SECRET` so Android hides the notification while the phone is locked. As a secondary safeguard, the notification's fallback public version includes only the period label and omits custom course names, teachers, and room numbers. | `ScheduleNotificationManager.kt`, `CustomLiveActivityManager.kt` |
| **No full-screen interruptions.** `USE_FULL_SCREEN_INTENT` is omitted and `showWhenLocked` is set to `false`, preventing a period timer from appearing over the lock screen or interrupting another app. | `AndroidManifest.xml` |
| **No in-app call or message handling.** Phone calls, text messages, emails, and web links are handed off to the system dialer, messaging app, mail app, or browser through `url_launcher`, so the app never accesses call audio or message contents. | `lib/support.dart` |
| **No analytics injected into school webpages.** Embedded newsletters and publications load Westview's existing pages in a WebView without adding tracking scripts. | `lib/web_page.dart`, `lib/publications.dart` |

---

## 4. Shared-Phone and Shoulder-Surfing Protections

`lib/safety.dart`, `MainActivity.kt`, `lib/settings_page.dart`

- **Quick exit (enabled by default):** Holding down any Help button pops the Get help route if it is open and moves the Android task to the background immediately. The gesture skips any confirmation prompt because asking "Are you sure?" would slow down a student who needs to close the screen quickly. Students can turn this gesture off under `Settings > Safety`.
- **Hidden app-switcher preview (enabled by default):** When WVAA moves to the background, `MainActivity` sets Android's `FLAG_SECURE` window flag so the system's recent-apps thumbnail appears blank instead of showing the last open screen. When the app returns to the foreground, `MainActivity` clears `FLAG_SECURE` so students can still take screenshots of their own class schedule.
- **Lock-screen hiding:** Covered in Section 3 above; class schedule details remain hidden until the device is unlocked.

---

## 5. Practical Safeguards for the Maintainer

The points below are not formal legal advice, though they explain the administrative and liability boundaries built into the repository:

1. **Never represent the app as official:** Refer to the project as an independent student-built app for Westview HS rather than "the Westview app" or "a PUSD app." Keeping the disclaimer bar visible on every tab ensures that even a cropped screenshot shows the project is unofficial. Do not use district or school logos on an app store listing without written permission from administration.
2. **Keep the district disclaimer verbatim:** Removing or paraphrasing the required Poway Unified wording creates avoidable trademark and endorsement issues, since that wording is the standard notice district staff expect on non-school materials.
3. **Do not imply partnerships with crisis organizations:** The hotlines listed on Get help are public services rather than sponsors or partners, which is why the screen states explicitly that the app is independent and receives no funding from them.
4. **Never imply live monitoring:** Get help states clearly that the app cannot read messages or respond to emergencies and directs students in immediate danger to call 911.
5. **Collect nothing:** A student audience makes every added data point a privacy question. Keeping the app free of analytics and crash reporting avoids collecting student records at all, and it removes any consent flow that could mislead users into thinking data is being gathered.
6. **Keep the app read-only:** Allowing user-generated posts would require content moderation under school-adjacent standards, whereas displaying read-only schedules, calendars, and public webpages avoids moderation and student-account risks altogether.
7. **Maintain a clean shutdown path:** Apart from the special-schedule files on `studycs.org`, the app does not depend on maintainer-run infrastructure. If that server stops responding, the cached schedules keep the app working until a new answer arrives.
8. **Re-verify contact information every term:** Outdated counselor extensions or hotline numbers can prevent a student from reaching help when needed, so `supportDataVerified` and `test/support_resources_test.dart` keep the verification date and expected digits explicit in code.

---

## 6. Checklist Before Merging Future Changes

- [ ] **Adding or editing a support contact:** Update `lib/support.dart`, update Section 1 of this file, and update the hardcoded assertions in `test/support_resources_test.dart`.
- [ ] **Adding any reporting or analytics:** Treat this as a policy change rather than a code change. It would require a new consent flow, an update to this document, and a review of what minors can be asked to share.
- [ ] **Modifying notifications:** Verify that `VISIBILITY_SECRET` remains enforced and that public fallback text never includes custom course names, teacher names, or room numbers.
- [ ] **Requesting an Android permission:** Document why the permission is necessary here and in `AndroidManifest.xml`. Beyond internet, notifications, and widget alarm/boot receivers, the app should not request camera, microphone, contacts, location, or storage permissions.
- [ ] **Changing the first-launch notice:** Keep the unofficial-app disclaimer visible in the prompt, since that notice is what tells a new student the app is not run by the district.
- [ ] **Updating a disclaimer:** Copy the required English and Spanish text verbatim from Poway Unified's policy page, update `disclaimers` in `lib/support.dart`, and pass `flutter test test/support_resources_test.dart`.

---

## 7. Current Limitations

- **Crashes leave no report behind:** Because the app has no crash reporting, a crash shows up only as a `debugPrint` line in a debug build. Fixing one depends on a student describing what happened, which is the tradeoff accepted for keeping the app free of data collection.
- **App-switcher blanking is Android-specific:** `FLAG_SECURE` only applies on Android, and certain manufacturer skins handle recent-app snapshots differently; on iOS, behavior depends on the operating system's own switcher blur.
- **iOS crisis-link launching is not tested on hardware:** While `Info.plist` declares the relevant URL schemes, call and SMS handoffs are actively verified on Android devices rather than iOS.
- **Automated tests cannot confirm live phone-line availability:** Unit tests prevent accidental edits to phone numbers in code, whereas confirming that an external hotline or school extension remains active still requires a manual check each term.
- **Embedded webpages are controlled upstream:** Newsletters and student publications load directly from Westview's external sites, so the app cannot control layout, privacy behavior, or link targets inside those pages.
