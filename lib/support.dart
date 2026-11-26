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
// I copied every phone number, caseload range, and email address below from
// Westview High School's counseling page on westview.powayusd.com (checked
// November 2025). Because counselor assignments can shift between school years,
// the screen always shows when this list was checked and links to the live
// counseling webpage so students know to double-check there if needed.
//
// If you update any contact here, update `support_resources_test.dart` too so
// the test suite keeps pinning the exact digits.

/// Westview High School main / counseling office line.
const String westviewMainPhone = '8587802000';
const String westviewMainPhoneDisplay = '(858) 780-2000';
const String westviewAddress = '13500 Camino del Sur, San Diego, CA 92129';

/// Live Westview counseling staff webpage.
const String westviewCounselingPageUrl =
    'https://westview.powayusd.com/apps/pages/counseling-staff';

/// Poway Unified's anonymous "See Something, Say Something" tip line, printed
/// on the back of student ID cards and monitored 24/7 by law enforcement
/// rather than mental-health counselors.
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

/// 24/7 support lines. I put the free, confidential youth crisis lines ahead
/// of the law-enforcement tip line so support resources show up first.
const List<Hotline> crisisHotlines = <Hotline>[
  Hotline(
    id: '988',
    name: '988 Suicide & Crisis Lifeline',
    description:
        'Free, confidential 24/7 support by phone or text for anyone '
        'experiencing emotional distress or a suicidal crisis.',
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
        'San Diego County\'s 24/7 line for mental health or substance-use '
        'crises affecting you or someone you know, with free interpreters in '
        'over 200 languages and mobile crisis response teams when needed.',
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
        'Connects you by text with a trained crisis counselor at any hour if '
        'typing is easier than speaking on a call. Free and confidential.',
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
        'Free, confidential 24/7 crisis and suicide-prevention support for '
        'LGBTQ+ youth by phone or text.',
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
        'Anonymous reporting line run by Sandy Hook Promise and answered by '
        'crisis counselors for threats, weapons, or concern that a classmate '
        'may be at risk of harm.',
    callNumber: '18445729669',
    callDisplay: 'Call 1-844-5-SAYNOW',
    website: 'https://www.saysomething.net/',
    websiteLabel: 'saysomething.net',
  ),
  Hotline(
    id: 'pusdtip',
    name: 'PUSD "See Something, Say Something" Tip Line',
    description:
        'Poway Unified\'s 24-hour anonymous tip line monitored by law '
        'enforcement for campus threats and safety concerns (also printed on '
        'the back of student IDs).',
    callNumber: pusdTipLine,
    callDisplay: 'Call $pusdTipLineDisplay',
  ),
];

// ===========================================================================
// Launcher helpers (fall back cleanly without crashing if no app can open)
// ===========================================================================

/// Opens [uri] in the external dialer, messaging app, mail app, or browser.
///
/// If the phone doesn't have an app installed for that URI, this shows the
/// number or address on screen and copies it so you don't hit a dead end.
Future<bool> _launch(BuildContext context, Uri uri) async {
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return true;
  } catch (_) {
    // Fall through to the copyable dialog below.
  }
  if (context.mounted) {
    await _showManualFallback(context, uri);
  }
  return false;
}

/// Backup dialog that displays and copies the number or address when launching
/// an external app fails.
Future<void> _showManualFallback(BuildContext context, Uri uri) async {
  final dial = uri.path.isEmpty ? uri.toString() : uri.path;
  try {
    await Clipboard.setData(ClipboardData(text: dial));
  } catch (_) {
    // Even if clipboard access fails, the dialog still displays the text.
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

/// Opens the phone's messaging app with the hotline's keyword filled in.
///
/// Automated text lines expect a specific keyword like `HOME` or `START` to
/// open a chat, so showing a quick confirmation dialog first keeps someone
/// from accidentally erasing the keyword and getting no response.
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
  // Pre-fill the subject line in the current app language so a student doesn't
  // have to write a subject from scratch first.
  final subject = AppStrings.of(context)['help.counselor.emailSubject'];
  final uri = Uri(
    scheme: 'mailto',
    path: counselor.email,
    queryParameters: <String, String>{'subject': subject},
  );
  final opened = await _launch(context, uri);
  if (!opened && context.mounted) {
    // If no mail app is configured on the phone, copy the address so they can
    // still paste it into webmail.
    try {
      await Clipboard.setData(ClipboardData(text: counselor.email));
    } catch (_) {}
  }
}

/// Pushes the Get help screen onto the navigator from the Schedule button,
/// tab headers, or Settings.
Future<void> openSupportPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const SupportPage()),
  );
}

/// Help button placed in tab headers across the app.
class HelpIconButton extends StatelessWidget {
  const HelpIconButton({super.key, this.tooltip});

  /// Defaults to the translated "Get help now" label.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    // Only include the hold-to-exit hint in the tooltip when quick exit is on.
    final base = tooltip ?? strings['help.iconTooltip'];
    final label = SafetySettings.instance.quickExitEnabled
        ? strings['help.iconTooltipQuickExit'].replaceFirst('%s', base)
        : base;
    return GestureDetector(
      // Holding down triggers quick exit immediately without a confirmation
      // popup (`HitTestBehavior.opaque` makes the icon padding count too).
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
// Get help screen
// ===========================================================================

/// Support screen with Westview counselors, 24/7 crisis lines, anonymous
/// reporting links, and the Poway Unified disclaimer.
///
/// Key choices here:
///  * Nothing sits behind a login or network call; all contact numbers are
///    compiled into the app so they still load when campus Wi-Fi drops.
///  * Calls, texts, and emails hand off to the phone's own apps, so WVAA never
///    sees call audio or message text.
///  * I don't import `telemetry.dart` in this file at all so opening Get help
///    is never logged.
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
          // 48dp targets for both buttons, with explicit labels for TalkBack.
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

/// One-line disclaimer shown in the pinned bottom bar and first-launch dialog.
const String shortDisclaimer =
    'Not a Poway Unified app. Built independently by students and not '
    'sponsored or endorsed by Poway Unified School District or Westview High '
    'School.';
