/// Route view and route picker: the hops on the way to a contact with how
/// well each link works, and other ways through the mesh worth trying.
///
/// Link quality comes from two places this app already records: a trace
/// along the route (signal-to-noise for each hop, both ways) and the paths
/// heard on flooded packets (which repeaters pass packets to which, how
/// often, and how well this radio hears the last one).
library;

import 'dart:typed_data';

import '../data/data.dart';
import '../radio/radio.dart';
import 'path_graph.dart';

/// How usable a link is, from its signal-to-noise ratio in dB. Above 0 dB
/// is comfortable; below −10 dB is close to what LoRa can still decode.
enum LinkQuality {
  good,
  fair,
  poor,
  unknown;

  static LinkQuality fromSnr(double? snr) => switch (snr) {
    null => unknown,
    >= 0 => good,
    >= -10 => fair,
    _ => poor,
  };

  /// The worse of two, ignoring unknowns.
  LinkQuality worse(LinkQuality other) {
    if (this == unknown) return other;
    if (other == unknown) return this;
    return index > other.index ? this : other;
  }
}

/// The hop hashes, in hex, of [contact]'s stored route: nearest repeater
/// first. Null when the radio has no route and will flood.
List<String>? routeHops(Contact contact) {
  if (contact.outPathLength == pathUnknown) return null;
  final count = contact.outPathLength & 0x3F;
  final size = routeHashBytes(contact);
  if (contact.outPath.length < count * size) return null;
  return [
    for (var i = 0; i < count; i++)
      toHex(contact.outPath.sublist(i * size, (i + 1) * size)),
  ];
}

/// The hash size of [contact]'s route, 1 when it has none.
int routeHashBytes(Contact contact) =>
    contact.outPathLength == pathUnknown ? 1 : (contact.outPathLength >> 6) + 1;

/// [contact]'s own hash at [hashBytes], as repeaters list it on paths.
String nodeHash(Contact contact, int hashBytes) =>
    contact.publicKey.substring(0, hashBytes * 2).toLowerCase();

bool _passesTraces(Contact c) {
  final type = NodeType.fromByte(c.type);
  return type == NodeType.repeater || type == NodeType.room;
}

/// One link on a route, between two neighbouring nodes. [out] is how well
/// [to] heard [from]; [back] is how well [from] heard [to] on the way
/// back. Either is null when it hasn't been measured.
typedef RouteLeg = ({String from, String to, double? out, double? back});

extension RouteLegQuality on RouteLeg {
  LinkQuality get quality =>
      LinkQuality.fromSnr(out).worse(LinkQuality.fromSnr(back));
}

/// The legs of the route to [contact], named with [name] (which gets a hop
/// hash and returns a display name). [you] names this radio. With a
/// [trace] taken along the route by the trace planner, each leg carries the
/// measured signal both ways.
List<RouteLeg> routeLegs(
  Contact contact, {
  required String you,
  required String Function(String hash) name,
  TraceData? trace,
}) {
  final hops = routeHops(contact) ?? const <String>[];
  final nodes = [you, for (final h in hops) name(h), contact.name];
  final legCount = nodes.length - 1;
  // A trace goes out through every hop (and the contact, when it passes
  // traces on) and back the same way. Its signal list is: each node on the
  // way out hearing the one before, then each on the way back, then this
  // radio hearing the first hop.
  final traced = _passesTraces(contact) ? legCount : legCount - 1;
  final snrs = trace == null ? null : [...trace.snrs, trace.finalSnr];
  final fits = snrs != null && traced > 0 && snrs.length == 2 * traced;
  double? out(int leg) => fits && leg < traced ? snrs[leg] : null;
  double? back(int leg) {
    if (!fits || leg >= traced) return null;
    // Leg 0's back signal is the last one; leg k's is 2·traced − 1 − k.
    return snrs[2 * traced - 1 - leg];
  }

  return [
    for (var i = 0; i < legCount; i++)
      (from: nodes[i], to: nodes[i + 1], out: out(i), back: back(i)),
  ];
}

/// Where a route option came from.
enum RouteSource {
  /// The route the radio is using now.
  current,

  /// Built from paths heard on flooded packets.
  heard,

  /// No route: the message floods the whole mesh and the reply teaches the
  /// radio a new route.
  flood,
}

/// A way to reach a contact, rated for reliability.
typedef RouteOption = ({
  List<String> hops,
  int hashBytes,
  RouteSource source,

  /// 0 to 100: higher is more likely to get through.
  int score,

  /// The weakest link with a known quality.
  LinkQuality weakest,

  /// Links on the route that have been seen working (heard on a flooded
  /// packet or measured by a trace), out of [links].
  int seenLinks,
  int links,
});

/// Points off for each hop: every relay is another chance to lose it.
const _hopCost = 8;

/// Rates and ranks the ways to reach [contact]: its current route, routes
/// built from [heard] paths, and flooding. Best first. [trace] is a trace
/// of the current route, if one was taken.
///
/// Heard paths run from where a packet started to this radio, so reversed
/// they're a way out. They're used when they pass through [contact] itself
/// (a repeater or room) or through the repeater next to it on its current
/// route.
List<RouteOption> routeOptions(
  Contact contact,
  List<HeardPathRow> heard, {
  TraceData? trace,
}) {
  final current = routeHops(contact);
  final size = routeHashBytes(contact);
  final links = _linkEvidence(heard);
  final firstHop = {
    for (final r in directRepeaters(heard))
      if (r.averageSnr != null) r.hash.toLowerCase(): r.averageSnr!,
  };
  final measured = current == null
      ? const <RouteLeg>[]
      : routeLegs(contact, you: '', name: (h) => h, trace: trace);

  final candidates = <String, (List<String>, int, RouteSource)>{};
  void add(List<String> hops, int hashBytes, RouteSource source) {
    final key = '$hashBytes:${pathKey(hops)}';
    candidates.putIfAbsent(key, () => (hops, hashBytes, source));
  }

  if (current != null) add(current, size, RouteSource.current);

  final sizes = current == null ? {1, 2, 3} : {size};
  for (final p in heard) {
    if (!sizes.contains(p.hashBytes)) continue;
    final hops = [for (final h in pathHops(p.hops)) h.toLowerCase()];
    // Through the contact itself: the repeaters after it lead here.
    if (_passesTraces(contact)) {
      final at = hops.indexOf(nodeHash(contact, p.hashBytes));
      if (at >= 0) {
        add(
          hops.sublist(at + 1).reversed.toList(),
          p.hashBytes,
          RouteSource.heard,
        );
      }
    }
    // Through the repeater next to the contact on its current route.
    if (current != null && current.isNotEmpty) {
      final anchor = current.last.toLowerCase();
      final at = hops.indexOf(anchor);
      if (at >= 0) {
        add(
          [...hops.sublist(at + 1).reversed, anchor],
          p.hashBytes,
          RouteSource.heard,
        );
      }
    }
  }

  final options = <RouteOption>[
    for (final (hops, hashBytes, source) in candidates.values)
      _rate(
        hops,
        hashBytes,
        source,
        links: links,
        firstHop: firstHop,
        measured: source == RouteSource.current ? measured : const [],
        target: _passesTraces(contact) ? nodeHash(contact, hashBytes) : null,
      ),
    (
      hops: const [],
      hashBytes: size,
      source: RouteSource.flood,
      // Flooding nearly always arrives but costs the whole mesh airtime
      // and takes longer, so a good direct route beats it.
      score: 55,
      weakest: LinkQuality.unknown,
      seenLinks: 0,
      links: 0,
    ),
  ];
  options.sort((a, b) {
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    return a.source.index.compareTo(b.source.index);
  });
  return options;
}

/// The option worth switching to, or null when the current route (or
/// flooding, when there's no route) is already as good as anything else.
RouteOption? suggestedRoute(List<RouteOption> options) {
  if (options.isEmpty) return null;
  final best = options.first;
  final now = options.firstWhere(
    (o) => o.source == RouteSource.current,
    orElse: () => options.firstWhere((o) => o.source == RouteSource.flood),
  );
  if (identical(best, now) || best.score < now.score + 10) return null;
  return best;
}

/// How often each link (from one hop to the next, both lowercase hex) was
/// seen on heard paths.
Map<String, int> _linkEvidence(List<HeardPathRow> heard) {
  final out = <String, int>{};
  for (final p in heard) {
    final hops = [for (final h in pathHops(p.hops)) h.toLowerCase()];
    for (var i = 0; i + 1 < hops.length; i++) {
      // Links work both ways often enough to count either direction.
      final key = _linkKey(hops[i], hops[i + 1]);
      out[key] = (out[key] ?? 0) + p.count;
    }
  }
  return out;
}

String _linkKey(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

RouteOption _rate(
  List<String> hops,
  int hashBytes,
  RouteSource source, {
  required Map<String, int> links,
  required Map<String, double> firstHop,
  required List<RouteLeg> measured,
  String? target,
}) {
  var score = 100 - _hopCost * hops.length;
  var weakest = LinkQuality.unknown;
  var seen = 0;
  // The links this app can judge: you → first hop, then hop to hop, and on
  // to the contact when it's a repeater or room (a person's radio never
  // shows up on a repeater's path, so that last link can't be judged).
  final chain = [...hops, ?target];
  for (var i = 0; i < chain.length; i++) {
    final traced = i < measured.length ? measured[i] : null;
    LinkQuality q;
    if (traced != null && traced.quality != LinkQuality.unknown) {
      q = traced.quality;
    } else if (i == 0) {
      q = LinkQuality.fromSnr(firstHop[chain[0]]);
    } else {
      q = switch (links[_linkKey(chain[i - 1], chain[i])] ?? 0) {
        0 => LinkQuality.unknown,
        1 => LinkQuality.fair,
        _ => LinkQuality.good,
      };
    }
    if (q != LinkQuality.unknown) seen++;
    weakest = weakest.worse(q);
    score -= switch (q) {
      LinkQuality.good => 0,
      LinkQuality.fair => 10,
      LinkQuality.poor => 30,
      LinkQuality.unknown => 15,
    };
  }
  return (
    hops: hops,
    hashBytes: hashBytes,
    source: source,
    score: score.clamp(0, 100),
    weakest: weakest,
    seenLinks: seen,
    links: chain.length,
  );
}

/// Whether [hops] at [hashBytes] fits in a stored route.
bool routeFits(List<String> hops, int hashBytes) =>
    hashBytes >= 1 &&
    hashBytes <= 3 &&
    hops.length < 64 &&
    hops.length * hashBytes <= maxPathSize &&
    hops.every((h) => h.length == hashBytes * 2);

/// [hops] as the bytes of a stored route.
Uint8List routeBytes(List<String> hops) =>
    Uint8List.fromList([for (final h in hops) ...fromHex(h)]);

/// The encoded route length for [hopCount] hops of [hashBytes] each.
int encodeRouteLength(int hopCount, int hashBytes) =>
    ((hashBytes - 1) << 6) | hopCount;
