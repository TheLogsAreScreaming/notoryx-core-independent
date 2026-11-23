import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/telemetry.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'history_chart.dart';
import '../l10n/l10n.dart';
import '../app/telemetry_alerts.dart';

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
      setState(() => _note = context.l10n.connectToTheRadioFirst);
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
          null when _needsLogin => context.l10n.noReplyLogInFirst,
          null => context.l10n.noReplyOutOfRange,
          [] => context.l10n.answeredNoReadings,
          _ => null,
        },
      );
    } on RadioRequestException {
      if (mounted) {
        setState(() => _note = context.l10n.radioCouldNotSendRequest);
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
        content: Text(context.l10n.allSavedReadingsFromAreDeleted(widget.name)),
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

  Future<void> _editLimit(
    String radioKey,
    TelemetrySeriesKey key,
    Map<String, TelemetryLimit> limits,
  ) async {
    final id = limitId(key.channel, key.kind);
    final current = limits[id];
    final result = await showDialog<TelemetryLimit>(
      context: context,
      builder: (_) => _LimitDialog(
        title: seriesLabel(key, axis: false, l10n: context.l10n),
        current: current,
      ),
    );
    if (result == null) return;
    await saveTelemetryLimit(
      ref.read(storeProvider),
      radioKey: radioKey,
      nodeKey: widget.nodeKey,
      id: id,
      limit: result,
    );
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
    final limits = radioKey == null
        ? const <String, TelemetryLimit>{}
        : ref
                  .watch(
                    telemetryLimitsProvider((
                      radioKey: radioKey,
                      nodeKey: widget.nodeKey,
                    )),
                  )
                  .value ??
              const <String, TelemetryLimit>{};

    final cutoff = switch (_range.span) {
      final span? => DateTime.now().subtract(span).millisecondsSinceEpoch,
      null => 0,
    };
    final shown = samples.where((s) => s.at >= cutoff).toList();
    final series = telemetrySeries(shown);
    final latest = samples.isEmpty ? null : samples.last;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelf ? context.l10n.radioTelemetry : widget.name),
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
                ? context.l10n.telemetrySelfNote
                : _needsLogin
                ? context.l10n.telemetryServerNote
                : context.l10n.telemetryNodeNote,
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
            label: Text(context.l10n.askingOrRequest('$_asking')),
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
                  ButtonSegment(value: r, label: Text(r.label(context.l10n))),
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
              _SeriesCard(
                seriesKey: entry.key,
                points: entry.value,
                limit: limits[limitId(entry.key.channel, entry.key.kind)],
                onSetLimit: radioKey == null || entry.key.index != 0
                    ? null
                    : () => _editLimit(radioKey, entry.key, limits),
              ),
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
            Text(_when(context.l10n, at), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (readings.isEmpty) Text(context.l10n.noReadingsInThisReply),
            for (final r in readings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        readingLabel(r, context.l10n),
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

String _when(AppLocalizations l10n, DateTime at) {
  final ago = DateTime.now().difference(at);
  if (ago.inMinutes < 1) return l10n.agoJustNowCap;
  if (ago.inHours < 1) return l10n.agoMinutes(ago.inMinutes);
  if (ago.inDays < 1) return l10n.agoHours(ago.inHours);
  return l10n.agoDays(ago.inDays);
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.seriesKey,
    required this.points,
    this.limit,
    this.onSetLimit,
  });

  final TelemetrySeriesKey seriesKey;
  final List<TelemetryPoint> points;
  final TelemetryLimit? limit;

  /// Opens the alert limits; null where alerts aren't offered.
  final VoidCallback? onSetLimit;

  @override
  Widget build(BuildContext context) {
    final chart = HistoryChartCard(
      label: seriesLabel(seriesKey, l10n: context.l10n),
      points: points,
      format: (v) => formatValue(seriesKey.kind, v),
    );
    final set = onSetLimit;
    if (set == null) return chart;
    final l10n = context.l10n;
    final l = limit;
    String f(double v) => formatValue(seriesKey.kind, v);
    final text = l == null
        ? l10n.telemetryNoAlert
        : [
            if (l.above case final a?) l10n.telemetryAlertWhenAbove(f(a)),
            if (l.below case final b?) l10n.telemetryAlertWhenBelow(f(b)),
          ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chart,
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Row(
            children: [
              Icon(
                l == null
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton(
                key: Key('alert-${seriesKey.channel}-${seriesKey.kind.name}'),
                onPressed: set,
                child: Text(l10n.telemetrySetAlert),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Upper and lower limits for one value.
class _LimitDialog extends StatefulWidget {
  const _LimitDialog({required this.title, this.current});

  final String title;
  final TelemetryLimit? current;

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late final _above = TextEditingController(
    text: widget.current?.above?.toString() ?? '',
  );
  late final _below = TextEditingController(
    text: widget.current?.below?.toString() ?? '',
  );

  @override
  void dispose() {
    _above.dispose();
    _below.dispose();
    super.dispose();
  }

  double? _read(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final above = _read(_above.text), below = _read(_below.text);
    final wrong = above != null && below != null && below >= above;
    const keys = TextInputType.numberWithOptions(decimal: true, signed: true);
    return AlertDialog(
      title: Text(l10n.telemetryAlertDialogTitle(widget.title)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.telemetryAlertDialogHint),
          TextField(
            key: const Key('limit-above'),
            controller: _above,
            keyboardType: keys,
            decoration: InputDecoration(labelText: l10n.telemetryAbove),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            key: const Key('limit-below'),
            controller: _below,
            keyboardType: keys,
            decoration: InputDecoration(
              labelText: l10n.telemetryBelow,
              errorText: wrong ? l10n.telemetryBelowMustBeLower : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, (above: null, below: null)),
            child: Text(l10n.telemetryRemoveAlert),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('limit-save'),
          onPressed: wrong
              ? null
              : () => Navigator.pop(context, (above: above, below: below)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
