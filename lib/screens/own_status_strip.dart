import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/telemetry.dart';
import 'telemetry_screen.dart';

/// The connected radio's own battery and sensors, on the home screen. Tap
/// for the history. Reading them goes over the link, so it costs no airtime.
class OwnStatusStrip extends ConsumerStatefulWidget {
  const OwnStatusStrip({
    required this.radioKey,
    required this.radioName,
    super.key,
  });

  final String radioKey;
  final String radioName;

  @override
  ConsumerState<OwnStatusStrip> createState() => _OwnStatusStripState();
}

class _OwnStatusStripState extends ConsumerState<OwnStatusStrip> {
  bool _reading = false;

  Future<void> _read() async {
    final state = ref.read(connectionProvider);
    if (state is! Connected || _reading) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reading = true);
    try {
      final readings = await state.sync.requestTelemetry();
      if (readings == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('The radio didn’t answer.')),
        );
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn’t read the radio.')),
      );
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(latestTelemetryProvider(widget.radioKey)).value;
    final sample = latest?[widget.radioKey];
    final text = sample == null ? null : ownStatusText(sample);
    if (sample == null || text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final age = readingAge(
      DateTime.fromMillisecondsSinceEpoch(sample.at),
      DateTime.now(),
    );
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TelemetryScreen(
                    nodeKey: widget.radioKey,
                    name: widget.radioName,
                    isSelf: true,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Text(
                  '$text\nRead $age',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Read battery and sensors now',
            onPressed: _reading ? null : _read,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
