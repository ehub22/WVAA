import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'network_cache.dart';
import 'safety.dart';
import 'settings.dart';
import 'support.dart';
import 'telemetry.dart';

/// Settings screen opened from the gear button on the Schedule tab.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return ListenableBuilder(
      // Merge both notifiers so flipping a safety switch or a class setting
      // updates this list right away.
      listenable: Listenable.merge([settings, SafetySettings.instance]),
      builder: (context, _) {
        final safety = SafetySettings.instance;
        final t = AppStrings.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(t['settings.title'])),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _SectionHeader(t['settings.notifications']),
                SwitchListTile(
                  value: settings.notificationsEnabled,
                  onChanged: (value) => settings.setNotificationsEnabled(value),
                  title: Text(t['settings.notifications']),
                  subtitle: Text(t['settings.notificationsSub']),
                  secondary: const Icon(Icons.notifications_outlined),
                ),
                SwitchListTile(
                  value: settings.liveActivityActive,
                  onChanged: settings.notificationsEnabled
                      ? (value) => settings.setLiveActivityEnabled(value)
                      : null,
                  title: Text(t['settings.liveActivity']),
                  subtitle: Text(
                    settings.notificationsEnabled
                        ? t['settings.liveOn']
                        : t['settings.liveOff'],
                  ),
                  secondary: const Icon(Icons.timer_outlined),
                ),

                const Divider(height: 32),

                _SectionHeader(t['settings.safety']),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: Text(t['settings.getHelp']),
                  subtitle: Text(t['settings.getHelpSub']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openSupportPage(context),
                ),
                SwitchListTile(
                  value: safety.quickExitEnabled,
                  onChanged: SafetySettings.instance.setQuickExitEnabled,
                  title: Text(t['settings.quickExit']),
                  subtitle: Text(t['settings.quickExitSub']),
                  secondary: const Icon(Icons.exit_to_app),
                ),
                SwitchListTile(
                  value: safety.hideRecents,
                  onChanged: SafetySettings.instance.setHideRecents,
                  title: Text(t['settings.hideRecents']),
                  subtitle: Text(t['settings.hideRecentsSub']),
                  secondary: const Icon(Icons.visibility_off_outlined),
                ),
                Semantics(
                  button: true,
                  child: ListTile(
                    leading: const Icon(Icons.translate),
                    // Show all four language names in the row title so someone
                    // can still find this setting if the app was left in a
                    // language they don't read.
                    title: const Text('Language · Idioma · 语言 · Wika'),
                    subtitle: Text(
                      AppSettings.instance.language == AppLanguage.system
                          ? t['settings.langSystem']
                          : AppSettings.instance.language.pluralLabel,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickLanguage(context),
                  ),
                ),

                _SectionHeader(t['settings.privacy']),
                SwitchListTile(
                  value: settings.analyticsEnabled,
                  onChanged: (value) => settings.setAnalyticsEnabled(value),
                  title: Text(t['settings.analytics']),
                  subtitle: Text(t['settings.analyticsSub']),
                  secondary: const Icon(Icons.insights_outlined),
                ),
                SwitchListTile(
                  value: settings.crashReportingEnabled,
                  onChanged: (value) => settings.setCrashReportingEnabled(value),
                  title: Text(t['settings.crash']),
                  subtitle: Text(t['settings.crashSub']),
                  secondary: const Icon(Icons.bug_report_outlined),
                ),
                const _PrivacyDisclosure(),

                const Divider(height: 32),

                _SectionHeader(t['settings.savedContent']),
                ListTile(
                  leading: const Icon(Icons.download_done_outlined),
                  title: Text(t['settings.clear']),
                  subtitle: Text(t['settings.clearSub']),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () => _clearCachedContent(context),
                ),

                const Divider(height: 32),

                _SectionHeader(t['settings.classDetails']),
                SwitchListTile(
                  value: settings.showTeacher,
                  onChanged: (value) => settings.setShowTeacher(value),
                  title: Text(t['settings.showTeacher']),
                  subtitle: Text(t['settings.showTeacherSub']),
                  secondary: const Icon(Icons.person_outline),
                ),
                SwitchListTile(
                  value: settings.showRoom,
                  onChanged: (value) => settings.setShowRoom(value),
                  title: Text(t['settings.showRoom']),
                  subtitle: Text(t['settings.showRoomSub']),
                  secondary: const Icon(Icons.meeting_room_outlined),
                ),

                const Divider(height: 32),

                _SectionHeader(t['settings.myClasses']),
                for (final name in customizablePeriodNames)
                  _PeriodTile(canonicalName: name),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmReset(context),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(t['settings.resetClasses']),
                  ),
                ),
                const _AboutAppFooter(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Bottom sheet for switching the app language. Each option shows its native
  /// name alongside all four language names on the subtitle line.
  Future<void> _pickLanguage(BuildContext context) async {
    final current = AppSettings.instance.language;
    final t = AppStrings.of(context);
    final choice = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                header: true,
                child: Text(
                  t['settings.langPickTitle'],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final language in AppLanguage.values)
              ListTile(
                // Every entry is legible from any starting language: its own
                // name first, then all four names on the subtitle line.
                title: Text(language.nativeName),
                subtitle: language == AppLanguage.system
                    ? null
                    : Text(language.pluralLabel),
                trailing: language == current
                    ? Icon(Icons.check, semanticLabel: t['common.selected'])
                    : null,
                selected: language == current,
                onTap: () => Navigator.of(context).pop(language),
              ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await AppSettings.instance.setLanguage(choice);
    }
  }

  Future<void> _clearCachedContent(BuildContext context) async {
    await NetworkCache.instance.clearAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context)['settings.cleared'])),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final t = AppStrings.of(context);
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t['settings.resetTitle']),
        content: Text(t['settings.resetBody']),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t['settings.cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t['settings.reset']),
          ),
        ],
      ),
    );
    if (shouldReset ?? false) {
      await AppSettings.instance.resetPeriods();
    }
  }
}

/// Footer at the bottom of Settings showing the full English and Spanish
/// Poway Unified disclaimers and what the app does not monitor.
class _AboutAppFooter extends StatelessWidget {
  const _AboutAppFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          _SectionHeader(t['settings.about']),
          Text(
            t['disclaimer.title'],
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            disclaimers.english,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            disclaimers.spanish,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t['settings.verified'],
            style: textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            t['settings.notCrisis'],
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t['disclaimer.translationNote'],
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card under Privacy & data summarizing what optional diagnostics send.
class _PrivacyDisclosure extends StatelessWidget {
  const _PrivacyDisclosure();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
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
              Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.of(context)['settings.collectTitle'],
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${AppStrings.of(context)['settings.collectBody']} '
                '(${Uri.parse(telemetryEndpoint).host})',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          // Uppercasing is a Latin-script convention and reads badly in
          // Chinese; leave CJK headings as written.
          _isCjk(title) ? title : title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }

  static bool _isCjk(String value) =>
      RegExp(r'[\u4e00-\u9fff]').hasMatch(value);
}

/// One editable period in the "My classes" list.
class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.canonicalName});

  final String canonicalName;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final t = AppStrings.of(context);
    final periodSettings = settings.periodSettings(canonicalName);
    final details = <String>[
      if (periodSettings.teacher.isNotEmpty) periodSettings.teacher,
      if (periodSettings.room.isNotEmpty)
        '${t['settings.roomShort']} ${periodSettings.room}',
    ].join(' · ');

    final subtitle = <String>[
      if (settings.isRenamed(canonicalName)) canonicalName,
      if (details.isNotEmpty) details,
    ].join(' · ');

    return ListTile(
      title: Text(settings.displayName(canonicalName)),
      subtitle: Text(
        subtitle.isEmpty ? t['settings.tapToAdd'] : subtitle,
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _editPeriod(context),
    );
  }

  Future<void> _editPeriod(BuildContext context) async {
    final settings = AppSettings.instance;
    final result = await showDialog<PeriodSettings>(
      context: context,
      builder: (context) => _EditPeriodDialog(
        canonicalName: canonicalName,
        initial: settings.periodSettings(canonicalName),
      ),
    );
    if (result != null) {
      await settings.setPeriodSettings(canonicalName, result);
    }
  }
}

class _EditPeriodDialog extends StatefulWidget {
  const _EditPeriodDialog({required this.canonicalName, required this.initial});

  final String canonicalName;
  final PeriodSettings initial;

  @override
  State<_EditPeriodDialog> createState() => _EditPeriodDialogState();
}

class _EditPeriodDialogState extends State<_EditPeriodDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initial.customName);
  late final TextEditingController _teacherController =
      TextEditingController(text: widget.initial.teacher);
  late final TextEditingController _roomController =
      TextEditingController(text: widget.initial.room);

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return AlertDialog(
      title: Text(widget.canonicalName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t['settings.editClass'],
                helperText: t['settings.leaveEmpty'],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teacherController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: t['settings.teacher']),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: t['settings.room']),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const PeriodSettings()),
          child: Text(t['settings.clearField']),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t['settings.cancel']),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            PeriodSettings(
              customName: _nameController.text.trim(),
              teacher: _teacherController.text.trim(),
              room: _roomController.text.trim(),
            ),
          ),
          child: Text(t['settings.save']),
        ),
      ],
    );
  }
}
