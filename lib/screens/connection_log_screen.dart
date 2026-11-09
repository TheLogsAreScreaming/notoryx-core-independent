import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/connection_log.dart';
import 'packet_log_screen.dart';
import '../l10n/l10n.dart';

/// What the connection has been doing, newest at the bottom, with a button
/// to copy it all for a bug report.
class ConnectionLogScreen extends ConsumerStatefulWidget {
  const ConnectionLogScreen({super.key});

  @override
  ConsumerState<ConnectionLogScreen> createState() =>
      _ConnectionLogScreenState();
}

class _ConnectionLogScreenState extends ConsumerState<ConnectionLogScreen> {
  LogView _view = LogView.all;

  @override
  void initState() {
    super.initState();
    ref.read(connectionLogProvider).load();
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(connectionLogProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.connectionLog),
        actions: [
          IconButton(
            tooltip: context.l10n.packetsHeard,
            icon: const Icon(Icons.podcasts),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PacketLogScreen()),
            ),
          ),
          IconButton(
            tooltip: context.l10n.copyLog,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final l10n = context.l10n;
              await Clipboard.setData(
                ClipboardData(text: entriesFor(log.entries, _view).join('\n')),
              );
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.connectionLogCopied)),
              );
            },
          ),
          IconButton(
            tooltip: context.l10n.clearLog,
            icon: const Icon(Icons.delete_outline),
            onPressed: log.clear,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<LogView>(
              segments: [
                ButtonSegment(
                  value: LogView.all,
                  label: Text(context.l10n.all),
                ),
                ButtonSegment(
                  value: LogView.bluetooth,
                  label: Text(context.l10n.bluetooth),
                ),
                ButtonSegment(
                  value: LogView.app,
                  label: Text(context.l10n.app),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (v) => setState(() => _view = v.first),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: log.changes,
        initialData: log.entries,
        builder: (context, snapshot) {
          final entries = entriesFor(snapshot.data ?? const <String>[], _view);
          if (entries.isEmpty) {
            return Center(child: Text(context.l10n.nothingLoggedYet));
          }
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SelectableText(
                entries[entries.length - 1 - i],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// App-bar button that opens the [ConnectionLogScreen].
class ConnectionLogButton extends StatelessWidget {
  const ConnectionLogButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.connectionLog,
    icon: const Icon(Icons.receipt_long_outlined),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ConnectionLogScreen()),
    ),
  );
}
