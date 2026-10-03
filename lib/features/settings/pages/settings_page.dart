import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_mode_controller.dart';
import '../settings_controller.dart';

/// Settings, including the data-management actions.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataManagementControllerProvider);
    final controller = ref.read(dataManagementControllerProvider.notifier);
    final busy = state.isBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Data management'),
          _SettingsTile(
            icon: Icons.backup_outlined,
            title: 'Back up data',
            subtitle: 'Save a copy of all students and attendance to a file.',
            onTap: busy ? null : () => _run(context, ref, controller.backUp),
          ),
          _SettingsTile(
            icon: Icons.restore_outlined,
            title: 'Restore data',
            subtitle: 'Replace everything with the contents of a backup file.',
            onTap: busy
                ? null
                : () => _chooseAndReview(context, ref, controller),
          ),
          _SettingsTile(
            icon: Icons.table_view_outlined,
            title: 'Export data',
            subtitle:
                'Create an Excel workbook you can open in Excel or Sheets.',
            onTap: busy
                ? null
                : () => _run(context, ref, controller.exportData),
          ),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            title: 'Clear all data',
            subtitle: 'Delete every student and attendance record.',
            destructive: true,
            onTap: busy ? null : () => _confirmClear(context, ref, controller),
          ),
          const _SectionHeader('Appearance'),
          const _ThemeModeSelector(),
        ],
      ),
    );
  }

  /// Runs [action], then surfaces whatever message or error it produced.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    await action();
    if (!context.mounted) return;
    final state = ref.read(dataManagementControllerProvider);
    final text = state.error ?? state.message;
    if (text != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      ref.read(dataManagementControllerProvider.notifier).acknowledge();
    }
  }

  Future<void> _chooseAndReview(
    BuildContext context,
    WidgetRef ref,
    DataManagementController controller,
  ) async {
    final ready = await controller.chooseBackupToRestore();
    if (!context.mounted) return;

    if (ready) {
      context.push('/settings/restore');
      return;
    }

    final state = ref.read(dataManagementControllerProvider);
    if (state.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!)));
      controller.acknowledge();
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    DataManagementController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _ClearAllDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    await _run(context, ref, controller.clearAllData);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Lets the operator choose System, Light or Dark. Persisted across launches.
class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto_outlined),
            label: Text('System'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Light'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Dark'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) =>
            ref.read(themeModeProvider.notifier).setMode(selection.first),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;
    return ListTile(
      enabled: onTap != null,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Asks the operator to type CLEAR before wiping everything.
class _ClearAllDialog extends StatefulWidget {
  const _ClearAllDialog();

  @override
  State<_ClearAllDialog> createState() => _ClearAllDialogState();
}

class _ClearAllDialogState extends State<_ClearAllDialog> {
  static const String _phrase = 'CLEAR';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canClear = _controller.text.trim().toUpperCase() == _phrase;
    return AlertDialog(
      title: const Text('Clear all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This deletes every student, attendance session and record. '
            'A safety copy will be saved automatically first, but the app will '
            'be empty afterwards.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Type CLEAR to confirm',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: canClear ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Clear all data'),
        ),
      ],
    );
  }
}
