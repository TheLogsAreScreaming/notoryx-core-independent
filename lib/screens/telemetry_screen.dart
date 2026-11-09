import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/telemetry.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'history_chart.dart';
import '../l10n/l10n.dart';

export 'history_chart.dart' show TelemetryRange;

/// A node's sensor readings: ask for new ones, see the latest, and chart
/// each value over time. With [isSelf], the connected radio itself.
class TelemetryScreen extends ConsumerStatefulWidget {
  const TelemetryScreen({
    required this.nodeKey,
    required this.name,
    this.type,
    this.isSelf = false,
    super.key,
  });

  /// The node's public key, hex.
  final String nodeKey;
  final String name;
  final NodeType? type;
  final bool isSelf;

  @override
  ConsumerState<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends ConsumerState<TelemetryScreen> {
  bool _asking = false;
  String? _note;
  TelemetryRange _range = TelemetryRange.week;

  bool get _needsLogin =>
      widget.type == NodeType.repeater || widget.type == NodeType.room;

  Future<void> _ask() async {
    final state = ref.read(connectionProvider);
    if (state is! Connected) {
      setState(() => _note = 'Connect to the radio first.');
      return;
    }
    setState(() {
      _asking = true;
      _note = null;
    });
    try {
      final readings = await state.sync.requestTelemetry(
        widget.isSelf ? null : PublicKey.fromHex(widget.nodeKey),
      );
      if (!mounted) return;
      setState(
        () => _note = switch (readings) {
          null when _needsLogin =>
            'No reply. Log in first (guest is enough), and check the '
                'node is in range.',
          null =>
            'No reply. The node may be out of range, or not share '
                'telemetry with you.',
          [] => 'It answered, but shared no readings.',
          _ => null,
        },
      );
    } on RadioRequestException {
      if (mounted) {
        setState(() => _note = 'The radio could not send the request.');
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _clear(String radioKey) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.clearHistory2),
        content: Text('All saved readings from ${widget.name} are deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.clear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(storeProvider).clearTelemetry(radioKey, widget.nodeKey);
  }

  @override
  Widget build(BuildContext context) {
    final radioKey = ref.watch(radioKeyProvider);
    final samples = radioKey == null
        ? const <TelemetrySample>[]
        : ref
                  .watch(
                    telemetryHistoryProvider((
                      radioKey: radioKey,
                      nodeKey: widget.nodeKey,
                    )),
                  )
                  .value ??
              const <TelemetrySample>[];
    final theme = Theme.of(context);

    final cutoff = switch (_range.span) {
      final span? => DateTime.now().subtract(span).millisecondsSinceEpoch,
      null => 0,
    };
    final shown = samples.where((s) => s.at >= cutoff).toList();
    final series = telemetrySeries(shown);
    final latest = samples.isEmpty ? null : samples.last;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelf ? 'Radio telemetry' : widget.name),
        actions: [
          if (radioKey != null && samples.isNotEmpty)
            IconButton(
              tooltip: context.l10n.clearHistory,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _clear(radioKey),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.isSelf
                ? 'Your radio’s battery and sensors. Saved every 30 minutes '
                      'while connected, at no airtime cost.'
                : _needsLogin
                ? 'Repeaters and rooms answer after you log in. Guest is '
                      'enough for the battery; admin gets every sensor.'
                : 'Each request sends one packet. The node only answers if '
                      'it shares telemetry with you.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _asking ? null : _ask,
            icon: _asking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sensors),
            label: Text(_asking ? 'Asking…' : 'Request readings'),
          ),
          if (_note case final note?)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(note)),
          const SizedBox(height: 16),
          if (latest != null) _Latest(sample: latest),
          if (samples.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.l10n.noReadingsSavedYet,
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            const SizedBox(height: 16),
            SegmentedButton<TelemetryRange>(
              segments: [
                for (final r in TelemetryRange.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            const SizedBox(height: 8),
            if (series.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(context.l10n.noReadingsInThisRange),
              ),
            for (final entry in series.entries)
              _SeriesCard(seriesKey: entry.key, points: entry.value),
          ],
        ],
      ),
    );
  }
}

class _Latest extends StatelessWidget {
  const _Latest({required this.sample});

  final TelemetrySample sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readings = decodeLpp(sample.data);
    final at = DateTime.fromMillisecondsSinceEpoch(sample.at);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.latest, style: theme.textTheme.titleMedium),
            Text(_when(at), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (readings.isEmpty) Text(context.l10n.noReadingsInThisReply),
            for (final r in readings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        readingLabel(r),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Flexible(
                      child: Text(readingText(r), textAlign: TextAlign.end),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _when(DateTime at) {
  final ago = DateTime.now().difference(at);
  if (ago.inMinutes < 1) return 'Just now';
  if (ago.inHours < 1) return '${ago.inMinutes} min ago';
  if (ago.inDays < 1) return '${ago.inHours} h ago';
  return '${ago.inDays} d ago';
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.seriesKey, required this.points});

  final TelemetrySeriesKey seriesKey;
  final List<TelemetryPoint> points;

  @override
  Widget build(BuildContext context) => HistoryChartCard(
    label: seriesLabel(seriesKey),
    points: points,
    format: (v) => formatValue(seriesKey.kind, v),
  );
}
