import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/contact_room.dart' show isFavourite;
import '../app/favourites_view.dart';
import '../app/connection.dart';
import '../app/map_cache.dart';
import '../app/map_clusters.dart';
import '../app/map_packs.dart';
import '../app/telemetry.dart';
import '../app/track_log.dart';
import '../app/traffic.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import '../app/node_look.dart';
import 'node_details.dart';
import 'map_packs_screen.dart';
import 'zone_alerts_screen.dart';
import 'track_log_screen.dart';
import 'traffic_layer.dart';
import 'packet_log_screen.dart';
import '../app/position.dart';
import '../app/range_rings.dart';
import '../app/stale_nodes.dart';
import 'range_rings_layer.dart';
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
  final network = NetworkTileProvider(cachingProvider: cache);
  // An offline map pack in use is drawn first, online tiles fill the rest.
  final pack = ref.watch(activeMapPackPathProvider).value;
  return TileLayer(
    key: ValueKey(pack),
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.bastionmesh.notoryx_core',
    maxZoom: 19,
    tileProvider: pack == null ? network : MapPackTileProvider(pack, network),
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
  /// Width kept clear down the right for the toolbar and its margin.
  static const _toolbarRoom = 84.0;

  /// The traffic card's height until it has been measured.
  static const _trafficCardGuess = 120.0;

  /// Space between the traffic card and the bottom of the map.
  static const _trafficCardMargin = 12.0;

  /// The traffic card's height when it was last laid out, so the range
  /// rings can keep clear of it. Null until measured.
  double? _trafficCardHeight;
  final _trafficCardKey = GlobalKey();

  /// Reads the traffic card's height after this frame, and rebuilds only
  /// when it changed, so the rings follow the card as its text grows.
  void _measureTrafficCard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _trafficCardKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final height = box.size.height;
      if (height != _trafficCardHeight) {
        setState(() => _trafficCardHeight = height);
      }
    });
  }

  final _map = MapController();
  LatLng? _phone;
  bool _locating = false;

  /// The map's zoom in half steps, for clustering; null until it's shown.
  double? _zoom;

  void _onMove(MapCamera camera) {
    final zoom = (camera.zoom * 2).floorToDouble() / 2;
    if (zoom != _zoom && mounted) setState(() => _zoom = zoom);
  }

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

  /// Hands the nodes this map knows to the traffic layer, so heard paths
  /// can be named and placed.
  void _shareWithTraffic(
    List<Contact> contacts,
    List<DiscoveredData> heard,
    LatLng? radio,
  ) {
    final state = ref.read(connectionProvider);
    final self = state is Connected ? state.radio.self : null;
    LatLng? at(double? lat, double? lon) =>
        lat == null || lon == null ? null : LatLng(lat, lon);
    ref.read(trafficProvider.notifier).place = (
      nodes: [
        for (final c in contacts)
          (
            publicKey: c.publicKey,
            name: c.name,
            at: at(c.latitude, c.longitude),
          ),
        for (final d in heard)
          (
            publicKey: d.publicKey,
            name: d.name,
            at: at(d.latitude, d.longitude),
          ),
      ],
      self: self == null
          ? null
          : (publicKey: self.publicKey.hex, name: self.name, at: radio),
    );
  }

  /// Whether [node] advertised in the last hour.
  bool _recentlyHeard(NodeSummary node) {
    if (node.lastAdvert <= 0) return false;
    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - node.lastAdvert;
    return age >= 0 && age < 3600;
  }

  /// Turns the range rings on or off, and says so when there's no position
  /// to centre them on.
  void _toggleRings({required bool on, required LatLng? centre}) {
    unawaited(setRangeRings(ref, on));
    if (on && centre == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.rangeRingsNoPosition)),
      );
    }
  }

  /// Zooms in on a cluster until its pins come apart.
  void _openCluster(MapCluster<NodeSummary> cluster) {
    final points = [
      for (final n in cluster.items) LatLng(n.latitude!, n.longitude!),
    ];
    final bounds = LatLngBounds.fromPoints(points);
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
      _map.move(cluster.at, clusterUntilZoom);
      return;
    }
    _map.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(72),
        maxZoom: clusterUntilZoom,
      ),
    );
  }

  void _fitAll(List<LatLng> points) {
    if (points.length == 1) {
      _map.move(points.single, 13);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 48, 96, 48),
        maxZoom: 15,
      ),
    );
  }

  Future<void> _advert(BuildContext context) async {
    final l10n = context.l10n;
    final state = ref.read(connectionProvider);
    final messenger = ScaffoldMessenger.of(context);
    final flood = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('map-advert-nearby'),
              leading: const Icon(Icons.campaign_outlined),
              title: Text(l10n.advertiseNearby),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              key: const Key('map-advert-flood'),
              leading: const Icon(Icons.public),
              title: Text(l10n.advertiseAcrossMesh),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (flood == null || state is! Connected) return;
    try {
      await state.sync.sendAdvert(flood: flood);
      unawaited(HapticFeedback.lightImpact());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            flood ? l10n.advertSentAcrossMesh : l10n.advertSentNearby,
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _search(BuildContext context, List<NodeSummary> nodes) async {
    final picked = await showModalBottomSheet<NodeSummary>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NodeSearchSheet(nodes: nodes),
    );
    if (picked == null) return;
    _map.move(LatLng(picked.latitude!, picked.longitude!), 14);
  }

  List<_MapOption> _options(
    BuildContext context, {
    required LatLng? radio,
    required bool favouritesOnly,
    required bool tracking,
    required bool rings,
    required LatLng? me,
  }) {
    final l10n = context.l10n;
    void push(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));
    return [
      if (radio != null)
        _MapOption(
          'map-radio',
          Icons.router,
          l10n.goToMyRadio,
          () => _map.move(radio, 13),
        ),
      _MapOption(
        'map-range-rings',
        rings ? Icons.track_changes : Icons.adjust,
        rings ? l10n.rangeRingsHide : l10n.rangeRingsShow,
        () => _toggleRings(on: !rings, centre: me),
      ),
      _MapOption(
        'map-packs',
        Icons.layers_outlined,
        l10n.offlineMapPacks,
        () => push(const MapPacksScreen()),
      ),
      _MapOption(
        'map-zones',
        Icons.radar,
        l10n.zoneAlerts,
        () => push(const ZoneAlertsScreen()),
      ),
      _MapOption(
        'map-favourites-only',
        favouritesOnly ? Icons.star : Icons.star_outline,
        favouritesOnly ? l10n.showEveryone : l10n.favouritesOnly,
        () => setFavouritesOnly(ref.read(storeProvider), !favouritesOnly),
      ),
      _MapOption(
        'map-wardrive',
        ref.watch(wardriveProvider) == null
            ? Icons.cell_tower
            : Icons.radio_button_on,
        l10n.wardrive,
        () => push(const WardriveScreen()),
      ),
      _MapOption(
        'map-track',
        tracking ? Icons.radio_button_on : Icons.route,
        tracking ? l10n.recordingTrack : l10n.trackLog,
        () => push(const TrackLogScreen()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final contacts =
        ref.watch(contactsProvider(widget.radioKey)).value ?? const [];
    final favouritesOnly = ref.watch(favouritesOnlyProvider).value ?? false;
    final heard = favouritesOnly
        ? const <DiscoveredData>[]
        : ref.watch(discoveredProvider(widget.radioKey)).value ?? const [];
    final nodes = [
      for (final c in contacts)
        if (c.latitude != null && (!favouritesOnly || isFavourite(c)))
          nodeFromContact(c),
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
    // "Me" on the map: the phone once located, otherwise the radio.
    final me = _phone ?? radio;
    final rings = ref.watch(rangeRingsProvider).value ?? false;
    final staleAfter =
        (ref.watch(staleAfterProvider).value ?? StaleAfter.fallback).after;
    final now = DateTime.now();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final traffic = ref.watch(trafficProvider);
    if (rings && traffic.on) _measureTrafficCard();
    _shareWithTraffic(contacts, heard, radio);
    final tiles = ref.watch(mapTilesProvider);
    final zoom = _zoom;
    final grouping = zoom != null && zoom < clusterUntilZoom;
    final clusters = clusterPins(
      nodes,
      position: (n) => LatLng(n.latitude!, n.longitude!),
      project: (at) => const Epsg3857().latLngToOffset(at, zoom ?? 0),
      // Until the map is shown, or when zoomed right in, nothing groups.
      radius: grouping ? clusterRadius : -1,
    );
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
            onMapReady: () => _onMove(_map.camera),
            onPositionChanged: (camera, _) => _onMove(camera),
          ),
          children: [
            if (tiles != null)
              theme.brightness == Brightness.dark
                  ? ColorFiltered(colorFilter: _nightTiles, child: tiles)
                  : tiles,
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
            if (rings && me != null)
              RangeRingsLayer(
                centre: me,
                unit: distanceUnitFor(
                  WidgetsBinding.instance.platformDispatcher.locale,
                ),
                // The toolbar down the right (and the traffic card along
                // the bottom, when it's on) sit over the map.
                covered: EdgeInsets.fromLTRB(
                  8,
                  8,
                  _toolbarRoom,
                  traffic.on
                      ? _trafficCardMargin +
                            (_trafficCardHeight ?? _trafficCardGuess) +
                            8
                      : 8,
                ),
              ),
            const TrafficLayer(),
            MarkerLayer(
              markers: [
                for (final cluster in clusters)
                  if (cluster.items.length > 1)
                    Marker(
                      point: cluster.at,
                      width: 48,
                      height: 48,
                      child: _ClusterMarker(
                        count: cluster.items.length,
                        onTap: () => _openCluster(cluster),
                      ),
                    ),
                for (final node in [
                  for (final c in clusters)
                    if (c.items.length == 1) c.items.single,
                ])
                  Marker(
                    point: LatLng(node.latitude!, node.longitude!),
                    width: 110,
                    height: 84,
                    child: _NodeMarker(
                      node: node,
                      recent: _recentlyHeard(node),
                      stale: isStale(
                        advertTime(node.lastAdvert),
                        now,
                        staleAfter,
                      ),
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
                    // Taps fall through to a cluster underneath.
                    child: Semantics(
                      label: context.l10n.yourRadio,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.router,
                          color: scheme.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                if (_phone case final phone?)
                  Marker(
                    point: phone,
                    width: 24,
                    height: 24,
                    child: Semantics(
                      label: context.l10n.youLabel,
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
        if (traffic.on)
          Positioned(
            left: 12,
            right: _toolbarRoom,
            bottom: _trafficCardMargin,
            child: TrafficRouteCard(
              key: _trafficCardKey,
              onTap: () {
                final latest = ref.read(trafficProvider).latest;
                void openLog() => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PacketLogScreen(),
                  ),
                );
                if (latest == null) {
                  openLog();
                } else {
                  showTrafficPacket(context, latest, onOpenLog: openLog);
                }
              },
            ),
          ),
        Positioned(
          right: 12,
          top: 12,
          bottom: 12,
          child: Align(
            alignment: Alignment.topRight,
            child: SingleChildScrollView(
              child: _MapToolbar(
                locating: _locating,
                trafficOn: traffic.on,
                onLocate: _goToPhone,
                onAdvert: () => _advert(context),
                onFilter: () => showTrafficFilter(context, ref),
                onTraffic: () =>
                    ref.read(trafficProvider.notifier).setOn(!traffic.on),
                onSearch: () => _search(context, nodes),
                onFitAll: points.isEmpty ? null : () => _fitAll(points),
                options: _options(
                  context,
                  radio: radio,
                  favouritesOnly: favouritesOnly,
                  tracking: activeTrack != null,
                  rings: rings,
                  me: me,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeMarker extends ConsumerWidget {
  const _NodeMarker({
    required this.node,
    required this.onTap,
    this.recent = false,
    this.stale = false,
    this.badge,
  });

  final NodeSummary node;
  final VoidCallback onTap;

  /// Whether it was heard lately; drawn with a green ring.
  final bool recent;

  /// Whether it hasn't been heard for the stale-after time; drawn faded,
  /// and said aloud.
  final bool stale;

  /// Latest readings, when there are recent ones.
  final String? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final look = ref
        .watch(nodeLooksProvider)
        .value?[node.publicKey.toLowerCase()];
    final color = switch (look) {
      NodeColour(:final colour) => colour,
      _ when node.isContact => scheme.primaryContainer,
      _ => scheme.surfaceContainerHighest,
    };
    final iconColour = switch (look) {
      NodeColour(:final colour) => onColour(colour),
      _ when node.isContact => scheme.onPrimaryContainer,
      _ => scheme.onSurfaceVariant,
    };
    final badgeText = badge;
    final tower = node.type == NodeType.repeater;
    final ring = recent
        ? const Color(0xFF3DDC84)
        : node.isContact
        ? scheme.primary
        : scheme.outline;
    final staleText = stale
        ? context.l10n.staleBadge(
            timeAgo(node.lastAdvert, DateTime.now(), context.l10n),
          )
        : null;
    final spoken = [node.name, ?staleText, ?badgeText].join(', ');
    // The circle stays centred on the node's position; the badge hangs
    // below it.
    final marker = Stack(
      alignment: Alignment.center,
      children: [
        Semantics(
          button: true,
          label: spoken,
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
                  image: look is NodePhoto
                      ? DecorationImage(image: look.image, fit: BoxFit.cover)
                      : null,
                  shape: tower ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: tower ? BorderRadius.circular(12) : null,
                  border: Border.all(color: ring, width: recent ? 3 : 2),
                ),
                child: look is NodePhoto
                    ? null
                    : Icon(
                        switch (node.type) {
                          NodeType.chat => Icons.person,
                          NodeType.repeater => Icons.cell_tower,
                          _ => nodeIcon(node.type),
                        },
                        size: 20,
                        color: iconColour,
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
    // Faded, not recoloured: the spoken label carries the state too.
    return stale ? Opacity(opacity: 0.45, child: marker) : marker;
  }
}

/// Darkens daytime map tiles for the dark theme: inverted brightness with
/// a slight blue cast, so roads and labels stay readable.
const _nightTiles = ColorFilter.matrix([
  -0.25, -0.62, -0.08, 0, 240, //
  -0.25, -0.62, -0.08, 0, 244, //
  -0.22, -0.58, -0.07, 0, 252, //
  0, 0, 0, 1, 0, //
]);

/// An item in the map's Options menu.
class _MapOption {
  const _MapOption(this.key, this.icon, this.label, this.onTap);

  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The map's tools in one frosted pill down the right side.
class _MapToolbar extends StatelessWidget {
  const _MapToolbar({
    required this.locating,
    required this.trafficOn,
    required this.onLocate,
    required this.onAdvert,
    required this.onFilter,
    required this.onTraffic,
    required this.onSearch,
    required this.onFitAll,
    required this.options,
  });

  final bool locating;
  final bool trafficOn;
  final VoidCallback onLocate;
  final VoidCallback onAdvert;
  final VoidCallback onFilter;
  final VoidCallback onTraffic;
  final VoidCallback onSearch;
  final VoidCallback? onFitAll;
  final List<_MapOption> options;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(
              key: const Key('map-locate'),
              icon: Icons.near_me_outlined,
              label: l10n.mapLocate,
              tooltip: l10n.goToMyLocation,
              busy: locating,
              onTap: locating ? null : onLocate,
            ),
            _ToolButton(
              key: const Key('map-advert'),
              icon: Icons.campaign_outlined,
              label: l10n.mapAdvert,
              tooltip: l10n.mapAdvert,
              onTap: onAdvert,
            ),
            _ToolButton(
              key: const Key('map-filter'),
              icon: Icons.filter_list,
              label: l10n.mapFilter,
              tooltip: l10n.trafficShowPackets,
              onTap: onFilter,
            ),
            _ToolButton(
              key: const Key('map-traffic'),
              icon: Icons.timeline,
              label: l10n.mapTraffic,
              tooltip: trafficOn ? l10n.trafficHideLive : l10n.trafficShowLive,
              selected: trafficOn,
              onTap: onTraffic,
            ),
            _ToolButton(
              key: const Key('map-search'),
              icon: Icons.search,
              label: l10n.search,
              tooltip: l10n.mapSearchNodes,
              onTap: onSearch,
            ),
            _ToolButton(
              key: const Key('map-fit-all'),
              icon: Icons.open_in_full,
              label: l10n.mapFitAll,
              tooltip: l10n.mapShowAllNodes,
              onTap: onFitAll,
            ),
            PopupMenuButton<_MapOption>(
              key: const Key('map-options'),
              tooltip: l10n.mapOptions,
              onSelected: (o) => o.onTap(),
              itemBuilder: (_) => [
                for (final o in options)
                  PopupMenuItem(
                    key: Key(o.key),
                    value: o,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(o.icon),
                      title: Text(o.label),
                    ),
                  ),
              ],
              child: _ToolFace(icon: Icons.more_horiz, label: l10n.mapOptions),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      toggled: selected ? true : null,
      enabled: onTap != null,
      label: tooltip,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: _ToolFace(
          icon: icon,
          label: label,
          selected: selected,
          busy: busy,
          enabled: onTap != null,
        ),
      ),
    ),
  );
}

class _ToolFace extends StatelessWidget {
  const _ToolFace({
    required this.icon,
    required this.label,
    this.selected = false,
    this.busy = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = !enabled && !busy
        ? scheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? scheme.primary
        : scheme.onSurface;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: selected
          ? BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 22,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Icon(icon, size: 22, color: colour),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colour,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Finds a node on the map by name.
class _NodeSearchSheet extends StatefulWidget {
  const _NodeSearchSheet({required this.nodes});

  final List<NodeSummary> nodes;

  @override
  State<_NodeSearchSheet> createState() => _NodeSearchSheetState();
}

class _NodeSearchSheetState extends State<_NodeSearchSheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = [
      for (final n in widget.nodes)
        if (q.isEmpty ||
            n.name.toLowerCase().contains(q) ||
            n.publicKey.toLowerCase().startsWith(q))
          n,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('map-search-field'),
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.l10n.mapSearchNodes,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(child: Text(context.l10n.mapNoNodesMatch))
                  : ListView(
                      children: [
                        for (final n in matches)
                          ListTile(
                            leading: Icon(nodeIcon(n.type)),
                            title: Text(n.name),
                            subtitle: Text(nodeKind(n.type, context.l10n)),
                            onTap: () => Navigator.pop(context, n),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Several nodes too close to tell apart at this zoom.
class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.mapClusterNodes(count),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2F7DF6),
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 6),
              ],
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
