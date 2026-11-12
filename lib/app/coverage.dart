/// Coverage from wardrive pings: hexagons coloured by the best two-way link
/// heard there, optionally for one repeater, and a radio-horizon check.
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'connection.dart';
import 'wardrive.dart';

/// Hexagon size: centre to corner, in metres.
const coverageHexMetres = 250.0;

const _metresPerDegLat = 110540.0;
const _metresPerDegLon = 111320.0;

/// A hexagon on a flat grid around [origin], by axial coordinates.
typedef Hex = ({int q, int r});

/// The hexagon holding [p]. Longitude is scaled by the origin's latitude,
/// which is plenty accurate across a town or county.
Hex hexOf(LatLng p, LatLng origin, {double size = coverageHexMetres}) {
  final x =
      (p.longitude - origin.longitude) *
      _metresPerDegLon *
      math.cos(origin.latitude * math.pi / 180);
  final y = (p.latitude - origin.latitude) * _metresPerDegLat;
  // Pointy-top axial coordinates, then cube rounding.
  final q = (math.sqrt(3) / 3 * x - y / 3) / size;
  final r = (2 / 3 * y) / size;
  var rx = q.roundToDouble();
  var rz = r.roundToDouble();
  final ry = (-q - r).roundToDouble();
  final dx = (rx - q).abs(), dy = (ry - (-q - r)).abs(), dz = (rz - r).abs();
  if (dx > dy && dx > dz) {
    rx = -ry - rz;
  } else if (dz > dy) {
    rz = -rx - ry;
  }
  return (q: rx.toInt(), r: rz.toInt());
}

/// The six corners of [h].
List<LatLng> hexCorners(
  Hex h,
  LatLng origin, {
  double size = coverageHexMetres,
}) {
  final cx = size * math.sqrt(3) * (h.q + h.r / 2);
  final cy = size * 1.5 * h.r;
  final lonScale = _metresPerDegLon * math.cos(origin.latitude * math.pi / 180);
  return [
    for (var i = 0; i < 6; i++)
      () {
        final a = math.pi / 180 * (60 * i - 30);
        return LatLng(
          origin.latitude + (cy + size * math.sin(a)) / _metresPerDegLat,
          origin.longitude + (cx + size * math.cos(a)) / lonScale,
        );
      }(),
  ];
}

/// One ping with what answered it.
typedef CoveragePing = ({
  LatLng at,
  List<({String repeater, double heardUs, double weHeard})> hits,
});

/// A filled hexagon.
typedef CoverageCell = ({Hex hex, int pings, double? best});

/// Bins [pings] into hexagons. With [repeater], only that repeater's
/// answers count, so the map shows where it heard you.
List<CoverageCell> coverageCells(
  List<CoveragePing> pings,
  LatLng origin, {
  String? repeater,
}) {
  final cells = <Hex, ({int pings, double? best})>{};
  for (final p in pings) {
    final hex = hexOf(p.at, origin);
    final hits = [
      for (final h in p.hits)
        if (repeater == null || h.repeater == repeater)
          (heardUs: h.heardUs, weHeard: h.weHeard),
    ];
    final best = bestLink(hits);
    final old = cells[hex];
    final keep = switch ((old?.best, best)) {
      (null, final b) => b,
      (final a, null) => a,
      (final a!, final b!) => math.max(a, b),
    };
    cells[hex] = (pings: (old?.pings ?? 0) + 1, best: keep);
  }
  return [
    for (final MapEntry(:key, :value) in cells.entries)
      (hex: key, pings: value.pings, best: value.best),
  ];
}

/// Distance to the radio horizon between antennas [h1] and [h2] metres
/// high, in km, using the usual 4/3-earth radius for radio.
double radioHorizonKm(double h1, double h2) =>
    4.12 * (math.sqrt(math.max(h1, 0)) + math.sqrt(math.max(h2, 0)));

/// Radius of the first Fresnel zone at the middle of a [km] link at
/// [mhz], in metres. Keeping most of it clear matters as much as seeing
/// the other antenna.
double fresnelMetres(double km, double mhz) =>
    8.657 * math.sqrt(km / (mhz / 1000));

/// Every ping from every drive, with its answers.
final coveragePingsProvider = FutureProvider<List<CoveragePing>>((ref) async {
  ref.watch(wardrivesProvider);
  final db = ref.watch(databaseProvider);
  final pings = await db.select(db.wardrivePings).get();
  final hits = await db.select(db.wardriveHits).get();
  final byPing =
      <int, List<({String repeater, double heardUs, double weHeard})>>{};
  for (final h in hits) {
    (byPing[h.ping] ??= []).add((
      repeater: h.repeaterKey,
      heardUs: h.heardUs,
      weHeard: h.weHeard,
    ));
  }
  return [
    for (final p in pings)
      (at: LatLng(p.latitude, p.longitude), hits: byPing[p.id] ?? const []),
  ];
});
