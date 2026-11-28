import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

const _minVersionCode = 14;

const _destructiveCommands = [
  'reboot',
  'factory_reset',
  'format',
  'wipefs',
];

bool _isDestructive(String command) {
  final lower = command.trim().toLowerCase();
  return _destructiveCommands.any(
    (d) => lower == d || lower.startsWith('$d '),
  );
}

/// The connected radio's own command line, and Wi-Fi setup for radios
/// built with it. Commands go over the cable or Bluetooth, not the mesh.
class RadioConsoleScreen extends ConsumerStatefulWidget {
  const RadioConsoleScreen({super.key});

  @override
  ConsumerState<RadioConsoleScreen> createState() => _RadioConsoleScreenState();
}

class _RadioConsoleScreenState extends ConsumerState<RadioConsoleScreen> {
  final _command = TextEditingController();
  final _lines = <String>[];
  bool _busy = false;

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  /// Runs [command], showing it as [shown] so passwords stay off the screen.
  Future<void> _run(String command, {String? shown}) async {
    final l10n = context.l10n;
    final state = ref.read(connectionProvider);
    if (state is! Connected) {
      setState(() => _lines.add(context.l10n.connectToTheRadioFirst));
      return;
    }
    setState(() {
      _busy = true;
      _lines.add('> ${shown ?? command}');
    });
    String reply;
    try {
      reply = await state.sync.runRadioCommand(command);
    } on RadioRequestException {
      reply = l10n.cliNeedsFirmware;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _lines.add(reply);
      });
    }
  }

  Future<void> _send() async {
    final text = _command.text.trim();
    if (text.isEmpty || _busy) return;
    if (_isDestructive(text)) {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.cliDestructiveTitle),
          content: Text(l10n.cliDestructiveBody(text.split(' ').first)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.cliRunIt),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    _command.clear();
    await _run(text);
  }

  Future<void> _wifi() async {
    final details = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _WifiDialog(),
    );
    if (details == null) return;
    await _run('set wifi.ssid ${details.$1}');
    await _run('set wifi.pwd ${details.$2}', shown: 'set wifi.pwd ••••••');
    if (mounted) {
      setState(() => _lines.add(context.l10n.restartRadioToApply));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connection = ref.watch(connectionProvider);
    final int? versionCode = switch (connection) {
      Connected(:final radio) => radio.device.firmwareVersionCode,
      _ => null,
    };
    final bool olderFirmware =
        versionCode != null && versionCode < _minVersionCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.commandLine),
        actions: [
          IconButton(
            tooltip: l10n.wiFiSetup,
            onPressed: _busy ? null : _wifi,
            icon: const Icon(Icons.wifi),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (olderFirmware)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.cliOlderFirmware(versionCode),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(context.l10n.commandsRunOnYourRadioNot),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: _lines.length,
                    itemBuilder: (_, i) => SelectableText(
                      _lines[_lines.length - 1 - i],
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _command,
                    autocorrect: false,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(hintText: context.l10n.command),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.runCommand,
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _WifiDialog extends StatefulWidget {
  const _WifiDialog();

  @override
  State<_WifiDialog> createState() => _WifiDialogState();
}

class _WifiDialogState extends State<_WifiDialog> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.wiFiSetup),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ssid,
          autocorrect: false,
          decoration: InputDecoration(labelText: context.l10n.networkName),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: context.l10n.password),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () {
          if (_ssid.text.trim().isEmpty) return;
          Navigator.of(context).pop((_ssid.text.trim(), _password.text));
        },
        child: Text(context.l10n.save),
      ),
    ],
  );
}
