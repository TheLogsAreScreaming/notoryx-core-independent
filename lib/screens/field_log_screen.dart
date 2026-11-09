import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/field_log.dart';
import '../app/notifications.dart';

/// Everything sent and received, across every chat, newest first, with a
/// button to copy it as a record of the trip.
class FieldLogScreen extends ConsumerStatefulWidget {
  const FieldLogScreen({required this.radioKey, super.key});

  final String radioKey;

  @override
  ConsumerState<FieldLogScreen> createState() => _FieldLogScreenState();
}

class _FieldLogScreenState extends ConsumerState<FieldLogScreen> {
  FieldLogRange _range = FieldLogRange.today;
  late Future<List<String>> _lines = _load();

  Future<List<String>> _load() async {
    final store = ref.read(storeProvider);
    final span = _range.span;
    final messages = await store.fieldLog(
      widget.radioKey,
      since: span == null ? null : DateTime.now().subtract(span),
    );
    final titles = <String, String>{};
    return [
      for (final m in messages)
        fieldLogLine(
          m,
          titles[m.thread] ??= (await chatLinkFor(
            store,
            widget.radioKey,
            m.thread,
          )).title,
        ),
    ];
  }

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    final lines = await _lines;
    await Clipboard.setData(ClipboardData(text: lines.reversed.join('\n')));
    messenger.showSnackBar(const SnackBar(content: Text('Field Log copied')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Field Log'),
      actions: [
        IconButton(
          tooltip: 'Copy log',
          icon: const Icon(Icons.copy),
          onPressed: _copy,
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<FieldLogRange>(
            segments: [
              for (final r in FieldLogRange.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_range},
            onSelectionChanged: (v) => setState(() {
              _range = v.first;
              _lines = _load();
            }),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<String>>(
            future: _lines,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Couldn’t read the log.'));
              }
              final lines = snapshot.data;
              if (lines == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (lines.isEmpty) {
                return const Center(child: Text('Nothing in this period.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: lines.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (_, i) => SelectableText(lines[i]),
              );
            },
          ),
        ),
      ],
    ),
  );
}
