/// Live traffic on the map: each packet the radio hears becomes a route,
/// origin through each repeater to this radio, drawn hop by hop and
/// coloured by what the packet carries.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../radio/radio.dart';
import 'connection.dart';

/// The six colours packets are drawn in.
enum TrafficKind {
  advert(Color(0xFFFF5CAD)),
  direct(Color(0xFF4C8DFF)),
  channel(Color(0xFF37D67A)),
  ack(Color(0xFF2ED3E6)),
  trace(Color(0xFFFF9B2F)),
  path(Color(0xFFB57BFF));

  const TrafficKind(this.colour);

  final Color colour;

  /// Which colour a packet carrying [payload] gets. Encrypted requests and
  /// replies between two nodes count as direct messages; everything that
  /// doesn't fit another colour is drawn as a path.
  static TrafficKind of(PayloadKind payload) => switch (payload) {
    PayloadKind.advert => advert,
    PayloadKind.text ||
    PayloadKind.request ||
    PayloadKind.response ||
    PayloadKind.anonRequest => direct,
    PayloadKind.groupText || PayloadKind.groupData => channel,
    PayloadKind.ack => ack,
    PayloadKind.trace => trace,
    _ => path,
  };
}

/// A node the map knows about, for naming and placing hops.
typedef TrafficNode = ({String publicKey, String name, LatLng? at});

/// One stop on a packet's route.
final class TrafficStop {
  const TrafficStop({
    required this.id,
    this.name,
    this.publicKey,
    this.at,
    this.isSelf = false,
  });

  /// The ID as heard, lower-case hex: a hop hash, or a full key.
  final String id;

  /// The node's name, when the ID matched a known node.
  final String? name;
  final String? publicKey;

  /// Where it is, when the node shares a position.
  final LatLng? at;

  /// Whether this stop is this radio.
  final bool isSelf;

  /// The ID shortened for display, upper-case.
  String get shortId => id.substring(0, math.min(id.length, 8)).toUpperCase();

  String get label => name ?? shortId;

  @override
  String toString() => 'TrafficStop($label${at == null ? ', off map' : ''})';
}

/// A packet's route as far as the map can tell.
final class TrafficRoute {
  const TrafficRoute({
    required this.payload,
    required this.routeKind,
    required this.stops,
    required this.hopCount,
    required this.snr,
    required this.rssi,
    required this.heardAt,
    this.raw,
  });

  final PayloadKind payload;
  final RouteKind routeKind;

  /// Origin (when the packet names it), each repeater, then this radio
  /// when the packet reached it through them.
  final List<TrafficStop> stops;
  final int hopCount;
  final double snr;
  final int rssi;
  final DateTime heardAt;

  /// The packet as heard, for the details sheet.
  final Uint8List? raw;

  TrafficKind get kind => TrafficKind.of(payload);

  bool get isFlood => routeKind.label == 'flood';

  /// The stops that have a position, in route order.
  List<TrafficStop> get placed => [
    for (final s in stops)
      if (s.at != null) s,
  ];

  /// Map points in route order, without repeats of the same spot back to
  /// back. Stops with no position are skipped.
  List<LatLng> get points {
    final out = <LatLng>[];
    for (final s in stops) {
      final at = s.at;
      if (at == null) continue;
      if (out.isNotEmpty && out.last == at) continue;
      out.add(at);
    }
    return out;
  }

  /// A label for each of [points]: the first stop at that spot.
  List<String> get pointLabels {
    final out = <String>[];
    LatLng? last;
    for (final s in stops) {
      final at = s.at;
      if (at == null) continue;
      if (last == at) continue;
      last = at;
      out.add(s.label);
    }
    return out;
  }

  /// Stops with no position, not counting this radio.
  List<TrafficStop> get offMap => [
    for (final s in stops)
      if (s.at == null && !s.isSelf) s,
  ];

  /// The node this radio heard it from: the stop just before this radio.
  TrafficStop? get heardFrom {
    if (stops.length < 2 || !stops.last.isSelf) return null;
    return stops[stops.length - 2];
  }

  /// The route as text, `Origin → hop → … → last`.
  String get summary => stops.map((s) => s.label).join(' → ');
}

/// Works out the route of the packet [raw] that this radio heard.
///
/// Floods carry the repeaters that passed them on, oldest first, so the
/// route is origin → each repeater → this radio. Direct packets carry the
/// hops still to go, so the route ends at this radio only when none are
/// left. Hop hashes are matched to [nodes] by key prefix; when several
/// match, the one nearest the previous placed stop wins. Null when [raw]
/// isn't a packet.
TrafficRoute? buildTrafficRoute({
  required Uint8List raw,
  required double snr,
  required int rssi,
  required DateTime heardAt,
  required List<TrafficNode> nodes,
  TrafficNode? self,
}) {
  final header = PacketHeader.parse(raw);
  if (header == null) return null;
  final payload = Uint8List.sublistView(raw, raw.length - header.payloadLength);

  final ids = <String>[
    ?_originId(header, payload),
    ...(header.payload == PayloadKind.trace
        ? _traceHops(payload)
        : header.hops),
  ];
  final flood = header.route.label == 'flood';
  final reachesUs = flood || header.hops.isEmpty;

  final stops = <TrafficStop>[];
  LatLng? previous = self?.at;
  for (final id in ids) {
    final stop = _resolve(id, nodes, near: _lastPlaced(stops) ?? previous);
    // A repeater that's also the origin isn't drawn twice.
    if (stops.isNotEmpty &&
        stop.publicKey != null &&
        stops.last.publicKey == stop.publicKey) {
      continue;
    }
    stops.add(stop);
  }
  if (reachesUs && self != null) {
    stops.add(
      TrafficStop(
        id: self.publicKey.toLowerCase(),
        name: self.name,
        publicKey: self.publicKey.toLowerCase(),
        at: self.at,
        isSelf: true,
      ),
    );
  }
  return TrafficRoute(
    payload: header.payload,
    routeKind: header.route,
    stops: stops,
    hopCount: header.hopCount,
    snr: snr,
    rssi: rssi,
    heardAt: heardAt,
    raw: raw,
  );
}

LatLng? _lastPlaced(List<TrafficStop> stops) {
  for (final s in stops.reversed) {
    if (s.at case final at?) return at;
  }
  return null;
}

/// The sender, when the packet names it in the clear.
String? _originId(PacketHeader header, Uint8List payload) =>
    switch (header.payload) {
      PayloadKind.advert => header.advertKey,
      // Destination hash, then the sender's full key.
      PayloadKind.anonRequest when payload.length >= 33 => toHex(
        payload.sublist(1, 33),
      ),
      // Destination hash, then the sender's hash.
      PayloadKind.text ||
      PayloadKind.request ||
      PayloadKind.response ||
      PayloadKind.path when payload.length >= 2 => toHex([payload[1]]),
      _ => null,
    };

/// A trace's planned hops: after a 4-byte tag, 4-byte auth code and a
/// flags byte whose low two bits give the hash size as a power of two.
List<String> _traceHops(Uint8List payload) {
  if (payload.length < 9) return const [];
  final size = 1 << (payload[8] & 0x03);
  final hashes = payload.length - 9;
  return [
    for (var i = 9; i + size <= 9 + hashes; i += size)
      toHex(payload.sublist(i, i + size)),
  ];
}

TrafficStop _resolve(String id, List<TrafficNode> nodes, {LatLng? near}) {
  final want = id.toLowerCase();
  final matches = [
    for (final n in nodes)
      if (n.publicKey.toLowerCase().startsWith(want)) n,
  ];
  if (matches.isEmpty) return TrafficStop(id: want);
  var pick = matches.first;
  if (matches.length > 1) {
    final placed = [
      for (final m in matches)
        if (m.at != null) m,
    ];
    if (placed.isNotEmpty) {
      pick = placed.first;
      if (near != null) {
        const distance = Distance();
        var best = double.infinity;
        for (final m in placed) {
          final d = distance(near, m.at!);
          if (d < best) {
            best = d;
            pick = m;
          }
        }
      }
    }
  }
  return TrafficStop(
    id: want,
    name: pick.name,
    publicKey: pick.publicKey.toLowerCase(),
    at: pick.at,
  );
}

/// How long one leg of a route takes to travel, and how long the whole
/// route takes to fade once it has arrived.
const trafficLegTime = Duration(milliseconds: 550);
const trafficMaxTravel = Duration(milliseconds: 4000);
const trafficFadeTime = Duration(milliseconds: 3500);

/// How many routes animate at once; the rest wait their turn.
const trafficMaxActive = 3;

/// The most routes kept waiting; older ones are dropped.
const trafficMaxWaiting = 20;

/// How long [route] spends travelling before it fades. Nothing travels
/// when motion is reduced.
Duration trafficTravelTime(TrafficRoute route, {bool reduceMotion = false}) {
  if (reduceMotion) return Duration.zero;
  final legs = math.max(0, route.points.length - 1);
  final travel = trafficLegTime * legs;
  return travel > trafficMaxTravel ? trafficMaxTravel : travel;
}

/// A route on screen, started at [start] on the layer's clock.
typedef ActiveTraffic = ({TrafficRoute route, Duration start});

/// What the traffic layer shows.
final class TrafficState {
  const TrafficState({
    this.on = false,
    this.shown = const {...TrafficKind.values},
    this.active = const [],
    this.waiting = const [],
    this.latest,
  });

  /// Whether Traffic mode is on.
  final bool on;

  /// The kinds of packet drawn; the rest are ignored.
  final Set<TrafficKind> shown;
  final List<ActiveTraffic> active;
  final List<TrafficRoute> waiting;

  /// The newest route shown, for the route card.
  final TrafficRoute? latest;

  bool get busy => active.isNotEmpty || waiting.isNotEmpty;

  TrafficState copyWith({
    bool? on,
    Set<TrafficKind>? shown,
    List<ActiveTraffic>? active,
    List<TrafficRoute>? waiting,
    TrafficRoute? latest,
    bool clearLatest = false,
  }) => TrafficState(
    on: on ?? this.on,
    shown: shown ?? this.shown,
    active: active ?? this.active,
    waiting: waiting ?? this.waiting,
    latest: clearLatest ? null : latest ?? this.latest,
  );
}

/// Where the map's nodes and this radio are, for building routes. Kept up
/// to date by the map while it's open.
typedef TrafficPlace = ({List<TrafficNode> nodes, TrafficNode? self});

final trafficProvider = NotifierProvider<TrafficNotifier, TrafficState>(
  TrafficNotifier.new,
);

/// Setting keys: Traffic on ('1'/'0') and the shown kinds, comma-separated.
const trafficOnKey = 'traffic.on';
const trafficShownKey = 'traffic.shown';

/// Reads the saved shown kinds; unknown names are ignored, nothing saved
/// means all of them.
Set<TrafficKind> decodeTrafficShown(String? saved) {
  if (saved == null) return {...TrafficKind.values};
  final names = saved.split(',');
  return {
    for (final k in TrafficKind.values)
      if (names.contains(k.name)) k,
  };
}

String encodeTrafficShown(Set<TrafficKind> shown) => [
  for (final k in TrafficKind.values)
    if (shown.contains(k)) k.name,
].join(',');

class TrafficNotifier extends Notifier<TrafficState> {
  StreamSubscription<RxLog>? _sub;

  /// Whether the toggle or filter changed since the saved choice was read,
  /// so a late read doesn't undo it.
  bool _touched = false;
  bool _loaded = false;

  /// The nodes routes are matched against.
  TrafficPlace place = (nodes: const [], self: null);

  @override
  TrafficState build() {
    ref.listen(
      connectionProvider,
      (_, next) => _follow(next),
      fireImmediately: true,
    );
    ref.onDispose(() => _sub?.cancel());
    return const TrafficState();
  }

  void _follow(RadioConnectionState state) {
    unawaited(_sub?.cancel());
    _sub = null;
    if (state is! Connected) return;
    _sub = state.sync.heard.listen(heard);
    if (!_loaded) unawaited(_load());
  }

  /// Brings back the toggle and filter from last time.
  Future<void> _load() async {
    _loaded = true;
    try {
      final store = ref.read(storeProvider);
      final on = await store.setting(trafficOnKey);
      final shown = await store.setting(trafficShownKey);
      if (!ref.mounted || _touched) return;
      state = state.copyWith(on: on == '1', shown: decodeTrafficShown(shown));
    } on Object catch (e) {
      // Not worth stopping the map for; it starts off as before.
      _loaded = false;
      debugPrint('Traffic settings not read: $e');
    }
  }

  Future<void> _save(String key, String value) async {
    try {
      await ref.read(storeProvider).saveSetting(key, value);
    } on Object catch (_) {
      // The choice still holds for this run.
    }
  }

  void setOn(bool on) {
    _touched = true;
    state = on ? state.copyWith(on: true) : TrafficState(shown: state.shown);
    unawaited(_save(trafficOnKey, on ? '1' : '0'));
  }

  void setShown(Set<TrafficKind> shown) {
    _touched = true;
    unawaited(_save(trafficShownKey, encodeTrafficShown(shown)));
    state = state.copyWith(
      shown: shown,
      active: [
        for (final a in state.active)
          if (shown.contains(a.route.kind)) a,
      ],
      waiting: [
        for (final r in state.waiting)
          if (shown.contains(r.kind)) r,
      ],
    );
  }

  /// Turns [log], heard now, into a route waiting to be drawn.
  void heard(RxLog log, {DateTime? at}) {
    if (!state.on) return;
    final route = buildTrafficRoute(
      raw: log.packet,
      snr: log.snr,
      rssi: log.rssi,
      heardAt: at ?? DateTime.now(),
      nodes: place.nodes,
      self: place.self,
    );
    if (route != null) add(route);
  }

  /// Queues [route] to be drawn, if its kind is shown.
  void add(TrafficRoute route) {
    if (!state.on || !state.shown.contains(route.kind)) return;
    final waiting = [...state.waiting, route];
    state = state.copyWith(
      waiting: waiting.length > trafficMaxWaiting
          ? waiting.sublist(waiting.length - trafficMaxWaiting)
          : waiting,
      latest: route,
    );
  }

  /// Moves the layer's clock to [now]: finished routes go, and waiting ones
  /// start while there's room.
  void advance(Duration now, {bool reduceMotion = false}) {
    if (!state.busy) return;
    final active = [
      for (final a in state.active)
        if (a.start <= now &&
            now - a.start <
                trafficTravelTime(a.route, reduceMotion: reduceMotion) +
                    trafficFadeTime)
          a,
    ];
    final waiting = [...state.waiting];
    while (active.length < trafficMaxActive && waiting.isNotEmpty) {
      active.add((route: waiting.removeAt(0), start: now));
    }
    if (active.length == state.active.length &&
        waiting.length == state.waiting.length &&
        _same(active, state.active)) {
      return;
    }
    state = state.copyWith(active: active, waiting: waiting);
  }

  static bool _same(List<ActiveTraffic> a, List<ActiveTraffic> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i].route, b[i].route)) return false;
    }
    return true;
  }
}
