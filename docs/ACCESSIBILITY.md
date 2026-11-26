# Accessibility

Westview HS (WVAA) is used by whoever happens to need it — a student with low
vision, a parent who reads Spanish at home, a deaf student in a loud hallway, a
student whose phone is set to giant text. The app is built so that none of those
students has to ask anyone for help to use it.

This document records **what is implemented, where it lives, and what is still
missing**, so a future maintainer does not undo it by accident.

---

## 1. Languages

| Language | Code | Scope |
| --- | --- | --- |
| English | `en` | Complete |
| Spanish | `es` | Complete |
| Simplified Chinese | `zh` | Complete |
| Filipino / Tagalog | `tl` | Complete |

**Every screen the app draws itself is translated**, including every
safety-critical string: the 911 card, all six crisis lines, the counselor
roster, reporting guidance, the district disclaimer, the Settings screen, the
navigation bar, loading/error/empty states, the calendar and lunch-menu labels,
and the SMS confirmation dialog.

`lib/l10n/strings.dart` holds the catalogue:

- `AppLanguage` — `system`, `english`, `spanish`, `chinese`, `tagalog`, with
  BCP-47 codes and a `resolve(Locale)` that maps the device locale (`fil` →
  `tl`).
- `AppStrings` — a plain lookup with `operator []`. A missing key **falls back
  to English**, and then to the key name itself, so a typo is visible in tests
  instead of rendering a blank label on a safety screen.
- `AppStrings.of(context)` resolves `AppSettings.instance.language` first, then
  the device locale, so an explicit choice pins the app and `System default`
  follows the phone.

Why hand-rolled instead of `intl`/ARB generation: there is no build-time code
generation in this repo, the catalogue is small enough to review by hand, and
`flutter test` (not a `build_runner` step) enforces it. `flutter_localizations`
*is* included, so Material's own widgets (date pickers, "Back", the text
selection menu, semantic announcements) are translated too.

**Picker design.** Settings ▸ Safety ▸ *Language · Idioma · 语言 · Wika* opens a
sheet where every option is labelled in all four languages
(`Español · Spanish · 西班牙语 · Espanyol`), so a student who cannot yet read the
current UI language can still find theirs. A shared family phone can pin a
language; `System default` returns to the phone's setting.

**Android below the app.** `android/app/src/main/res/values-{es,zh,tl}/strings.xml`
translate the launcher and home-screen-widget labels, and
`res/xml/locale_config.xml` opts into Android 13+'s per-app language picker
(*Settings ▸ Apps ▸ Westview HS ▸ Language*). iOS declares the same four
languages via `CFBundleLocalizations`.

### What is *not* translated, deliberately

The embedded WebViews (newsletters, publications, Nexus, Vimeo) render the
school's own pages in whatever language those pages use. The app cannot
translate third-party content, and it must not fake a translation of a legal
disclaimer — so the PUSD-required English and Spanish disclaimer wording is
shown **verbatim**, with the app's own plain-language explanation translated
underneath plus a note that the official wording governs.

---

## 2. Colour and vision

- **Never colour alone (WCAG 1.4.1).** The current period is marked by a
  `primaryContainer` tint **plus** a play glyph **plus** the word "Now" — see
  `_NowBadge` in `lib/schedule_page.dart`. The live period row repeats the
  glyph. Status is legible in greyscale and in bright sunlight.
- **Contrast.** `tools/audit_contrast.py` checks every text/background pair the
  app actually uses against WCAG AA. Current results (worst case):

  | Pair | Light | Dark | AA (4.5:1) |
  | --- | --- | --- | --- |
  | body on surface | 16.31:1 | 14.42:1 | pass |
  | onSurfaceVariant on surface | 8.87:1 | — | pass |
  | onPrimary on primary | 6.47:1 | 9.41:1 | pass |
  | primary text on surface | 6.14:1 | — | pass |
  | onErrorContainer on errorContainer | 13.26:1 | 7.24:1 | pass |
  | outline (borders) | 4.26:1 | 6.11:1 | pass |

  Run `python3 tools/audit_contrast.py` (or `--strict` in CI) after touching
  `lib/theme/colors.dart`.
- **Colour-blind safe palette.** The brand gold/brass and the red error family
  were simulated under deuteranopia, protanopia and tritanopia
  (`tools/audit_contrast.py --simulate`, images in `docs/screenshots/`). The
  "now" card stays distinguishable from a normal card by ΔE ≥ 20 in every
  simulation (light) and ≥ 63 (dark), and it additionally carries text and a
  glyph, so even a total loss of colour is not a loss of meaning.
- **Icons always accompany colour**: warning triangle + text on the emergency
  card, cloud-off + text on offline notices, check + text on selected options.

---

## 3. Deaf and hard of hearing

- **Every crisis option has a non-voice route**, and the app says so *before*
  listing phone numbers: the note above the hotline list ("Hard of hearing, or
  can't speak on the phone? … 988 and the Crisis Text Line are text-first, and
  San Diego County's line can be reached through a relay operator: dial 711.")
  is a normally-translated catalogue key (`help.crisis.deaf`).
- Tap-to-text is a first-class action, not a footnote: 988, Crisis Text Line
  (741741), and The Trevor Project (678678) all have text buttons next to the
  call buttons.
- The SMS flow **shows the trigger word** (`HOME`, `START`) and asks for
  confirmation before opening the messaging app, because sending the wrong word
  to a crisis line is a silent failure that looks like being ignored.
- **No audio is required anywhere.** Nothing in the app speaks, plays a tone, or
  relies on a ringtone. The live countdown is visual and textual.
- **Notifications are silent by design**: the channel is created with
  `IMPORTANCE_LOW`, so the period-change notification never makes a sound or
  vibrates in class. See `ScheduleNotificationManager.kt`.
- **Video**: the Publications tab embeds Vimeo. Captions come from the source
  video, not the app — see §6 for what to tell the newscast team.

---

## 4. Screen readers (TalkBack / VoiceOver)

- Every interactive row, icon button and FAB has a `tooltip` or `semanticsLabel`;
  tooltips double as the accessibility label.
- The **911 button** is wrapped in
  `Semantics(button: true, label: 'Call 911, 9 1 1')` so the number is spoken
  digit by digit instead of "nine hundred eleven".
- Schedule period rows announce **one sentence**
  ("Period 2, Algebra 2, Mr. Smith · Rm 402, 8:00 AM – 9:40 AM") instead of
  four separate fragments, via `Semantics(container: true, excludeSemantics: true)`.
- The live countdown is **excluded** from the semantic tree (it would
  re-announce every second) and replaced by a single label that includes the
  minutes remaining and the end time.
- Section headings use `Semantics(header: true)` so TalkBack's heading navigation
  works; `SectionSelector` exposes the selected tab.
- Offline/cached banners announce "… Pull down to refresh" once.

---

## 5. Motor, low vision and cognitive load

- **Text scaling** is honoured up to **200 %** and floored at 85 %
  (`MediaQuery.textScaler.clamp` in `lib/main.dart`). The clamp exists so a
  runaway scale factor cannot push a crisis phone number off screen — every
  safety action stays reachable at the maximum size.
- **No text is clipped**: transcript, disclaimer and crisis copy never use
  `maxLines`; the always-visible disclaimer bar wraps and grows.
- **Touch targets**: 48 dp minimum everywhere, 56 dp for the 911 and primary
  crisis actions. Buttons are full-width where a mis-tap would be costly.
- **Reduced motion**: the OS "Remove animations"/"Reduce Motion" flag is read in
  `lib/main.dart` and exposed to the tree via `_ReducedMotionScope` +
  `reducedMotionFor(context, duration)`; Material's own animation-scale setting
  is respected. The app itself does not animate anything decorative.
- **Plain language** is a requirement, not a nicety: no jargon ("psychiatric
  emergency", "MCRT", "ACL") is shown without a plain-English gloss, phone
  numbers are spaced for reading aloud, and each crisis line gets a one-line
  description of what it is *for*.
- **No timers or forced flows**: nothing auto-dismisses, autoplays, or requires a
  response within N seconds. The quick-exit long-press is the only gesture
  shortcut, and every one of its outcomes is also reachable from Settings.

---

## 6. Tests that keep this true

`test/l10n_test.dart`:

- all four catalogues define exactly the same key set (no silent English
  fallback in a shipped language);
- no value is empty;
- every `help.*` and `disclaimer.*` key is present **and actually different**
  from English in `es`/`zh`/`tl`;
- every `hotline.<id>.name/desc/call/sms` key exists for every hotline;
- every catalogue lookup in `lib/` exists in the English catalogue (catches
  typo'd keys that would render as `settings.xyz`);
- language resolution (`fil` → `tl`, unknown → `en`, explicit choice wins) and
  persistence of the choice;
- the Get-help screen renders without layout exceptions in all four languages
  and at **200 % text scale** in Spanish (the longest), and asserts Spanish copy
  rather than English fallbacks;
- the 911 button's screen-reader label.

`tools/audit_contrast.py` covers colour; run it with `--strict` in CI.

---

## 7. Known gaps (and the plan)

| Gap | Impact | Plan |
| --- | --- | --- |
| No real-device TalkBack/VoiceOver pass | Semantics order is designed but not verified by ear | Test on a physical Android device with TalkBack before the next release; record the walkthrough in `docs/` |
| Chinese translations are unreviewed | Could read awkwardly to a native speaker | Have a Chinese-speaking student or staff member review `zh`; until then the catalogue is marked for review in code comments |
| Filipino (`tl`) uses the Tagalog standard, not Ilocano/Cebuano | Some Filipino students speak another language at home | Documented; `en` remains complete for everyone |
| WebView content is untranslated | Newsletters/publications are English-only | Ask ASB/counseling to publish Spanish summaries; the app cannot fix upstream content |
| No captions on the newscast | Deaf students cannot follow video | Request captions from the Westview Newscast team (Vimeo supports uploading SRT) |
| No high-contrast ("forced colours") theme | Some low-vision students need more than AA | Follows Material 3 dynamic contrast settings on Android 12+; a `highContrastTheme` is a candidate follow-up |
| Landscape large-text layout untested | Possible overflow on tablets | `flutter test` at 200 % covers the phone case; add a tablet widget test |

The mockup images in `docs/screenshots/` (rendered by `tools/render_mockups.py`
from the real colour tokens and real catalogue strings) include
`get-help-spanish.png` and `language-picker.png`.
