import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/repeater_tools.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

/// One-tap, one-hop trace showing the signal in both directions.
class RepeaterPingCard extends ConsumerStatefulWidget {
  const RepeaterPingCard({required this.publicKey, super.key});

  final String publicKey;

  @override
  ConsumerState<RepeaterPingCard> createState() => _RepeaterPingCardState();
}

class _RepeaterPingCardState extends ConsumerState<RepeaterPingCard> {
  bool _busy = false;
  String? _result;

  Future<void> _ping() async {
    final state = ref.read(connectionProvider);
    if (state is! Connected) {
      setState(() => _result = 'Connect to the radio first.');
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    String text;
    try {
      final reply = await state.sync.trace([
        fromHex(widget.publicKey).sublist(0, 1),
      ], hashBytes: 1);
      text = reply == null || reply.snrs.isEmpty
          ? 'No answer. It may be more than one hop away.'
          : 'It heard you at ${reply.snrs.first.toStringAsFixed(1)} dB. '
                'You heard it at ${reply.finalSnr.toStringAsFixed(1)} dB.';
    } on RadioRequestException {
      text = 'The radio could not send it.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _result = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.network_ping),
      title: Text(context.l10n.ping2),
      subtitle: Text(_result ?? 'Signal both ways, one hop'),
      trailing: _busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _busy ? null : _ping,
    ),
  );
}

/// Admin buttons that send console commands for you.
class RepeaterAdminTools extends ConsumerWidget {
  const RepeaterAdminTools({
    required this.radioKey,
    required this.server,
    required this.lines,
    super.key,
  });

  final String radioKey;
  final PublicKey server;

  /// The console so far, oldest first.
  final List<Message> lines;

  Future<void> _send(BuildContext context, WidgetRef ref, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final state = ref.read(connectionProvider);
    if (state is! Connected) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.connectToTheRadioFirst)),
      );
      return;
    }
    try {
      await state.sync.sendCommand(server, text);
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotSendIt)),
      );
    }
  }

  Future<void> _access(
    BuildContext context,
    WidgetRef ref,
    List<Contact> people,
  ) async {
    final choice = await showDialog<(Contact, ServerPermission)>(
      context: context,
      builder: (_) => _AccessDialog(people: people),
    );
    if (choice == null || !context.mounted) return;
    await _send(
      context,
      ref,
      setPermissionCommand(choice.$1.publicKey, choice.$2),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider(radioKey)).value ?? const [];
    final neighbors = latestNeighbors(lines);
    String nameFor(String prefix) {
      for (final c in contacts) {
        if (c.publicKey.startsWith(prefix)) return c.name;
      }
      return prefix.toUpperCase();
    }

    final people = [
      for (final c in contacts)
        if (NodeType.fromByte(c.type) == NodeType.chat) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.hub_outlined, size: 18),
              label: Text(context.l10n.neighbors),
              onPressed: () => _send(context, ref, 'neighbors'),
            ),
            ActionChip(
              avatar: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: Text(context.l10n.accessControl),
              onPressed: people.isEmpty
                  ? null
                  : () => _access(context, ref, people),
            ),
          ],
        ),
        if (neighbors case final list?) ...[
          const SizedBox(height: 4),
          if (list.isEmpty) Text(context.l10n.itHasnTHeardAnyNeighbors),
          for (final n in list)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                context.l10n.db(
                  nameFor(n.prefix),
                  n.snr.toStringAsFixed(1),
                  _ago(n.secondsAgo),
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  static String _ago(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays} d ago';
    if (d.inHours > 0) return '${d.inHours} h ago';
    if (d.inMinutes > 0) return '${d.inMinutes} min ago';
    return '${d.inSeconds} s ago';
  }
}

class _AccessDialog extends StatefulWidget {
  const _AccessDialog({required this.people});

  final List<Contact> people;

  @override
  State<_AccessDialog> createState() => _AccessDialogState();
}

class _AccessDialogState extends State<_AccessDialog> {
  late Contact _who = widget.people.first;
  ServerPermission _what = ServerPermission.readWrite;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.accessControl),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<Contact>(
          initialValue: _who,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.l10n.contact),
          items: [
            for (final c in widget.people)
              DropdownMenuItem(value: c, child: Text(c.name)),
          ],
          onChanged: (c) => setState(() => _who = c ?? _who),
        ),
        DropdownButtonFormField<ServerPermission>(
          initialValue: _what,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.l10n.permission),
          items: [
            for (final p in ServerPermission.values)
              DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: (p) => setState(() => _what = p ?? _what),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop((_who, _what)),
        child: Text(context.l10n.set),
      ),
    ],
  );
}
