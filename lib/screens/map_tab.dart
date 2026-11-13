import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/connection.dart';
import '../app/map_cache.dart';
import '../app/telemetry.dart';
import '../app/track_log.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'node_details.dart';
import 'zone_alerts_screen.dart';
import 'track_log_screen.dart';
import '../app/position.dart';
import '../l10n/l10n.dart';
import '../app/wardrive.dart';
import 'wardrive_screen.dart';

export '../app/position.dart' show phonePositionProvider;

/// The map's base tiles, saved as they're viewed so they work offline
/// later. Tests replace this with nothing so they don't hit the network.
final mapTilesProvider = Provider<Widget?>((ref) {
  // Wait for the saved tiles: the first tile layer fixes where they live.
  final cache = ref.watch(mapCacheProvider).value;
  if (cache == null) return null;
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.bastionmesh.notoryx_core',
    maxZoom: 19,
    tileProvider: NetworkTileProvider(cachingProvider: cache),
  );
});

/// Contacts and nodes heard nearby that share a position, plus this radio
/// and (on request) the phone. Tap a marker for details.
class MapTab extends ConsumerStatefulWidget {
  const MapTab({required this.radioKey, super.key});

  final String radioKey;

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  final _map = MapController();
  LatLng? _phone;
  bool _locating = false;

  /// The connected radio's own position, if it has one.
  LatLng? _radioPosition() {
    final state = ref.watch(connectionProvider);
    if (state is! Connected) return null;
    final self = state.radio.self;
    return self.latitude == null
        ? null
        : LatLng(self.latitude!, self.longitude!);
  }

  Future<void> _goToPhone() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      final here = await ref.read(phonePositionProvider)();
      if (!mounted) return;
      if (here == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.locationIsOffOrNotAllowed)),
        );
        return;
      }
      setState(() => _phone = here);
      _map.move(here, 14);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts =
        ref.watch(contactsProvider(widget.radioKey)).value ?? const [];
    final heard =
        ref.watch(discoveredProvider(widget.radioKey)).value ?? const [];
    final nodes = [
      for (final c in contacts)
        if (c.latitude != null) nodeFromContact(c),
      for (final d in heard)
        if (d.latitude != null) nodeFromDiscovered(d),
    ];
    final latest =
        ref.watch(latestTelemetryProvider(widget.radioKey)).value ?? const {};
    final activeTrack = ref.watch(trackRecorderProvider);
    final trail = activeTrack == null
        ? const <LatLng>[]
        : [
            for (final p
                in ref.watch(trackPointsProvider(activeTrack)).value ??
                    const <TrackPoint>[])
              LatLng(p.latitude, p.longitude),
          ];
    final radio = _radioPosition();
    final scheme = Theme.of(context).colorScheme;
    final points = [
      for (final n in nodes) LatLng(n.latitude!, n.longitude!),
      ?radio,
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter:
                radio ?? (points.isEmpty ? const LatLng(20, 0) : points.first),
            initialZoom: radio != null || points.isNotEmpty ? 10 : 2,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(48),
                    maxZoom: 13,
                  )
                : null,
          ),
          children: [
            ?ref.watch(mapTilesProvider),
            if (trail.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: trail,
                    strokeWidth: 4,
                    color: scheme.primary,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final node in nodes)
                  Marker(
                    point: LatLng(node.latitude!, node.longitude!),
                    width: 110,
                    height: 84,
                    child: _NodeMarker(
                      node: node,
                      badge: switch (latest[node.publicKey]) {
                        final sample? => telemetryBadge(sample),
                        null => null,
                      },
                      onTap: () =>
                          showNodeDetails(context, ref, node, from: radio),
                    ),
                  ),
                if (radio != null)
                  Marker(
                    point: radio,
                    width: 40,
                    height: 40,
                    child: Semantics(
                      label: 'Your radio',
                      child: Icon(
                        Icons.router,
                        color: scheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
                if (_phone case final phone?)
                  Marker(
                    point: phone,
                    width: 24,
                    height: 24,
                    child: Semantics(
                      label: 'You',
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (nodes.isEmpty && radio == null)
          Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(context.l10n.noPositionsYetNodesAppearHere),
              ),
            ),
          ),
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              if (radio != null)
                FloatingActionButton.small(
                  heroTag: 'map-radio',
                  tooltip: context.l10n.goToMyRadio,
                  onPressed: () => _map.move(radio, 13),
                  child: const Icon(Icons.router),
                ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                key: const Key('map-zones'),
                heroTag: 'map-zones',
                tooltip: context.l10n.zoneAlerts,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ZoneAlertsScreen(),
                  ),
                ),
                child: const Icon(Icons.radar),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'map-wardrive',
                tooltip: context.l10n.wardrive,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WardriveScreen(),
                  ),
                ),
                child: Icon(
                  ref.watch(wardriveProvider) == null
                      ? Icons.cell_tower
                      : Icons.radio_button_on,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'map-track',
                tooltip: activeTrack == null ? 'Track log' : 'Recording track',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TrackLogScreen(),
                  ),
                ),
                child: Icon(
                  activeTrack == null ? Icons.route : Icons.radio_button_on,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'map-phone',
                tooltip: context.l10n.goToMyLocation,
                onPressed: _locating ? null : _goToPhone,
                child: _locating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NodeMarker extends StatelessWidget {
  const _NodeMarker({required this.node, required this.onTap, this.badge});

  final NodeSummary node;
  final VoidCallback onTap;

  /// Latest readings, when there are recent ones.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = node.isContact
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final badgeText = badge;
    // The circle stays centred on the node's position; the badge hangs
    // below it.
    return Stack(
      alignment: Alignment.center,
      children: [
        Semantics(
          button: true,
          label: badgeText == null ? node.name : '${node.name}, $badgeText',
          child: GestureDetector(
            // Bigger than the dot, so it's a comfortable target.
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: node.isContact ? scheme.primary : scheme.outline,
                    width: 2,
                  ),
                ),
                child: Icon(
                  node.type == NodeType.chat
                      ? Icons.person
                      : nodeIcon(node.type),
                  size: 20,
                  color: node.isContact
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        if (badgeText != null)
          Positioned(
            bottom: 2,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outline),
                ),
                child: Text(
                  badgeText,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
