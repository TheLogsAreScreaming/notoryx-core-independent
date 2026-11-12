import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/path_graph.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';

/// Every path heard, grouped by the repeater it reached you through.
class PathGraphScreen extends ConsumerWidget {
  const PathGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radioKey = ref.watch(radioKeyProvider) ?? '';
    final paths = ref.watch(heardPathsProvider(radioKey)).value ?? const [];
    final repeater = NodeType.repeater.value;
    final known = <({String name, String publicKey})>[
      for (final c
          in ref.watch(contactsProvider(radioKey)).value ?? const <Contact>[])
        if (c.type == repeater) (name: c.name, publicKey: c.publicKey),
      for (final d
          in ref.watch(discoveredProvider(radioKey)).value ??
              const <DiscoveredData>[])
        if (d.type == repeater) (name: d.name, publicKey: d.publicKey),
    ];
    String name(String hash) => hopName(hash, known);
    final direct = directRepeaters(paths);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.pathGraph),
        actions: [
          IconButton(
            tooltip: context.l10n.clearPaths,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: paths.isEmpty
                ? null
                : () => clearHeardPaths(ref.read(databaseProvider), radioKey),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.pathGraphIntro),
          ),
          if (direct.isEmpty)
            ListTile(title: Text(context.l10n.noPathsYet))
          else
            ListTile(
              title: Text(
                context.l10n.heardDirectly,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          for (final r in direct)
            ExpansionTile(
              leading: const Icon(Icons.cell_tower),
              title: Text(name(r.hash)),
              subtitle: Text(
                r.averageSnr == null
                    ? context.l10n.heardTimesNoSnr(r.heard)
                    : context.l10n.heardTimes(
                        r.heard,
                        r.averageSnr!.toStringAsFixed(1),
                      ),
              ),
              children: [
                for (final p in r.paths)
                  ListTile(
                    dense: true,
                    title: Text(
                      [
                        for (final h in pathHops(p.hops)) name(h),
                        context.l10n.you,
                      ].join(' → '),
                    ),
                    trailing: Text('×${p.count}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
