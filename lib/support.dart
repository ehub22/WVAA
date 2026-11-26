import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/strings.dart';
import 'safety.dart';
import 'settings.dart';

// ===========================================================================
// Verified contact data
// ===========================================================================
//
// Every number, caseload and e-mail address below was copied from the
// Westview High School counseling page on westview.powayusd.com
// (verified November 2025). Caseloads and staff change from year to year, so the UI
// always shows a "verify this list" note and links to the live page, and the
// screen never pretends to be the school's system of record.
//
// If you change a value here, update `support_resources_test.dart` too — the
// tests pin the hotline digits so a typo can't silently ship to students.

/// Westview High School main / counseling office line.
const String westviewMainPhone = '8587802000';
const String westviewMainPhoneDisplay = '(858) 780-2000';
const String westviewAddress = '13500 Camino del Sur, San Diego, CA 92129';

/// Where the live, authoritative counselor list lives.
const String westviewCounselingPageUrl =
    'https://westview.powayusd.com/apps/pages/counseling-staff';

/// The district's anonymous "See Something, Say Something" tip line, printed
/// on the back of every secondary student ID card. Monitored 24/7 by law
/// enforcement (not a mental-health line).
const String pusdTipLine = '18447873747'; // 1-844-PUSD-TIP
const String pusdTipLineDisplay = '1-844-PUSD-TIP';

/// Date the contact data below was last checked against the school website.
const String supportDataVerified = 'November 2025';

@immutable
class Counselor {
  const Counselor({
    required this.name,
    required this.caseload,
    required this.email,
    required this.extension,
  });

  final String name;

  /// Last-name range the counselor covers, e.g. `A–C`.
  final String caseload;
  final String email;
  final String extension;

  String get phoneDisplay => '$westviewMainPhoneDisplay ext $extension';

  /// `tel:` URI with the extension encoded as a dial pause (`;` → `%3B`),
  /// which both Android and iOS dialers understand.
  Uri get phoneUri => Uri(
        scheme: 'tel',
        path: '$westviewMainPhone;ext=$extension',
      );
}

/// Counselors by student last name, straight from the school's counseling page.
const List<Counselor> westviewCounselors = <Counselor>[
  Counselor(
    name: 'Taylor Oakley',
    caseload: 'A–C',
    email: 'toakley@powayusd.com',
    extension: '3080',
  ),
  Counselor(
    name: 'Isabella Rusy',
    caseload: 'D–J',
    email: 'irusy@powayusd.com',
    extension: '3062',
  ),
  Counselor(
    name: 'Christine Cudmore',
    caseload: 'K–M',
    email: 'ccudmore@powayusd.com',
    extension: '3030',
  ),
  Counselor(
    name: 'Adriana Chittuluru',
    caseload: 'N–Sh',
    email: 'achittuluru@powayusd.com',
    extension: '3026',
  ),
  Counselor(
    name: 'Vicki deJesus',
    caseload: 'Si–Z',
    email: 'vdejesus@powayusd.com',
    extension: '3023',
  ),
];

/// College & career support (not a crisis resource, but students look for it
/// in the same place, so it sits at the bottom of the counselor list).
const String collegeCareerTechName = 'Danielle Beccarelli';
const String collegeCareerTechEmail = 'dbeccarelli@powayusd.com';
const String collegeCareerTechExtension = '3019';

@immutable
class Hotline {
  const Hotline({
    required this.id,
    required this.name,
    required this.description,
    this.callNumber,
    this.callDisplay,
    this.smsNumber,
    this.smsBody,
    this.smsDisplay,
    this.website,
    this.websiteLabel,
  });

  final String id;
  final String name;
  final String description;
  final String? callNumber;
  final String? callDisplay;
  final String? smsNumber;
  final String? smsBody;
  final String? smsDisplay;
  final String? website;
  final String? websiteLabel;

  Uri? get callUri =>
      callNumber == null ? null : Uri(scheme: 'tel', path: callNumber);
  Uri? get smsUri => smsNumber == null
      ? null
      : Uri(scheme: 'sms', path: smsNumber, queryParameters: <String, String>{
          if (smsBody != null) 'body': smsBody!,
        });
  Uri? get websiteUri => website == null ? null : Uri.parse(website!);

  /// Translated display name.
  String nameFor(AppStrings strings) => strings['hotline.$id.name'];

  /// Translated one-line description.
  String descriptionFor(AppStrings strings) => strings['hotline.$id.desc'];

  /// Translated action label (`Call 988`, `Text HOME to 741741`, …).
  String callLabelFor(AppStrings strings) => strings['hotline.$id.call'];
  String smsLabelFor(AppStrings strings) => strings['hotline.$id.sms'];
}

/// 24/7 support lines. Order matters: the free, confidential, youth-focused
/// options come before the law-enforcement-monitored tip line.
const List<Hotline> crisisHotlines = <Hotline>[
  Hotline(
    id: '988',
    name: '988 Suicide & Crisis Lifeline',
    description:
        'Free, confidential support for anyone in emotional distress or '
        'suicidal crisis. Call or text any time, day or night.',
    callNumber: '988',
    callDisplay: 'Call 988',
    smsNumber: '988',
    smsBody: 'HELLO',
    smsDisplay: 'Text 988',
    website: 'https://988lifeline.org/',
    websiteLabel: '988lifeline.org',
  ),
  Hotline(
    id: 'sdaocl',
    name: 'San Diego Access & Crisis Line',
    description:
        'San Diego County’s 24/7 line for mental health and substance use '
        'crises, for you or someone you’re worried about. Free interpreters '
        'in 200+ languages. They can also send a Mobile Crisis Response Team.',
    callNumber: '18887247240',
    callDisplay: 'Call 1-888-724-7240',
    website: 'https://www.sandiegocounty.gov/content/sdc/hhsa/programs/bhs/'
        'access_crisis_line.html',
    websiteLabel: 'County crisis line info',
  ),
  Hotline(
    id: 'crisistext',
    name: 'Crisis Text Line',
    description:
        'Prefer typing to talking? Text a trained volunteer about anything '
        'that’s weighing on you. Free, 24/7, and confidential.',
    smsNumber: '741741',
    smsBody: 'HOME',
    smsDisplay: 'Text HOME to 741741',
    website: 'https://www.crisistextline.org/',
    websiteLabel: 'crisistextline.org',
  ),
  Hotline(
    id: 'trevor',
    name: 'The Trevor Project',
    description:
        'Crisis and suicide-prevention support for LGBTQ+ young people, '
        '24/7. You deserve to be taken seriously.',
    callNumber: '18664887386',
    callDisplay: 'Call 1-866-488-7386',
    smsNumber: '678678',
    smsBody: 'START',
    smsDisplay: 'Text START to 678678',
    website: 'https://www.thetrevorproject.org/get-help/',
    websiteLabel: 'thetrevorproject.org',
  ),
  Hotline(
    id: 'sandyhook',
    name: 'Say Something Anonymous Reporting',
    description:
        'Anonymous way to report threats, weapons, or someone who may be in '
        'danger — run by Sandy Hook Promise and answered by crisis counselors. '
        'Good for “I’m worried about a classmate,” not just emergencies.',
    callNumber: '18445729669',
    callDisplay: 'Call 1-844-5-SAYNOW',
    website: 'https://www.saysomething.net/',
    websiteLabel: 'saysomething.net',
  ),
  Hotline(
    id: 'pusdtip',
    name: 'PUSD “See Something, Say Something” Tip Line',
    description:
        'Poway Unified’s 24-hour anonymous tip line, monitored by law '
        'enforcement, for school threats and safety concerns. The number is '
        'on the back of your student ID.',
    callNumber: pusdTipLine,
    callDisplay: 'Call $pusdTipLineDisplay',
  ),
];

// ===========================================================================
// Launcher helpers (every action fails soft — never crashes, never blocks)
// ===========================================================================

/// Opens [uri] in the right external app (dialer, SMS composer, browser).
///
/// Fails soft: if nothing can handle the URI the student gets the number to
/// dial manually instead of a dead end. Never throws.
Future<bool> _launch(BuildContext context, Uri uri) async {
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return true;
  } catch (_) {
    // Fall through to the manual fallback below.
  }
  if (context.mounted) {
    await _showManualFallback(context, uri);
  }
  return false;
}

/// Last-resort helper: shows the number (or address) and copies it, so the
/// student can still make contact if no app could be launched.
Future<void> _showManualFallback(BuildContext context, Uri uri) async {
  final dial = uri.path.isEmpty ? uri.toString() : uri.path;
  try {
    await Clipboard.setData(ClipboardData(text: dial));
  } catch (_) {
    // Clipboard unavailable — the dialog still shows the number.
  }
  if (!context.mounted) return;
  final strings = AppStrings.of(context);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(strings['common.copyNumber']),
      content: SelectableText(
        dial,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings['common.close']),
        ),
      ],
    ),
  );
}

Future<void> callNumber(BuildContext context, Uri uri) =>
    _launch(context, uri);

/// Composes an SMS in the student's own messaging app.
///
/// For the crisis lines the app pre-fills the trigger word the service expects
/// (HOME, START, …) but *shows it* first: sending the wrong word to a crisis
/// line is a silent failure that looks like being ignored, so the student gets
/// one tap to confirm or edit what will be sent.
Future<void> sendSms(
  BuildContext context,
  Uri uri, {
  String? prefilledBody,
  String? serviceName,
}) async {
  if (prefilledBody == null) {
    await _launch(context, uri);
    return;
  }

  final strings = AppStrings.of(context);
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(strings['sms.confirmTitle']),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serviceName == null
                ? (uri.path.isEmpty
                    ? 'To your messaging app:'
                    : 'To ${uri.path}:')
                : '$serviceName (${uri.path})',
          ),
          const SizedBox(height: 8),
          SelectableText(
            prefilledBody,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            strings['sms.editNote'],
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings['common.cancel']),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings['sms.openApp']),
        ),
      ],
    ),
  );

  if (proceed != true) return;
  if (!context.mounted) return;
  await _launch(context, uri);
}

Future<void> openWebsite(BuildContext context, Uri uri) =>
    _launch(context, uri);

Future<void> emailCounselor(
  BuildContext context,
  Counselor counselor,
) async {
  // The subject line is pre-filled in the student's language: they can send
  // it without composing anything in a language they may not read well.
  final subject = AppStrings.of(context)['help.counselor.emailSubject'];
  final uri = Uri(
    scheme: 'mailto',
    path: counselor.email,
    queryParameters: <String, String>{'subject': subject},
  );
  final opened = await _launch(context, uri);
  if (!opened && context.mounted) {
    // Some devices have no mail app configured: at least let them copy the
    // address instead of hitting a dead end.
    try {
      await Clipboard.setData(ClipboardData(text: counselor.email));
    } catch (_) {}
  }
}

/// Opens the in-app help screen. Reached from the Help button on the schedule,
/// the Help icon in the Newsletters/Publications/Calendars headers, and
/// Settings, so a student never has to hunt for it.
Future<void> openSupportPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const SupportPage()),
  );
}

/// Compact help entry point for any app bar.
class HelpIconButton extends StatelessWidget {
  const HelpIconButton({super.key, this.tooltip});

  /// Defaults to the translated "Get help now".
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    // The quick-exit hint is appended only when the gesture is actually
    // enabled, and in the reader's own language.
    final base = tooltip ?? strings['help.iconTooltip'];
    final label = SafetySettings.instance.quickExitEnabled
        ? strings['help.iconTooltipQuickExit'].replaceFirst('%s', base)
        : base;
    return GestureDetector(
      // Long-press = quick exit (see safety.dart). No confirmation: the whole
      // point is that it is instant. Opaque so the glyph's transparent padding
      // still counts as part of the button.
      behavior: HitTestBehavior.opaque,
      onLongPress: QuickExit.longPressHandler(context),
      child: IconButton(
        tooltip: label,
        icon: const Icon(Icons.support_agent),
        onPressed: () => openSupportPage(context),
      ),
    );
  }
}

// ===========================================================================
// The help screen
// ===========================================================================

/// Student-facing support screen: counselors, crisis lines, how to report a
/// safety concern, and the district disclaimer.
///
/// Design notes (deliberate, safety-driven):
///  * nothing here is hidden behind a menu, a login, or a network request —
///    all contact details are compiled into the app, so they work offline and
///    on the school's bad Wi-Fi;
///  * phone/SMS actions use the platform dialer, so no call audio or message
///    content ever touches this app;
///  * this screen is deliberately kept out of analytics: the app never
///    records that a student opened help resources, so `telemetry.dart` is
///    not imported here at all.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => _buildPage(context, AppStrings.of(context)),
    );
  }

  Widget _buildPage(BuildContext context, AppStrings strings) {
    return Scaffold(
      appBar: AppBar(
        title: Text(strings['help.title']),
        actions: [
          IconButton(
            tooltip: strings['help.counselor.website'],
            icon: const Icon(Icons.public),
            onPressed: () => openWebsite(
              context,
              Uri.parse(westviewCounselingPageUrl),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            _EmergencyCard(strings: strings),
            const SizedBox(height: 16),
            _SectionTitle(
              icon: Icons.school_outlined,
              title: strings['help.counselor.title'],
            ),
            _CounselorCard(strings: strings),
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.favorite_outline,
              title: strings['help.crisis.title'],
            ),
            // Deaf and hard-of-hearing students need to know, before reading a
            // list of phone numbers, that every line also has a text route.
            _InfoNote(
              icon: Icons.hearing_disabled,
              text: strings['help.crisis.deaf'],
            ),
            _HotlineList(strings: strings),
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.campaign_outlined,
              title: strings['help.report.title'],
            ),
            _ReportingCard(strings: strings),
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.info_outline,
              title: strings['help.about.title'],
            ),
            _DisclaimerCard(strings: strings),
          ],
        ),
      ),
    );
  }
}

/// Small inline note with an icon, used for accessibility guidance.
class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Immediately visible, above the fold: if someone is in danger right now,
/// the app should not make them scroll.
class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 22, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings['help.emergency.title'],
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings['help.emergency.body'],
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onErrorContainer, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                button: true,
                // Announce what the button dials, not just the glyph text.
                label: '${strings['help.emergency.call']}, 9 1 1',
                excludeSemantics: true,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    // Larger than the 48dp minimum: this is the one control a
                    // panicking student must hit first time.
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () =>
                      callNumber(context, Uri(scheme: 'tel', path: '911')),
                  icon: const Icon(Icons.call),
                  label: Text(
                    strings['help.emergency.call'],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings['help.emergency.note'],
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounselorCard extends StatelessWidget {
  const _CounselorCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings['help.counselor.body'],
              style: textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => callNumber(
                    context,
                    Uri(scheme: 'tel', path: westviewMainPhone),
                  ),
                  icon: const Icon(Icons.call),
                  label: Text(strings['help.counselor.callOffice']),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => openWebsite(
                    context,
                    Uri.parse(westviewCounselingPageUrl),
                  ),
                  icon: const Icon(Icons.public),
                  label: Text(strings['help.counselor.website']),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Westview High School · $westviewAddress · '
              '$westviewMainPhoneDisplay',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const Divider(height: 24),
            Semantics(
              header: true,
              child: Text(
                strings['help.counselor.find'],
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              strings['help.counselor.byLast'],
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            for (final counselor in westviewCounselors)
              _CounselorTile(counselor: counselor),
            const Divider(height: 24),
            Text(
              strings['help.counselor.career'],
              style: textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              '$collegeCareerTechName · '
              '${strings['help.counselor.careerRole']} · '
              'ext $collegeCareerTechExtension · $collegeCareerTechEmail',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              strings['help.counselor.verified'],
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounselorTile extends StatelessWidget {
  const _CounselorTile({required this.counselor});

  final Counselor counselor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              counselor.caseload,
              textAlign: TextAlign.center,
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  counselor.name,
                  style:
                      textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  counselor.phoneDisplay,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // 48dp targets for both quick actions, labelled for TalkBack.
          IconButton(
            tooltip: AppStrings.of(context)['help.counselor.callA11y']
                .replaceFirst('%s', counselor.name),
            icon: const Icon(Icons.call_outlined),
            onPressed: () => callNumber(context, counselor.phoneUri),
          ),
          IconButton(
            tooltip: AppStrings.of(context)['help.counselor.emailA11y']
                .replaceFirst('%s', counselor.name),
            icon: const Icon(Icons.mail_outline),
            onPressed: () => emailCounselor(context, counselor),
          ),
        ],
      ),
    );
  }
}

class _HotlineList extends StatelessWidget {
  const _HotlineList({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final hotline in crisisHotlines)
          _HotlineCard(hotline: hotline, strings: strings),
      ],
    );
  }
}

class _HotlineCard extends StatelessWidget {
  const _HotlineCard({required this.hotline, required this.strings});

  final Hotline hotline;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      // Each card is its own container so TalkBack reads the hotline name and
      // description before the actions — but not merged, so every call/text
      // button stays individually focusable.
      child: Semantics(
        container: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  hotline.nameFor(strings),
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hotline.descriptionFor(strings),
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 10),
              // At large text scales a side-by-side row of "Call 1-888-724-7240"
              // buttons would overflow, so the actions stack and go full width.
              LayoutBuilder(
                builder: (context, _) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(13) > 13 * 1.35;
                  final buttons = <Widget>[
                    if (hotline.callUri != null)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => callNumber(context, hotline.callUri!),
                        icon: const Icon(Icons.call),
                        label: Text(hotline.callLabelFor(strings)),
                      ),
                    if (hotline.smsUri != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => sendSms(
                          context,
                          hotline.smsUri!,
                          prefilledBody: hotline.smsBody,
                          serviceName: hotline.nameFor(strings),
                        ),
                        icon: const Icon(Icons.sms_outlined),
                        label: Text(hotline.smsLabelFor(strings)),
                      ),
                    if (hotline.websiteUri != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () =>
                            openWebsite(context, hotline.websiteUri!),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          hotline.websiteLabel ?? strings['common.website'],
                        ),
                      ),
                  ];
                  if (!largeText) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: buttons,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final button in buttons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: button,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportingCard extends StatelessWidget {
  const _ReportingCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tipLine = crisisHotlines.firstWhere((h) => h.id == 'pusdtip');
    final saySomething = crisisHotlines.firstWhere((h) => h.id == 'sandyhook');

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings['help.report.body'],
              style: textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 10),
            for (final hotline in [saySomething, tipLine])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hotline.nameFor(strings),
                            style: textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            hotline.callDisplay ?? '',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => callNumber(context, hotline.callUri!),
                      child: Text(strings['help.crisis.call']),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              strings['help.report.note'],
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// The required district disclaimer, in the exact wording Poway Unified
/// requires on materials from non-district sources (see the district's
/// "Flyers – Outside Organizations" page), plus a short plain-language
/// restatement for students.
class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings['disclaimer.title'],
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              disclaimers.english,
              style: textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              disclaimers.spanish,
              style: textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              strings['disclaimer.plain'],
              style: textTheme.bodySmall
                  ?.copyWith(height: 1.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Text(
              strings['disclaimer.crisis'],
              style: textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              strings['disclaimer.translationNote'],
              style: textTheme.bodySmall?.copyWith(
                height: 1.45,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared disclaimer strings
// ===========================================================================

/// Canonical disclaimer text. Kept in one place so the support screen, the
/// privacy/onboarding screen and the Settings footer never drift apart.
class Disclaimers {
  const Disclaimers._();

  /// Exact English wording Poway Unified requires on material produced by
  /// any non-district organization.
  String get english =>
      'DISCLAIMER: This activity is not a school-sponsored activity and is '
      'not endorsed by the school or Poway Unified School District. The '
      'products or services advertised in this flyer are not endorsed by the '
      'school or the District.';

  /// The Spanish wording the district requires on the same material.
  String get spanish =>
      'AVISO LEGAL: Esta actividad no es una actividad patrocinada por la '
      'escuela y no está avalada por la escuela ni por el Distrito Escolar '
      'Unificado de Poway. Los productos o servicios anunciados en este '
      'folleto no están respaldados por la escuela ni el Distrito.';
}

const Disclaimers disclaimers = Disclaimers._();

/// One-line version used in compact places (splash, first-run screen, app
/// bars, the schedule footer).
const String shortDisclaimer =
    'Not a Poway Unified app. Not sponsored or endorsed by Poway Unified '
    'School District or Westview High School.';
