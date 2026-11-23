import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/server_history.dart';
import '../l10n/l10n.dart';
import 'history_chart.dart';

/// A server's kept status replies, one value at a time, over a chosen span.
class ServerHistoryCard extends ConsumerStatefulWidget {
  const ServerHistoryCard({
    required this.radioKey,
    required this.nodeKey,
    required this.version,
    super.key,
  });

  final String radioKey;
  final String nodeKey;

  /// Changes after each new status reply, so the card reloads.
  final int version;

  @override
  ConsumerState<ServerHistoryCard> createState() => _ServerHistoryCardState();
}

class _ServerHistoryCardState extends ConsumerState<ServerHistoryCard> {
  ServerValue _value = ServerValue.battery;
  TelemetryRange _range = TelemetryRange.week;
  late Future<List<ServerCheck>> _checks = _load();

  Future<List<ServerCheck>> _load() => loadServerChecks(
    ref.read(storeProvider),
    widget.radioKey,
    widget.nodeKey,
  );

  @override
  void didUpdateWidget(ServerHistoryCard old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) _checks = _load();
  }

  String _label(ServerValue v) {
    final l10n = context.l10n;
    return switch (v) {
      ServerValue.battery => l10n.infoBattery,
      ServerValue.rssi => l10n.serverHistoryRssi,
      ServerValue.snr => l10n.serverHistorySnr,
      ServerValue.noiseFloor => l10n.noiseFloor,
      ServerValue.errors => l10n.serverHistoryErrors,
      ServerValue.upTime => l10n.statUpFor,
    };
  }

  static String _format(ServerValue v, double x) => switch (v) {
    ServerValue.battery => '${x.toStringAsFixed(2)} V',
    ServerValue.snr => '${x.toStringAsFixed(1)} dB',
    ServerValue.rssi || ServerValue.noiseFloor => '${x.round()} dBm',
    ServerValue.errors => '${x.round()}',
    ServerValue.upTime => '${x.toStringAsFixed(x < 10 ? 1 : 0)} h',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FutureBuilder<List<ServerCheck>>(
      future: _checks,
      builder: (context, snap) {
        final all = snap.data ?? const <ServerCheck>[];
        final span = _range.span;
        final since = span == null ? null : DateTime.now().subtract(span);
        final points = [
          for (final c in all)
            if (since == null || !c.at.isBefore(since))
              (at: c.at, value: serverValue(c, _value)),
        ];
        return Card(
          key: const Key('server-history'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.serverHistoryTitle,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  l10n.serverHistoryCount(all.length),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final v in ServerValue.values)
                      ChoiceChip(
                        label: Text(_label(v)),
                        selected: _value == v,
                        onSelected: (_) => setState(() => _value = v),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<TelemetryRange>(
                  showSelectedIcon: false,
                  segments: [
                    for (final r in TelemetryRange.values)
                      ButtonSegment(value: r, label: Text(r.label(l10n))),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                const SizedBox(height: 8),
                if (points.isEmpty)
                  Text(
                    all.isEmpty
                        ? l10n.serverHistoryEmpty
                        : l10n.serverHistoryNoneInRange,
                    style: theme.textTheme.bodySmall,
                  )
                else
                  HistoryChartCard(
                    label: _label(_value),
                    points: points,
                    format: (x) => _format(_value, x),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
