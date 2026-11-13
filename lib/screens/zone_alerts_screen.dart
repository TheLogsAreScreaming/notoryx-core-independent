import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/position.dart';
import '../app/zone_alerts.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';
import 'track_log_screen.dart' show tracksProvider;

const _radii = <double>[50, 100, 200, 300, 500, 750, 1000, 2000, 5000, 10000];
const _limits = <double>[25, 50, 75, 100, 150, 200, 300, 500, 1000];

int _nearest(List<double> stops, double v) {
  var best = 0;
  for (var i = 1; i < stops.length; i++) {
    if ((stops[i] - v).abs() < (stops[best] - v).abs()) best = i;
  }
  return best;
}

String _onLabel(AppLocalizations l, ZoneAlertOn on) => switch (on) {
  ZoneAlertOn.enter => l.zoneOnEnter,
  ZoneAlertOn.leave => l.zoneOnLeave,
  ZoneAlertOn.both => l.zoneOnBoth,
};

typedef _Centre = ({String label, double lat, double lon});

/// Zones that alert when someone crosses them, and a trail that alerts when
/// someone wanders off it.
class ZoneAlertsScreen extends ConsumerWidget {
  const ZoneAlertsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Zone? z) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final radioKey = ref.read(radioKeyProvider);
    final state = ref.read(connectionProvider);
    final self = state is Connected ? state.radio.self : null;
    final phone = await ref.read(phonePositionProvider)();
    final contacts = radioKey == null
        ? const <Contact>[]
        : ref.read(contactsProvider(radioKey)).value ?? const <Contact>[];
    final centres = <_Centre>[
      if (z != null) (label: z.name, lat: z.lat, lon: z.lon),
      if (self?.latitude case final lat?)
        if (self?.longitude case final lon?)
          (label: l.zoneCentreRadio, lat: lat, lon: lon),
      if (phone != null)
        (label: l.zoneCentrePhone, lat: phone.latitude, lon: phone.longitude),
      for (final c in contacts)
        if (c.latitude case final lat?)
          if (c.longitude case final lon?)
            if (!(lat == 0 && lon == 0)) (label: c.name, lat: lat, lon: lon),
    ];
    if (!context.mounted) return;
    if (centres.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.zoneNoCentre)));
      return;
    }
    final saved = await showDialog<Zone>(
      context: context,
      builder: (_) => _ZoneDialog(existing: z, centres: centres),
    );
    if (saved == null) return;
    final ok = await ref.read(zoneSettingsProvider.notifier).saveZone(saved);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.zonesFull(ZoneSettings.maxZones))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(zoneSettingsProvider).value;
    final notifier = ref.read(zoneSettingsProvider.notifier);
    final tracks = ref.watch(tracksProvider).value ?? const <Track>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.zoneAlerts)),
      floatingActionButton: s == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('zone-add'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l.zoneAdd),
              onPressed: () => _edit(context, ref, null),
            ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                SwitchListTile(
                  key: const Key('zones-on'),
                  title: Text(l.zoneAlertsOn),
                  subtitle: Text(l.zoneAlertsHint),
                  value: s.enabled,
                  onChanged: notifier.setEnabled,
                ),
                SwitchListTile(
                  title: Text(l.zoneWatchFavourites),
                  subtitle: Text(l.zoneWatchFavouritesHint),
                  value: s.favouritesOnly,
                  onChanged: notifier.setFavouritesOnly,
                ),
                SwitchListTile(
                  title: Text(l.zoneWatchRadio),
                  value: s.includeRadio,
                  onChanged: notifier.setIncludeRadio,
                ),
                const Divider(),
                ListTile(
                  title: Text(
                    l.zones,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (s.zones.isEmpty) ListTile(subtitle: Text(l.zonesNone)),
                for (final z in s.zones)
                  ListTile(
                    key: Key('zone-${z.id}'),
                    leading: const Icon(Icons.radar),
                    title: Text(z.name),
                    subtitle: Text(
                      '${shortDistance(z.radius)} · ${_onLabel(l, z.on)}',
                    ),
                    trailing: IconButton(
                      tooltip: l.zoneDelete(z.name),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => notifier.deleteZone(z.id),
                    ),
                    onTap: () => _edit(context, ref, z),
                  ),
                const Divider(),
                ListTile(
                  title: Text(
                    l.trailWatch,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(l.trailWatchHint),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<int?>(
                    key: const Key('trail-track'),
                    initialValue: tracks.any((t) => t.id == s.trackId)
                        ? s.trackId
                        : null,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.trailNone)),
                      for (final t in tracks)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: notifier.setTrack,
                  ),
                ),
                if (s.trackId != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(l.trailLimit(shortDistance(s.offTrailMetres))),
                  ),
                  Slider(
                    value: _nearest(_limits, s.offTrailMetres).toDouble(),
                    max: (_limits.length - 1).toDouble(),
                    divisions: _limits.length - 1,
                    onChanged: (v) =>
                        notifier.setOffTrailMetres(_limits[v.round()]),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ZoneDialog extends StatefulWidget {
  const _ZoneDialog({required this.existing, required this.centres});

  final Zone? existing;
  final List<_Centre> centres;

  @override
  State<_ZoneDialog> createState() => _ZoneDialogState();
}

class _ZoneDialogState extends State<_ZoneDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  var _centre = 0;
  late var _radius = _nearest(_radii, widget.existing?.radius ?? 300);
  late var _on = widget.existing?.on ?? ZoneAlertOn.both;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.existing == null ? l.zoneAdd : l.zoneEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('zone-name'),
              controller: _name,
              maxLength: 40,
              decoration: InputDecoration(labelText: l.zoneName),
            ),
            DropdownButtonFormField<int>(
              initialValue: _centre,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.zoneCentre),
              items: [
                for (var i = 0; i < widget.centres.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      widget.centres[i].label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _centre = v ?? 0),
            ),
            const SizedBox(height: 16),
            Text(l.zoneRadius(shortDistance(_radii[_radius]))),
            Slider(
              value: _radius.toDouble(),
              max: (_radii.length - 1).toDouble(),
              divisions: _radii.length - 1,
              onChanged: (v) => setState(() => _radius = v.round()),
            ),
            SegmentedButton<ZoneAlertOn>(
              segments: [
                for (final o in ZoneAlertOn.values)
                  ButtonSegment(value: o, label: Text(_onLabel(l, o))),
              ],
              selected: {_on},
              onSelectionChanged: (v) => setState(() => _on = v.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('zone-save'),
          onPressed: () {
            final c = widget.centres[_centre];
            final n = _name.text.trim();
            Navigator.pop<Zone>(context, (
              id:
                  widget.existing?.id ??
                  DateTime.now().microsecondsSinceEpoch.toRadixString(36),
              name: n.isEmpty ? l.zoneDefaultName : n,
              lat: c.lat,
              lon: c.lon,
              radius: _radii[_radius],
              on: _on,
            ));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
