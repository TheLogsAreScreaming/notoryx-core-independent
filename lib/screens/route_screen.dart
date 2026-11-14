import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/hop_names.dart';
import '../app/path_graph.dart';
import '../app/route_planner.dart';
import '../app/trace.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';

/// The route to a contact, hop by hop with how well each link works, and
/// a picker for a more reliable one. Opened from a message (which adds how
/// that message travelled) or from the contact's details.
class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({required this.contact, this.message, super.key});

  final Contact contact;
  final Message? message;

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

enum _Measure { idle, running, failed }

class _RouteScreenState extends ConsumerState<RouteScreen> {
  _Measure _measure = _Measure.idle;
  TraceData? _trace;

  /// The route the trace was taken on, so a new route drops old numbers.
  int? _traceRoute;

  /// Hops of the route being built by hand, or null when not building.
  List<String>? _custom;
  bool _saving = false;

  Contact _live(List<Contact> contacts) =>
      contacts
          .where((c) => c.publicKey == widget.contact.publicKey)
          .firstOrNull ??
      widget.contact;

  Future<void> _runMeasure(Contact contact) async {
    final connection = ref.read(connectionProvider);
    final plan = planTrace(contact);
    if (connection is! Connected || plan == null) return;
    setState(() => _measure = _Measure.running);
    try {
      final trace = await connection.sync.trace(
        plan.hops,
        hashBytes: plan.hashBytes,
      );
      if (!mounted) return;
      setState(() {
        _trace = trace;
        _traceRoute = contact.outPathLength;
        _measure = trace == null ? _Measure.failed : _Measure.idle;
      });
    } on RadioRequestException {
      if (mounted) setState(() => _measure = _Measure.failed);
    }
  }

  Future<void> _apply(Contact contact, List<String>? hops, int size) async {
    final connection = ref.read(connectionProvider);
    if (connection is! Connected) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final key = PublicKey.fromHex(contact.publicKey);
    setState(() => _saving = true);
    try {
      if (hops == null) {
        await connection.sync.resetRoute(key);
      } else {
        await connection.sync.setRoute(key, routeBytes(hops), hashBytes: size);
      }
      if (!mounted) return;
      setState(() {
        _custom = null;
        _trace = null;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            hops == null
                ? l10n.routeResetTheNextMessageFloods
                : l10n.routeSaved,
          ),
        ),
      );
    } on RadioRequestException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.routeSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final radioKey = ref.watch(radioKeyProvider) ?? widget.contact.radioKey;
    final contacts = ref.watch(contactsProvider(radioKey)).value ?? const [];
    final heard = ref.watch(heardPathsProvider(radioKey)).value ?? const [];
    final connected = ref.watch(connectionProvider) is Connected;
    final contact = _live(contacts);
    final repeaters = [
      for (final c in contacts)
        if (NodeType.fromByte(c.type) case NodeType.repeater || NodeType.room)
          (name: c.name, publicKey: c.publicKey),
    ];
    final hints = hopHints(
      ref,
      radioKey,
      onlineLabel: context.l10n.foundOnline,
    );
    final unknown = <String>{};
    String name(String hash) {
      final named = hopName(hash, repeaters, hints: hints);
      if (named == hash.toUpperCase()) unknown.add(hash);
      return named;
    }

    afterNamingHops(ref, unknown, hints);

    final trace = _traceRoute == contact.outPathLength ? _trace : null;
    final hops = routeHops(contact);
    final legs = hops == null
        ? const <RouteLeg>[]
        : routeLegs(contact, you: l10n.routeYou, name: name, trace: trace);
    final options = routeOptions(contact, heard, trace: trace);
    final suggestion = suggestedRoute(options);
    final canMeasure = connected && planTrace(contact) != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeTo(contact.name))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (widget.message case final message?)
            _MessageNote(message: message),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(switch (hops) {
              null => l10n.routeFloods(contact.name),
              [] => l10n.routeDirect(contact.name),
              _ => l10n.routeIntro(contact.name),
            }),
          ),
          if (legs.isNotEmpty) _RouteChart(legs: legs),
          if (hops != null && hops.isNotEmpty || canMeasure)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _measure == _Measure.running
                  ? Row(
                      children: [
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.measuringRoute)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.network_check),
                          label: Text(l10n.measureEachHop),
                          onPressed: canMeasure
                              ? () => _runMeasure(contact)
                              : null,
                        ),
                        if (!connected)
                          Text(l10n.connectToTheRadioFirst)
                        else if (!canMeasure)
                          Text(l10n.routeCannotMeasure),
                        if (_measure == _Measure.failed)
                          Text(l10n.routeMeasureFailed),
                      ],
                    ),
            ),
          const Divider(height: 32),
          ListTile(
            title: Text(
              l10n.chooseARoute,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(l10n.routeOptionsIntro),
          ),
          for (final option in options)
            _OptionTile(
              option: option,
              name: name,
              suggested: identical(option, suggestion),
              onUse:
                  !connected || _saving || option.source == RouteSource.current
                  ? null
                  : () => _apply(
                      contact,
                      option.source == RouteSource.flood ? null : option.hops,
                      option.hashBytes,
                    ),
            ),
          const Divider(height: 32),
          _CustomRoute(
            hops: _custom,
            hashBytes: routeHashBytes(contact),
            repeaters: repeaters,
            heard: heard,
            name: name,
            enabled: connected && !_saving,
            onChanged: (hops) => setState(() => _custom = hops),
            onSave: (hops) => _apply(contact, hops, routeHashBytes(contact)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// How the message the screen was opened from travelled.
class _MessageNote extends StatelessWidget {
  const _MessageNote({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lines = <String>[
      if (message.outgoing)
        message.flooded == true
            ? l10n.thisMessageFlooded
            : l10n.thisMessageUsedTheRoute
      else if (message.pathLength case final len? when len != pathUnknown)
        l10n.thisMessageFloodedHops(len & 0x3F)
      else
        l10n.thisMessageCameByRoute,
      if (!message.outgoing && message.snr != null)
        l10n.lastHopHeardAt(message.snr!.toStringAsFixed(1)),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(lines.join('\n')),
      ),
    );
  }
}

/// Colour, icon and words for a link quality: never colour alone.
({Color color, IconData icon, String label}) _look(
  BuildContext context,
  LinkQuality q,
) {
  final scheme = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  return switch (q) {
    LinkQuality.good => (
      color: scheme.primary,
      icon: Icons.signal_cellular_alt,
      label: l10n.linkGood,
    ),
    LinkQuality.fair => (
      color: scheme.tertiary,
      icon: Icons.signal_cellular_alt_2_bar,
      label: l10n.linkFair,
    ),
    LinkQuality.poor => (
      color: scheme.error,
      icon: Icons.signal_cellular_alt_1_bar,
      label: l10n.linkPoor,
    ),
    LinkQuality.unknown => (
      color: scheme.outline,
      icon: Icons.signal_cellular_null,
      label: l10n.linkNotMeasured,
    ),
  };
}

String _db(BuildContext context, double? snr) =>
    snr == null ? '–' : context.l10n.db2(snr.toStringAsFixed(1));

/// Each node down the left, joined by a bar per link whose colour, icon,
/// words and length all say how good it is.
class _RouteChart extends StatelessWidget {
  const _RouteChart({required this.legs});

  final List<RouteLeg> legs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget node(String name) => Row(
      children: [
        Icon(Icons.radio_button_checked, color: theme.colorScheme.onSurface),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: node(legs.first.from)),
          for (final leg in legs) ...[
            _LegRow(leg: leg),
            ExcludeSemantics(child: node(leg.to)),
          ],
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg});

  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final look = _look(context, leg.quality);
    final signal = l10n.outAndBack(
      _db(context, leg.out),
      _db(context, leg.back),
    );
    // Bar length follows the weaker measured signal: −20 dB or worse is
    // nearly empty, +10 dB or better is full.
    final weaker = switch ((leg.out, leg.back)) {
      (final a?, final b?) => a < b ? a : b,
      (final a?, null) => a,
      (null, final b?) => b,
      (null, null) => null,
    };
    final fill = weaker == null ? 0.0 : ((weaker + 20) / 30).clamp(0.05, 1.0);
    return Semantics(
      container: true,
      label: l10n.linkSemantics(leg.from, leg.to, look.label, signal),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Center(
                  child: Container(width: 4, height: 44, color: look.color),
                ),
              ),
              const SizedBox(width: 12),
              Icon(look.icon, color: look.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${look.label} · $signal'),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: fill,
                        minHeight: 6,
                        color: look.color,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.name,
    required this.suggested,
    required this.onUse,
  });

  final RouteOption option;
  final String Function(String hash) name;
  final bool suggested;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final look = _look(context, option.weakest);
    final title = switch (option.source) {
      RouteSource.flood => l10n.floodTheMesh,
      _ when option.hops.isEmpty => l10n.directNoRepeaters,
      _ => option.hops.map(name).join(' → '),
    };
    final lines = [
      switch (option.source) {
        RouteSource.current => l10n.routeInUseNow,
        RouteSource.heard => l10n.routeHeardOnTheMesh,
        RouteSource.flood => l10n.floodSubtitle,
      },
      if (option.source != RouteSource.flood) ...[
        l10n.routeReliability(option.score),
        if (option.links > 0) ...[
          l10n.linksSeenWorking(option.seenLinks, option.links),
          l10n.weakestLink(look.label),
        ],
      ],
      if (suggested) l10n.suggestedRoute,
    ];
    return Semantics(
      container: true,
      label: '$title. ${lines.join('. ')}',
      child: ExcludeSemantics(
        child: ListTile(
          leading: Icon(
            suggested
                ? Icons.recommend
                : option.source == RouteSource.flood
                ? Icons.waves
                : look.icon,
            color: suggested ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(title),
          subtitle: Text(lines.join('\n')),
          isThreeLine: true,
          trailing: option.source == RouteSource.current
              ? null
              : TextButton(onPressed: onUse, child: Text(l10n.useThisRoute)),
        ),
      ),
    );
  }
}

/// Builds a route by hand from known repeaters, nearest first.
class _CustomRoute extends StatelessWidget {
  const _CustomRoute({
    required this.hops,
    required this.hashBytes,
    required this.repeaters,
    required this.heard,
    required this.name,
    required this.enabled,
    required this.onChanged,
    required this.onSave,
  });

  final List<String>? hops;
  final int hashBytes;
  final List<({String name, String publicKey})> repeaters;
  final List<HeardPathRow> heard;
  final String Function(String hash) name;
  final bool enabled;
  final ValueChanged<List<String>?> onChanged;
  final ValueChanged<List<String>> onSave;

  /// Every repeater hash this route could use: contacts first, then
  /// repeaters only seen on heard paths.
  List<String> _choices() {
    final out = <String>{
      for (final r in repeaters)
        r.publicKey.substring(0, hashBytes * 2).toLowerCase(),
    };
    for (final p in heard) {
      if (p.hashBytes != hashBytes) continue;
      out.addAll(pathHops(p.hops).map((h) => h.toLowerCase()));
    }
    return out.toList();
  }

  Future<void> _pick(BuildContext context, List<String> current) async {
    final choices = _choices();
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(sheet.l10n.pickARepeater)),
            if (choices.isEmpty)
              ListTile(subtitle: Text(sheet.l10n.noRepeatersKnownYet)),
            for (final h in choices)
              ListTile(
                leading: const Icon(Icons.cell_tower),
                title: Text(name(h)),
                subtitle: Text(h.toUpperCase()),
                onTap: () => Navigator.pop(sheet, h),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged([...current, picked]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hops = this.hops;
    if (hops == null) {
      return ListTile(
        leading: const Icon(Icons.edit_road),
        title: Text(l10n.buildYourOwnRoute),
        subtitle: Text(l10n.buildRouteIntro),
        onTap: () => onChanged(const []),
      );
    }
    final fits = routeFits(hops, hashBytes);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.buildYourOwnRoute,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(l10n.buildRouteIntro),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hops.isEmpty) Chip(label: Text(l10n.directNoRepeaters)),
              for (final (i, h) in hops.indexed)
                InputChip(
                  label: Text('${i + 1}. ${name(h)}'),
                  deleteButtonTooltipMessage: l10n.removeHop(name(h)),
                  onDeleted: () => onChanged([...hops]..removeAt(i)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add),
                label: Text(l10n.addHop),
                onPressed: () => _pick(context, hops),
              ),
            ],
          ),
          if (!fits && hops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.routeTooLong),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: enabled && fits ? () => onSave(hops) : null,
                child: Text(l10n.useThisRoute),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => onChanged(null),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
