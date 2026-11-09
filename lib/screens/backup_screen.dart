import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/backup_service.dart';
import '../app/connection.dart';
import '../data/backup_crypto.dart';

/// Save everything to an encrypted file, or bring it back on a new phone.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _show = false;
  String? _working;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  String? get _passwordProblem {
    final p = _password.text;
    if (p.length < minBackupPassword) {
      return 'At least $minBackupPassword characters.';
    }
    if (_again.text != p) return 'The two passwords don’t match.';
    return null;
  }

  Future<void> _backUp() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = 'Encrypting…');
    try {
      final saved = await ref
          .read(backupServiceProvider)
          .backUp(_password.text);
      if (saved) {
        _password.clear();
        _again.clear();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Backup saved. Keep the password: without it the file '
                      'can’t be opened.'
                : 'Not saved.',
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    final file = await service.pick();
    if (file == null || !mounted) return;
    final password = await _askPassword();
    if (password == null || !mounted) return;
    setState(() => _working = 'Opening…');
    try {
      final backup = await service.open(file, password);
      if (!mounted) return;
      setState(() => _working = null);
      final when = backup.info.exportedAt.toLocal();
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace everything on this device?'),
          content: Text(
            'The backup from '
            '${MaterialLocalizations.of(context).formatMediumDate(when)} '
            '${TimeOfDay.fromDateTime(when).format(context)} '
            '(app ${backup.info.appVersion}) replaces all chats, contacts, '
            'settings and history here. This can’t be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
      setState(() => _working = 'Restoring…');
      final summary = await service.restore(backup);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restored ${summary.messages} message'
            '${summary.messages == 1 ? '' : 's'} from '
            '${summary.radios} radio${summary.radios == 1 ? '' : 's'}.',
          ),
        ),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<String?> _askPassword() => showDialog<String>(
    context: context,
    builder: (context) => const _PasswordDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(connectionProvider);
    final disconnected = state is Disconnected || state is ViewingSaved;
    final problem = _passwordProblem;
    final busy = _working != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup and restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_working case final working?)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(working),
                ],
              ),
            ),
          Text('Back up', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Saves everything in this app (chats, contacts, channels and '
            'their keys, settings, history) to one file, encrypted with a '
            'password you choose. Keep the file somewhere safe: anyone with '
            'it and the password can read your chats and join your private '
            'channels.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: !_show,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _show ? 'Hide password' : 'Show password',
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _again,
            obscureText: !_show,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Password again',
              border: const OutlineInputBorder(),
              errorText: _password.text.isEmpty ? null : problem,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'There is no way to recover a forgotten password.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: problem == null && !busy ? _backUp : null,
            icon: const Icon(Icons.save_alt),
            label: const Text('Save backup file'),
          ),
          const Divider(height: 40),
          Text('Restore', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            disconnected
                ? 'Brings back a backup, replacing everything in this app. '
                      'Backups from older versions are upgraded.'
                : 'Disconnect the radio first, so nothing changes while the '
                      'backup is put back.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: disconnected && !busy ? _restore : null,
            icon: const Icon(Icons.restore),
            label: const Text('Choose backup file'),
          ),
        ],
      ),
    );
  }
}

/// Asks for a backup's password. Owns its text box, so it is disposed only
/// once the dialog has finished closing.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Backup password'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Password'),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Open'),
      ),
    ],
  );
}
