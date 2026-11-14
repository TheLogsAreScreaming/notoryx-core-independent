import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/observer_reach.dart';
import '../l10n/l10n.dart';

/// Which observers (listening stations reporting to an analyzer server)
/// heard this radio directly, and which repeaters it links with. Nothing is
/// sent until the person turns it on here.
class ObserverReachScreen extends ConsumerStatefulWidget {
  const ObserverReachScreen({
    required this.nodeKey,
    required this.name,
    super.key,
  });

  /// The radio's public key (hex).
  final String nodeKey;
  final String name;

  @override
  ConsumerState<ObserverReachScreen> createState() =>
      _ObserverReachScreenState();
}

class _ObserverReachScreenState extends ConsumerState<ObserverReachScreen> {
  late final _server = TextEditingController(
    text: ref.read(observerReachProvider).server,
  );
  ReachResult? _result;
  bool _busy = false;
  bool _badServer = false;

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    final result = await ref
        .read(observerReachProvider.notifier)
        .check(widget.nodeKey);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  Future<void> _setServer(String url) async {
    final ok = await ref.read(observerReachProvider.notifier).setServer(url);
    if (!mounted) return;
    setState(() {
      _badServer = !ok;
      if (ok) _result = null;
    });
  }

  Future<void> _setOn(bool on) async {
    await ref.read(observerReachProvider.notifier).setOn(on);
    if (!mounted) return;
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(observerReachProvider);
    ref.listen(observerReachProvider, (old, next) {
      if (old?.server != next.server && _server.text != next.server) {
        _server.text = next.server;
      }
    });
    final small = Theme.of(context).textTheme.bodySmall;

    return Scaffold(
      appBar: AppBar(title: Text(l.observerReach)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.observerReachExplainer(settings.host),
              key: const ValueKey('reach-explainer'),
              style: small,
            ),
          ),
          SwitchListTile(
            key: const ValueKey('reach-on'),
            title: Text(l.observerReachSwitch),
            subtitle: Text(
              settings.on
                  ? l.observerReachSends(settings.host)
                  : l.observerReachOffNote,
            ),
            value: settings.on,
            onChanged: _setOn,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('reach-server'),
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.reachServer,
                errorText: _badServer ? l.reachServerInvalid : null,
              ),
              onSubmitted: _setServer,
            ),
          ),
          if (settings.on)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const ValueKey('reach-check'),
                onPressed: _busy ? null : _check,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cell_tower),
                label: Text(_busy ? l.reachChecking : l.reachCheckNow),
              ),
            ),
          if (settings.on && _result != null) ..._results(context, _result!),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context, ReachResult result) {
    final l = context.l10n;
    Widget note(String text) => Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(liveRegion: true, child: Text(text)),
    );
    switch (result) {
      case ReachOff():
        return const [];
      case ReachUnknown():
        return [note(l.reachUnknown)];
      case ReachFailed():
        return [note(l.reachFailed)];
      case ReachFound(:final reach):
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                l.reachHeardBy(reach.observers.length, reach.days),
                key: const ValueKey('reach-summary'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          for (final o in reach.observers)
            ListTile(
              key: ValueKey('reach-observer-${o.key}'),
              leading: const Icon(Icons.hearing),
              title: Text(o.name),
              subtitle: Text(
                [
                  l.reachPackets(o.count),
                  if (o.snr case final snr?)
                    l.reachAverageSnr(snr.toStringAsFixed(1)),
                  if (o.km case final km?) l.reachKmAway(_km(km)),
                ].join(' · '),
              ),
            ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              header: true,
              child: Text(
                l.reachLinks,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (reach.links.isEmpty) note(l.reachNoLinks),
          for (final link in reach.links)
            ListTile(
              key: ValueKey('reach-link-${link.key}'),
              leading: Icon(link.both ? Icons.sync_alt : Icons.east),
              title: Text(link.name),
              subtitle: Text(
                [
                  l.reachLinkCounts(link.weHear, link.theyHear),
                  if (!link.both) l.reachOneWay,
                  if (link.km case final km?) l.reachKmAway(_km(km)),
                ].join(' · '),
              ),
            ),
        ];
    }
  }

  static String _km(double km) =>
      km < 10 ? km.toStringAsFixed(1) : km.round().toString();
}
