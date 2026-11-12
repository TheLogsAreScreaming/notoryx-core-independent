import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/network_scan.dart';
import '../l10n/l10n.dart';
import '../presets/area_presets_provider.dart';
import '../presets/community_presets.dart';
import 'area_screen.dart';

/// Scans the presets in the radio's band for repeaters that answer.
class NetworkScanScreen extends ConsumerWidget {
  const NetworkScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(networkScanProvider);
    final scanner = ref.read(networkScanProvider.notifier);
    final current = ref.watch(radioSettingsProvider);
    final connected = ref.watch(connectionProvider) is Connected;
    final presets = [
      ...?ref.watch(communityPresetsProvider).value,
      ...?ref.watch(areaPresetsProvider).value,
    ];
    final count = current == null ? 0 : scanCandidates(presets, current).length;
    // About 10 seconds a preset: settle, ping, listen.
    final minutes = (count * 10 / 60).ceil().clamp(1, 99);
    final names = <String, String>{
      for (final c
          in ref
                  .watch(contactsProvider(ref.watch(radioKeyProvider) ?? ''))
                  .value ??
              const [])
        c.publicKey: c.name,
    };
    final results = [...scan.results]
      ..sort((a, b) => b.hits.length.compareTo(a.hits.length));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.networkScan)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.networkScanIntro(minutes)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: scan.running
                ? OutlinedButton(
                    onPressed: scanner.cancel,
                    child: Text(context.l10n.cancelScan),
                  )
                : FilledButton(
                    onPressed: connected && current != null
                        ? scanner.start
                        : null,
                    child: Text(context.l10n.startScan),
                  ),
          ),
          if (scan.running) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: scan.total == 0 ? null : scan.done / scan.total,
              ),
            ),
            ListTile(
              title: Text(context.l10n.scanProgress(scan.done, scan.total)),
            ),
          ],
          if (scan.error case final error?)
            ListTile(title: Text(context.l10n.scanFailed(error))),
          for (final r in results)
            ListTile(
              title: Text(r.preset.name),
              subtitle: Text(
                r.hits.isEmpty
                    ? '${r.preset.summary}\n${context.l10n.noRepeatersHeard}'
                    : '${r.preset.summary}\n${context.l10n.repeatersHeard(r.hits.length, [for (final h in r.hits) names[h.publicKey] ?? h.publicKey.substring(0, 8).toUpperCase()].join(', '))}',
              ),
              isThreeLine: true,
              onTap: scan.running || r.preset.id == 'current'
                  ? null
                  : () => reviewArea(context, ref, r.preset),
            ),
        ],
      ),
    );
  }
}
