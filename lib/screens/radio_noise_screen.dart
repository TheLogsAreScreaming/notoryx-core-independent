import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/radio_stats.dart';
import '../data/data.dart';
import 'history_chart.dart';
import '../l10n/l10n.dart';

/// The connected radio's noise floor and last-packet signal over time.
class RadioNoiseScreen extends ConsumerStatefulWidget {
  const RadioNoiseScreen({super.key});

  @override
  ConsumerState<RadioNoiseScreen> createState() => _RadioNoiseScreenState();
}

class _RadioNoiseScreenState extends ConsumerState<RadioNoiseScreen> {
  TelemetryRange _range = TelemetryRange.day;
  bool _reading = false;
  String? _note;

  Future<void> _readNow() async {
    final state = ref.read(connectionProvider);
    if (state is! Connected) return;
    setState(() {
      _reading = true;
      _note = null;
    });
    try {
      final stats = await state.sync.sampleRadioStats();
      if (!mounted) return;
      setState(
        () => _note = stats == null
            ? 'This radio’s firmware doesn’t report its noise floor.'
            : null,
      );
    } on Object catch (e) {
      if (mounted) setState(() => _note = 'Couldn’t read it: $e');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _clear(String radioKey) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.clearNoiseHistory),
        content: Text(context.l10n.savedReadingsForThisRadioAre),
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
    if (ok == true) await ref.read(storeProvider).clearRadioStats(radioKey);
  }

  @override
  Widget build(BuildContext context) {
    final radioKey = ref.watch(radioKeyProvider);
    final connected = ref.watch(connectionProvider) is Connected;
    final samples = radioKey == null
        ? const <RadioStatsSample>[]
        : ref.watch(radioStatsHistoryProvider(radioKey)).value ??
              const <RadioStatsSample>[];
    final theme = Theme.of(context);
    final cutoff = switch (_range.span) {
      final span? => DateTime.now().subtract(span).millisecondsSinceEpoch,
      null => 0,
    };
    final shown = samples.where((s) => s.at >= cutoff).toList();
    final latest = samples.isEmpty ? null : samples.last;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.noiseFloor),
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
            context.l10n.howMuchBackgroundNoiseYourRadio,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: connected && !_reading ? _readNow : null,
            icon: const Icon(Icons.graphic_eq),
            label: Text(_reading ? 'Reading…' : 'Read now'),
          ),
          if (_note case final note?)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(note)),
          if (latest != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.dbm2(latest.noiseFloor),
                      style: theme.textTheme.headlineSmall,
                    ),
                    Text(noiseVerdict(latest.noiseFloor)),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.airtimeSinceTheRadioStartedSending(
                        formatAirtime(latest.txAirSeconds),
                        formatAirtime(latest.rxAirSeconds),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            if (shown.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(context.l10n.noReadingsInThisRange),
              )
            else
              for (final series in RadioStatsSeries.values)
                HistoryChartCard(
                  label: series.label,
                  points: series.points(shown),
                  format: series.format,
                ),
          ],
        ],
      ),
    );
  }
}
