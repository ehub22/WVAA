import 'package:flutter/material.dart';

import 'network_cache.dart';
import 'settings.dart';
import 'telemetry.dart';

/// Settings page, opened from the button in the bottom right of the home page.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const _SectionHeader('Notifications'),
                SwitchListTile(
                  value: settings.notificationsEnabled,
                  onChanged: (value) => settings.setNotificationsEnabled(value),
                  title: const Text('Notifications'),
                  subtitle: const Text(
                    'Allow Westview HS to send notifications',
                  ),
                  secondary: const Icon(Icons.notifications_outlined),
                ),
                SwitchListTile(
                  value: settings.liveActivityActive,
                  onChanged: settings.notificationsEnabled
                      ? (value) => settings.setLiveActivityEnabled(value)
                      : null,
                  title: const Text('Live activity'),
                  subtitle: Text(
                    settings.notificationsEnabled
                        ? 'Ongoing notification with a countdown to the end of '
                            'the current period'
                        : 'Turn notifications on to use the live activity',
                  ),
                  secondary: const Icon(Icons.timer_outlined),
                ),

                const Divider(height: 32),

                const _SectionHeader('Privacy & data'),
                SwitchListTile(
                  value: settings.analyticsEnabled,
                  onChanged: (value) => settings.setAnalyticsEnabled(value),
                  title: const Text('Anonymous usage statistics'),
                  subtitle: const Text(
                    'Counts of which screens are opened and whether refreshes '
                    'succeed. Never identifies you.',
                  ),
                  secondary: const Icon(Icons.insights_outlined),
                ),
                SwitchListTile(
                  value: settings.crashReportingEnabled,
                  onChanged: (value) => settings.setCrashReportingEnabled(value),
                  title: const Text('Crash reports'),
                  subtitle: const Text(
                    'Error text and stack trace when the app breaks, so it can '
                    'be fixed. Never identifies you.',
                  ),
                  secondary: const Icon(Icons.bug_report_outlined),
                ),
                const _PrivacyDisclosure(),

                const Divider(height: 32),

                const _SectionHeader('Saved content'),
                ListTile(
                  leading: const Icon(Icons.download_done_outlined),
                  title: const Text('Clear saved content'),
                  subtitle: const Text(
                    'Removes calendars, lunch menus and nutrition data saved '
                    'for offline use. They download again next time you open '
                    'them.',
                  ),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () => _clearCachedContent(context),
                ),

                const Divider(height: 32),

                const _SectionHeader('Class details'),
                SwitchListTile(
                  value: settings.showTeacher,
                  onChanged: (value) => settings.setShowTeacher(value),
                  title: const Text('Show teacher'),
                  subtitle: const Text(
                    'Show the teacher in the schedule, notification and widget',
                  ),
                  secondary: const Icon(Icons.person_outline),
                ),
                SwitchListTile(
                  value: settings.showRoom,
                  onChanged: (value) => settings.setShowRoom(value),
                  title: const Text('Show room number'),
                  subtitle: const Text(
                    'Show the room in the schedule, notification and widget',
                  ),
                  secondary: const Icon(Icons.meeting_room_outlined),
                ),

                const Divider(height: 32),

                const _SectionHeader('My classes'),
                for (final name in customizablePeriodNames)
                  _PeriodTile(canonicalName: name),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmReset(context),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset all class names'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearCachedContent(BuildContext context) async {
    await NetworkCache.instance.clearAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved content cleared')),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset class names?'),
        content: const Text(
          'This removes every custom name, teacher and room you entered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (shouldReset ?? false) {
      await AppSettings.instance.resetPeriods();
    }
  }
}

/// Plain-language privacy disclosure, always visible in Settings.
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
                  Text(
                    'What we collect (and don\'t)',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Westview HS collects anonymous usage counts and crash reports '
                'to keep the app working. It never collects your name, student '
                'ID, contacts, location or advertising identifiers, and it '
                'shares nothing with third parties. Reports go only to the '
                'school\'s server (${Uri.parse(telemetryEndpoint).host}). Use '
                'the switches above to turn either off at any time.',
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
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// One editable period in the "My classes" list.
class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.canonicalName});

  final String canonicalName;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final periodSettings = settings.periodSettings(canonicalName);
    final details = <String>[
      if (periodSettings.teacher.isNotEmpty) periodSettings.teacher,
      if (periodSettings.room.isNotEmpty) 'Rm ${periodSettings.room}',
    ].join(' · ');

    final subtitle = <String>[
      if (settings.isRenamed(canonicalName)) canonicalName,
      if (details.isNotEmpty) details,
    ].join(' · ');

    return ListTile(
      title: Text(settings.displayName(canonicalName)),
      subtitle: Text(
        subtitle.isEmpty ? 'Tap to add a name, teacher or room' : subtitle,
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
                labelText: 'Class name',
                helperText: 'Leave empty to keep "${widget.canonicalName}"',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teacherController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Teacher'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Room number'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const PeriodSettings()),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            PeriodSettings(
              customName: _nameController.text.trim(),
              teacher: _teacherController.text.trim(),
              room: _roomController.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
