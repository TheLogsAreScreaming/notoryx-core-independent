import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/telemetry.dart';
import 'telemetry_screen.dart';
import '../l10n/l10n.dart';

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
    final l10n = context.l10n;
    setState(() => _reading = true);
    try {
      final readings = await state.sync.requestTelemetry();
      if (readings == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.theRadioDidnTAnswer)),
        );
      }
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldnTReadTheRadio)));
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
                  context.l10n.read(text, age),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.readBatteryAndSensorsNow,
            onPressed: _reading ? null : _read,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
