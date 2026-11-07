import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app/connection.dart';
import '../radio/radio.dart';
import 'node_details.dart';

/// The map's base tiles. Tests replace this with nothing so they don't hit
/// the network.
final mapTilesProvider = Provider<Widget?>(
  (ref) => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.bastionmesh.notoryx_core',
    maxZoom: 19,
  ),
);

/// Finds the phone's own position. Tests replace this.
final phonePositionProvider = Provider<Future<LatLng?> Function()>(
  (ref) => () async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final p = await Geolocator.getCurrentPosition();
    return LatLng(p.latitude, p.longitude);
  },
);

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
          const SnackBar(
            content: Text(
              'Location is off or not allowed for NOTORYX Independent.',
            ),
          ),
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
            MarkerLayer(
              markers: [
                for (final node in nodes)
                  Marker(
                    point: LatLng(node.latitude!, node.longitude!),
                    width: 40,
                    height: 40,
                    child: _NodeMarker(
                      node: node,
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
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No positions yet. Nodes appear here when their '
                  'adverts share where they are.',
                ),
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
                  tooltip: 'Go to my radio',
                  onPressed: () => _map.move(radio, 13),
                  child: const Icon(Icons.router),
                ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'map-phone',
                tooltip: 'Go to my location',
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
  const _NodeMarker({required this.node, required this.onTap});

  final NodeSummary node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = node.isContact
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    return Semantics(
      button: true,
      label: node.name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: node.isContact ? scheme.primary : scheme.outline,
              width: 2,
            ),
          ),
          child: Icon(
            node.type == NodeType.chat ? Icons.person : nodeIcon(node.type),
            size: 20,
            color: node.isContact
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
