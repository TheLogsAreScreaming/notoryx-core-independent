import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

/// Runs commands on a trusted contact's radio, if they've allowed you.
class TrustedConsoleScreen extends ConsumerStatefulWidget {
  const TrustedConsoleScreen({required this.contact, super.key});

  final Contact contact;

  @override
  ConsumerState<TrustedConsoleScreen> createState() =>
      _TrustedConsoleScreenState();
}

class _TrustedConsoleScreenState extends ConsumerState<TrustedConsoleScreen> {
  final _command = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _command.text.trim();
    final state = ref.read(connectionProvider);
    if (text.isEmpty || state is! Connected || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      await state.sync.sendCommand(
        PublicKey.fromHex(widget.contact.publicKey),
        text,
        type: TextType.cliCommand,
      );
      _command.clear();
    } on ArgumentError {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.thatCommandIsTooLong)),
      );
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotSendIt)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radioKey = ref.watch(radioKeyProvider);
    final connected = ref.watch(connectionProvider) is Connected;
    final lines = radioKey == null
        ? const <Message>[]
        : ref
                  .watch(
                    consoleProvider((
                      radioKey: radioKey,
                      thread: Threads.direct(widget.contact.publicKey),
                    )),
                  )
                  .value ??
              const <Message>[];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.commandLine2(widget.contact.name)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.theseRunOnSRadioIt(widget.contact.name),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: lines.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SelectableText(
                  '${lines[i].outgoing ? '> ' : ''}${lines[i].body}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _command,
                      enabled: connected,
                      autocorrect: false,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        labelText: connected
                            ? 'Command'
                            : 'Connect a radio to send commands',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.sendCommand,
                    icon: const Icon(Icons.send),
                    onPressed: connected && !_sending ? _send : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
