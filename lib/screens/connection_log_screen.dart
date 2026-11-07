import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import 'packet_log_screen.dart';

/// What the connection has been doing, newest at the bottom, with a button
/// to copy it all for a bug report.
class ConnectionLogScreen extends ConsumerStatefulWidget {
  const ConnectionLogScreen({super.key});

  @override
  ConsumerState<ConnectionLogScreen> createState() =>
      _ConnectionLogScreenState();
}

class _ConnectionLogScreenState extends ConsumerState<ConnectionLogScreen> {
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
        title: const Text('Connection log'),
        actions: [
          IconButton(
            tooltip: 'Packets heard',
            icon: const Icon(Icons.podcasts),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PacketLogScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Copy log',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                ClipboardData(text: log.entries.join('\n')),
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Connection log copied')),
              );
            },
          ),
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_outline),
            onPressed: log.clear,
          ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: log.changes,
        initialData: log.entries,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <String>[];
          if (entries.isEmpty) {
            return const Center(child: Text('Nothing logged yet'));
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
    tooltip: 'Connection log',
    icon: const Icon(Icons.receipt_long_outlined),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ConnectionLogScreen()),
    ),
  );
}
