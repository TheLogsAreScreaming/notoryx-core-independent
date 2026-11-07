import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/telemetry.dart';
import '../data/data.dart';
import '../radio/radio.dart';

/// How far back the charts reach.
enum TelemetryRange {
  day('24 h', Duration(hours: 24)),
  week('7 days', Duration(days: 7)),
  all('All', null);

  const TelemetryRange(this.label, this.span);

  final String label;
  final Duration? span;
}

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
        title: const Text('Clear history?'),
        content: Text('All saved readings from ${widget.name} are deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
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
              tooltip: 'Clear history',
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No readings saved yet.',
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No readings in this range.'),
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
            Text('Latest', style: theme.textTheme.titleMedium),
            Text(_when(at), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (readings.isEmpty) const Text('No readings in this reply.'),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = seriesLabel(seriesKey);
    final kind = seriesKey.kind;
    final values = points.map((p) => p.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final last = points.last.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                Text(formatValue(kind, last)),
              ],
            ),
            Text(
              '${points.length} reading${points.length == 1 ? '' : 's'} · '
              'low ${formatValue(kind, low)} · '
              'high ${formatValue(kind, high)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (points.length < 2)
              Text(
                'The chart appears after a second reading.',
                style: theme.textTheme.bodySmall,
              )
            else
              Semantics(
                label:
                    '$label chart, ${points.length} readings, from '
                    '${formatValue(kind, points.first.value)} to '
                    '${formatValue(kind, last)}',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 96,
                    child: CustomPaint(
                      painter: _LinePainter(
                        points: points,
                        line: theme.colorScheme.primary,
                        grid: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A plain line through the points, spaced by time, with the low and high
/// marked by faint lines top and bottom.
class _LinePainter extends CustomPainter {
  _LinePainter({required this.points, required this.line, required this.grid});

  final List<TelemetryPoint> points;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final start = points.first.at.millisecondsSinceEpoch;
    final span = math.max(1, points.last.at.millisecondsSinceEpoch - start);
    var low = points.first.value;
    var high = low;
    for (final p in points) {
      low = math.min(low, p.value);
      high = math.max(high, p.value);
    }
    final range = high - low == 0 ? 1.0 : high - low;
    const pad = 4.0;
    final h = size.height - pad * 2;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas
      ..drawLine(const Offset(0, pad), Offset(size.width, pad), gridPaint)
      ..drawLine(
        Offset(0, size.height - pad),
        Offset(size.width, size.height - pad),
        gridPaint,
      );

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.at.millisecondsSinceEpoch - start) / span * size.width;
      final y = pad + h - (p.value - low) / range * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.line != line || old.grid != grid;
}
