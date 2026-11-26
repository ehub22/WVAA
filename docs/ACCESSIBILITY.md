# Accessibility

Westview HS (WVAA) serves students and families with different language, vision, hearing, and motor needs, such as parents reading Spanish at home, students using screen readers or enlarged system fonts, and deaf or hard-of-hearing students reaching support in a loud hallway. Because those situations are common across a public high school, the app builds translations, contrast checks, screen-reader labels, and non-voice crisis options directly into its standard screens.

This document records what is implemented today, which files enforce each behavior, and which gaps still need testing or upstream support.

---

## 1. Languages

| Language | Code | Coverage |
| --- | --- | --- |
| English | `en` | Complete |
| Spanish | `es` | Complete |
| Simplified Chinese | `zh` | Complete |
| Filipino / Tagalog | `tl` | Complete |
| French | `fr` | Complete |

Every screen drawn by the Flutter app is translated across all five languages, including all safety-related text: the 911 card, all six crisis lines, the counselor list, reporting instructions, the plain-language disclaimer summary, Settings, bottom navigation labels, loading/error/empty views, calendar and lunch headings, and the SMS confirmation dialog.

All app translations live in `lib/l10n/strings.dart`:

- **`AppLanguage`:** Defines `system`, `english`, `spanish`, `chinese`, and `tagalog`, mapping device locales (including `fil` to `tl`) to supported BCP-47 tags.
- **`AppStrings`:** Provides string lookup via `operator []`. If a lookup ever misses in a non-English map, it falls back to English and then to the key string itself so that an automated test catches the mistake instead of leaving a safety button blank.
- **`AppStrings.of(context)`:** Checks `AppSettings.instance.language` before checking the device locale, allowing a student on a shared family phone to lock the app to one language while letting `System default` follow the operating system.

Instead of using `intl` `.arb` code generation, the repository keeps the five maps in one Dart file validated by `tools/check_strings.py` and `test/l10n_test.dart`. Because the catalog has roughly two hundred keys, keeping them in plain Dart avoids a `build_runner` step while letting unit tests check key parity directly. At the same time, `flutter_localizations` is still enabled so Material widgets (such as back buttons, selection menus, and system tooltips) localize properly in `en`, `es`, `zh`, `tl`, and `fr`.

### Language Picker and System Integration

Under `Settings > Safety > English · Español · 中文 · Filipino · Français`, the setting row lists every supported language, and each option inside the bottom sheet repeats that list on its subtitle line (for example, `Español · Spanish · 西班牙语 · Espanyol · Espagnol`). Naming every language on every row allows a user to find their own language even if the app was previously set to one they cannot read.

Outside Flutter, `android/app/src/main/res/values-{es,zh,tl,fr}/strings.xml` translates the launcher and home-screen widget descriptions, while `res/xml/locale_config.xml` registers all five locales with Android 13's system per-app language menu (`Settings > Apps > Westview HS > Language`). On iOS, `Info.plist` declares the same five locales in `CFBundleLocalizations`.

### Content Left Untranslated

Embedded WebViews (newsletters, Westview Nexus, and Westview Newscast) display external webpages controlled by school groups, so the app cannot translate their contents. In addition, the official Poway Unified disclaimer is kept verbatim in English and Spanish rather than translated informally into Chinese, Filipino, or French, because legal disclaimer text should not be paraphrased as if the district wrote that translation; instead, the app translates its own plain-language explanation underneath and notes that the official district text governs.

---

## 2. Color and Contrast

- **Status never relies on color alone (WCAG 1.4.1):** On the Schedule tab, the active period card combines a `primaryContainer` background tint with a left accent bar and an explicit "Now" pill (`_NowBadge` in `lib/schedule_page.dart`). The bar and the word mean students viewing the screen in grayscale or bright outdoor glare can still tell which period is running, and neither element is shaped like a control, so the card never looks tappable.
- **Verified WCAG AA contrast:** `tools/audit_contrast.py` calculates contrast ratios for every foreground/background token pair used in `lib/theme/colors.dart`:

  | Token Pair | Light Theme | Dark Theme | WCAG AA (4.5:1) |
  | --- | --- | --- | --- |
  | `onSurface` on `surface` | 16.31:1 | 14.42:1 | Pass |
  | `onSurfaceVariant` on `surface` | 8.87:1 | 11.11:1 | Pass |
  | `onPrimary` on `primary` | 6.47:1 | 9.41:1 | Pass |
  | `primary` on `surface` | 6.14:1 | 13.30:1 | Pass |
  | `onErrorContainer` on `errorContainer` | 13.26:1 | 7.24:1 | Pass |
  | `outline` on `surface` (3.0:1 non-text target) | 4.26:1 | 6.11:1 | Pass |

  Any change to `lib/theme/colors.dart` should be checked locally with `python3 tools/audit_contrast.py --strict`, which also runs automatically in GitHub Actions.
- **Color-vision deficiency separation:** `tools/audit_contrast.py` simulates deuteranopia, protanopia, and tritanopia to confirm that the active-period card (`primaryContainer`) remains visually distinct from standard period cards (`surfaceContainerLow`). Across all three simulations, separation stays at `ΔE >= 20.3` in light mode and `ΔE >= 63.2` in dark mode, reinforced by a left accent bar and the "Now" label, neither of which looks like a button.
- **Paired icons on status cards:** Emergency cards pair red error fills with a warning icon and heading text, offline banners pair container tints with a `cloud_off` or `offline_bolt` icon, and language selections pair highlight colors with a checkmark icon.

---

## 3. Deaf and Hard-of-Hearing Access

- **Text and relay options appear above phone numbers:** At the top of the crisis-lines section, a translated notice (`help.crisis.deaf`) points out that 988 and Crisis Text Line support texting directly and that San Diego County's crisis line can be reached through 711 relay if speaking on a call is not possible.
- **Side-by-side text buttons:** For 988, Crisis Text Line (`741741`), and The Trevor Project (`678678`), tap-to-text buttons sit directly beside tap-to-call buttons at the same visual prominence.
- **Explicit SMS keyword confirmation:** Before opening the phone's messaging app for a keyword-triggered hotline (`HOME` or `START`), the app displays a confirmation dialog showing the number and keyword and copies the keyword if needed, since sending a blank message to an automated shortcode can fail to start a session.
- **No audio-only cues:** No feature in the app depends on sound effects or spoken prompts, and the period countdown is entirely visual and text-based.
- **Silent ongoing notifications:** `ScheduleNotificationManager.kt` registers the countdown channel with `IMPORTANCE_LOW`, which prevents period transitions from playing alert tones or vibrating during class.
- **Embedded video captions:** Westview Newscast videos play from the channel's YouTube page inside a WebView, so closed captions depend on the caption tracks the Newscast team uploads to YouTube (see Section 7).

---

## 4. Screen Readers (TalkBack and VoiceOver)

- **Labeled controls:** Icon buttons, action buttons, and floating action buttons provide either a `tooltip` or an explicit `Semantics` label so screen readers never announce an unlabeled button.
- **Digit-by-digit 911 label:** The emergency button wraps its child in `Semantics(button: true, label: '..., 9 1 1')` so TalkBack and VoiceOver read "nine one one" rather than "nine hundred eleven."
- **Grouped schedule rows:** Each period card uses `Semantics(container: true, excludeSemantics: true)` to combine the period label, custom class name, teacher/room details, and start–end times into a single spoken sentence rather than four separate focus stops.
- **Stable countdown announcements:** The per-second visual timer is hidden from the accessibility tree so TalkBack does not interrupt itself every second; instead, the summary card exposes a single semantic label stating the remaining minutes and end time.
- **Heading and selection states:** Section titles declare `Semantics(header: true)` for heading-by-heading navigation, `SectionSelector` marks its pills with `button: true` and `selected: ...`, and `SavedCopyNotice` announces the saved date alongside `"Pull down to refresh."`

---

## 5. Motor Access, Low Vision, and Clear Language

- **Font scaling up to 200%:** `lib/main.dart` clamps `MediaQuery.textScaler` between `0.85` and `2.0`. Supporting up to `2.0` honors large system text settings while preventing extreme scale multipliers from pushing emergency phone buttons off the viewport.
- **Unclipped safety text:** Crisis descriptions, counselor cards, and disclaimers avoid fixed `maxLines` limits so enlarged text wraps onto additional lines instead of truncating with ellipses.
- **Generous touch targets:** Interactive controls enforce a minimum 48dp height across the app, while the 911 emergency button uses a 56dp full-width target to reduce mis-taps under stress.
- **Reduced motion:** `lib/theme/theme.dart` checks `MediaQuery.maybeDisableAnimationsOf(context)` inside `_AccessiblePageTransitionsBuilder` and switches route transitions to instant swaps when system animations are disabled, while `reducedMotionFor` in `lib/main.dart` zeroes out in-app animation durations.
- **Plain descriptions over clinical acronyms:** Crisis-line descriptions explain what each service helps with in everyday words (for example, explaining mobile crisis response in plain sentences rather than leaving acronyms like "MCRT" or "ACL" unexplained), and phone numbers include spaces or hyphens so they are easier to read aloud.
- **No timed prompts:** Banners, dialogs, and navigation flows never auto-dismiss on a timer. Quick exit uses a long-press shortcut on Help buttons, and the same settings remain reachable through standard taps in Settings.

---

## 6. Automated Accessibility Checks

`test/l10n_test.dart` and `tools/check_strings.py` verify localization and layout rules on every test run:

- All five language maps (`en`, `es`, `zh`, `tl`, `fr`) contain identical, non-empty key sets.
- Every `help.*` and `disclaimer.*` key (apart from shared proper-noun constants) differs from English in `es`, `zh`, and `tl`, preventing untranslated safety copy from slipping through.
- Every hotline defined in `lib/support.dart` has matching name, description, call, and SMS keys across all five languages.
- Every literal `strings['...']` lookup in `lib/` resolves to an existing key in `lib/l10n/strings.dart`.
- Locale resolution maps `fil` to `tl`, falls back cleanly for unsupported tags, and persists explicit language selections.
- `SupportPage` renders without overflow or layout exceptions in all five languages and at **200% text scale** in Spanish.
- The 911 action exposes its `"..., 9 1 1"` screen-reader label in the semantics tree.

Separately, `python3 tools/audit_contrast.py --strict` verifies light and dark contrast ratios and colorblind separation before CI builds the APK.

---

## 7. Known Gaps and Follow-Up Work

| Gap | Effect on Users | Planned Follow-Up |
| --- | --- | --- |
| No manual TalkBack or VoiceOver walkthrough recorded yet | Reading order is tested structurally in widget tests rather than by ear on a phone | Run a full TalkBack pass on a physical Android device and document any focus-order fixes in `docs/` |
| Simplified Chinese (`zh`) strings have not had native-speaker review | Phrasing is accurate in meaning but may sound stiff in places | Ask a fluent Chinese-speaking Westview student or staff member to review the `zh` map in `lib/l10n/strings.dart` |
| Filipino (`tl`) uses Tagalog phrasing rather than Ilocano or Cebuano | Students whose home language is another Philippine language will rely on Tagalog or English | Keep English available alongside `tl` and expand only if native reviewers are available |
| French (`fr`) strings have not had native-speaker review | Wording follows standard metropolitan French and should read correctly, though phrasing may sound formal to some students | Ask a fluent French-speaking student or staff member to review the `fr` map in `lib/l10n/strings.dart` |
| Embedded newsletters and publications are English-only | WebViews show external school pages as published | Suggest short multilingual summaries to ASB or counseling; cannot be solved inside the app alone |
| Newscast videos may lack closed captions | Deaf and hard-of-hearing students cannot follow uncaptioned broadcasts | Ask the Westview Newscast editors to enable YouTube's automatic captions or upload their own |
| No dedicated high-contrast (`forced-colors`) theme yet | Users needing contrast well above WCAG AA rely on standard light/dark palettes | Add `highContrastLight` and `highContrastDark` `ThemeData` variants in `lib/theme/theme.dart` |
| Tablet landscape layout at 200% text scale is untested | Dialogs with open keyboards could crowd vertical space on wide screens | Add widget tests covering an `800x1280` landscape viewport at `2.0` text scale |

`tools/render_mockups.py` renders preview mockups from `lib/theme/colors.dart` and `lib/l10n/strings.dart` and writes them to `docs/screenshots/`, including `get-help-spanish.png`, `language-picker.png`, `get-help-deuteranopia.png`, and `palette-simulated.png`.
