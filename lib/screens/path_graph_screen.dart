import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/path_graph.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';
import 'network_diagram.dart';

/// Every path heard, grouped by the repeater it reached you through, or
/// drawn as rings of repeaters around you.
class PathGraphScreen extends ConsumerStatefulWidget {
  const PathGraphScreen({super.key});

  @override
  ConsumerState<PathGraphScreen> createState() => _PathGraphScreenState();
}

class _PathGraphScreenState extends ConsumerState<PathGraphScreen> {
  bool _network = false;

  @override
  Widget build(BuildContext context) {
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
          if (direct.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<bool>(
                key: const Key('path-view'),
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.list),
                    label: Text(context.l10n.pathViewList),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.hub_outlined),
                    label: Text(context.l10n.pathViewNetwork),
                  ),
                ],
                selected: {_network},
                onSelectionChanged: (v) => setState(() => _network = v.first),
              ),
            ),
          if (direct.isEmpty)
            ListTile(title: Text(context.l10n.noPathsYet))
          else if (_network)
            _NetworkView(
              net: pathNetwork(paths),
              label: (id) => id == networkSelf ? context.l10n.you : name(id),
            )
          else
            ListTile(
              title: Text(
                context.l10n.heardDirectly,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          for (final r in _network ? const <DirectRepeater>[] : direct)
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

class _NetworkView extends StatelessWidget {
  const _NetworkView({required this.net, required this.label});

  final PathNetwork net;
  final String Function(String id) label;

  void _show(BuildContext context, String id) {
    final n = net.nodes[id]!;
    final l = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l.networkDot(label(id), n.ring, n.relayed))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final size = Size(box.maxWidth, box.maxWidth.clamp(220, 520));
              final layout = layoutNetwork(net, size);
              return Semantics(
                label: context.l10n.networkSemantics(
                  net.nodes.length - 1,
                  layout.rings,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final id = layout.hit(d.localPosition);
                    if (id != null && id != networkSelf) _show(context, id);
                  },
                  child: SizedBox.fromSize(
                    key: const Key('path-network'),
                    size: size,
                    child: CustomPaint(
                      painter: NetworkPainter(
                        net: net,
                        layout: layout,
                        scheme: scheme,
                        labelStyle:
                            (Theme.of(context).textTheme.labelSmall ??
                                    const TextStyle())
                                .copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                        label: label,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.networkHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
