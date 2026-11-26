# Student safety design (and developer safety)

This document is for anyone reviewing, shipping or maintaining Westview HS
(WVAA). It records **what the app does to keep students safe while they use it**,
**what it deliberately refuses to do**, and the **legal/administrative posture**
for the developer. Every claim below maps to code; file names are given so a
reviewer can check them.

> Scope note: this is a school-information app. It is **not** a crisis service,
> it is **not** affiliated with Poway Unified School District (PUSD), and it is
> **not** a substitute for a counselor, a parent or 911.

---

## 1. Crisis and counseling resources (Get help tab)

`lib/support.dart`

A permanent **Get help** tab sits in the bottom navigation bar on every screen,
and the same screen is reachable from the big **Help** button on the Schedule
tab and from Settings ▸ Safety ▸ Get help now. A student in a bad moment never
has to guess where resources live.

Screen order is deliberate — someone in danger should not have to scroll:

1. **In immediate danger?** — a full-width *Call 911* button (`tel:911`).
2. **Talk to a counselor at Westview** — the school office number, the
   counseling page, and every counselor with their caseload, extension and
   e-mail. Each row has 48dp call and e-mail buttons.
3. **Crisis lines — free, confidential, 24/7**, each with tap-to-call,
   tap-to-text and a website link:
   - 988 Suicide & Crisis Lifeline — call/text 988
   - San Diego Access & Crisis Line — 1-888-724-7240
   - Crisis Text Line — text HOME to 741741
   - The Trevor Project — 1-866-488-7386 / text START to 678678
   - Say Something Anonymous Reporting (Sandy Hook Promise) — 1-844-5-SAYNOW
   - PUSD "See Something, Say Something" tip line — 1-844-PUSD-TIP
4. **Report a safety concern** — what to do if you are worried about a
   classmate, plus the two anonymous reporting routes.
5. **About this app** — the district disclaimer in English and Spanish and a
   plain-language explanation of the app's limits.

### Contact data (verified November 2025)

Counselors, by the first letter of the student's last name (source:
`westview.powayusd.com/apps/pages/counseling-staff`):

| Caseload | Counselor | Extension | E-mail |
| --- | --- | --- | --- |
| A–C | Taylor Oakley | 3080 | toakley@powayusd.com |
| D–J | Isabella Rusy | 3062 | irusy@powayusd.com |
| K–M | Christine Cudmore | 3030 | ccudmore@powayusd.com |
| N–Sh | Adriana Chittuluru | 3026 | achittuluru@powayusd.com |
| Si–Z | Vicki deJesus | 3023 | vdejesus@powayusd.com |

College & Career Guidance Technician: Danielle Beccarelli, ext 3019.
Main line: (858) 780-2000. Address: 13500 Camino del Sur, San Diego, CA 92129.

Because caseloads change every year, the screen always shows a "list checked
November 2025 — confirm with the counseling office" note and links to the live
counseling page. **Update `lib/support.dart`, this table and
`test/support_resources_test.dart` together.**

### Why the numbers are compiled into the app

No network call is made to render the Get-help screen: it works offline, on the
school's flaky Wi-Fi, and during an outage. `test/support_resources_test.dart`
hard-codes the expected digits so a typo cannot ship unnoticed.

---

## 2. District disclaimer

`lib/support.dart` (`disclaimers`), `lib/main.dart`, `lib/settings_page.dart`

The wording is copied exactly from PUSD's "Flyers – Outside Organizations" page,
which is where the district specifies the disclaimer required on material from
any non-district source:

> **DISCLAIMER:** This activity is not a school-sponsored activity and is not
> endorsed by the school or Poway Unified School District. The products or
> services advertised in this flyer are not endorsed by the school or the
> District.

> **AVISO LEGAL:** Esta actividad no es una actividad patrocinada por la escuela
> y no está avalada por la escuela ni por el Distrito Escolar Unificado de
> Poway. Los productos o servicios anunciados en este folleto no están
> respaldados por la escuela ni el Distrito.

It appears in three places, so it cannot be missed:

- a **permanent bar under the navigation bar on every tab** (short form:
  "Not a Poway Unified app. Not sponsored or endorsed by Poway Unified School
  District or Westview High School."), tappable to open the full text;
- the **Get help** screen's "About this app" card, in full, English + Spanish;
- **Settings ▸ About this app**, in full, English + Spanish, plus the
  "not a crisis service, not monitored" line.

The first-run privacy dialog also states it before anything else happens.

---

## 3. What the app refuses to do

| Refusal | Where |
| --- | --- |
| **No analytics of help-seeking.** Opening the Get-help tab is never logged. `support.dart` does not even import `telemetry.dart`. | `lib/main.dart`, `lib/support.dart` |
| **No collection before consent.** Analytics and crash reporting default to **off**; nothing is queued until the student picks "Share anonymously" in the first-run dialog (turning a switch on in Settings counts as consent too). | `lib/settings.dart`, `lib/telemetry.dart`, `lib/main.dart` |
| **No inherited consent.** Installs upgrading from the old opt-out build have their stored "on" values discarded (no consent version in the payload) and are asked again. | `lib/settings.dart` (`_consentVersion`) |
| **No free text in reports.** Crash errors and stacks are scrubbed of anything the student typed into "My classes" (class names, teacher names, room numbers) and of any e-mail address or phone number before they leave the device. | `lib/telemetry.dart` |
| **No identifying device data.** No device model, IDFA/GAID, install id, contacts, location or account. Only a per-launch session id. | `lib/telemetry.dart` |
| **No school details on the lock screen.** Notification visibility is `SECRET`: nothing from the countdown appears until the phone is unlocked. As defence in depth, the notification's redacted "public" version (shown only if visibility is ever loosened) carries the period name alone — never the course name, teacher or room. | `ScheduleNotificationManager.kt`, `CustomLiveActivityManager.kt` |
| **No full-screen takeover.** `USE_FULL_SCREEN_INTENT` was removed and `showWhenLocked` is `false`: a countdown timer can never slam an activity over whatever the student was doing, or over the lock screen. | `AndroidManifest.xml` |
| **No handling of calls or messages.** All phone, SMS and e-mail actions are handed to the system dialer / Messages / Mail app via `url_launcher`; the app never sees or stores call audio or message content. | `lib/support.dart` |
| **No tracking in web content.** Embedded newsletters and publications are plain WebViews of the school's own pages; the app injects nothing. | `lib/web_page.dart`, `lib/publications.dart` |

---

## 4. Use-it-safely features (shared / watched devices)

`lib/safety.dart`, `MainActivity.kt`, `lib/settings_page.dart`

- **Quick exit** (on by default): long-press the Help button (Schedule tab or
  app bar) to leave the app instantly — the help screen is popped off the
  navigation stack and the task is sent to the background. Deliberately *no*
  confirmation dialog: a quick exit that asks "are you sure?" is not a quick
  exit. Toggle in Settings ▸ Safety.
- **Hide preview in app switcher** (on by default): the app's content is
  blanked in the Android recents thumbnail, so the last screen opened is not
  visible to whoever picks the phone up next. Implemented with `FLAG_SECURE`
  applied only while the app is in the background, so screenshots of your own
  timetable still work.
- **Lock-screen privacy**: see the refusal table above.

---

## 5. Developer safety (the person shipping this)

Not legal advice; it is the practical posture the code is written to support.

1. **Never call it an official app.** Use "Westview HS companion app", never
   "Westview's app", "the PUSD app" or anything using district branding. The
   disclaimer bar is permanent precisely so a screenshot can never be mistaken
   for a district product. Do not use PUSD/Westview logos in store listings
   without written permission, and do not publish under a school-sounding
   developer name.
2. **Keep the disclaimer intact.** Removing or rewording it is the single
   fastest way to turn a helpful project into a trademark / implied-endorsement
   problem. It is also the first thing a district administrator will look for.
3. **Do not speak for the school.** Crisis numbers you list are public
   resources, not partnerships; the app says explicitly that it receives no
   payment from them and is not affiliated with them.
4. **Never present the app as a crisis service.** The Get-help screen says it
   is not monitored, tells students to call 911 in an emergency, and never
   implies a reply is guaranteed.
5. **Do not collect more.** Every added field is a new privacy obligation and a
   new thing that could identify a minor. The telemetry pipeline is
   deliberately tiny; keep it that way, and keep it opt-in.
6. **Moderate the review pipeline, not the students.** If the app ever gains
   user-generated content, the district's own flyer rules (no politics, no
   discrimination, nothing illegal or age-inappropriate) are a reasonable bar —
   but the safer design is to keep the app read-only.
7. **Have a takedown plan.** If the school asks you to stop, you can: there is
   no server you own in the critical path except the telemetry endpoint, which
   fails closed (4xx/404 drops the batch and the app carries on).
8. **Keep the data current.** Stale counselor or hotline data is a safety bug,
   not a cosmetic one. Re-verify each term (the `supportDataVerified` constant
   and the tests make the current value visible).

---

## 6. Checklist for future changes

- [ ] Adding a contact? Put it in `lib/support.dart` and pin it in
      `test/support_resources_test.dart`.
- [ ] Adding an event or property? Ask whether it could identify a student;
      if yes, don't. Never log anything on the Get-help screen.
- [ ] Adding a notification? It must not contain teacher, room or course names
      in the lock-screen / public version.
- [ ] Adding a permission? Justify it here and in the manifest comment. The app
      needs INTERNET, notifications, and alarm/boot permissions for the widget —
      nothing else (no camera, mic, location, contacts, storage).
- [ ] Touching the first-run dialog? Consent must stay opt-in and the disclaimer
      must stay visible.
- [ ] Changing a disclaimer string? Copy it verbatim from the district page
      (`docs/SAFETY.md` §2), update `Disclaimers` in `lib/support.dart`, and run
      `flutter test test/support_resources_test.dart`.

---

## 7. Known gaps / next steps

Honest list of what this hardening does **not** cover:

- **Crash-report scrubbing is best effort.** Values typed into "My classes" and
  anything matching an e-mail/phone pattern are removed, but free-form text
  cannot be perfectly anonymised. Keep new `context` labels developer-authored.
- **The recents-privacy flag is Android-only** and OEM-dependent; on iOS the app
  relies on the system app-switcher blur.
- **The iOS share sheet / link handling is untested** (`LSApplicationQueriesSchemes`
  is declared, but the crisis actions are only exercised on Android).
- **Nothing verifies that a hotline is still in service.** Numbers are pinned by
  tests but re-checking them each term is a human task (see `supportDataVerified`).
- **WebView content is out of scope.** Newsletters and publications are the
  school's own pages; the app adds no protection inside them beyond the
  surrounding UI.
