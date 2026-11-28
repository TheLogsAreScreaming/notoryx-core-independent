import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/hop_names.dart';
import '../app/path_graph.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';

/// Shows which repeaters are part of this radio's relay chain, inferred from
/// the flooded-packet paths the radio hears while connected. The direct
/// repeaters (last hop of each heard path) are the nodes most likely
/// forwarding this radio's own messages into the mesh.
class WhoRepeatsMeScreen extends ConsumerWidget {
  const WhoRepeatsMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radioKey = ref.watch(radioKeyProvider) ?? '';
    final paths = ref.watch(heardPathsProvider(radioKey)).value ?? const [];
    final direct = directRepeaters(paths);

    final repeaterType = NodeType.repeater.value;
    final known = <({String name, String publicKey})>[
      for (final c
          in ref.watch(contactsProvider(radioKey)).value ?? const <Contact>[])
        if (c.type == repeaterType) (name: c.name, publicKey: c.publicKey),
      for (final d
          in ref.watch(discoveredProvider(radioKey)).value ??
              const <DiscoveredData>[])
        if (d.type == repeaterType) (name: d.name, publicKey: d.publicKey),
    ];

    final hints = hopHints(
      ref,
      radioKey,
      onlineLabel: context.l10n.foundOnline,
    );
    final unknown = <String>{};

    String resolvedName(String hash) {
      final n = hopName(hash, known, hints: hints);
      if (n == hash.toUpperCase()) unknown.add(hash);
      return n;
    }

    afterNamingHops(ref, unknown, hints);

    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.whoRepeatsMeTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.whoRepeatsMeIntro),
          ),
          if (direct.isEmpty)
            ListTile(title: Text(l10n.noPathsYet))
          else
            for (final r in direct)
              _RepeaterTile(
                repeater: r,
                name: resolvedName(r.hash),
                paths: r.paths,
                resolvedName: resolvedName,
              ),
        ],
      ),
    );
  }
}

class _RepeaterTile extends StatelessWidget {
  const _RepeaterTile({
    required this.repeater,
    required this.name,
    required this.paths,
    required this.resolvedName,
  });

  final DirectRepeater repeater;
  final String name;
  final List<HeardPathRow> paths;
  final String Function(String) resolvedName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = repeater.averageSnr == null
        ? l10n.heardTimesNoSnr(repeater.heard)
        : l10n.heardTimes(
            repeater.heard,
            repeater.averageSnr!.toStringAsFixed(1),
          );

    return ExpansionTile(
      leading: const Icon(Icons.cell_tower),
      title: Text(name),
      subtitle: Text(subtitle),
      children: [
        for (final p in paths)
          ListTile(
            dense: true,
            title: Text(
              [
                for (final h in pathHops(p.hops)) resolvedName(h),
                context.l10n.you,
              ].join(' → '),
            ),
            trailing: Text('×${p.count}'),
          ),
      ],
    );
  }
}
